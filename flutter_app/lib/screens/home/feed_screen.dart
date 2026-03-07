import 'dart:async';

import 'package:adpopcornreward/adpopcornreward.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/adpopcorn_config.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/viewed_posts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_profile_icon.dart';
import '../../widgets/upload_modal.dart';
import '../post_detail_screen.dart';
import 'notice_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.getAllPosts();
      if (!mounted) return;
      await _checkCharcoalAdoptionDialog(context);
      if (!mounted) return;
      await _checkCoalAdoptionDialog(context);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final dataService = Provider.of<DataService>(context, listen: false);
    if (!dataService.hasMorePosts || dataService.isLoadingMore || dataService.posts.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      dataService.loadMorePosts();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 댓글 채택 알림을 알림 모달 스타일로 표시 (notification tile 스타일)
  Future<void> _showAdoptionModal(
    BuildContext context, {
    required int coinAmount,
    required String postTitle,
    required List<Map<String, dynamic>> adoptable,
    required Future<void> Function(Map<String, dynamic> item) onSelect,
    required String successMessage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdoptionModalContent(
        coinAmount: coinAmount,
        postTitle: postTitle,
        adoptable: adoptable,
        onSelect: onSelect,
        successMessage: successMessage,
      ),
    );
  }

  /// 디버그 전용: 실제 아이템 사용 없이 채택 모달 UI 테스트 (kDebugMode에서만 노출)
  void _showAdoptionModalTest(BuildContext context) {
    const mockAdoptable = [
      {'author': '테스트유저1', 'text': '첫 번째 댓글 내용입니다.', 'commentId': 'mock1', 'commentIndex': 0, 'replyPath': null},
      {'author': '테스트유저2', 'text': '두 번째 댓글 미리보기 텍스트입니다.', 'commentId': 'mock2', 'commentIndex': 1, 'replyPath': null},
      {'author': '테스트유저3', 'text': '세 번째 댓글을 선택한 뒤 확인 버튼을 누르면 채택됩니다.ㅇㄴㅁㄹㅇㅁ놂ㅇㄴ렁널;ㅁㄴ얼;ㅣㅓㅇㄴ;ㅣ러;민어링너;미러;ㅣㅇ넘ㄹ;ㅣㅓㅇㄴ;ㅣㅓㄹ;이널;ㅣㅓㅇㄹ;ㅣㅁ넝리ㅓㅇ니ㅏㅏ', 'commentId': 'mock3', 'commentIndex': 2, 'replyPath': null},
      {'author': '테스트유저4', 'text': '네 번째 댓글입니다. 스크롤 테스트용.', 'commentId': 'mock4', 'commentIndex': 3, 'replyPath': null},
      {'author': '테스트유저5', 'text': '다섯 번째 댓글입니다.', 'commentId': 'mock5', 'commentIndex': 4, 'replyPath': null},
      {'author': '테스트유저6', 'text': '여섯 번째 댓글까지 스크롤할 수 있습니다.', 'commentId': 'mock6', 'commentIndex': 5, 'replyPath': null},
    ];
    _showAdoptionModal(
      context,
      coinAmount: 50,
      postTitle: '[테스트] 채택 모달 확인',
      adoptable: mockAdoptable,
      onSelect: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
      },
      successMessage: '테스트: 댓글을 50코인으로 채택했습니다.',
    );
  }

  /// 목탄 사용 후 24h~48h: 댓글 채택 다이얼로그(50코인), 48h 경과: 랜덤 채택
  Future<void> _checkCharcoalAdoptionDialog(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dataService = Provider.of<DataService>(context, listen: false);
    if (authService.user == null) return;
    final uid = authService.user!.uid;
    final pending = await dataService.getPostsPendingCharcoalAdoption(uid);
    if (pending.isEmpty) return;
    final now = DateTime.now();
    for (final post in pending) {
      final usedAt = post.charcoalUsedAt!;
      final diff = now.difference(usedAt);
      if (diff.inHours >= 48) {
        await dataService.doRandomCharcoalAdoption(post.id, post.authorUid ?? uid);
        if (!mounted) return;
      }
    }
    final again = await dataService.getPostsPendingCharcoalAdoption(uid);
    final toShow = again.where((p) {
      final d = now.difference(p.charcoalUsedAt!);
      return d.inHours >= 24 && d.inHours < 48;
    }).toList();
    if (toShow.isEmpty || !mounted) return;
    final post = toShow.first;
    final freshPost = await dataService.getPost(post.id);
    if (freshPost == null || !mounted) return;
    final adoptable = dataService.getAdoptableCommentsForCharcoal(freshPost, freshPost.authorUid ?? uid);
    if (adoptable.isEmpty) {
      await dataService.doRandomCharcoalAdoption(post.id, post.authorUid ?? uid);
      return;
    }
    if (!mounted) return;
    await _showAdoptionModal(
      context,
      coinAmount: 50,
      postTitle: post.title,
      adoptable: adoptable,
      onSelect: (item) async {
        final replyPath = item['replyPath'] as List<int>?;
        await dataService.acceptCommentCharcoal(
          postId: post.id,
          commentId: item['commentId'] as String,
          commentAuthorUsername: item['author'] as String,
          postAuthorUid: freshPost.authorUid ?? uid,
          commentIndex: item['commentIndex'] as int,
          replyPath: replyPath != null && replyPath.isNotEmpty ? replyPath : null,
        );
      },
      successMessage: '댓글을 50코인으로 채택했습니다.',
    );
  }

  /// 석탄 사용 후 24h~48h: 댓글 채택 다이얼로그(300코인), 48h 경과: 랜덤 채택
  Future<void> _checkCoalAdoptionDialog(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dataService = Provider.of<DataService>(context, listen: false);
    if (authService.user == null) return;
    final uid = authService.user!.uid;
    final pending = await dataService.getPostsPendingCoalAdoption(uid);
    if (pending.isEmpty) return;
    final now = DateTime.now();
    for (final post in pending) {
      final usedAt = post.coalUsedAt!;
      final diff = now.difference(usedAt);
      if (diff.inHours >= 48) {
        await dataService.doRandomCoalAdoption(post.id, post.authorUid ?? uid);
        if (!mounted) return;
      }
    }
    final again = await dataService.getPostsPendingCoalAdoption(uid);
    final toShow = again.where((p) {
      final d = now.difference(p.coalUsedAt!);
      return d.inHours >= 24 && d.inHours < 48;
    }).toList();
    if (toShow.isEmpty || !mounted) return;
    final post = toShow.first;
    final freshPost = await dataService.getPost(post.id);
    if (freshPost == null || !mounted) return;
    final adoptable = dataService.getAdoptableCommentsForCharcoal(freshPost, freshPost.authorUid ?? uid);
    if (adoptable.isEmpty) {
      await dataService.doRandomCoalAdoption(post.id, post.authorUid ?? uid);
      return;
    }
    if (!mounted) return;
    await _showAdoptionModal(
      context,
      coinAmount: 300,
      postTitle: post.title,
      adoptable: adoptable,
      onSelect: (item) async {
        final replyPath = item['replyPath'] as List<int>?;
        await dataService.acceptCommentCoal(
          postId: post.id,
          commentId: item['commentId'] as String,
          commentAuthorUsername: item['author'] as String,
          postAuthorUid: freshPost.authorUid ?? uid,
          commentIndex: item['commentIndex'] as int,
          replyPath: replyPath != null && replyPath.isNotEmpty ? replyPath : null,
        );
      },
      successMessage: '댓글을 300코인으로 채택했습니다.',
    );
  }

  void _openUploadModal() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const UploadModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bottomNavHeight = 60.0;
    const fabBottomMargin = 14.0;
    const fabLowerBy = 100.0; // 글쓰기 버튼을 100px 낮춤

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false, // 하단 SafeArea는 하단바가 처리
        child: Stack(
          children: [
            Consumer<DataService>(
              builder: (context, dataService, _) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await dataService.getAllPosts();
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _FeatureIconsSection()),
                      SliverToBoxAdapter(child: _MissionPreviewSection()),
                      if (kDebugMode)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: GestureDetector(
                              onTap: () => _showAdoptionModalTest(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bug_report, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      '채택 모달 테스트',
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (dataService.isLoading)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (dataService.posts.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: Text('아직 게시물이 없습니다.')),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final post = dataService.posts[index];
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (index > 0)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      child: Container(
                                        height: 1,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6E8F0),
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Consumer<ViewedPostsService>(
                                      builder: (context, viewedPostsService, _) {
                                        final isViewed = viewedPostsService.isViewed(post.id);
                                        return _PostCard(post: post, isViewed: isViewed);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                            childCount: dataService.posts.length,
                          ),
                        ),
                      if (dataService.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 80,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // 하단바 위 글쓰기 버튼 (스토어 사용하기 버튼과 동일 색상)
            Positioned(
              right: 16,
              bottom: (bottomNavHeight + fabBottomMargin + MediaQuery.of(context).padding.bottom - fabLowerBy).clamp(14.0, double.infinity),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openUploadModal,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 모달 스타일의 댓글 채택 UI (notifications_screen 타일과 동일한 디자인)
class _AdoptionModalContent extends StatefulWidget {
  const _AdoptionModalContent({
    required this.coinAmount,
    required this.postTitle,
    required this.adoptable,
    required this.onSelect,
    required this.successMessage,
  });

  final int coinAmount;
  final String postTitle;
  final List<Map<String, dynamic>> adoptable;
  final Future<void> Function(Map<String, dynamic> item) onSelect;
  final String successMessage;

  @override
  State<_AdoptionModalContent> createState() => _AdoptionModalContentState();
}

class _AdoptionModalContentState extends State<_AdoptionModalContent> {
  int? _selectedIndex;
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '아이템을 사용한 게시물의 댓글을 채택해주세요',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: widget.adoptable.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                  final item = widget.adoptable[i];
                  final fullText = item['text'] as String;
                  final preview = fullText.length > 20 ? '${fullText.substring(0, 20)}...' : fullText;
                  final author = item['author'] as String;
                  return _AdoptionCommentTile(
                    author: author,
                    fullText: fullText,
                    preview: preview,
                    isExpanded: _expandedIndex == i,
                    isSelected: _selectedIndex == i,
                    onRowTap: () => setState(() {
                      _expandedIndex = _expandedIndex == i ? null : i;
                    }),
                    onCheckTap: () => setState(() => _selectedIndex = i),
                  );
                },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFE3E5EC)),
                        backgroundColor: const Color(0xFFF5F6FA),
                      ),
                      child: const Text(
                        '나중에',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF555B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedIndex == null
                          ? null
                          : () async {
                              final item = widget.adoptable[_selectedIndex!];
                              Navigator.pop(context);
                              try {
                                await widget.onSelect(item);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(widget.successMessage)),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('채택 실패: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedIndex == null ? Colors.grey : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 타일과 동일 스타일: 흰 배경, 테두리, 아이콘 박스 + 텍스트
class _AdoptionModalTile extends StatelessWidget {
  const _AdoptionModalTile({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: subtitle == null
                  ? Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 채택 가능 댓글 (탭 시 펼쳐서 전체 내용, 선택은 체크 버튼만)
class _AdoptionCommentTile extends StatelessWidget {
  const _AdoptionCommentTile({
    required this.author,
    required this.fullText,
    required this.preview,
    required this.isExpanded,
    required this.isSelected,
    required this.onRowTap,
    required this.onCheckTap,
  });

  final String author;
  final String fullText;
  final String preview;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onRowTap;
  final VoidCallback onCheckTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFE6E8F0),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onRowTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.comment, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isExpanded ? fullText : preview,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: isExpanded ? null : 1,
                            overflow: isExpanded ? null : TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onCheckTap,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isSelected ? Icons.check_circle : Icons.check_circle_outline,
                          color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 기능 아이콘 행
class _FeatureIconsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: AppTheme.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _FeatureIcon(
              icon: Icons.check_circle,
              label: '충전소',
              onTap: () {
                if (!AdPopcornConfig.isConfigured) return;
                final auth = Provider.of<AuthService>(context, listen: false);
                if (!auth.isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인 후 이용할 수 있습니다.')),
                  );
                  return;
                }
                () async {
                  AdPopcornReward.setUserId(auth.user!.uid);
                  AdPopcornReward.setStyle('코인 충전소', '#667eea');
                  AdPopcornReward.openOfferwall();
                }();
              },
            ),
          ),
          Expanded(
            child: _FeatureIcon(
              customIcon: const _MegaphoneIcon(),
              label: '공지',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NoticeScreen(),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _FeatureIcon(
              icon: Icons.privacy_tip,
              label: '개인정보',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _FeatureIcon(
              icon: Icons.description,
              label: '이용약관',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TermsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 메가폰 아이콘 (몸통 + 손잡이만, 앞쪽 막대 3개 없음)
class _MegaphonePainter extends CustomPainter {
  _MegaphonePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 몸통: 혼 형태 (길게, 왼쪽 좁음 ~ 오른쪽 넓음)
    const bodyLeft = 6.0;
    const bodyRight = 21.0;
    const topNarrow = 7.0;
    const bottomNarrow = 15.0;
    const topWide = 4.0;
    const bottomWide = 20.0;

    // U자 손잡이 (왼쪽)
    const uHandleLeft = 0.0;

    // 세로 손잡이 (U자 손잡이 아래, 왼쪽)
    const verticalHandleLeft = 2.5;
    const verticalHandleRight = 4.5;
    const verticalHandleTop = 15.0;
    const verticalHandleBottom = 22.0;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 몸통 + U자 손잡이 (한 경로)
    final bodyPath = Path()
      ..moveTo(uHandleLeft, topNarrow)
      ..lineTo(bodyLeft, topNarrow)
      ..lineTo(bodyRight, topWide)
      ..lineTo(bodyRight, bottomWide)
      ..lineTo(bodyLeft, bottomNarrow)
      ..lineTo(uHandleLeft, bottomNarrow)
      ..close();
    canvas.drawPath(bodyPath, fillPaint);
    canvas.drawPath(bodyPath, strokePaint);

    // 세로 손잡이 (몸통 아래, 얇게)
    final verticalPath = Path()
      ..moveTo(verticalHandleLeft, verticalHandleTop)
      ..lineTo(verticalHandleRight, verticalHandleTop)
      ..lineTo(verticalHandleRight, verticalHandleBottom)
      ..lineTo(verticalHandleLeft, verticalHandleBottom)
      ..close();
    canvas.drawPath(verticalPath, fillPaint);
    canvas.drawPath(verticalPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MegaphonePainter oldDelegate) => oldDelegate.color != color;
}

class _MegaphoneIcon extends StatelessWidget {
  const _MegaphoneIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _MegaphonePainter(color: AppTheme.primaryColor),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback onTap;

  const _FeatureIcon({
    this.icon,
    this.customIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: customIcon ?? Icon(icon, color: AppTheme.primaryColor, size: 24),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 미션 미리보기 섹션 (추첨 결과 표시)
class _MissionPreviewSection extends StatefulWidget {
  @override
  State<_MissionPreviewSection> createState() => _MissionPreviewSectionState();
}

class _MissionPreviewSectionState extends State<_MissionPreviewSection> with WidgetsBindingObserver {
  String? _generalWinner;
  String? _generalWinnerPostId;
  String? _popularWinner;
  String? _popularWinnerPostId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLotteryResults();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 포그라운드로 돌아올 때 당첨 결과 갱신 (오후 5시 당첨 후 반영)
    if (state == AppLifecycleState.resumed) {
      _loadLotteryResults();
    }
  }

  Future<void> _loadLotteryResults() async {
    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      final results = await dataService.getTodayLotteryResults();
      
      if (mounted) {
        setState(() {
          _generalWinner = results['generalWinner'] as String?;
          _generalWinnerPostId = results['generalWinnerPostId'] as String?;
          _popularWinner = results['popularWinner'] as String?;
          _popularWinnerPostId = results['popularWinnerPostId'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('추첨 결과 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _navigateToWinnerPost(String? postId) {
    if (postId == null || postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('당첨 작품을 찾을 수 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset.zero,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Row(
              children: [
                Expanded(
                  child: _LotteryStatItem(
                    label: '일반작품 당첨자',
                    value: _generalWinner ?? '미정',
                    onTap: _generalWinnerPostId != null
                        ? () => _navigateToWinnerPost(_generalWinnerPostId)
                        : null,
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: const Color(0xFFF0F0F0),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: _LotteryStatItem(
                    label: '인기작품 당첨자',
                    value: _popularWinner ?? '미정',
                    onTap: _popularWinnerPostId != null
                        ? () => _navigateToWinnerPost(_popularWinnerPostId)
                        : null,
                  ),
                ),
              ],
            ),
    );
  }
}

class _LotteryStatItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _LotteryStatItem({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null && value != '미정';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isClickable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isClickable 
                            ? AppTheme.primaryColor 
                            : AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isClickable) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final bool isViewed;

  const _PostCard({required this.post, required this.isViewed});

  @override
  Widget build(BuildContext context) {
    final opacity = isViewed ? 0.8 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: post.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const AppProfileIcon(size: 40, iconSize: 24, flat: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            post.author,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isViewed ? const Color(0xFF999999) : AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        Text(
                          DateFormat('yyyy.MM.dd').format(post.date),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 목탄/석탄 사용 시 100%채택 문구, 인기작품이면 불꽃은 그 아래 표시
                  if (post.charcoalUsedAt != null || post.coalUsedAt != null || post.isPopular)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (post.charcoalUsedAt != null || post.coalUsedAt != null)
                          Text(
                            '100%채택',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        if (post.isPopular) ...[
                          if (post.charcoalUsedAt != null) const SizedBox(height: 4),
                          Image.asset(
                            'assets/icons/star.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 24,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            // 제목 (CSS: .post-title) - 긴 제목은 가로 스크롤
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), // CSS: margin: 0.5rem 0
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  post.title,
                  style: TextStyle(
                    fontSize: 17.6,
                    fontWeight: FontWeight.w600,
                    color: isViewed ? const Color(0xFF666666) : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
            // 액션 버튼 (CSS: .post-actions)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // CSS: padding: 0; margin-top: 0.5rem
              child: Consumer<AuthService>(
                builder: (context, authService, _) {
                  // 인기작품이 아니면 작성자 본인만 좋아요 수 표시
                  final isPostOwner = authService.isLoggedIn && 
                      post.author == (authService.userData?['name'] as String? ?? '');
                  final shouldShowLikes = post.isPopular || isPostOwner;
                  
                  return Row(
                    children: [
                      // 좋아요 수 표시 (CSS: .like-count) - 피드에서는 클릭 불가, 숫자만 표시
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: const Color(0xFFFF6B6B), // CSS: fill: #ff6b6b
                            size: 14.4, // CSS: 0.9rem ≈ 14.4px
                          ),
                          if (shouldShowLikes) ...[
                            const SizedBox(width: 4), // CSS: gap: 0.25rem
                            Text(
                              '${post.likes.length}',
                              style: TextStyle(
                                color: AppTheme.textSecondary, // CSS: color: #666
                                fontSize: 14.4, // CSS: 0.9rem
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(width: 16), // CSS: gap: 1rem
                      // 댓글 (CSS: .comment-count)
                      Row(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            color: AppTheme.primaryColor, // CSS: fill: #667eea
                            size: 14.4, // CSS: 0.9rem
                          ),
                          const SizedBox(width: 4), // CSS: gap: 0.25rem
                          Text(
                            '${post.totalCommentCount}',
                            style: TextStyle(
                              color: AppTheme.textSecondary, // CSS: color: #666
                              fontSize: 14.4, // CSS: 0.9rem
                            ),
                          ),
                        ],
                      ),
                      // 태그 (CSS: .post-tags) - 댓글 아이콘 옆에 가로 스크롤로 나열
                      if (post.tags.isNotEmpty) ...[
                        const SizedBox(width: 16), // CSS: gap: 1rem
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: post.tags.map((tag) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F2FF), // CSS: background: #f0f2ff
                                  borderRadius: BorderRadius.circular(15), // CSS: border-radius: 15px
                                ),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor, // CSS: color: #667eea
                                    fontSize: 13.6, // CSS: 0.85rem
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}


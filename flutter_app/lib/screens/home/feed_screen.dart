import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/viewed_posts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_profile_icon.dart';
import '../../widgets/feed_header.dart';
import '../../widgets/upload_modal.dart';
import '../post_detail_screen.dart';
import 'notice_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 채택하기'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '목탄을 사용한 게시물 "${post.title}"의 댓글 중 한 명을 50코인으로 채택해 주세요.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...adoptable.map((item) {
                final text = item['text'] as String;
                final preview = text.length > 20 ? '${text.substring(0, 20)}...' : text;
                return ListTile(
                  title: Text('${item['author']}'),
                  subtitle: Text(preview),
                  dense: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final replyPath = item['replyPath'] as List<int>?;
                    try {
                      await dataService.acceptCommentCharcoal(
                        postId: post.id,
                        commentId: item['commentId'] as String,
                        commentAuthorUsername: item['author'] as String,
                        postAuthorUid: freshPost.authorUid ?? uid,
                        commentIndex: item['commentIndex'] as int,
                        replyPath: replyPath != null && replyPath.isNotEmpty ? replyPath : null,
                      );
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('댓글을 50코인으로 채택했습니다.')),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('채택 실패: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에'),
          ),
        ],
      ),
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 채택하기'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '석탄을 사용한 게시물 "${post.title}"의 댓글 중 한 명을 300코인으로 채택해 주세요.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...adoptable.map((item) {
                final text = item['text'] as String;
                final preview = text.length > 20 ? '${text.substring(0, 20)}...' : text;
                return ListTile(
                  title: Text('${item['author']}'),
                  subtitle: Text(preview),
                  dense: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final replyPath = item['replyPath'] as List<int>?;
                    try {
                      await dataService.acceptCommentCoal(
                        postId: post.id,
                        commentId: item['commentId'] as String,
                        commentAuthorUsername: item['author'] as String,
                        postAuthorUid: freshPost.authorUid ?? uid,
                        commentIndex: item['commentIndex'] as int,
                        replyPath: replyPath != null && replyPath.isNotEmpty ? replyPath : null,
                      );
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('댓글을 300코인으로 채택했습니다.')),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('채택 실패: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        bottom: false, // 하단 SafeArea는 하단바가 처리
        child: Consumer<DataService>(
        builder: (context, dataService, _) {
          return RefreshIndicator(
            onRefresh: () async {
              await dataService.getAllPosts();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                // 프로모션 배너
                SliverToBoxAdapter(
                  child: _PromoBanner(),
                ),
                // 기능 아이콘 행
                SliverToBoxAdapter(
                  child: _FeatureIconsSection(),
                ),
                // 미션 미리보기
                SliverToBoxAdapter(
                  child: _MissionPreviewSection(),
                ),
                // 피드 헤더 (검색 + 업로드)
                SliverToBoxAdapter(
                  child: FeedHeader(
                    onUploadTap: () {
                      // 업로드 버튼 클릭 처리 (기존 프로그램과 동일 - 모달 팝업)
                      final authService = Provider.of<AuthService>(context, listen: false);
                      if (!authService.isLoggedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('로그인이 필요합니다.'),
                          ),
                        );
                        return;
                      }
                      // 업로드 모달 표시
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) => const UploadModal(),
                      );
                    },
                  ),
                ),
                // 게시물 목록
                if (dataService.isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (dataService.posts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('아직 게시물이 없습니다.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = dataService.posts[index];
                          return Consumer<ViewedPostsService>(
                            builder: (context, viewedPostsService, _) {
                              final isViewed = viewedPostsService.isViewed(post.id);
                              return _PostCard(post: post, isViewed: isViewed);
                            },
                          );
                        },
                        childCount: dataService.posts.length,
                      ),
                    ),
                  ),
                // 마지막 게시물이 하단바에 잘리지 않도록 여백 추가
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 80, // SafeArea 하단 + 하단바 높이(60) + 추가 여백(20)
                  ),
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

// 프로모션 배너
class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '그림 커뮤니티',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '다양한 작품을 감상하고 나만의 작품을 공유해보세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              // TODO: 시작하기 동작
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('시작하기'),
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
              icon: Icons.calendar_today,
              label: '출석체크',
              onTap: () {
                // TODO: 출석체크 화면
              },
            ),
          ),
          Expanded(
            child: _FeatureIcon(
              icon: Icons.checklist,
              label: '미션',
              onTap: () {
                // TODO: 미션 화면
              },
            ),
          ),
          Expanded(
            child: _FeatureIcon(
              icon: Icons.shopping_bag,
              label: '스토어',
              onTap: () {
                // TODO: 상점 화면
              },
            ),
          ),
          Expanded(
            child: _FeatureIcon(
              icon: Icons.check_circle,
              label: '충전소',
              onTap: () {
                // TODO: 충전소 화면
              },
            ),
          ),
          Expanded(
            child: _FeatureIcon(
              icon: null, // 커스텀 아이콘 사용
              customIcon: const _SimpleMegaphoneIcon(),
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
        ],
      ),
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

// 심플한 메가폰 아이콘
class _SimpleMegaphoneIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _SimpleMegaphoneIcon({
    this.size = 24,
    this.color = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MegaphonePainter(color: color),
      ),
    );
  }
}

class _MegaphonePainter extends CustomPainter {
  final Color color;

  _MegaphonePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;
    
    // 심플한 메가폰 경로 (오른쪽을 향한 형태)
    final path = Path();
    
    // 원뿔형 벨 부분 (오른쪽, 넓은 부분)
    final bellRightTop = Offset(width * 0.85, height * 0.2);
    final bellRightBottom = Offset(width * 0.85, height * 0.8);
    final bellLeftTop = Offset(width * 0.5, height * 0.3);
    final bellLeftBottom = Offset(width * 0.5, height * 0.7);
    
    // 원뿔형 벨
    path.moveTo(bellLeftTop.dx, bellLeftTop.dy);
    path.lineTo(bellRightTop.dx, bellRightTop.dy);
    path.lineTo(bellRightBottom.dx, bellRightBottom.dy);
    path.lineTo(bellLeftBottom.dx, bellLeftBottom.dy);
    path.close();
    
    // 원통형 몸체 (왼쪽)
    final bodyLeftTop = Offset(width * 0.15, height * 0.4);
    final bodyLeftBottom = Offset(width * 0.15, height * 0.6);
    
    path.moveTo(bellLeftTop.dx, bellLeftTop.dy);
    path.lineTo(bodyLeftTop.dx, bodyLeftTop.dy);
    path.lineTo(bodyLeftBottom.dx, bodyLeftBottom.dy);
    path.lineTo(bellLeftBottom.dx, bellLeftBottom.dy);
    path.close();
    
    // 손잡이 (아래쪽, 더 두껍게)
    final handleStartLeft = Offset(width * 0.18, height * 0.6);
    final handleStartRight = Offset(width * 0.22, height * 0.6);
    final handleEndLeft = Offset(width * 0.3, height * 0.92);
    final handleEndRight = Offset(width * 0.38, height * 0.92);
    final handleMidLeft = Offset(width * 0.24, height * 0.76);
    final handleMidRight = Offset(width * 0.32, height * 0.76);
    
    // 손잡이 왼쪽 경로
    path.moveTo(handleStartLeft.dx, handleStartLeft.dy);
    path.quadraticBezierTo(handleMidLeft.dx, handleMidLeft.dy, handleEndLeft.dx, handleEndLeft.dy);
    // 손잡이 오른쪽 경로
    path.lineTo(handleEndRight.dx, handleEndRight.dy);
    path.quadraticBezierTo(handleMidRight.dx, handleMidRight.dy, handleStartRight.dx, handleStartRight.dy);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 4),
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
    // 본 게시물 스타일 (CSS: .post-card.viewed-post)
    final backgroundColor = isViewed ? const Color(0xFFF5F5F5) : Colors.white;
    final opacity = isViewed ? 0.8 : 1.0;
    
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: post.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
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
                        Text(
                          post.author,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isViewed ? const Color(0xFF999999) : AppTheme.textPrimary, // CSS: .viewed-post .author-name
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
            // 제목 (CSS: .post-title)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), // CSS: margin: 0.5rem 0
              child: Text(
                post.title,
                style: TextStyle(
                  fontSize: 17.6, // CSS: 1.1rem ≈ 17.6px
                  fontWeight: FontWeight.w600, // CSS: font-weight: 600
                  color: isViewed ? const Color(0xFF666666) : AppTheme.textPrimary, // CSS: .viewed-post .post-title
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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




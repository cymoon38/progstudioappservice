import 'dart:async';
import 'dart:io' show Platform;

import 'package:adpopcornreward/adpopcornreward.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/adpopcorn_config.dart';
import '../../services/adpopcorn_ssp_state.dart';
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
                      SliverToBoxAdapter(child: _AdBannerSection()),
                      SliverToBoxAdapter(child: _FeatureIconsSection()),
                      SliverToBoxAdapter(child: _MissionPreviewSection()),
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

// 네이티브 광고 (애드팝콘 SSP) - 상용: 앱키 123870086, 캔버스 캐시 홈 네이티브
// [가이드] 네이티브는 사용자 환경에 맞춰 자동 최적화. width/height를 creationParams로 전달해 화면 크기별 요청( setReactNativeWidth/Height ).
// 플레이스먼트 허용 사이즈 1200x627 → 요청 크기를 이 비율로 맞춰 5002(No Ad) 방지
//
// [가이드] 광고가 나올 때도 있고 안 나올 때도 있는 이유:
// - 광고 재고(fill)는 항상 보장되지 않음. 수요·지역·시간·타깃(adid) 등에 따라 간헐적 노출은 정상.
// - loadAd 실패 시 재호출 금지 (과도한 요청 시 block 사유). 현재 구현은 실패 시 슬롯만 숨김.
// - 5002(No Ad): 서버에 해당 조건의 광고 없음. 콘솔·미디에이션·광고 ID 설정 확인 권장.
//
// [필률 높이기] 안 나오는 경우를 줄이려면 (코드 재호출 X, 아래만 권장):
// 1) 콘솔: 미디에이션에 광고 네트워크 추가, 플로어 가격·타깃 조정, 해당 플레이스먼트 노출 조건 확인.
// 2) 기기: AD_ID 권한·개인맞춤 광고 허용 시 타깃팅 개선으로 필 가능성 상승 (이미 manifest에 AD_ID 반영).
// 3) 플레이스먼트: 네이티브보다 배너가 필이 잘 나오는 경우 있음. 콘솔에서 배너 플레이스먼트 추가 후 테스트 권장.
class _AdBannerSection extends StatefulWidget {
  @override
  State<_AdBannerSection> createState() => _AdBannerSectionState();
}

class _AdBannerSectionState extends State<_AdBannerSection> {
  static const String _viewType = 'AdPopcornSSPNativeView';
  static const String _appKey = '123870086';
  static const String _placementId = 'RMArXdt3NJV48Ph'; // 캔버스 캐시 홈 네이티브

  /// 플레이스먼트 허용 비율 1200:627 유지. 기기 폭에 맞춰 같은 비율로만 스케일.
  static double _heightForWidth(double width) {
    return width * 627 / 1200;
  }

  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    adPopcornNativeAdLoadFailed.addListener(_onLoadFailedChanged);
  }

  void _onLoadFailedChanged() {
    if (!mounted) return;
    if (!adPopcornNativeAdLoadFailed.value) return;
    if (_loadFailed) return; // 이미 실패 상태면 setState 스킵 (중복 방지)
    setState(() => _loadFailed = true);
  }

  @override
  void dispose() {
    adPopcornNativeAdLoadFailed.removeListener(_onLoadFailedChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 앱 중단 원인 확인용: true면 광고 섹션 자체를 숨김 (테스트 후 반드시 false로 복구)
    const bool _hideAdSectionForDebug = false;
    // ignore: dead_code
    if (_hideAdSectionForDebug) return const SizedBox.shrink();
    if (_loadFailed) return const SizedBox.shrink();

    // 실제 이 위젯이 차지하는 가로 폭(버튼 박스와 동일)으로 광고 크기 계산 → 기기/레이아웃이 달라도 같은 비율 유지
    return LayoutBuilder(
      builder: (context, constraints) {
        const double horizontalMargin = 16;
        final contentMaxWidth = constraints.maxWidth;
        final adWidth = (contentMaxWidth - horizontalMargin * 2).clamp(0.0, double.infinity);
        final adHeight = _heightForWidth(adWidth);
        final visibleHeight = adHeight;

        final creationParams = <String, dynamic>{
          'appKey': _appKey,
          'placementId': _placementId,
          if (Platform.isAndroid) ...{
            'width': adWidth.round(),
            'height': adHeight.round(),
          },
        };

        Widget wrapAd(Widget ad) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          width: adWidth,
          height: visibleHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ad,
          ),
        );

        if (Platform.isAndroid) {
          return wrapAd(SizedBox(
            key: ValueKey('native_ad_$_placementId'),
            width: adWidth,
            height: visibleHeight,
            child: AndroidView(
              viewType: _viewType,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ));
        }
        if (Platform.isIOS) {
          return wrapAd(SizedBox(
            key: const ValueKey('native_ad_NATIVE'),
            width: adWidth,
            height: visibleHeight,
            child: UiKitView(
              viewType: _viewType,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ));
        }
        return const SizedBox.shrink();
      },
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


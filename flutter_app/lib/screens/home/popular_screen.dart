import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/data_service.dart';
import '../../services/auth_service.dart';
import '../../services/viewed_posts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_profile_icon.dart';
import '../post_detail_screen.dart';

class PopularScreen extends StatefulWidget {
  const PopularScreen({super.key});

  @override
  State<PopularScreen> createState() => _PopularScreenState();
}

class _PopularScreenState extends State<PopularScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataService>(context, listen: false).getPopularPosts();
    });
  }

  void _handleSearch() {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    Navigator.pushNamed(context, '/search', arguments: q);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null, // 상단 네비게이션은 HomeScreen에서 처리
      body: SafeArea(
        bottom: false, // 하단 SafeArea는 하단바가 처리
        child: Consumer<DataService>(
          builder: (context, dataService, _) {
            if (dataService.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (dataService.popularPosts.isEmpty) {
              return Center(
                child: Text(
                  '아직 인기작품이 없습니다. (좋아요 2개 이상인 작품이 표시됩니다)',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => dataService.getPopularPosts(),
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(), // CSS와 동일하게 스크롤 정지
                slivers: [
                  // 헤더 (CSS: .popular-header)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24, top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment:
                            isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                        children: [
                          // 검색바 (개선: 모바일/데스크톱 공통, 피드 검색바 스타일과 통일)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Container(
                              padding: const EdgeInsets.only(left: 16, right: 4, top: 0, bottom: 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: const Color(0x0F000000),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: '작품 검색',
                                          hintStyle: TextStyle(
                                            color: AppTheme.textTertiary,
                                            fontSize: 15.2,
                                            fontWeight: FontWeight.w200,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                          isDense: true,
                                        ),
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 15.2,
                                        ),
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) => _handleSearch(),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _handleSearch,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.search,
                                          color: AppTheme.primaryColor,
                                          size: 20,
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
                    ),
                  ),
                  // 게시물 리스트 (구분선으로 구분)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = dataService.popularPosts[index];
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
                                  return _PopularPostCard(
                                    post: post,
                                    isViewed: isViewed,
                                    onOpen: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PostDetailScreen(postId: post.id),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: dataService.popularPosts.length,
                    ),
                  ),
                  // 하단 여백 (하단바와 SafeArea 고려)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 60, // 하단바 높이 60
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

class _PopularPostCard extends StatelessWidget {
  final Post post;
  final bool isViewed;
  final VoidCallback onOpen;

  const _PopularPostCard({
    required this.post,
    required this.isViewed,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isViewed ? 0.8 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onOpen,
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
                    if (post.isPopular)
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
                ),
              ),
                // 제목 (CSS: .post-title) - 긴 제목은 가로 스크롤
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    // 좋아요 수 표시 (CSS: .like-count) - 인기작품 페이지는 모든 게시물이 인기작품이므로 항상 표시
                    Consumer<AuthService>(
                      builder: (context, authService, _) {
                        // 인기작품 페이지는 모든 게시물이 인기작품이므로 항상 좋아요 수 표시
                        final shouldShowLikes = post.isPopular;
                        
                        return Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: const Color(0xFFFF6B6B),
                              size: 14.4,
                            ),
                            if (shouldShowLikes) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${post.likes.length}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14.4,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    // 댓글 (CSS: .comment-count)
                    Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          color: AppTheme.primaryColor,
                          size: 14.4,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.totalCommentCount}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14.4,
                          ),
                        ),
                      ],
                    ),
                    // 태그 (CSS: .post-tags) - 댓글 아이콘 옆에 가로 스크롤로 나열
                    if (post.tags.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: post.tags.map((tag) => Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2FF),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 13.6,
                                ),
                              ),
                            )).toList(),
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
      ),
    );
  }
}
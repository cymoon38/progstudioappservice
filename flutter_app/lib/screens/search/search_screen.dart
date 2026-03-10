import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../post_detail_screen.dart';
import '../../widgets/app_profile_icon.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  List<Post> _results = [];
  String _title = '검색 결과';
  String _countText = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _title = '검색 결과';
        _countText = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _title = '"$q" 검색 결과';
      _countText = '';
    });

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      final results = await dataService.searchPosts(q, limit: 50);
      setState(() {
        _results = results;
        _countText = '총 ${results.length}개의 작품을 찾았습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('검색 오류: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          // 인기작품 / 피드와 동일 스타일의 검색바
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
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
                        controller: _controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
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
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _loading ? null : _search,
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
          if (_countText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _countText,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final post = _results[index];
                          return _SearchResultCard(post: post);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final Post post;
  const _SearchResultCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (작성자, 날짜, 인기작품 별표)
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
                              color: AppTheme.textPrimary,
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
                  if (post.popularRewarded)
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
            // 제목 (가로 스크롤)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 17.6,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
            // 하단 액션 영역 (좋아요/댓글 수, 태그)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Color(0xFFFF6B6B),
                        size: 14.4,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes.length}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.comment_outlined,
                        color: AppTheme.primaryColor,
                        size: 14.4,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.totalCommentCount}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14.4,
                        ),
                      ),
                    ],
                  ),
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: post.tags
                              .map(
                                (tag) => Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
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
                                ),
                              )
                              .toList(),
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




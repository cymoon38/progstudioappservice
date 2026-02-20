import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/viewed_posts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_profile_icon.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _isLoading = true;
  final _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReplyForms = {};

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final viewedPostsService = Provider.of<ViewedPostsService>(context, listen: false);
      final post = await dataService.getPost(widget.postId);
      
      // 조회수 증가 (로그인한 사용자만, 기존 프로그램과 동일)
      if (post != null && authService.isLoggedIn) {
        await dataService.incrementViews(widget.postId);
        // 본 게시물로 표시 (기존 프로그램과 동일)
        await viewedPostsService.markAsViewed(widget.postId);
        // 조회수 증가 후 다시 로드
        final updatedPost = await dataService.getPost(widget.postId);
        if (mounted && updatedPost != null) {
          setState(() {
            _post = updatedPost;
            _isLoading = false;
          });
          return;
        }
      }
      
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
        // 본 게시물로 표시 (로그인하지 않은 사용자도 표시)
        if (post != null) {
          await viewedPostsService.markAsViewed(widget.postId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시물 로드 실패: $e')),
        );
      }
    }
  }

  // 표시할 좋아요 수 계산 (인기작품이 아니면 작성자 본인만 표시)
  int _getDisplayLikesCount(Post post, AuthService authService) {
    // 인기작품이면 모든 사용자에게 실제 좋아요 수 표시
    if (post.isPopular) {
      return post.likes.length;
    }
    
    // 인기작품이 아니면 작성자 본인만 실제 좋아요 수 표시
    final isPostOwner = authService.isLoggedIn && 
        post.author == (authService.userData?['name'] as String? ?? '');
    
    return isPostOwner ? post.likes.length : 0;
  }

  Future<void> _toggleLike() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (_post == null) return;

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      final username = authService.userData?['name'] as String? ?? 
          authService.user!.displayName ?? '익명';
      
      final isLiked = _post!.likes.contains(username);
      
      // 이미 좋아요를 눌렀다면 취소 불가 (일반 게시물 포함)
      if (isLiked) {
        return; // 알림 없이 그냥 반환
      }
      
      // 즉시 UI 업데이트 (네트워크 요청 전에)
      final updatedLikes = List<String>.from(_post!.likes);
      updatedLikes.add(username);
      
      if (mounted) {
        setState(() {
          _post = Post(
            id: _post!.id,
            author: _post!.author,
            authorUid: _post!.authorUid,
            title: _post!.title,
            caption: _post!.caption,
            imageUrl: _post!.imageUrl,
            originalImageUrl: _post!.originalImageUrl,
            compressedImageUrl: _post!.compressedImageUrl,
            tags: _post!.tags,
            likes: updatedLikes,
            comments: _post!.comments,
            date: _post!.date,
            views: _post!.views,
            type: _post!.type,
            originalPostId: _post!.originalPostId,
            isPopular: _post!.isPopular,
            coins: _post!.coins,
          );
        });
      }
      
      // 백그라운드에서 Firestore 업데이트 (블로킹하지 않음)
      dataService.toggleLike(
        widget.postId, 
        authService.user!.uid,
        username,
      ).catchError((e) {
        debugPrint('좋아요 업데이트 오류 (무시): $e');
        // 오류 발생 시 원래 상태로 복구
        if (mounted) {
          setState(() {
            _post = _post; // 원래 상태 유지
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 처리 실패: $e')),
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // 키보드 닫기
    FocusScope.of(context).unfocus();

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.addComment(
        widget.postId,
        authService.user!.uid,
        authService.userData?['name'] ?? authService.user!.displayName ?? '익명',
        text,
      );
      
      _commentController.clear();
      await _loadPost();
    } catch (e) {
      debugPrint('❌ 댓글 작성 오류 (UI): $e');
      String errorMessage = '댓글 작성 실패: $e';
      
      // Firestore 권한 오류인 경우 더 명확한 메시지 표시
      if (e.toString().contains('permission') || 
          e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('허가')) {
        errorMessage = '댓글 작성 권한이 없습니다. Firebase Console의 Firestore 보안 규칙을 확인해주세요.';
      }
      
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
      );
      }
    }
  }

  void _toggleReplyForm(int commentIndex, [List<int>? replyPath]) {
    final key = replyPath == null 
        ? 'comment_$commentIndex' 
        : 'comment_${commentIndex}_${replyPath.join('_')}';
    
    setState(() {
      _showReplyForms[key] = !(_showReplyForms[key] ?? false);
      if (_showReplyForms[key] == true && !_replyControllers.containsKey(key)) {
        _replyControllers[key] = TextEditingController();
      }
    });
  }

  Future<void> _addReply(int commentIndex, [List<int>? replyPath]) async {
    final key = replyPath == null 
        ? 'comment_$commentIndex' 
        : 'comment_${commentIndex}_${replyPath.join('_')}';
    
    final controller = _replyControllers[key];
    if (controller == null) return;
    
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // 키보드 닫기
    FocusScope.of(context).unfocus();

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.addReply(
        widget.postId,
        authService.user!.uid,
        authService.userData?['name'] ?? authService.user!.displayName ?? '익명',
        text,
        commentIndex,
        replyPath,
      );
      
      controller.clear();
      _toggleReplyForm(commentIndex, replyPath);
      await _loadPost();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('답글 작성 실패: $e')),
      );
    }
  }

  Future<void> _deleteComment(int commentIndex) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.deleteComment(widget.postId, commentIndex);
      await _loadPost();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 삭제 실패: $e')),
      );
    }
  }

  Future<void> _deleteReply(int commentIndex, List<int> replyPath) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.deleteReply(widget.postId, commentIndex, replyPath);
      await _loadPost();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('답글 삭제 실패: $e')),
      );
    }
  }

  // 댓글 채택 즉시 UI 업데이트
  void _updateCommentAccepted(int commentIndex, int coinAmount) {
    if (_post == null) return;
    
    setState(() {
      final updatedComments = List<Comment>.from(_post!.comments);
      if (commentIndex < updatedComments.length) {
        final comment = updatedComments[commentIndex];
        updatedComments[commentIndex] = Comment(
          id: comment.id,
          author: comment.author,
          authorUid: comment.authorUid,
          text: comment.text,
          createdAt: comment.createdAt,
          replies: comment.replies,
          isAccepted: true,
          acceptedCoinAmount: coinAmount,
        );
        _post = Post(
          id: _post!.id,
          author: _post!.author,
          authorUid: _post!.authorUid,
          title: _post!.title,
          caption: _post!.caption,
          imageUrl: _post!.imageUrl,
          originalImageUrl: _post!.originalImageUrl,
          compressedImageUrl: _post!.compressedImageUrl,
          tags: _post!.tags,
          likes: _post!.likes,
          comments: updatedComments,
          date: _post!.date,
          views: _post!.views,
          type: _post!.type,
          originalPostId: _post!.originalPostId,
          isPopular: _post!.isPopular,
          coins: _post!.coins,
        );
      }
    });
  }

  // 대댓글 채택 즉시 UI 업데이트
  void _updateReplyAccepted(int commentIndex, List<int> replyPath, int coinAmount) {
    if (_post == null) return;

    setState(() {
      final updatedComments = List<Comment>.from(_post!.comments);
      if (commentIndex < updatedComments.length) {
        final comment = updatedComments[commentIndex];
        
        // 대댓글 업데이트 헬퍼 함수
        List<Comment> updateReplies(List<Comment> replies, List<int> path, int currentIndex) {
          if (path.isEmpty) return replies;
          
          return replies.asMap().entries.map((entry) {
            final idx = entry.key;
            final reply = entry.value;
            
            if (path.length == 1 && path[0] == idx) {
              // 이 대댓글이 채택 대상
              return Comment(
                id: reply.id,
                author: reply.author,
                authorUid: reply.authorUid,
                text: reply.text,
                createdAt: reply.createdAt,
                replies: reply.replies,
                isAccepted: true,
                acceptedCoinAmount: coinAmount,
              );
            } else if (path.length > 1 && path[0] == idx) {
              // 중첩 대댓글
              return Comment(
                id: reply.id,
                author: reply.author,
                authorUid: reply.authorUid,
                text: reply.text,
                createdAt: reply.createdAt,
                replies: updateReplies(reply.replies, path.sublist(1), 0),
                isAccepted: reply.isAccepted,
                acceptedCoinAmount: reply.acceptedCoinAmount,
              );
            }
            return reply;
          }).toList();
        }
        
        updatedComments[commentIndex] = Comment(
          id: comment.id,
          author: comment.author,
          authorUid: comment.authorUid,
          text: comment.text,
          createdAt: comment.createdAt,
          replies: updateReplies(comment.replies, replyPath, 0),
          isAccepted: comment.isAccepted,
          acceptedCoinAmount: comment.acceptedCoinAmount,
        );
        
            _post = Post(
              id: _post!.id,
              author: _post!.author,
              authorUid: _post!.authorUid,
              title: _post!.title,
              caption: _post!.caption,
              imageUrl: _post!.imageUrl,
              originalImageUrl: _post!.originalImageUrl,
              compressedImageUrl: _post!.compressedImageUrl,
              tags: _post!.tags,
              likes: _post!.likes,
              comments: updatedComments,
              date: _post!.date,
              views: _post!.views,
              type: _post!.type,
              originalPostId: _post!.originalPostId,
              isPopular: _post!.isPopular,
              coins: _post!.coins,
            );
      }
    });
  }

  Future<void> _deletePost() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (_post == null) return;

    // 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('정말 이 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 즉시 UI 업데이트 (낙관적 업데이트)
    if (mounted) {
      Navigator.pop(context); // 게시물 상세 화면 즉시 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물이 삭제되었습니다.')),
      );
    }

    // 백그라운드에서 실제 삭제 작업 수행 (블로킹하지 않음)
    final dataService = Provider.of<DataService>(context, listen: false);
    dataService.deletePost(widget.postId).catchError((e) {
      debugPrint('게시물 삭제 오류 (무시): $e');
      // 삭제 실패 시 사용자에게 알림 (선택적)
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('게시물 삭제 실패: $e')),
      // );
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('게시물 상세')),
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('게시물')),
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(child: Text('게시물을 찾을 수 없습니다.')),
      );
    }

    final post = _post!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final username = authService.userData?['name'] as String? ?? '';
    final isLiked = authService.isLoggedIn && post.likes.contains(username);
    final isPostOwner = authService.isLoggedIn && 
        post.author == (authService.userData?['name'] as String? ?? '');
    final isAdmin = authService.isAdmin();

    return Scaffold(
      appBar: AppBar(
        title: Text(post.type == 'notice' ? '공지사항' : '게시물 상세'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          // 게시물 삭제 버튼
          // - 일반 게시물: 작성자만
          // - 공지사항: 운영자만
          if ((isPostOwner && post.type != 'notice') || (isAdmin && post.type == 'notice'))
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
              tooltip: post.type == 'notice' ? '공지사항 삭제' : '게시물 삭제',
            ),
        ],
      ),
      backgroundColor: Colors.white, // 배경을 흰색으로 변경
      body: SingleChildScrollView(
        child: Container(
          margin: post.type == 'notice' ? EdgeInsets.zero : const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: post.type == 'notice' ? BorderRadius.zero : BorderRadius.circular(15),
            // 입체감 제거: boxShadow 제거
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 (공지글이 아닌 경우에만 표시) - 여백 없음
              if (post.type != 'notice') ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const AppProfileIcon(size: 24, iconSize: 16, flat: true),
                            const SizedBox(width: 8),
                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  post.author,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy.MM.dd').format(post.date),
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 14.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // 제목 섹션 - 여백 없음
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 28.8,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '조회수 ${post.views}',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 14.4,
                      ),
                    ),
                  ],
                ),
              ),
              // 태그 - 여백 없음
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.tags.map((tag) => Container(
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
              ],
              // 공지글이 아닌 경우에만 이미지 표시
              if (post.type != 'notice') ...[
                const SizedBox(height: 24),
                // 제목과 게시물 내용 구분선 - 여백 없음
                const Divider(
                  color: Color(0xFFF0F0F0),
                  thickness: 2,
                  height: 1,
                ),
                const SizedBox(height: 24),
                // 이미지 컨테이너 (크기 확대) - 여백 있음
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: 400, // CSS: min-height: 300px (더 크게)
                        maxHeight: MediaQuery.of(context).size.height * 0.7, // CSS: max-height: 70vh
                      ),
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: post.compressedImageUrl ?? post.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: 400, // 더 큰 플레이스홀더
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 400, // 더 큰 에러 위젯
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                ),
                // 모작인 경우 원본 그림 표시 (모든 사용자가 볼 수 있음) - 여백 있음
                if (post.type == 'recreation' && post.originalImageUrl != null && post.originalImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24), // CSS: margin-bottom: 1.5rem
                      padding: const EdgeInsets.all(16), // CSS: padding: 1rem
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF), // CSS: background: #f8f9ff
                        borderRadius: BorderRadius.circular(10), // CSS: border-radius: 10px
                        border: Border.all(
                          color: const Color(0xFFE0E0E0), // CSS: border-color: #e0e0e0
                          width: 2, // CSS: border: 2px solid
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '원본 그림',
                            style: TextStyle(
                              fontSize: 16, // CSS: font-size: 1rem
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor, // CSS: color: #667eea
                            ),
                          ),
                          const SizedBox(height: 12), // CSS: margin-bottom: 0.75rem
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8), // CSS: border-radius: 8px
                            child: CachedNetworkImage(
                              imageUrl: post.originalImageUrl!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                height: 300,
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 300,
                                color: Colors.grey[200],
                                child: const Icon(Icons.error),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
              // 설명 - 여백 있음
              if (post.caption != null && post.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    post.caption!,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ),
              if (post.caption != null && post.caption!.isNotEmpty)
                const SizedBox(height: 24),
              // 공지글이 아닌 경우에만 좋아요/댓글 버튼 표시 - 여백 없음
              if (post.type != 'notice') ...[
                // 액션 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _LikeButton(
                        isLiked: isLiked,
                        likesCount: _getDisplayLikesCount(post, authService),
                        onTap: authService.isLoggedIn ? _toggleLike : null,
                      ),
                      const SizedBox(width: 24),
                      _CommentButton(commentsCount: post.totalCommentCount),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // 공지글이 아닌 경우에만 댓글 섹션 표시 - 여백 없음
              if (post.type != 'notice')
                Container(
                padding: const EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFFF0F0F0),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 댓글 제목 - 여백 없음
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '댓글',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 댓글 폼 - 여백 없음
                    if (authService.isLoggedIn) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _commentController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: '댓글을 입력하세요...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: AppTheme.gradientButtonDecoration,
                          child: ElevatedButton(
                            onPressed: _addComment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text('댓글 작성'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // 댓글 목록 - 여백 없음
                    if (post.comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                        child: Center(
                          child: Text(
                            '아직 댓글이 없습니다.',
                            style: TextStyle(color: AppTheme.textTertiary),
                          ),
                        ),
                      )
                    else
                      ...post.comments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final comment = entry.value;
                        // 채택된 댓글/대댓글 수 계산 (재귀적으로)
                        int countAccepted(Comment comment) {
                          int count = comment.isAccepted ? 1 : 0;
                          for (final reply in comment.replies) {
                            count += countAccepted(reply);
                          }
                          return count;
                        }
                        int acceptedCount = 0;
                        for (final comment in post.comments) {
                          acceptedCount += countAccepted(comment);
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _CommentItem(
                            comment: comment,
                            commentIndex: index,
                            postId: widget.postId,
                            postAuthor: post.author,
                            postAuthorUid: post.authorUid,
                            acceptedCount: acceptedCount,
                            onToggleReply: () => _toggleReplyForm(index),
                            onAddReply: () => _addReply(index),
                            onDeleteComment: () => _deleteComment(index),
                            onDeleteReply: (replyPath) => _deleteReply(index, replyPath),
                            showReplyForm: _showReplyForms['comment_$index'] ?? false,
                            replyController: _replyControllers['comment_$index'],
                            onToggleNestedReply: (path) => _toggleReplyForm(index, path),
                            onAddNestedReply: (path) => _addReply(index, path),
                            showNestedReplyForms: _showReplyForms,
                            nestedReplyControllers: _replyControllers,
                            onPostUpdated: _loadPost,
                            onCommentAccepted: _updateCommentAccepted,
                            onReplyAccepted: _updateReplyAccepted,
                          ),
                        );
                      }),
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

// 좋아요 버튼
class _LikeButton extends StatelessWidget {
  final bool isLiked;
  final int likesCount;
  final VoidCallback? onTap;

  const _LikeButton({
    required this.isLiked,
    required this.likesCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLiked ? null : onTap, // 이미 좋아요를 눌렀다면 클릭 불가
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isLiked ? const Color(0xFFFF6B6B) : Colors.transparent,
            border: Border.all(
              color: isLiked ? const Color(0xFFE74C3C) : const Color(0xFFE0E0E0),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite,
                color: isLiked ? Colors.white : const Color(0xFFFF6B6B),
                size: 16,
              ),
              if (likesCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$likesCount',
                  style: TextStyle(
                    color: isLiked ? Colors.white : AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// 댓글 버튼
class _CommentButton extends StatelessWidget {
  final int commentsCount;

  const _CommentButton({required this.commentsCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.comment_outlined,
            color: AppTheme.primaryColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$commentsCount',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// 댓글 아이템 (재귀적 답글 포함)
class _CommentItem extends StatelessWidget {
  final Comment comment;
  final int commentIndex;
  final String postId;
  final String postAuthor;
  final String? postAuthorUid;
  final int acceptedCount;
  final VoidCallback onToggleReply;
  final VoidCallback onAddReply;
  final VoidCallback onDeleteComment;
  final Function(List<int>) onDeleteReply;
  final bool showReplyForm;
  final TextEditingController? replyController;
  final Function(List<int>)? onToggleNestedReply;
  final Function(List<int>)? onAddNestedReply;
  final Map<String, bool>? showNestedReplyForms;
  final Map<String, TextEditingController>? nestedReplyControllers;
  final VoidCallback onPostUpdated;
  final Function(int, int)? onCommentAccepted; // 즉시 UI 업데이트용 (commentIndex, coinAmount)
  final Function(int, List<int>, int)? onReplyAccepted; // 대댓글 즉시 UI 업데이트용 (commentIndex, replyPath, coinAmount)

  const _CommentItem({
    required this.comment,
    required this.commentIndex,
    required this.postId,
    required this.postAuthor,
    this.postAuthorUid,
    required this.acceptedCount,
    required this.onToggleReply,
    required this.onAddReply,
    required this.onDeleteComment,
    required this.onDeleteReply,
    required this.showReplyForm,
    this.replyController,
    this.onToggleNestedReply,
    this.onAddNestedReply,
    this.showNestedReplyForms,
    this.nestedReplyControllers,
    required this.onPostUpdated,
    this.onCommentAccepted,
    this.onReplyAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOwner = authService.isLoggedIn &&
        comment.author == (authService.userData?['name'] as String? ?? '');
    final isPostAuthor = authService.isLoggedIn &&
        postAuthor == (authService.userData?['name'] as String? ?? '');
    final isAccepted = comment.isAccepted;
    // 본인 댓글은 채택 불가
    final canAccept = isPostAuthor && !isAccepted && !isOwner;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 댓글 메인
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 댓글 헤더
              Row(
                children: [
                  Text(
                    comment.author,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                  // 채택 표시 - 아이디 옆에 표시
                  if (isAccepted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '채택됨',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (comment.acceptedCoinAmount != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${comment.acceptedCoinAmount}코인',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // 채택하기 버튼 - 게시물 작성자만, 아직 채택되지 않은 경우만, 본인 댓글 아님, 최대 3명까지
                  if (canAccept && acceptedCount < 3) ...[
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAcceptCommentDialog(context),
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '채택하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('yyyy.MM.dd').format(comment.createdAt),
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 13.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 댓글 내용
              Text(
                comment.text,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          // 댓글 액션
          if (authService.isLoggedIn || isOwner) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (authService.isLoggedIn)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onToggleReply,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        child: Text(
                          '답글',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 14.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (isOwner)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onDeleteComment,
                      borderRadius: BorderRadius.circular(5),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          // 답글 입력 폼
          if (showReplyForm && replyController != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFD0D2FF),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: replyController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: AppTheme.gradientButtonDecoration,
                          child: ElevatedButton(
                            onPressed: onAddReply,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              '작성',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            replyController?.clear();
                            onToggleReply();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 14.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // 답글 목록 (재귀적 렌더링)
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.only(top: 24, bottom: 16),
              padding: const EdgeInsets.only(left: 32, top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFE8E8E8),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comment.replies.asMap().entries.map((entry) {
                  final replyIndex = entry.key;
                  final reply = entry.value;
                  final path = [replyIndex];
                  final key = 'comment_${commentIndex}_${path.join('_')}';
                  return _ReplyItem(
                    reply: reply,
                    commentIndex: commentIndex,
                    replyPath: path,
                    onToggleReply: onToggleNestedReply ?? (path) {},
                    onAddReply: onAddNestedReply ?? (path) {},
                    onDeleteReply: onDeleteReply,
                    showReplyForm: showNestedReplyForms?[key] ?? false,
                    replyController: nestedReplyControllers?[key],
                    postId: postId,
                    postAuthor: postAuthor,
                    postAuthorUid: postAuthorUid,
                    acceptedCount: acceptedCount,
                    onPostUpdated: onPostUpdated,
                    showNestedReplyForms: showNestedReplyForms,
                    nestedReplyControllers: nestedReplyControllers,
                    onReplyAccepted: onReplyAccepted, // _CommentItem에서 전달받은 콜백 전달
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAcceptCommentDialog(BuildContext context) {
    int? selectedCoinAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 그라데이션 헤더
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '댓글 채택',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '지급할 코인 양을 입력하세요',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 코인 선택 드롭다운
                  DropdownButtonFormField<int>(
                    value: selectedCoinAmount,
                    decoration: InputDecoration(
                      labelText: '코인 선택',
                      prefixIcon: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'C',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 50,
                        child: Text('50 코인'),
                      ),
                      DropdownMenuItem(
                        value: 100,
                        child: Text('100 코인'),
                      ),
                      DropdownMenuItem(
                        value: 200,
                        child: Text('200 코인'),
                      ),
                      DropdownMenuItem(
                        value: 300,
                        child: Text('300 코인'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCoinAmount = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: AppTheme.gradientButtonDecoration,
                          child: ElevatedButton(
                            onPressed: selectedCoinAmount == null
                                ? null
                                : () async {
                                    Navigator.of(dialogContext).pop();
                                    await _acceptComment(context, selectedCoinAmount!);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: const Text(
                              '채택하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptComment(BuildContext context, int coinAmount) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn || postAuthorUid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    // 코인 잔액 확인
    final userCoins = authService.userData?['coins'] ?? 0;
    final currentCoins = userCoins is int ? userCoins : int.tryParse('$userCoins') ?? 0;
    if (currentCoins < coinAmount) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('코인이 부족합니다. (보유: $currentCoins 코인)')),
        );
      }
      return;
    }
    try {
      // 즉시 UI 업데이트 (로컬 상태 먼저 업데이트)
      if (onCommentAccepted != null) {
        onCommentAccepted!(commentIndex, coinAmount);
      }

      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.acceptComment(
        postId: postId,
        commentId: comment.id,
        commentAuthorUsername: comment.author,
        coinAmount: coinAmount,
        postAuthorUid: postAuthorUid!,
      );

      // 코인 잔액 업데이트
      await authService.updateCoinBalance();

      // 게시물 새로고침 (백그라운드에서)
      onPostUpdated();

      if (context.mounted) {
        final actualCoinAmount = (coinAmount * 0.9).round();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글이 채택되었습니다. ${actualCoinAmount}코인이 지급되었습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 채택 실패: $e')),
        );
      }
    }
  }
}

// 답글 아이템 (재귀적)
class _ReplyItem extends StatelessWidget {
  final Comment reply;
  final int commentIndex;
  final List<int> replyPath;
  final Function(List<int>) onToggleReply;
  final Function(List<int>) onAddReply;
  final Function(List<int>) onDeleteReply;
  final bool showReplyForm;
  final TextEditingController? replyController;
  final Map<String, bool>? showNestedReplyForms;
  final Map<String, TextEditingController>? nestedReplyControllers;
  final String postId;
  final String postAuthor;
  final String? postAuthorUid;
  final int acceptedCount;
  final VoidCallback onPostUpdated;
  final Function(int, List<int>, int)? onReplyAccepted; // 즉시 UI 업데이트용 (commentIndex, replyPath, coinAmount)

  const _ReplyItem({
    required this.reply,
    required this.commentIndex,
    required this.replyPath,
    required this.onToggleReply,
    required this.onAddReply,
    required this.onDeleteReply,
    this.showReplyForm = false,
    this.replyController,
    this.showNestedReplyForms,
    this.nestedReplyControllers,
    required this.postId,
    required this.postAuthor,
    this.postAuthorUid,
    required this.acceptedCount,
    required this.onPostUpdated,
    this.onReplyAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOwner = authService.isLoggedIn &&
        reply.author == (authService.userData?['name'] as String? ?? '');
    final isPostAuthor = authService.isLoggedIn &&
        postAuthor == (authService.userData?['name'] as String? ?? '');
    final isAccepted = reply.isAccepted;
    // 본인 대댓글은 채택 불가
    final canAccept = isPostAuthor && !isAccepted && !isOwner;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 답글 내용
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reply.author,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                  // 채택 표시 - 아이디 옆에 표시
                  if (isAccepted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '채택됨',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (reply.acceptedCoinAmount != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${reply.acceptedCoinAmount}코인',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // 채택하기 버튼 - 게시물 작성자만, 아직 채택되지 않은 경우만, 본인 대댓글 아님, 최대 3명까지
                  if (canAccept && acceptedCount < 3) ...[
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAcceptReplyDialog(context),
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '채택하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // 채택된 경우 날짜 표시하지 않음 (overflow 방지)
                  if (!isAccepted) ...[
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('yyyy.MM.dd').format(reply.createdAt),
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 13.6,
                    ),
                  ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reply.text,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          // 답글 액션
          if (authService.isLoggedIn || isOwner) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (authService.isLoggedIn)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onToggleReply(replyPath),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        child: Text(
                          '답글',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 14.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (isOwner)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onDeleteReply(replyPath),
                      borderRadius: BorderRadius.circular(5),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          // 답글 입력 폼
          if (showReplyForm && replyController != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFD0D2FF),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: replyController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: AppTheme.gradientButtonDecoration,
                          child: ElevatedButton(
                            onPressed: () => onAddReply(replyPath),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              '작성',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            replyController?.clear();
                            onToggleReply(replyPath);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 14.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // 중첩 답글 목록
          if (reply.replies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.only(left: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: reply.replies.asMap().entries.map((entry) {
                  final nestedIndex = entry.key;
                  final nestedReply = entry.value;
                  final nestedPath = [...replyPath, nestedIndex];
                  final key = 'comment_${commentIndex}_${nestedPath.join('_')}';
                  return _ReplyItem(
                    reply: nestedReply,
                    commentIndex: commentIndex,
                    replyPath: nestedPath,
                    onToggleReply: onToggleReply,
                    onAddReply: onAddReply,
                    onDeleteReply: onDeleteReply,
                    showReplyForm: showNestedReplyForms?[key] ?? false,
                    replyController: nestedReplyControllers?[key],
                    showNestedReplyForms: showNestedReplyForms,
                    nestedReplyControllers: nestedReplyControllers,
                    postId: postId,
                    postAuthor: postAuthor,
                    postAuthorUid: postAuthorUid,
                    acceptedCount: acceptedCount,
                    onPostUpdated: onPostUpdated,
                    onReplyAccepted: onReplyAccepted, // 상위에서 전달받은 콜백 전달
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAcceptReplyDialog(BuildContext context) {
    int? selectedCoinAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 그라데이션 헤더
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '대댓글 채택',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '지급할 코인 양을 입력하세요',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 코인 선택 드롭다운
                  DropdownButtonFormField<int>(
                    value: selectedCoinAmount,
                    decoration: InputDecoration(
                      labelText: '코인 선택',
                      prefixIcon: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'C',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 50,
                        child: Text('50 코인'),
                      ),
                      DropdownMenuItem(
                        value: 100,
                        child: Text('100 코인'),
                      ),
                      DropdownMenuItem(
                        value: 200,
                        child: Text('200 코인'),
                      ),
                      DropdownMenuItem(
                        value: 300,
                        child: Text('300 코인'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCoinAmount = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: AppTheme.gradientButtonDecoration,
                          child: ElevatedButton(
                            onPressed: selectedCoinAmount == null
                                ? null
                                : () async {
                                    Navigator.of(dialogContext).pop();
                                    await _acceptReply(context, selectedCoinAmount!);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: const Text(
                              '채택하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptReply(BuildContext context, int coinAmount) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn || postAuthorUid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    // 코인 잔액 확인
    final userCoins = authService.userData?['coins'] ?? 0;
    final currentCoins = userCoins is int ? userCoins : int.tryParse('$userCoins') ?? 0;
    if (currentCoins < coinAmount) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('코인이 부족합니다. (보유: $currentCoins 코인)')),
        );
      }
      return;
    }
    try {
      // 즉시 UI 업데이트 (로컬 상태 먼저 업데이트)
      if (onReplyAccepted != null) {
        onReplyAccepted!(commentIndex, replyPath, coinAmount);
      }

      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.acceptComment(
        postId: postId,
        commentId: reply.id,
        commentAuthorUsername: reply.author,
        coinAmount: coinAmount,
        postAuthorUid: postAuthorUid!,
        commentIndex: commentIndex,
        replyPath: replyPath,
      );

      // 코인 잔액 업데이트
      await authService.updateCoinBalance();

      // 게시물 새로고침 (백그라운드에서)
      onPostUpdated();

      if (context.mounted) {
        final actualCoinAmount = (coinAmount * 0.9).round();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('대댓글이 채택되었습니다. ${actualCoinAmount}코인이 지급되었습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('대댓글 채택 실패: $e')),
        );
      }
    }
  }
}

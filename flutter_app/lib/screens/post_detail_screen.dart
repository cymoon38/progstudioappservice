import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/viewed_posts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_profile_icon.dart';
import '../widgets/ban_dialog.dart';

Future<void> _showBanConfirmDialog(
  BuildContext context, {
  required String targetUid,
  required String targetName,
  required Duration duration,
}) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  if (!authService.isAdmin()) {
    return;
  }

  final days = duration.inDays;
  final label = days == 1 ? '1일' : days == 7 ? '7일' : '${days}일';

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '차단하기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$targetName 님을 $label 동안 차단하시겠습니까?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF111827),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '차단 기간 동안 게시물/댓글/대댓글 작성, 좋아요,\n기프티콘 및 아이템 사용이 제한됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFE3E5EC)),
                        backgroundColor: const Color(0xFFF5F6FA),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF555B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (confirmed != true) return;

  try {
    final now = DateTime.now();
    final banUntil = now.add(duration);
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'banUntil': Timestamp.fromDate(banUntil),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$targetName 님이 $label 동안 차단되었습니다.'),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('차단 처리 중 오류가 발생했습니다: $e')),
    );
  }
}

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
    if (post.popularRewarded) {
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

    if (authService.isBanned) {
      showBanDialog(context, authService.banUntil);
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
            isPopular: _post!.popularRewarded,
            popularDate: _post!.popularDate,
            popularRewarded: _post!.popularRewarded,
            coins: _post!.coins,
            sortTime: _post!.sortTime,
            charcoalUsedAt: _post!.charcoalUsedAt,
            charcoalFixedUntil: _post!.charcoalFixedUntil,
            charcoalAdoptionDone: _post!.charcoalAdoptionDone,
            coalUsedAt: _post!.coalUsedAt,
            coalFixedUntil: _post!.coalFixedUntil,
            coalAdoptionDone: _post!.coalAdoptionDone,
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

    if (authService.isBanned) {
      showBanDialog(context, authService.banUntil);
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

    if (authService.isBanned) {
      showBanDialog(context, authService.banUntil);
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

    if (authService.isBanned) {
      showBanDialog(context, authService.banUntil);
      return;
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.deleteComment(widget.postId, commentIndex);
      await _loadPost();
    } catch (e) {
      // 댓글 삭제 실패 시에도 별도 알림은 표시하지 않음
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

    if (authService.isBanned) {
      showBanDialog(context, authService.banUntil);
      return;
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.deleteReply(widget.postId, commentIndex, replyPath);
      await _loadPost();
    } catch (e) {
      // 답글 삭제 실패 시에도 별도 알림은 표시하지 않음
    }
  }

  /// 댓글/게시물 신고 다이얼로그
  Future<void> _showReportDialog({
    required BuildContext context,
    required String targetPostId,
    String? targetCommentId,
    required String targetAuthor,
    required String targetType, // 'post' | 'comment'
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (authService.isBanned) {
      showBanDialog(context, authService.banUntil);
      return;
    }

    String? selectedType = '어뷰징';
    final detailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '신고하기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final type in ['어뷰징', '선정성', '도배', '개인정보 유출'])
                            Padding(
                              padding: EdgeInsets.only(
                                  right: type == '개인정보 유출' ? 0 : 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedType = type;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: selectedType == type
                                        ? AppTheme.primaryColor.withOpacity(0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedType == type
                                          ? AppTheme.primaryColor
                                          : const Color(0xFFE3E5EC),
                                    ),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selectedType == type
                                          ? AppTheme.primaryColor
                                          : const Color(0xFF555B6B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '상세한 내용을 입력해주세요.',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w300,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: Color(0xFFE3E5EC)),
                              backgroundColor: const Color(0xFFF5F6FA),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF555B6B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedType == null ||
                                  detailController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('신고 유형과 내용을 입력해주세요.')),
                                );
                                return;
                              }
                              Navigator.of(ctx).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '신고',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (result == true && selectedType != null) {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.createReport(
        reporterUid: authService.user!.uid,
        reporterName:
            authService.userData?['name'] as String? ?? '익명',
        targetPostId: targetPostId,
        targetCommentId: targetCommentId,
        targetAuthor: targetAuthor,
        targetType: targetType,
        reportType: selectedType!,
        detail: detailController.text.trim(),
      );
      if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '신고가 접수되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      }
    }
  }

  // _showSimpleAlertDialog는 더 이상 사용하지 않음 (신고 완료 전용 모달로 대체)

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
          isPopular: _post!.popularRewarded,
          popularDate: _post!.popularDate,
          popularRewarded: _post!.popularRewarded,
          coins: _post!.coins,
          sortTime: _post!.sortTime,
          charcoalUsedAt: _post!.charcoalUsedAt,
          charcoalFixedUntil: _post!.charcoalFixedUntil,
          charcoalAdoptionDone: _post!.charcoalAdoptionDone,
          coalUsedAt: _post!.coalUsedAt,
          coalFixedUntil: _post!.coalFixedUntil,
          coalAdoptionDone: _post!.coalAdoptionDone,
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
              isPopular: _post!.popularRewarded,
              popularDate: _post!.popularDate,
              popularRewarded: _post!.popularRewarded,
              coins: _post!.coins,
              sortTime: _post!.sortTime,
              charcoalUsedAt: _post!.charcoalUsedAt,
              charcoalFixedUntil: _post!.charcoalFixedUntil,
              charcoalAdoptionDone: _post!.charcoalAdoptionDone,
              coalUsedAt: _post!.coalUsedAt,
              coalFixedUntil: _post!.coalFixedUntil,
              coalAdoptionDone: _post!.coalAdoptionDone,
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

    // 확인 다이얼로그 (코인 부족 모달과 동일한 카드 스타일, 예/아니요 버튼)
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '게시물을 정말 삭제할까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '삭제된 게시물은 복구할 수 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9FA4B3),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Color(0xFFE3E5EC)),
                          backgroundColor: const Color(0xFFF5F6FA),
                        ),
                        child: const Text(
                          '아니요',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF555B6B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '예',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    // 즉시 UI 업데이트 (낙관적 업데이트)
    if (mounted) {
      Navigator.pop(context); // 게시물 상세 화면 즉시 닫기
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
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('게시물')),
        backgroundColor: Colors.white,
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
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          // 게시물 삭제 버튼
          // - 일반 게시물: 작성자 또는 관리자
          // - 공지사항: 관리자만
          if (isPostOwner || isAdmin)
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
                if (post.charcoalUsedAt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      '댓글 작성자 중 무조건 한 명이 50코인에 채택됩니다',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (post.coalUsedAt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      '댓글 작성자 중 무조건 한 명이 300코인에 채택됩니다',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
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
                                child: Row(
                                  children: [
                                    Text(
                                      post.author,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (!isPostOwner)
                                      Theme(
                                        data: Theme.of(context).copyWith(
                                          useMaterial3: false,
                                          popupMenuTheme: const PopupMenuThemeData(
                                            color: Colors.white,
                                          ),
                                        ),
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 140, minHeight: 0),
                                          iconSize: 18,
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: Color(0xFFB0B0B0),
                                            size: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          itemBuilder: (context) {
                                            final items = <PopupMenuEntry<String>>[
                                              const PopupMenuItem(
                                                value: 'report_post',
                                                child: Text('신고하기'),
                                              ),
                                            ];
                                            if (isAdmin && (post.authorUid != null && post.authorUid!.isNotEmpty)) {
                                              items.addAll(const [
                                                PopupMenuItem(
                                                  value: 'ban_1d_post',
                                                  child: Text('1일 차단'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'ban_7d_post',
                                                  child: Text('7일 차단'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'ban_30d_post',
                                                  child: Text('30일 차단'),
                                                ),
                                              ]);
                                            }
                                            return items;
                                          },
                                          onSelected: (value) {
                                            if (value == 'report_post') {
                                              _showReportDialog(
                                                context: context,
                                                targetPostId: widget.postId,
                                                targetCommentId: null,
                                                targetAuthor: post.author,
                                                targetType: 'post',
                                              );
                                            } else if (value == 'ban_1d_post' &&
                                                post.authorUid != null &&
                                                post.authorUid!.isNotEmpty) {
                                              _showBanConfirmDialog(
                                                context,
                                                targetUid: post.authorUid!,
                                                targetName: post.author,
                                                duration: const Duration(days: 1),
                                              );
                                            } else if (value == 'ban_7d_post' &&
                                                post.authorUid != null &&
                                                post.authorUid!.isNotEmpty) {
                                              _showBanConfirmDialog(
                                                context,
                                                targetUid: post.authorUid!,
                                                targetName: post.author,
                                                duration: const Duration(days: 7),
                                              );
                                            } else if (value == 'ban_30d_post' &&
                                                post.authorUid != null &&
                                                post.authorUid!.isNotEmpty) {
                                              _showBanConfirmDialog(
                                                context,
                                                targetUid: post.authorUid!,
                                                targetName: post.author,
                                                duration: const Duration(days: 30),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                  ],
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
              // 공지사항: 제목과 본문 구분선
              if (post.type == 'notice') ...[
                const SizedBox(height: 16),
                const Divider(
                  color: Color(0xFFE6E8F0),
                  height: 1,
                  thickness: 1,
                ),
                const SizedBox(height: 16),
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
                            hintStyle: const TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF9CA3AF),
                            ),
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
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _addComment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('댓글 작성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

/// 가로 스크롤 필요 시 날짜가 내용과 함께 스크롤, 불필요 시 날짜는 오른쪽 끝 고정
class _AdaptiveHeaderRow extends StatefulWidget {
  final List<Widget> leftContent;
  final Widget? dateWidget;

  const _AdaptiveHeaderRow({
    required this.leftContent,
    this.dateWidget,
  });

  @override
  State<_AdaptiveHeaderRow> createState() => _AdaptiveHeaderRowState();
}

class _AdaptiveHeaderRowState extends State<_AdaptiveHeaderRow> {
  bool? _needsScroll;
  final GlobalKey _measureKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _AdaptiveHeaderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 댓글/대댓글이 채택되면서 헤더 내용 길이가 달라지면 다시 측정하도록 초기화
    if (oldWidget.leftContent.length != widget.leftContent.length ||
        oldWidget.dateWidget.runtimeType != widget.dateWidget.runtimeType) {
      setState(() {
        _needsScroll = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_needsScroll == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
            if (box != null && mounted) {
              final contentWidth = box.size.width;
              if (contentWidth > constraints.maxWidth) {
                setState(() => _needsScroll = true);
              } else {
                setState(() => _needsScroll = false);
              }
            }
          });
        }

        final fullContent = [
          ...widget.leftContent,
          if (widget.dateWidget != null) ...[
            const SizedBox(width: 8),
            widget.dateWidget!,
          ],
        ];

        // 초기 또는 스크롤 필요: 가로 스크롤 (날짜가 내용과 함께 스크롤)
        if (_needsScroll != false) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: fullContent,
                      ),
                    ),
                  ),
                ],
              ),
              // 측정용 (화면 밖)
              if (_needsScroll == null)
                Positioned(
                  left: -9999,
                  top: 0,
                  child: Row(
                    key: _measureKey,
                    mainAxisSize: MainAxisSize.min,
                    children: fullContent,
                  ),
                ),
            ],
          );
        }

        // 스크롤 불필요: 날짜 오른쪽 끝 고정
        return Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.leftContent,
              ),
            ),
            if (widget.dateWidget != null) widget.dateWidget!,
          ],
        );
      },
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
    final isAdmin = authService.isAdmin();
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
          // 댓글 메인 (클릭 시 답글 작성 폼 토글)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: authService.isLoggedIn ? onToggleReply : null,
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 댓글 헤더 (스크롤 불필요 시 날짜 오른쪽 끝, 필요 시 날짜 포함 가로 스크롤)
                  _AdaptiveHeaderRow(
                    leftContent: [
                      Text(
                        comment.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Theme(
                        data: Theme.of(context).copyWith(
                          useMaterial3: false,
                          popupMenuTheme: const PopupMenuThemeData(
                            color: Colors.white,
                          ),
                        ),
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 140, minHeight: 0),
                          iconSize: 16,
                          icon: const Icon(Icons.more_vert, color: Color(0xFFB0B0B0), size: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) {
                            final items = <PopupMenuEntry<String>>[];
                            if (canAccept && acceptedCount < 3) {
                              items.add(const PopupMenuItem(value: 'accept', child: Text('채택하기')));
                            }
                            items.add(const PopupMenuItem(value: 'report', child: Text('신고하기')));
                            if (isOwner || isAdmin) {
                              items.add(const PopupMenuItem(value: 'delete', child: Text('삭제하기')));
                            }
                            if (isAdmin && comment.authorUid != null && comment.authorUid!.isNotEmpty) {
                              items.addAll(const [
                                PopupMenuItem(
                                  value: 'ban_1d_comment',
                                  child: Text('1일 차단'),
                                ),
                                PopupMenuItem(
                                  value: 'ban_7d_comment',
                                  child: Text('7일 차단'),
                                ),
                                PopupMenuItem(
                                  value: 'ban_30d_comment',
                                  child: Text('30일 차단'),
                                ),
                              ]);
                            }
                            return items;
                          },
                          onSelected: (value) {
                            if (value == 'accept') {
                              _showAcceptCommentDialog(context);
                            } else if (value == 'report') {
                              _showReportDialogForComment(context);
                            } else if (value == 'delete') {
                              onDeleteComment();
                            } else if (value == 'ban_1d_comment' &&
                                comment.authorUid != null &&
                                comment.authorUid!.isNotEmpty) {
                              _showBanConfirmDialog(
                                context,
                                targetUid: comment.authorUid!,
                                targetName: comment.author,
                                duration: const Duration(days: 1),
                              );
                            } else if (value == 'ban_7d_comment' &&
                                comment.authorUid != null &&
                                comment.authorUid!.isNotEmpty) {
                              _showBanConfirmDialog(
                                context,
                                targetUid: comment.authorUid!,
                                targetName: comment.author,
                                duration: const Duration(days: 7),
                              );
                            } else if (value == 'ban_30d_comment' &&
                                comment.authorUid != null &&
                                comment.authorUid!.isNotEmpty) {
                              _showBanConfirmDialog(
                                context,
                                targetUid: comment.authorUid!,
                                targetName: comment.author,
                                duration: const Duration(days: 30),
                              );
                            }
                          },
                        ),
                      ),
                      if (isAccepted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
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
                    ],
                    dateWidget: Text(
                      DateFormat('yyyy.MM.dd').format(comment.createdAt),
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 13.6,
                      ),
                    ),
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
            ),
          ),
          // 답글 입력 폼
          if (showReplyForm && replyController != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 255, 255, 255),
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
                      hintText: '댓글을 입력하세요',
                      hintStyle: const TextStyle(
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF9CA3AF),
                      ),
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
                        child: ElevatedButton(
                          onPressed: onAddReply,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '작성',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
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
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (replyIndex > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFE6E8F0)),
                        ),
                      _ReplyItem(
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
                        onReplyAccepted: onReplyAccepted,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReportDialogForComment(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    String? selectedType = '어뷰징';
    final detailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '신고하기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final type in ['어뷰징', '선정성', '도배', '개인정보 유출'])
                            Padding(
                              padding: EdgeInsets.only(
                                  right: type == '개인정보 유출' ? 0 : 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedType = type;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: selectedType == type
                                        ? AppTheme.primaryColor.withOpacity(0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedType == type
                                          ? AppTheme.primaryColor
                                          : const Color(0xFFE3E5EC),
                                    ),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selectedType == type
                                          ? AppTheme.primaryColor
                                          : const Color(0xFF555B6B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '상세한 내용을 입력해주세요.',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w300,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: Color(0xFFE3E5EC)),
                              backgroundColor: const Color(0xFFF5F6FA),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF555B6B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedType == null ||
                                  detailController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('신고 유형과 내용을 입력해주세요.')),
                                );
                                return;
                              }
                              Navigator.of(ctx).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '신고',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (result == true && selectedType != null) {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.createReport(
        reporterUid: authService.user!.uid,
        reporterName:
            authService.userData?['name'] as String? ?? '익명',
        targetPostId: postId,
        targetCommentId: comment.id,
        targetAuthor: comment.author,
        targetType: 'comment',
        reportType: selectedType!,
        detail: detailController.text.trim(),
      );
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '신고가 접수되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '댓글 채택',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '지급할 코인 양을 선택하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
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
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: selectedCoinAmount == null
                              ? null
                              : () async {
                                  Navigator.of(dialogContext).pop();
                                  await _acceptComment(context, selectedCoinAmount!);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: const Text(
                            '채택하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
    final isAdmin = authService.isAdmin();
    // 본인 대댓글은 채택 불가
    final canAccept = isPostAuthor && !isAccepted && !isOwner;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 답글 내용 (클릭 시 답글 작성 폼 토글)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: authService.isLoggedIn ? () => onToggleReply(replyPath) : null,
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 답글 헤더 (스크롤 불필요 시 날짜 오른쪽 끝, 필요 시 날짜 포함 가로 스크롤)
                  _AdaptiveHeaderRow(
                    leftContent: [
                      Text(
                        reply.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Theme(
                        data: Theme.of(context).copyWith(
                          useMaterial3: false,
                          popupMenuTheme: const PopupMenuThemeData(
                            color: Colors.white,
                          ),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Color(0xFFB0B0B0), size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 140, minHeight: 0),
                          iconSize: 16,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) {
                            final items = <PopupMenuEntry<String>>[];
                            if (canAccept && acceptedCount < 3) {
                              items.add(const PopupMenuItem(value: 'accept', child: Text('채택하기')));
                            }
                            items.add(const PopupMenuItem(value: 'report', child: Text('신고하기')));
                            if (isOwner || isAdmin) {
                              items.add(const PopupMenuItem(value: 'delete', child: Text('삭제하기')));
                            }
                            if (isAdmin && reply.authorUid != null && reply.authorUid!.isNotEmpty) {
                              items.addAll(const [
                                PopupMenuItem(
                                  value: 'ban_1d_reply',
                                  child: Text('1일 차단'),
                                ),
                                PopupMenuItem(
                                  value: 'ban_7d_reply',
                                  child: Text('7일 차단'),
                                ),
                                PopupMenuItem(
                                  value: 'ban_30d_reply',
                                  child: Text('30일 차단'),
                                ),
                              ]);
                            }
                            return items;
                          },
                          onSelected: (value) {
                            if (value == 'accept') {
                              _showAcceptReplyDialog(context);
                            } else if (value == 'report') {
                              _showReportDialogForReply(context);
                            } else if (value == 'delete') {
                              onDeleteReply(replyPath);
                            } else if (value == 'ban_1d_reply' &&
                                reply.authorUid != null &&
                                reply.authorUid!.isNotEmpty) {
                              _showBanConfirmDialog(
                                context,
                                targetUid: reply.authorUid!,
                                targetName: reply.author,
                                duration: const Duration(days: 1),
                              );
                            } else if (value == 'ban_7d_reply' &&
                                reply.authorUid != null &&
                                reply.authorUid!.isNotEmpty) {
                              _showBanConfirmDialog(
                                context,
                                targetUid: reply.authorUid!,
                                targetName: reply.author,
                                duration: const Duration(days: 7),
                              );
                            } else if (value == 'ban_30d_reply' &&
                                reply.authorUid != null &&
                                reply.authorUid!.isNotEmpty) {
                              _showBanConfirmDialog(
                                context,
                                targetUid: reply.authorUid!,
                                targetName: reply.author,
                                duration: const Duration(days: 30),
                              );
                            }
                          },
                        ),
                      ),
                      if (isAccepted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
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
                    ],
                    dateWidget: isAccepted
                        ? null
                        : Text(
                            DateFormat('yyyy.MM.dd').format(reply.createdAt),
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 13.6,
                            ),
                          ),
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
            ),
          ),
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
                      hintStyle: const TextStyle(
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF9CA3AF),
                      ),
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
                        child: ElevatedButton(
                          onPressed: () => onAddReply(replyPath),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '작성',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
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
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (nestedIndex > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFE6E8F0)),
                        ),
                      _ReplyItem(
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
                        onReplyAccepted: onReplyAccepted,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReportDialogForReply(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    String? selectedType = '어뷰징';
    final detailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '신고하기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final type in ['어뷰징', '선정성', '도배', '개인정보 유출'])
                            Padding(
                              padding: EdgeInsets.only(
                                  right: type == '개인정보 유출' ? 0 : 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedType = type;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: selectedType == type
                                        ? AppTheme.primaryColor.withOpacity(0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedType == type
                                          ? AppTheme.primaryColor
                                          : const Color(0xFFE3E5EC),
                                    ),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selectedType == type
                                          ? AppTheme.primaryColor
                                          : const Color(0xFF555B6B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '상세한 내용을 입력해주세요.',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w300,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: Color(0xFFE3E5EC)),
                              backgroundColor: const Color(0xFFF5F6FA),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF555B6B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedType == null ||
                                  detailController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('신고 유형과 내용을 입력해주세요.')),
                                );
                                return;
                              }
                              Navigator.of(ctx).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '신고',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (result == true && selectedType != null) {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.createReport(
        reporterUid: authService.user!.uid,
        reporterName:
            authService.userData?['name'] as String? ?? '익명',
        targetPostId: postId,
        targetCommentId: reply.id,
        targetAuthor: reply.author,
        targetType: 'comment',
        reportType: selectedType!,
        detail: detailController.text.trim(),
      );
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '신고가 접수되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
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
                        child: ElevatedButton(
                          onPressed: selectedCoinAmount == null
                              ? null
                              : () async {
                                  Navigator.of(dialogContext).pop();
                                  await _acceptReply(context, selectedCoinAmount!);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: const Text(
                            '채택하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

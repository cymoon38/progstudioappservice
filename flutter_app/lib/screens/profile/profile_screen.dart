import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/data_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../post_detail_screen.dart';
import '../../widgets/app_profile_icon.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _sortType = 'newest'; // 'newest', 'oldest', 'popular'
  int _currentPage = 1;
  static const int _postsPerPage = 4;
  List<Post> _allUserPosts = [];
  bool _isLoading = true;
  bool _isSelectionMode = false; // 선택 모드 여부
  Set<String> _selectedPostIds = {}; // 선택된 게시물 ID 목록

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
  }



  Future<void> _loadUserPosts() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dataService = Provider.of<DataService>(context, listen: false);
      
      if (!authService.isLoggedIn || authService.userData == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final username = authService.userData!['name'] as String?;
      if (username == null || username.isEmpty) {
        return;
      }

      // Firestore에서 최신 게시물 목록 가져오기 (삭제된 게시물은 자동으로 제외됨)
      _allUserPosts = await dataService.getUserPosts(username);
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('사용자 게시물 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Post> _getSortedPosts() {
    final sorted = List<Post>.from(_allUserPosts);
    switch (_sortType) {
      case 'newest':
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'oldest':
        sorted.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'popular':
        sorted.sort((a, b) {
          final likesDiff = b.likes.length - a.likes.length;
          return likesDiff != 0 ? likesDiff : b.date.compareTo(a.date);
        });
        break;
    }
    return sorted;
  }

  List<Post> _getCurrentPagePosts() {
    final sorted = _getSortedPosts();
    final startIndex = (_currentPage - 1) * _postsPerPage;
    final endIndex = startIndex + _postsPerPage;
    return sorted.length > startIndex 
        ? sorted.sublist(startIndex, endIndex > sorted.length ? sorted.length : endIndex)
        : [];
  }

  int _getTotalPages() {
    return (_allUserPosts.length / _postsPerPage).ceil();
  }

  // 선택 모드 토글
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPostIds.clear(); // 선택 모드 종료 시 선택 해제
      }
    });
  }

  // 게시물 선택/해제
  void _togglePostSelection(String postId) {
    setState(() {
      if (_selectedPostIds.contains(postId)) {
        _selectedPostIds.remove(postId);
      } else {
        _selectedPostIds.add(postId);
      }
    });
  }

  // 선택된 게시물 일괄 삭제
  Future<void> _deleteSelectedPosts() async {
    if (_selectedPostIds.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

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
    final selectedIds = Set<String>.from(_selectedPostIds);
    setState(() {
      _allUserPosts.removeWhere((post) => selectedIds.contains(post.id));
      _selectedPostIds.clear();
      _isSelectionMode = false;
    });

    // 성공 메시지
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selectedIds.length}개의 게시물이 삭제되었습니다.')),
    );

    // 백그라운드에서 실제 삭제 작업 수행
    final dataService = Provider.of<DataService>(context, listen: false);
    for (final postId in selectedIds) {
      dataService.deletePost(postId).catchError((e) {
        debugPrint('게시물 삭제 오류 (무시): $postId - $e');
      });
    }

    // 게시물 목록 새로고침
    _loadUserPosts();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    if (!authService.isLoggedIn || authService.userData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('마이페이지'),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        ),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    final userData = authService.userData!;
    final username = userData['name'] as String? ?? '사용자';
    final email = authService.user?.email ?? '';
    final postCount = _allUserPosts.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedPostIds.length}개 선택됨' : '마이페이지'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          if (_isSelectionMode) ...[
            if (_selectedPostIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _deleteSelectedPosts,
                tooltip: '선택한 게시물 삭제',
              ),
            TextButton(
              onPressed: _toggleSelectionMode,
              child: const Text('취소'),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: '선택 모드',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserPosts,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  // 프로필 헤더
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.cardDecoration,
                      child: Row(
                        children: [
                          // 아바타
                          const AppProfileIcon(size: 80, iconSize: 48),
                          const SizedBox(width: 20),
                          // 사용자 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '작품 수: $postCount개',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 갤러리 헤더 (정렬 옵션)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '내 작품',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Row(
                            children: [
                              const Text('정렬:', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              _SortDropdown(
                                value: _sortType,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _sortType = value;
                                      _currentPage = 1;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 갤러리 그리드
                  if (_allUserPosts.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('아직 업로드한 작품이 없습니다.'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                // TODO: 작품 업로드 화면으로 이동
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                elevation: 0,
                                side: const BorderSide(color: AppTheme.primaryColor, width: 1),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('작품 업로드하기'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final currentPosts = _getCurrentPagePosts();
                            if (index >= currentPosts.length) return null;
                            final post = currentPosts[index];
                            final isPopular = post.likes.length >= 2;
                            
                            final isSelected = _selectedPostIds.contains(post.id);
                            return Stack(
                              children: [
                                GestureDetector(
                                  onLongPress: () {
                                    // 길게 누르면 선택 모드로 전환
                                    if (!_isSelectionMode) {
                                      _toggleSelectionMode();
                                    }
                                    _togglePostSelection(post.id);
                                  },
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      // 선택 모드일 때는 선택/해제
                                      _togglePostSelection(post.id);
                                    } else {
                                      // 일반 모드일 때는 상세 페이지로 이동
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PostDetailScreen(postId: post.id),
                                        ),
                                      ).then((_) {
                                        // 게시물 상세 페이지에서 돌아왔을 때 새로고침 (삭제된 게시물 제거)
                                        if (mounted) {
                                          _loadUserPosts();
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[200],
                                      border: Border.all(
                                        color: const Color(0xFFE1E1E1),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: (post.compressedImageUrl?.isNotEmpty == true || post.imageUrl.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: post.compressedImageUrl ?? post.imageUrl,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) {
                                                // 이미지 로드 실패 시 해당 게시물을 목록에서 제거 (삭제된 게시물)
                                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                                  if (mounted) {
                                                    setState(() {
                                                      _allUserPosts.removeWhere((p) => p.id == post.id);
                                                      _selectedPostIds.remove(post.id);
                                                    });
                                                  }
                                                });
                                                return Container(
                                                  color: Colors.grey[200],
                                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                                );
                                              },
                                            )
                                          : Container(
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                            ),
                                    ),
                                  ),
                                ),
                                // 선택 모드일 때 선택 표시
                                if (_isSelectionMode)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primaryColor : Colors.grey,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                  ),
                                if (isPopular)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Image.asset(
                                      'assets/icons/star.png',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                // 선택된 게시물 오버레이
                                if (_isSelectionMode && isSelected)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          childCount: _getCurrentPagePosts().length,
                        ),
                      ),
                    ),
                  // 페이지네이션
                  if (_allUserPosts.isNotEmpty && _getTotalPages() > 1)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_currentPage > 1)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                },
                                child: const Text('이전'),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '$_currentPage / ${_getTotalPages()}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            if (_currentPage < _getTotalPages())
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                },
                                child: const Text('다음'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  // 로그아웃 버튼 (하단)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            await authService.signOut();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Color(0xFFE3E5EC)),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text(
                            '로그아웃',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF555B6B),
                              fontWeight: FontWeight.w600,
                            ),
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

// 기존 프로그램과 동일한 스타일의 드롭바 위젯
class _SortDropdown extends StatefulWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _SortDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SortDropdown> createState() => _SortDropdownState();
}

class _SortDropdownState extends State<_SortDropdown> {
  @override
  Widget build(BuildContext context) {
    // label은 DropdownButton이 직접 렌더링하므로 별도 계산 불필요

    const double width = 120.0;

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.white, // 드롭다운 메뉴 배경 흰색
      ),
      child: SizedBox(
        width: width,
        child: DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<String>(
              value: widget.value,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              items: const [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text('최신순'),
                ),
                DropdownMenuItem(
                  value: 'oldest',
                  child: Text('오래된순'),
                ),
                DropdownMenuItem(
                  value: 'popular',
                  child: Text('인기순'),
                ),
              ],
              onChanged: widget.onChanged,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF333333),
                size: 20,
              ),
              style: const TextStyle(
                fontSize: 15.2,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import 'giftcard_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _selectedTab = 0; // 0: 아이템, 1: 스킨, 2: 기프티콘, 3: 보유중

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          // 상단 탭 바 (스크롤 시 숨김)
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabButton(
                      label: '아이템',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                    _TabButton(
                      label: '스킨',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                    _TabButton(
                      label: '기프티콘',
                      isSelected: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                    _TabButton(
                      label: '보유중',
                      isSelected: _selectedTab == 3,
                      onTap: () => setState(() => _selectedTab = 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 탭별 콘텐츠
          _buildTabContentSliver(),
        ],
      ),
    );
  }

  Widget _buildTabContentSliver() {
    switch (_selectedTab) {
      case 0:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildItemTab(),
        );
      case 1:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildSkinTab(),
        );
      case 2:
        return _buildGiftCardTabSliver();
      case 3:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildOwnedTab(),
        );
      default:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildItemTab(),
        );
    }
  }
  
  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildItemTab();
      case 1:
        return _buildSkinTab();
      case 2:
        return _buildGiftCardTab();
      case 3:
        return _buildOwnedTab();
      default:
        return _buildItemTab();
    }
  }

  Widget _buildItemTab() {
    return Center(
      child: Text(
        '아이템',
        style: TextStyle(
          fontSize: 18,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSkinTab() {
    return Center(
      child: Text(
        '스킨',
        style: TextStyle(
          fontSize: 18,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildGiftCardTab() {
    return _GiftCardListTab();
  }
  
  Widget _buildGiftCardTabSliver() {
    return _GiftCardListTabSliver();
  }

  Widget _buildOwnedTab() {
    return Center(
      child: Text(
        '보유중',
        style: TextStyle(
          fontSize: 18,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            alignment: Alignment.center,
            constraints: const BoxConstraints(
              minHeight: 40,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

// 기프티콘 목록 탭
class _GiftCardListTab extends StatefulWidget {
  @override
  State<_GiftCardListTab> createState() => _GiftCardListTabState();
}

// 기프티콘 목록 탭 (Sliver 버전)
class _GiftCardListTabSliver extends StatefulWidget {
  @override
  State<_GiftCardListTabSliver> createState() => _GiftCardListTabSliverState();
}

class _GiftCardListTabState extends State<_GiftCardListTab> {
  List<GiftCard> _giftCards = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadGiftCards();
  }

  Future<void> _loadGiftCards() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      
      debugPrint('🔄 기프티콘 목록 로드 시작...');
      
      // 최신 데이터 먼저 가져오기
      final latestList = await dataService.getGiftCardList(start: 1, size: 20);
      debugPrint('📊 최신 데이터: ${latestList.length}개');
      
      if (mounted) {
        if (latestList.isNotEmpty) {
          setState(() {
            _giftCards = latestList;
            _isLoading = false;
            _hasError = false;
          });
          debugPrint('✅ 기프티콘 목록 표시: ${latestList.length}개');
        } else {
          // 최신 데이터가 없으면 캐시 확인
          debugPrint('📦 최신 데이터 없음, 캐시 확인 중...');
          final cachedList = await dataService.getCachedGiftCardList();
          debugPrint('📦 캐시 데이터: ${cachedList.length}개');
          
          setState(() {
            _giftCards = cachedList;
            _isLoading = false;
            _hasError = cachedList.isEmpty; // 캐시도 없으면 에러로 표시
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 기프티콘 목록 로드 오류: $e');
      debugPrint('📋 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '기프티콘 목록을 불러올 수 없습니다',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGiftCards,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_giftCards.isEmpty) {
      return const Center(
        child: Text(
          '기프티콘이 없습니다',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGiftCards,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final giftCard = _giftCards[index];
                  return _GiftCardItem(giftCard: giftCard);
                },
                childCount: _giftCards.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCardListTabSliverState extends State<_GiftCardListTabSliver> {
  List<GiftCard> _giftCards = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadGiftCards();
  }

  Future<void> _loadGiftCards() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      
      debugPrint('🔄 기프티콘 목록 로드 시작...');
      
      // 최신 데이터 먼저 가져오기
      final latestList = await dataService.getGiftCardList(start: 1, size: 100);
      debugPrint('📊 최신 데이터: ${latestList.length}개');
      
      if (mounted) {
        if (latestList.isNotEmpty) {
          setState(() {
            _giftCards = latestList;
            _isLoading = false;
            _hasError = false;
          });
          debugPrint('✅ 기프티콘 목록 표시: ${latestList.length}개');
        } else {
          // 최신 데이터가 없으면 캐시 확인
          debugPrint('📦 최신 데이터 없음, 캐시 확인 중...');
          final cachedList = await dataService.getCachedGiftCardList();
          debugPrint('📦 캐시 데이터: ${cachedList.length}개');
          
          setState(() {
            _giftCards = cachedList;
            _isLoading = false;
            _hasError = cachedList.isEmpty; // 캐시도 없으면 에러로 표시
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 기프티콘 목록 로드 오류: $e');
      debugPrint('📋 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                '기프티콘 목록을 불러올 수 없습니다',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadGiftCards,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_giftCards.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            '기프티콘이 없습니다',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, // 높이 조정 (정보 영역 공간 확보)
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final giftCard = _giftCards[index];
            return _GiftCardItem(giftCard: giftCard);
          },
          childCount: _giftCards.length,
        ),
      ),
    );
  }
}

// 기프티콘 아이템 위젯
class _GiftCardItem extends StatelessWidget {
  final GiftCard giftCard;

  const _GiftCardItem({required this.giftCard});

  @override
  Widget build(BuildContext context) {
    // 이미지 URL 확인 및 디버그
    final imageUrl = giftCard.goodsimg;
    debugPrint('🖼️ 이미지 URL: $imageUrl (상품: ${giftCard.goodsName})');
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GiftCardDetailScreen(
              goodsCode: giftCard.goodsCode,
              giftCard: giftCard,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이미지 (고정 비율)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 1,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('❌ 이미지 로드 실패: $url - $error');
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          // 정보 영역 (고정 높이, 오버플로우 방지)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 브랜드명
                  Text(
                    giftCard.brandName,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // 상품명 (좌우 스크롤 가능, 한 줄)
                  SizedBox(
                    height: 12, // 한 줄 고정 높이
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Text(
                        giftCard.goodsName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 가격 및 코인 아이콘 (상품명 아래에 표시)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _formatPrice(giftCard.discountPrice),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 코인 아이콘 (그라데이션 배경)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'C',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
  
  // 가격 포맷팅 (콤마 형식)
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}


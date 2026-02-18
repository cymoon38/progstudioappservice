import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import 'giftcard_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _selectedTab = 0; // 0: 아이템, 1: 기프티콘, 2: 보유중

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                      label: '기프티콘',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                    _TabButton(
                      label: '보유중',
                      isSelected: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
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
        return _buildGiftCardTabSliver();
      case 2:
        return _buildOwnedTabSliver();
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
        return _buildGiftCardTab();
      case 2:
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


  Widget _buildGiftCardTab() {
    return _GiftCardListTab();
  }
  
  Widget _buildGiftCardTabSliver() {
    return _GiftCardListTabSliver();
  }

  Widget _buildOwnedTab() {
    return _OwnedGiftCardListTab();
  }
  
  Widget _buildOwnedTabSliver() {
    return _OwnedGiftCardListTabSliver();
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
  List<GiftCard> _allGiftCards = [];
  // 고정된 카테고리 목록
  final List<String> _categories = [
    '전체',
    '커피/음료',
    '베이커리/도넛',
    '아이스크림',
    '편의점',
    '피자/버거/치킨',
    '영화/음악/독서',
    '상품권/마트/페이',
  ];
  
  // 카테고리 매핑 (UI 카테고리 -> API 카테고리 키워드)
  final Map<String, List<String>> _categoryMapping = {
    '커피/음료': ['커피', '음료', '카페', '스타벅스', '이디야', '투썸', '할리스'],
    '베이커리/도넛': ['베이커리', '도넛', '빵', '케이크', '파리바게뜨', '뚜레쥬르'],
    '아이스크림': ['아이스크림', '빙수', '베스킨라빈스', '하겐다즈'],
    '편의점': ['편의점', 'CU', 'GS25', '세븐일레븐', '이마트24'],
    '피자/버거/치킨': ['피자', '버거', '치킨', '도미노', '피자헛', '맥도날드', '버거킹', 'KFC', 'BBQ', '교촌'],
    '영화/음악/독서': ['영화', '음악', '독서', 'CGV', '롯데시네마', '메가박스', '멜론', 'YES24', '교보문고'],
    '상품권/마트/페이': ['상품권', '마트', '페이', '해피머니', '도서문화상품권', '이마트', '롯데마트', '네이버페이', '카카오페이'],
  };
  
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 50; // 카테고리별 50개씩
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadGiftCards();
  }

  Future<void> _loadGiftCards({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentPage = 1;
        _hasMore = true;
        _allGiftCards = [];
        _giftCards = [];
      });
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      
      // 카테고리별로 상품을 가져오기 위해 더 많은 데이터를 로드
      final loadSize = _selectedCategory == null || _selectedCategory == '전체' 
          ? _pageSize 
          : _pageSize * 10; // 카테고리 필터링을 위해 더 많이 로드 (50개 찾을 때까지)
      
      debugPrint('🔄 기프티콘 목록 로드 시작... (페이지: $_currentPage, 크기: $loadSize, 카테고리: $_selectedCategory)');
      
      // 페이지네이션으로 데이터 가져오기
      final latestList = await dataService.getGiftCardList(
        start: _currentPage, 
        size: loadSize
      );
      debugPrint('📊 최신 데이터: ${latestList.length}개');
      
      if (mounted) {
        if (latestList.isNotEmpty) {
          // 카테고리 필터 적용 (categoryName1 기준)
          List<GiftCard> filteredList = latestList;
          if (_selectedCategory != null && _selectedCategory!.isNotEmpty && _selectedCategory != '전체') {
            // 카테고리 매핑을 사용하여 필터링
            final mappingKeywords = _categoryMapping[_selectedCategory] ?? [_selectedCategory!];
            filteredList = latestList.where((card) {
              final category = card.categoryName1.toLowerCase();
              // 매핑된 키워드 중 하나라도 포함되어 있으면 포함
              for (var keyword in mappingKeywords) {
                if (category.contains(keyword.toLowerCase()) || 
                    keyword.toLowerCase().contains(category)) {
                  return true;
                }
              }
              // 직접 매칭도 시도
              final selected = _selectedCategory!.toLowerCase();
              return category == selected || 
                     category.contains(selected) || 
                     selected.contains(category);
            }).toList();
            
            // 카테고리별로 50개만 표시
            if (filteredList.length > _pageSize) {
              filteredList = filteredList.take(_pageSize).toList();
            }
            
            debugPrint('🔍 카테고리 필터링: "$_selectedCategory" -> ${filteredList.length}개 (전체: ${latestList.length}개)');
            if (filteredList.isEmpty && latestList.isNotEmpty) {
              debugPrint('⚠️ 필터링 결과가 비어있습니다.');
              debugPrint('   첫 번째 상품의 카테고리: ${latestList[0].categoryName1}');
              debugPrint('   첫 번째 상품의 goodsTypeNm: ${latestList[0].goodsTypeNm}');
            }
          } else {
            // 전체는 50개만 표시
            if (filteredList.length > _pageSize) {
              filteredList = filteredList.take(_pageSize).toList();
            }
          }
          
          setState(() {
            if (loadMore) {
              _allGiftCards.addAll(filteredList);
            } else {
              _allGiftCards = filteredList;
            }
            _currentPage++;
            // 카테고리 선택 시 필터링된 결과가 50개 미만이면 더 이상 없음
            _hasMore = _selectedCategory == null || _selectedCategory == '전체'
                ? filteredList.length >= _pageSize
                : filteredList.length >= _pageSize && latestList.length >= loadSize;
            _applyCategoryFilter();
            _isLoading = false;
            _isLoadingMore = false;
            _hasError = false;
          });
          debugPrint('✅ 기프티콘 목록 표시: ${_allGiftCards.length}개 (더 있음: $_hasMore)');
        } else {
          if (loadMore) {
            setState(() {
              _hasMore = false;
              _isLoadingMore = false;
            });
          } else {
            // 최신 데이터가 없으면 캐시 확인
            debugPrint('📦 최신 데이터 없음, 캐시 확인 중...');
            final cachedList = await dataService.getCachedGiftCardList();
            debugPrint('📦 캐시 데이터: ${cachedList.length}개');
            
            setState(() {
              _allGiftCards = cachedList;
              _applyCategoryFilter();
              _isLoading = false;
              _hasError = cachedList.isEmpty; // 캐시도 없으면 에러로 표시
            });
            
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 기프티콘 목록 로드 오류: $e');
      debugPrint('📋 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          if (loadMore) {
            _isLoadingMore = false;
          } else {
            _hasError = true;
            _isLoading = false;
          }
        });
      }
    }
  }

  // 카테고리 필터 적용
  void _applyCategoryFilter() {
    if (_selectedCategory == null || _selectedCategory!.isEmpty || _selectedCategory == '전체') {
      _giftCards = _allGiftCards;
    } else {
      // 카테고리 매핑을 사용하여 필터링
      final mappingKeywords = _categoryMapping[_selectedCategory] ?? [_selectedCategory!];
      _giftCards = _allGiftCards.where((card) {
        final category = card.categoryName1.toLowerCase();
        // 매핑된 키워드 중 하나라도 포함되어 있으면 포함
        for (var keyword in mappingKeywords) {
          if (category.contains(keyword.toLowerCase()) || 
              keyword.toLowerCase().contains(category)) {
            return true;
          }
        }
        // 직접 매칭도 시도
        final selected = _selectedCategory!.toLowerCase();
        return category == selected || 
               category.contains(selected) || 
               selected.contains(category);
      }).toList();
      
      debugPrint('🔍 카테고리 필터 적용: "$_selectedCategory" -> ${_giftCards.length}개 (전체: ${_allGiftCards.length}개)');
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

    if (_allGiftCards.isEmpty) {
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

    final categories = _categories;
    
    return SliverMainAxisGroup(
      slivers: [
        // 카테고리 필터
        SliverToBoxAdapter(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = (category == '전체' && _selectedCategory == null) ||
                                  (category != '전체' && category == _selectedCategory);
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category == '전체' ? null : category;
                        // 카테고리 변경 시 초기화하고 다시 로드
                        _currentPage = 1;
                        _hasMore = true;
                        _allGiftCards = [];
                        _giftCards = [];
                      });
                      _loadGiftCards();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // 기프티콘 목록
        if (_giftCards.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '선택한 카테고리에 기프티콘이 없습니다',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SliverMainAxisGroup(
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
                      if (index == _giftCards.length - 1 && _hasMore && !_isLoadingMore) {
                        // 마지막 아이템에 도달하면 추가 로드
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _loadGiftCards(loadMore: true);
                        });
                      }
                      if (index >= _giftCards.length) {
                        return null;
                      }
                      final giftCard = _giftCards[index];
                      return _GiftCardItem(giftCard: giftCard);
                    },
                    childCount: _giftCards.length + (_isLoadingMore ? 1 : 0),
                  ),
                ),
              ),
              // 로딩 인디케이터
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이미지 (고정 비율, 둥근 네모)
          Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 4),
                  // 가격 및 코인 아이콘 (상품명 바로 아래에 표시)
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
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
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

// 보유 기프티콘 목록 탭
class _OwnedGiftCardListTab extends StatefulWidget {
  @override
  State<_OwnedGiftCardListTab> createState() => _OwnedGiftCardListTabState();
}

// 보유 기프티콘 목록 탭 (Sliver 버전)
class _OwnedGiftCardListTabSliver extends StatefulWidget {
  @override
  State<_OwnedGiftCardListTabSliver> createState() => _OwnedGiftCardListTabSliverState();
}

class _OwnedGiftCardListTabState extends State<_OwnedGiftCardListTab> {
  List<Map<String, dynamic>> _ownedCards = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadOwnedCards();
  }

  Future<void> _loadOwnedCards() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isLoggedIn || authService.user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
            _ownedCards = [];
          });
        }
        return;
      }

      final dataService = Provider.of<DataService>(context, listen: false);
      final ownedCards = await dataService.getOwnedGiftCards(authService.user!.uid);
      
      // 바코드 정보가 있는 기프티콘만 필터링
      final filteredCards = ownedCards.where((card) {
        final giftCardInfo = card['giftCardInfo'];
        if (giftCardInfo == null) return false;
        
        // giftCardInfo가 Map인지 확인
        Map<String, dynamic>? infoMap;
        if (giftCardInfo is Map) {
          infoMap = Map<String, dynamic>.from(giftCardInfo);
        } else {
          return false;
        }
        
        // 유효한 바코드 또는 PIN 번호가 있는지 확인
        String? extractValidBarcodeOrPin(dynamic value) {
          if (value == null) return null;
          final str = value.toString().trim();
          if (str.isEmpty || str == '발행' || str == '발행됨' || str == 'issued') return null;
          if (RegExp(r'^[0-9A-Za-z]+$').hasMatch(str) && str.length >= 3) {
            return str;
          }
          return null;
        }
        
        final barcode = extractValidBarcodeOrPin(infoMap['barcode']) ??
                        extractValidBarcodeOrPin(infoMap['barcodeNumber']) ??
                        extractValidBarcodeOrPin(infoMap['barcode_no']) ??
                        extractValidBarcodeOrPin(infoMap['pinNo']);
        final pinNumber = extractValidBarcodeOrPin(infoMap['pinNumber']) ??
                         extractValidBarcodeOrPin(infoMap['pin']) ??
                         extractValidBarcodeOrPin(infoMap['pin_no']) ??
                         extractValidBarcodeOrPin(infoMap['pinNo']);
        final barcodeImage = infoMap['barcodeImage'] ?? 
                            infoMap['barcodeImageUrl'] ?? 
                            infoMap['couponImgUrl'] ?? 
                            '';
        
        // 바코드, PIN, 또는 바코드 이미지 중 하나라도 있으면 표시
        return (barcode != null && barcode.isNotEmpty) || 
               (pinNumber != null && pinNumber.isNotEmpty) || 
               (barcodeImage != null && barcodeImage.toString().trim().isNotEmpty);
      }).toList();
      
      if (mounted) {
        setState(() {
          _ownedCards = filteredCards;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 보유 기프티콘 목록 로드 오류: $e');
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
    final authService = Provider.of<AuthService>(context);
    
    if (!authService.isLoggedIn) {
      return const Center(
        child: Text(
          '로그인이 필요합니다.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

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
              '보유 기프티콘 목록을 불러올 수 없습니다',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOwnedCards,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_ownedCards.isEmpty) {
      return const Center(
        child: Text(
          '보유한 기프티콘이 없습니다',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOwnedCards,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ownedCards.length,
        itemBuilder: (context, index) {
          final card = _ownedCards[index];
          return _OwnedGiftCardItem(
            card: card,
            onTap: () {
              // 바코드 표시 화면으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _GiftCardBarcodeScreen(
                    card: card,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 보유 기프티콘 아이템
class _OwnedGiftCardItem extends StatefulWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  const _OwnedGiftCardItem({
    required this.card,
    required this.onTap,
  });

  @override
  State<_OwnedGiftCardItem> createState() => _OwnedGiftCardItemState();
}

class _OwnedGiftCardItemState extends State<_OwnedGiftCardItem> {

  @override
  Widget build(BuildContext context) {
    final goodsName = widget.card['goodsName'] ?? '기프티콘';
    final purchaseDate = widget.card['purchaseDate'] as Timestamp?;
    // Firestore 데이터를 안전하게 변환
    Map<String, dynamic>? giftCardInfo;
    final giftCardInfoValue = widget.card['giftCardInfo'];
    if (giftCardInfoValue != null) {
      if (giftCardInfoValue is Map) {
        giftCardInfo = Map<String, dynamic>.from(giftCardInfoValue);
      } else {
        debugPrint('⚠️ giftCardInfo 타입 오류: ${giftCardInfoValue.runtimeType}');
        giftCardInfo = null;
      }
    }
    
    final goodsImg = widget.card['goodsImg'] as String?;
    
    String dateText = '';
    if (purchaseDate != null) {
      final date = purchaseDate.toDate();
      dateText = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} 구매';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 기프티콘 이미지 또는 아이콘
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: goodsImg == null ? null : Colors.grey[200],
                ),
                child: goodsImg != null && goodsImg.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: goodsImg,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.card_giftcard,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goodsName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (giftCardInfo != null) ...[
                      const SizedBox(height: 4),
                      // 바코드 정보가 있는지 확인
                      Builder(
                        builder: (context) {
                          final hasBarcode = (giftCardInfo?['barcode'] as String? ?? '').isNotEmpty ||
                                            (giftCardInfo?['barcodeImage'] as String? ?? '').isNotEmpty ||
                                            (giftCardInfo?['pinNumber'] as String? ?? '').isNotEmpty;
                          
                          if (hasBarcode) {
                            return Text(
                              '사용 가능',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          } else {
                            return Text(
                              '사용 가능',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 기프티콘 바코드 표시 화면
class _GiftCardBarcodeScreen extends StatefulWidget {
  final Map<String, dynamic> card;

  const _GiftCardBarcodeScreen({
    required this.card,
  });

  @override
  State<_GiftCardBarcodeScreen> createState() => _GiftCardBarcodeScreenState();
}

class _GiftCardBarcodeScreenState extends State<_GiftCardBarcodeScreen> {
  Map<String, dynamic>? _currentCard;
  Map<String, dynamic>? _detailData;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    _currentCard = widget.card;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final goodsCode = widget.card['goodsCode'] as String?;
    if (goodsCode == null || goodsCode.isEmpty) return;
    
    setState(() {
      _isLoadingDetail = true;
    });

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      final detail = await dataService.getGiftCardDetail(goodsCode);
      
      if (mounted) {
        setState(() {
          _detailData = detail;
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 상세 정보 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoadingDetail = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final card = _currentCard ?? widget.card;
    final goodsName = card['goodsName'] ?? '기프티콘';
    final goodsImg = card['goodsImg'] as String?;
    // Firestore 데이터를 안전하게 변환
    Map<String, dynamic>? giftCardInfo;
    final giftCardInfoValue = card['giftCardInfo'];
    if (giftCardInfoValue != null) {
      if (giftCardInfoValue is Map) {
        giftCardInfo = Map<String, dynamic>.from(giftCardInfoValue);
      } else {
        debugPrint('⚠️ giftCardInfo 타입 오류: ${giftCardInfoValue.runtimeType}');
        giftCardInfo = null;
      }
    }
    
    // 디버깅: giftCardInfo 전체 출력
    debugPrint('═══════════════════════════════════════');
    debugPrint('📋 바코드 화면 - giftCardInfo 확인');
    debugPrint('───────────────────────────────────────');
    debugPrint('   giftCardInfo 존재: ${giftCardInfo != null}');
    if (giftCardInfo != null) {
      debugPrint('   giftCardInfo 키 목록: ${giftCardInfo.keys.toList()}');
      debugPrint('   giftCardInfo 전체: $giftCardInfo');
    }
    debugPrint('═══════════════════════════════════════');
    
    // 바코드 정보 추출 (다양한 필드명 지원)
    // "발행" 같은 상태 메시지는 실제 바코드/PIN 번호가 아니므로 제외
    String? extractValidBarcodeOrPin(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      // 빈 문자열이거나 "발행" 같은 상태 메시지 제외
      if (str.isEmpty || str == '발행' || str == '발행됨' || str == 'issued') return null;
      // 숫자와 영문으로만 구성된 값만 유효한 바코드/PIN으로 인식
      if (RegExp(r'^[0-9A-Za-z]+$').hasMatch(str) && str.length >= 3) {
        return str;
      }
      return null;
    }
    
    final barcode = extractValidBarcodeOrPin(giftCardInfo?['barcode']) ??
                    extractValidBarcodeOrPin(giftCardInfo?['barcodeNumber']) ??
                    extractValidBarcodeOrPin(giftCardInfo?['barcode_no']) ??
                    '';
    final barcodeImageUrl = giftCardInfo?['barcodeImage'] ?? 
                           giftCardInfo?['barcodeImageUrl'] ?? 
                           giftCardInfo?['barcode_img'] ?? 
                           giftCardInfo?['barcode_image'] ?? 
                           '';
    final pinNumber = extractValidBarcodeOrPin(giftCardInfo?['pinNumber']) ??
                     extractValidBarcodeOrPin(giftCardInfo?['pin']) ??
                     extractValidBarcodeOrPin(giftCardInfo?['pin_no']) ??
                     '';
    final expiryDate = giftCardInfo?['expiryDate'] ?? 
                      giftCardInfo?['expireDate'] ?? 
                      giftCardInfo?['expiry_date'] ?? 
                      giftCardInfo?['expire_date'] ?? 
                      '';
    
    debugPrint('📋 추출된 바코드 정보:');
    debugPrint('   barcode: $barcode');
    if (barcodeImageUrl.isNotEmpty) {
      final preview = barcodeImageUrl.length > 50 ? '${barcodeImageUrl.substring(0, 50)}...' : barcodeImageUrl;
      debugPrint('   barcodeImageUrl: $preview');
    } else {
      debugPrint('   barcodeImageUrl: (없음)');
    }
    debugPrint('   pinNumber: $pinNumber');
    debugPrint('   expiryDate: $expiryDate');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('기프티콘 사용'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상품명
            Text(
              goodsName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // 상품 이미지
            if (goodsImg != null && goodsImg.isNotEmpty) ...[
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 350),
                child: CachedNetworkImage(
                  imageUrl: goodsImg,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    height: 350,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 350,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 64,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // 바코드 이미지 (앱에서 자체 생성)
            if (barcode.isNotEmpty)
              // 바코드 번호가 있으면 바코드 이미지 자동 생성
              _BarcodeImage(barcode: barcode)
            else if (pinNumber.isNotEmpty)
              // PIN 번호가 있으면 PIN 번호로 바코드 이미지 생성
              _BarcodeImage(barcode: pinNumber)
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      '바코드 정보가 없습니다',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 30),
            
            // 유효기간
            if (expiryDate.isNotEmpty) ...[
              Text(
                '유효기간: $expiryDate',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 상품 설명
            if ((_detailData?['content'] ?? '').toString().isNotEmpty || 
                (widget.card['content'] ?? '').toString().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '상품 설명',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      (_detailData?['content'] ?? widget.card['content'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isLoadingDetail) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 바코드 이미지 생성 위젯
class _BarcodeImage extends StatelessWidget {
  final String barcode;

  const _BarcodeImage({required this.barcode});

  // 바코드 번호에서 숫자와 영문만 추출 (한글 제거)
  String _extractBarcodeData(String barcode) {
    // 숫자와 영문(대소문자)만 추출
    final regex = RegExp(r'[0-9A-Za-z]');
    final extracted = barcode.split('').where((char) => regex.hasMatch(char)).join();
    return extracted;
  }

  // 바코드 데이터가 유효한지 확인 (최소 1자 이상의 숫자/영문)
  bool _isValidBarcodeData(String data) {
    return data.isNotEmpty && RegExp(r'^[0-9A-Za-z]+$').hasMatch(data);
  }

  @override
  Widget build(BuildContext context) {
    // 바코드 번호에서 숫자와 영문만 추출
    final barcodeData = _extractBarcodeData(barcode);
    final isValid = _isValidBarcodeData(barcodeData);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 바코드 이미지 생성 (barcode_widget 패키지 사용)
          if (isValid)
            BarcodeWidget(
              barcode: Barcode.code128(), // Code128 형식 사용
              data: barcodeData, // 숫자/영문만 추출한 데이터 사용
              width: double.infinity,
              height: 120,
              drawText: true, // 바코드 아래에 번호 표시
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            // 바코드 생성 불가능한 경우 (한글만 있거나 숫자/영문이 없는 경우)
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 32),
                    SizedBox(height: 8),
                    Text(
                      '바코드 이미지 생성 불가',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
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

class _OwnedGiftCardListTabSliverState extends State<_OwnedGiftCardListTabSliver> {
  List<Map<String, dynamic>> _ownedCards = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadOwnedCards();
  }

  Future<void> _loadOwnedCards() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isLoggedIn || authService.user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
            _ownedCards = [];
          });
        }
        return;
      }

      final dataService = Provider.of<DataService>(context, listen: false);
      final ownedCards = await dataService.getOwnedGiftCards(authService.user!.uid);
      
      // 바코드 정보가 있는 기프티콘만 필터링
      final filteredCards = ownedCards.where((card) {
        final giftCardInfo = card['giftCardInfo'];
        if (giftCardInfo == null) return false;
        
        // giftCardInfo가 Map인지 확인
        Map<String, dynamic>? infoMap;
        if (giftCardInfo is Map) {
          infoMap = Map<String, dynamic>.from(giftCardInfo);
        } else {
          return false;
        }
        
        // 유효한 바코드 또는 PIN 번호가 있는지 확인
        String? extractValidBarcodeOrPin(dynamic value) {
          if (value == null) return null;
          final str = value.toString().trim();
          if (str.isEmpty || str == '발행' || str == '발행됨' || str == 'issued') return null;
          if (RegExp(r'^[0-9A-Za-z]+$').hasMatch(str) && str.length >= 3) {
            return str;
          }
          return null;
        }
        
        final barcode = extractValidBarcodeOrPin(infoMap['barcode']) ??
                        extractValidBarcodeOrPin(infoMap['barcodeNumber']) ??
                        extractValidBarcodeOrPin(infoMap['barcode_no']) ??
                        extractValidBarcodeOrPin(infoMap['pinNo']);
        final pinNumber = extractValidBarcodeOrPin(infoMap['pinNumber']) ??
                         extractValidBarcodeOrPin(infoMap['pin']) ??
                         extractValidBarcodeOrPin(infoMap['pin_no']) ??
                         extractValidBarcodeOrPin(infoMap['pinNo']);
        final barcodeImage = infoMap['barcodeImage'] ?? 
                            infoMap['barcodeImageUrl'] ?? 
                            infoMap['couponImgUrl'] ?? 
                            '';
        
        // 바코드, PIN, 또는 바코드 이미지 중 하나라도 있으면 표시
        return (barcode != null && barcode.isNotEmpty) || 
               (pinNumber != null && pinNumber.isNotEmpty) || 
               (barcodeImage != null && barcodeImage.toString().trim().isNotEmpty);
      }).toList();
      
      if (mounted) {
        setState(() {
          _ownedCards = filteredCards;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 보유 기프티콘 목록 로드 오류: $e');
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
    final authService = Provider.of<AuthService>(context);
    
    if (!authService.isLoggedIn) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: const Center(
          child: Text(
            '로그인이 필요합니다.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

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
                '보유 기프티콘 목록을 불러올 수 없습니다',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadOwnedCards,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_ownedCards.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            '보유한 기프티콘이 없습니다',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final card = _ownedCards[index];
            return _OwnedGiftCardItem(
              card: card,
              onTap: () {
                // 바코드 표시 화면으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _GiftCardBarcodeScreen(
                      card: card,
                    ),
                  ),
                );
              },
            );
          },
          childCount: _ownedCards.length,
        ),
      ),
    );
  }
}


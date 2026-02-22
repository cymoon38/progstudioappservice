import 'dart:async';

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
  String _giftCardCategory = '커피/음료'; // 기프티콘 카테고리 상태를 ShopScreen 레벨에서 관리 (기본값: 커피/음료)
  final GlobalKey<_GiftCardListTabSliverState> _giftCardListKey = GlobalKey<_GiftCardListTabSliverState>();

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
                decoration: const BoxDecoration(
                  color: Colors.white,
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
          // 기프티콘 탭일 때만 카테고리 필터 표시
          if (_selectedTab == 1)
            SliverToBoxAdapter(
              key: const ValueKey('category_filter_sliver'),
              child: RepaintBoundary(
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final state = _giftCardListKey.currentState;
                        return _CategoryFilterBar(
                          key: const ValueKey('category_filter_bar_widget'),
                          categories: const [
                            '커피/음료',
                            '베이커리/도넛',
                            '아이스크림',
                            '편의점',
                            '피자/버거/치킨',
                            '영화/음악/독서',
                            '상품권/마트/페이',
                            '상품 검색',
                          ],
                          selectedCategory: _giftCardCategory,
                          onCategorySelected: (category) {
                            setState(() {
                              _giftCardCategory = category;
                            });
                            // _GiftCardListTabSliver에 카테고리 변경 알림
                            _giftCardListKey.currentState?.setCategory(category);
                          },
                          // 검색 관련 콜백 전달
                          searchController: state?._searchController,
                          searchQuery: state?._searchQuery ?? '',
                          onSearchChanged: (value) {
                            // 검색어 입력 시에는 검색하지 않음 (비용 절감)
                            // 돋보기 버튼 클릭 시에만 검색 실행
                            // state?._debounceSearch(value); // 제거: 실시간 검색 비활성화
                          },
                          onSearchSubmitted: (value) {
                            // 엔터 키 입력 시에도 검색 실행 (사용자 편의성)
                            state?._performSearch(value);
                          },
                          onSearchClear: () {
                            if (state != null) {
                              state._searchController.clear();
                              state._performSearch('');
                            }
                          },
                        );
                      },
                    ),
                  ],
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
    return _GiftCardListTabSliver(
      key: _giftCardListKey,
      initialCategory: _giftCardCategory,
      onCategoryChanged: (category) {
        setState(() {
          _giftCardCategory = category;
        });
      },
    );
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
  final String initialCategory;
  final Function(String)? onCategoryChanged;
  
  const _GiftCardListTabSliver({
    super.key,
    required this.initialCategory,
    this.onCategoryChanged,
  });
  
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
  
  // 검색 관련 상태
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  Timer? _searchDebounce;
  List<GiftCard> _allSearchResults = []; // 검색 결과 전체 저장
  int _searchDisplayCount = 10; // 현재 표시할 검색 결과 개수
  
  // 카테고리별 상품코드 매핑 (각 카테고리별로 표시할 상품코드 목록)
  final Map<String, List<String>> _categoryGoodsCodes = {
    '커피/음료': ['G00003311076','G00003321051','G00003320983','G00003320985','G00003381084','G00003320984','G00003320992','G00002401526','G00003320986','G00003320987','G00003320988','G00002401526','G00002401537','G00002401542','G00003401079','G00003411061','G00004771059','G00002861259','G00003660932','G00003421395','G00001621761','G00001642212','G00001642210','G00004790938','G00004781056'], // 여기에 상품코드 목록을 추가하세요
    '베이커리/도넛': ['G00002281136','G00003401037','G00004061012','G00004600937','G00000211032','G00000183421','G00000183546','G00003411019','G00004031068','G00004521060','G00004461058','G00004461029','G00004451208','G00003383351','G00001380787','G00004261067','G00004181050','G00003531021','G00001401113','G00001411118'], // 여기에 상품코드 목록을 추가하세요
    '아이스크림': ['G00002101010','G00003181012','G00002081235','G00002101050','G00002101048','G00002100985','G00002101052','G00004521065','G00004451222','G00002090930','G00004820955','G00004261089','G00000183392','G00001961020','G00000221120','G00000220610'], // 여기에 상품코드 목록을 추가하세요
    '편의점': ['G00004261473','G00004291585','G00000970725','G00000970724','G00000750718','G00000750719','G00001460945','G00003261295','G00004291200','G00001470935','G00001700935','G00001561375','G00001751640','G00004291195','G00003271513','G00003401026','G00004061147','G00004061145','G00004061148','G00004291214','G00004261490','G00005001013','G00005001011','G00003271514'], // 여기에 상품코드 목록을 추가하세요
    '피자/버거/치킨': ['G00004661005','G00002971421','G00002971422','G00004701493','G00005150928','G00005122385','G00005150933','G00003151420','G00003151421','G00003491299','G00003151424','G00005101024','G00003151429','G00003900948','G00004680954','G00003890969','G00003900950','G00003900947','G00003900944','G00003890952','G00003900941','G00003890945','G00003511060','G00003530999','G00003530994','G00003530980','G00003511071','G00003431681','G00003002383','G00003011837'], // 여기에 상품코드 목록을 추가하세요
    '영화/음악/독서': ['G00004220933','G00003061244','G00005190931','G00001441070','G00004220939','G00005200929','G00004220934','G00003061245','G00004220935','G00005200928','G00004220936','G00004441004','G00004220937','G00004220938','G00000182630''G00000200518','G00000610800','G00001680961'], // 여기에 상품코드 목록을 추가하세요
    '상품권/마트/페이': ['G00001305415','G00005261004','G00000760670','G00000760671','G00001401607','G00000760672','G00004031412','G00004031411','G00001720988','G00001720986','G00001720987','G00001720985'

], // 여기에 상품코드 목록을 추가하세요
  };
  
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMore = false; // 상품코드 기반이므로 더 가져올 데이터 없음
  String? _selectedCategory;
  bool _isSyncing = false; // 동기화 중인지 확인
  static bool _hasCheckedSync = false; // 앱 전체에서 한 번만 확인
  String? _loadingCategory; // 현재 로딩 중인 카테고리 (경쟁 조건 방지)
  StreamSubscription? _syncStatusSubscription; // 동기화 상태 구독
  
  // 메모리 캐시: 카테고리별로 로드한 데이터 저장 (앱 실행 중 유지)
  static final Map<String, List<GiftCard>> _categoryCache = {};
  
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory; // 부모로부터 받은 초기 카테고리 사용
    _loadGiftCards();
    _listenToSyncStatus(); // 동기화 상태 실시간 감지
  }
  
  
  // 동기화 상태 실시간 감지
  void _listenToSyncStatus() {
    _syncStatusSubscription = FirebaseFirestore.instance
        .collection('syncStatus')
        .doc('giftcards')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final status = data?['status'] as String?;
        final isSyncing = status == 'syncing';
        
        if (mounted) {
          setState(() {
            _isSyncing = isSyncing;
          });
        }
      }
    }, onError: (error) {
      debugPrint('⚠️ 동기화 상태 감지 오류: $error');
    });
  }
  
  // 외부에서 카테고리 변경을 요청할 때 사용
  void setCategory(String category) {
    if (_selectedCategory != category) {
      setState(() {
        _selectedCategory = category;
        _hasMore = false;
        _allGiftCards = [];
        _giftCards = [];
        _isSearching = category == '상품 검색';
        if (!_isSearching) {
          _searchQuery = '';
          _searchController.clear();
        }
      });
      if (_isSearching) {
        // 검색 모드에서는 검색어 입력 대기
        setState(() {
          _isLoading = false;
        });
      } else {
        _loadGiftCards();
      }
      widget.onCategoryChanged?.call(category);
    }
  }
  
  // 디바운싱된 검색 (입력 중에는 검색하지 않고, 입력이 멈춘 후 검색)
  void _debounceSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }
  
  // 검색 실행
  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _giftCards = [];
        _allGiftCards = [];
        _allSearchResults = [];
        _searchDisplayCount = 10;
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _searchQuery = query.trim();
      _isLoading = true;
      _searchDisplayCount = 10; // 검색 시 처음 10개로 리셋
    });
    
    _searchGiftCards(query.trim());
  }
  
  // 검색 결과 더 로드 (스크롤 시)
  void _loadMoreSearchResults() {
    if (_isLoadingMore || _selectedCategory != '상품 검색') return;
    
    final totalResults = _allSearchResults.length;
    if (_searchDisplayCount >= totalResults) {
      setState(() {
        _hasMore = false;
      });
      return;
    }
    
    setState(() {
      _isLoadingMore = true;
      _searchDisplayCount += 10; // 10개씩 추가
    });
    
    // 다음 10개 표시
    setState(() {
      _giftCards = _allSearchResults.take(_searchDisplayCount).toList();
      _allGiftCards = _giftCards;
      _hasMore = _searchDisplayCount < totalResults;
      _isLoadingMore = false;
    });
  }
  
  // Firestore에서 상품 검색
  Future<void> _searchGiftCards(String query) async {
    try {
      debugPrint('🔍 상품 검색 시작: "$query"');
      
      // ⚠️ 중요: Firestore 읽기 비용은 실제로 읽은 문서 수에 따라 결정됩니다
      // 비용 최적화: 처음 500개만 읽고, 검색 결과가 10개 미만이면 500개씩 더 읽기
      const int initialLimit = 500;
      const int batchSize = 500;
      const int maxReads = 2000; // 최대 2000개까지만 읽기
      
      final List<GiftCard> searchResults = [];
      final queryLower = query.toLowerCase();
      int totalReads = 0;
      int currentLimit = initialLimit;
      Set<String> processedDocIds = {}; // 이미 처리한 문서 ID 추적
      
      // 검색 결과가 10개 미만이면 500개씩 더 읽기
      while (searchResults.length < 10 && currentLimit <= maxReads) {
        // 캐시 우선 사용 (이미 읽은 데이터는 비용 없음)
        final snapshot = await FirebaseFirestore.instance
            .collection('giftcards')
            .limit(currentLimit)
            .get(const GetOptions(source: Source.cache));
        
        // 캐시에 없으면 서버에서 가져오기
        final finalSnapshot = snapshot.docs.isEmpty
            ? await FirebaseFirestore.instance
                .collection('giftcards')
                .limit(currentLimit)
                .get(const GetOptions(source: Source.server))
            : snapshot;
        
        // 새로 읽은 문서만 검색 (중복 제거)
        for (final doc in finalSnapshot.docs) {
          // 이미 처리한 문서는 건너뛰기
          if (processedDocIds.contains(doc.id)) {
            continue;
          }
          processedDocIds.add(doc.id);
          
          try {
            final data = doc.data();
            // 검색 대상 필드: brandName, goodsTypeNm, goodsName
            final goodsName = (data['goodsName'] ?? '').toString().toLowerCase();
            final brandName = (data['brandName'] ?? '').toString().toLowerCase();
            final goodsTypeNm = (data['goodsTypeNm'] ?? '').toString().toLowerCase();
            
            // 검색어가 상품명, 브랜드명, 상품타입명 중 하나라도 포함되면 추가
            if (goodsName.contains(queryLower) || 
                brandName.contains(queryLower) || 
                goodsTypeNm.contains(queryLower)) {
              final giftCard = DataService.fromGiftCardMap(data);
              searchResults.add(giftCard);
            }
          } catch (e) {
            debugPrint('⚠️ 상품 데이터 변환 오류 (${doc.id}): $e');
          }
        }
        
        // 읽기 비용 계산 (서버에서 읽은 경우만)
        if (snapshot.docs.isEmpty) {
          totalReads += finalSnapshot.docs.length;
        }
        
        // 검색 결과가 10개 이상이거나 더 이상 읽을 문서가 없으면 종료
        if (searchResults.length >= 10 || finalSnapshot.docs.length < currentLimit) {
          break;
        }
        
        // 다음 배치 읽기
        currentLimit += batchSize;
      }
      
      // 로그 설명: 읽은 문서 = 전체 읽은 문서 수, 실제 reads = 서버에서 읽은 문서 수 (비용 발생)
      // 실제 reads가 0이면 모두 캐시에서 읽은 것이므로 비용이 발생하지 않음
      debugPrint('✅ 검색 결과: ${searchResults.length}개 (검색어: "$query")');
      debugPrint('   📊 읽은 문서: $currentLimit개 (캐시에서 읽음: ${currentLimit - totalReads}개, 서버에서 읽음: $totalReads개)');
      debugPrint('   💰 실제 reads 비용: $totalReads개 (캐시는 비용 없음)');
      
      if (mounted && _selectedCategory == '상품 검색' && _searchQuery == query) {
        // 검색 결과 전체 저장
        _allSearchResults = searchResults;
        
        // 처음 10개만 표시
        final displayCount = searchResults.length > 10 ? 10 : searchResults.length;
        final displayedResults = searchResults.take(displayCount).toList();
        
        setState(() {
          _allGiftCards = displayedResults;
          _giftCards = displayedResults;
          _hasMore = searchResults.length > 10; // 10개보다 많으면 더 로드 가능
          _isLoading = false;
          _hasError = false;
          _searchDisplayCount = displayCount;
        });
      }
    } catch (e) {
      debugPrint('❌ 상품 검색 오류: $e');
      if (mounted && _selectedCategory == '상품 검색') {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGiftCards({bool loadMore = false, bool forceRefresh = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      // 캐시 확인: 같은 카테고리를 다시 로드하는 경우 캐시에서 먼저 표시
      if (!forceRefresh && _selectedCategory != null && _categoryCache.containsKey(_selectedCategory)) {
        final cachedCards = _categoryCache[_selectedCategory]!;
        debugPrint('✅ 캐시에서 로드: ${cachedCards.length}개 (카테고리: $_selectedCategory)');
        setState(() {
          _allGiftCards = cachedCards;
          _giftCards = cachedCards;
          _isLoading = false;
          _hasError = false;
        });
        return; // 캐시에서 로드했으므로 종료
      }
      
      setState(() {
        _isLoading = true;
        _hasError = false;
        _hasMore = false; // 상품코드 기반이므로 더 가져올 데이터 없음
        _allGiftCards = [];
        _giftCards = [];
      });
    }

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });
        return;
      }
      
      // 카테고리별 상품코드 목록 가져오기
      final goodsCodes = _categoryGoodsCodes[_selectedCategory] ?? [];
      
      if (goodsCodes.isEmpty) {
        debugPrint('⚠️ 카테고리 "$_selectedCategory"에 상품코드가 없습니다.');
        setState(() {
          _allGiftCards = [];
          _giftCards = [];
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });
        return;
      }
      
      debugPrint('🔄 기프티콘 목록 로드 시작... (카테고리: $_selectedCategory, 상품코드 수: ${goodsCodes.length})');
      
      // 로딩 시작 시 현재 카테고리 저장 (경쟁 조건 방지)
      final loadingCategory = _selectedCategory;
      _loadingCategory = loadingCategory;
      
      // 1. Firestore에 전체 상품이 있는지 확인 (앱 전체에서 한 번만)
      if (!_hasCheckedSync && !_isSyncing) {
        _isSyncing = true;
        debugPrint('📋 Firestore 데이터 확인 중...');
        final existingSnapshot = await FirebaseFirestore.instance
            .collection('giftcards')
            .limit(1)
            .get();
        
        // 2. 전체 상품이 없으면 백그라운드에서 동기화 시작
        if (existingSnapshot.docs.isEmpty) {
          debugPrint('📋 Firestore에 데이터가 없습니다. 백그라운드에서 동기화 시작...');
          _hasCheckedSync = true;
          
          // 백그라운드에서 동기화 (블로킹하지 않음)
          _syncGiftCardsInBackground(dataService);
        } else {
          debugPrint('✅ Firestore에 이미 데이터가 있습니다.');
          _hasCheckedSync = true;
        }
        _isSyncing = false;
      }
      
      // 2. Firestore에서 지정된 상품코드만 필터링하여 가져오기
      // whereIn은 최대 10개까지만 허용하므로 여러 번 나눠서 조회
      // 병렬 처리로 속도 향상
      debugPrint('📋 Firestore에서 상품코드 필터링 시작... (총 ${goodsCodes.length}개)');
      final List<GiftCard> giftCards = [];
      const maxWhereInSize = 10; // Firestore whereIn 최대 개수
      
      // 빈 상품코드 제거
      final validGoodsCodes = goodsCodes.where((code) => code.isNotEmpty).toList();
      
      // 10개씩 나눠서 병렬 조회 (캐시 우선으로 더 빠르게)
      final List<Future<List<GiftCard>>> batchFutures = [];
      for (int i = 0; i < validGoodsCodes.length; i += maxWhereInSize) {
        final batch = validGoodsCodes.skip(i).take(maxWhereInSize).toList();
        batchFutures.add(
          FirebaseFirestore.instance
              .collection('giftcards')
              .where(FieldPath.documentId, whereIn: batch)
              .get(const GetOptions(source: Source.cache)) // 캐시 우선 조회로 빠른 응답
              .then((snapshot) {
                final List<GiftCard> batchCards = [];
                for (final doc in snapshot.docs) {
                  try {
                    final data = doc.data();
                    final giftCard = DataService.fromGiftCardMap(data);
                    batchCards.add(giftCard);
                  } catch (e) {
                    debugPrint('⚠️ 상품 데이터 변환 오류 (${doc.id}): $e');
                  }
                }
                return batchCards;
              })
              .catchError((e) {
                // 캐시에서 실패하면 서버에서 조회
                return FirebaseFirestore.instance
                    .collection('giftcards')
                    .where(FieldPath.documentId, whereIn: batch)
                    .get()
                    .then((snapshot) {
                      final List<GiftCard> batchCards = [];
                      for (final doc in snapshot.docs) {
                        try {
                          final data = doc.data();
                          final giftCard = DataService.fromGiftCardMap(data);
                          batchCards.add(giftCard);
                        } catch (e) {
                          debugPrint('⚠️ 상품 데이터 변환 오류 (${doc.id}): $e');
                        }
                      }
                      return batchCards;
                    })
                    .catchError((e) {
                      debugPrint('⚠️ Firestore 배치 조회 오류: $e');
                      return <GiftCard>[];
                    });
              }),
        );
      }
      
      // 모든 배치를 병렬로 실행
      final batchResults = await Future.wait(batchFutures);
      for (final batchCards in batchResults) {
        giftCards.addAll(batchCards);
      }
      
      debugPrint('📊 Firestore에서 총 조회된 상품: ${giftCards.length}개');
      
      debugPrint('✅ 필터링된 상품: ${giftCards.length}개 (요청한 상품코드: ${goodsCodes.length}개)');
      
      // Firestore에서 찾지 못한 상품코드가 있으면 상세 API로 시도 (병렬 처리)
      final foundGoodsCodes = giftCards.map((card) => card.goodsCode).toSet();
      final missingGoodsCodes = validGoodsCodes.where((code) => !foundGoodsCodes.contains(code)).toList();
      
      if (missingGoodsCodes.isNotEmpty) {
        debugPrint('⚠️ Firestore에서 찾지 못한 상품코드: ${missingGoodsCodes.length}개');
        
        // 상세 API를 병렬로 호출 (최대 5개씩 동시 실행)
        const maxConcurrent = 5;
        for (int i = 0; i < missingGoodsCodes.length; i += maxConcurrent) {
          final batch = missingGoodsCodes.skip(i).take(maxConcurrent).toList();
          final detailFutures = batch.map((goodsCode) async {
            try {
              final detail = await dataService.getGiftCardDetail(goodsCode);
              if (detail != null) {
                final goodsDetail = detail['goodsDetail'] ?? detail;
                if (goodsDetail is Map && goodsDetail.isNotEmpty) {
                  try {
                    final giftCard = DataService.fromGiftCardMap(Map<String, dynamic>.from(goodsDetail));
                    // Firestore에 저장 (백그라운드, await 하지 않음)
                    FirebaseFirestore.instance
                        .collection('giftcards')
                        .doc(goodsCode)
                        .set(Map<String, dynamic>.from(goodsDetail), SetOptions(merge: true))
                        .catchError((e) => debugPrint('⚠️ Firestore 저장 실패 ($goodsCode): $e'));
                    return giftCard;
                  } catch (e) {
                    debugPrint('⚠️ 상품 데이터 변환 오류 ($goodsCode): $e');
                    return null;
                  }
                }
              }
              return null;
            } catch (e) {
              debugPrint('⚠️ 상품코드 $goodsCode 상세 정보 조회 실패: $e');
              return null;
            }
          }).toList();
          
          final detailResults = await Future.wait(detailFutures);
          for (final giftCard in detailResults) {
            if (giftCard != null) {
              giftCards.add(giftCard);
            }
          }
        }
        
        debugPrint('✅ API로 추가된 상품: ${giftCards.length - foundGoodsCodes.length}개');
      }
      
      // 상품코드 입력 순서대로 정렬
      final Map<String, int> codeOrderMap = {};
      for (int i = 0; i < validGoodsCodes.length; i++) {
        codeOrderMap[validGoodsCodes[i]] = i;
      }
      
      giftCards.sort((a, b) {
        final orderA = codeOrderMap[a.goodsCode] ?? 999999;
        final orderB = codeOrderMap[b.goodsCode] ?? 999999;
        return orderA.compareTo(orderB);
      });
      
      debugPrint('📊 로드된 기프티콘: ${giftCards.length}개 (정렬 완료)');
      
      // 경쟁 조건 방지: 로딩 시작 시 저장한 카테고리와 현재 카테고리가 일치하는지 확인
      if (loadingCategory != _selectedCategory) {
        debugPrint('⚠️ 카테고리가 변경되어 로딩 결과 무시 (로딩: $loadingCategory, 현재: $_selectedCategory)');
        return; // 카테고리가 변경되었으므로 결과 무시
      }
      
      // 메모리 캐시에 저장
      if (loadingCategory != null) {
        _categoryCache[loadingCategory] = giftCards;
        debugPrint('💾 캐시에 저장: ${giftCards.length}개 (카테고리: $loadingCategory)');
      }
      
      if (mounted && loadingCategory == _selectedCategory) {
        setState(() {
          _allGiftCards = giftCards;
          _giftCards = giftCards;
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });
        debugPrint('✅ 기프티콘 목록 표시: ${_giftCards.length}개');
      }
    } catch (e) {
      debugPrint('❌ 기프티콘 목록 로드 오류: $e');
      // 경쟁 조건 방지: 로딩 시작 시 저장한 카테고리와 현재 카테고리가 일치하는지 확인
      if (mounted && _loadingCategory == _selectedCategory) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = true;
        });
      }
    }
  }

  // 카테고리 필터 적용 (이제 상품코드 기반이므로 단순히 복사만 함)
  void _applyCategoryFilter() {
    _giftCards = _allGiftCards;
  }

  // 백그라운드에서 기프티콘 동기화 (블로킹하지 않음)
  Future<void> _syncGiftCardsInBackground(DataService dataService) async {
    try {
      const totalProducts = 4304;
      const pageSize = 500;
      int currentPage = 1;
      int totalLoaded = 0;
      
      // 페이지네이션으로 전체 상품 가져오기
      while (totalLoaded < totalProducts) {
        final remaining = totalProducts - totalLoaded;
        final size = remaining > pageSize ? pageSize : remaining;
        
        debugPrint('📦 [백그라운드] 페이지 $currentPage 로드 중... (size: $size, 누적: $totalLoaded/$totalProducts)');
        final cards = await dataService.getGiftCardList(start: currentPage, size: size);
        
        if (cards.isEmpty) {
          debugPrint('⚠️ [백그라운드] 더 이상 가져올 상품이 없습니다.');
          break;
        }
        
        totalLoaded += cards.length;
        debugPrint('✅ [백그라운드] 페이지 $currentPage 완료: ${cards.length}개 (누적: $totalLoaded/$totalProducts)');
        
        // 마지막 페이지이거나 요청한 개수만큼 가져왔으면 종료
        if (cards.length < size || totalLoaded >= totalProducts) {
          break;
        }
        
        currentPage++;
      }
      
      debugPrint('✅ [백그라운드] 전체 상품 Firestore 저장 완료: 총 $totalLoaded개');
    } catch (e) {
      debugPrint('❌ [백그라운드] 동기화 오류: $e');
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

    // 카테고리 필터는 ShopScreen 레벨에서 관리하므로 여기서는 제거
    return SliverMainAxisGroup(
      slivers: [
        // 기프티콘 목록
        // 동기화 중일 때 "상품 업데이트중..." 메시지 표시
        if (_isSyncing && _giftCards.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '상품 업데이트중...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else if (_giftCards.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                // 검색 카테고리를 선택했고 검색어가 비어있을 때만 다른 문구 표시
                (_selectedCategory == '상품 검색' && _searchQuery.isEmpty)
                    ? '더 많은 기프티콘을 찾아보세요'
                    : '선택한 카테고리에 기프티콘이 없습니다',
                style: const TextStyle(color: Colors.grey),
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
                          // 검색 모드인지 확인
                          if (_selectedCategory == '상품 검색') {
                            _loadMoreSearchResults();
                          } else {
                            _loadGiftCards(loadMore: true);
                          }
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

// 카테고리 필터 바 (별도 StatefulWidget으로 분리하여 불필요한 rebuild 방지)
class _CategoryFilterBar extends StatefulWidget {
  final List<String> categories;
  final String? selectedCategory;
  final Function(String) onCategorySelected;
  final TextEditingController? searchController;
  final String searchQuery;
  final Function(String)? onSearchChanged;
  final Function(String)? onSearchSubmitted;
  final VoidCallback? onSearchClear;

  const _CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.searchController,
    this.searchQuery = '',
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchClear,
  });

  @override
  State<_CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<_CategoryFilterBar> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 위젯 상태 유지
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin을 위해 필요
    
    return Container(
      key: const ValueKey('category_filter_bar'),
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        key: const ValueKey('category_list_view'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final isSelected = category == widget.selectedCategory;
          final isSearchCategory = category == '상품 검색';
          
          // '상품 검색' 카테고리이고 선택되었을 때 검색 입력 필드 표시
          if (isSearchCategory && isSelected && widget.searchController != null) {
            // 검색어 길이에 따라 동적으로 너비 계산
            final searchText = widget.searchQuery;
            final textLength = searchText.length;
            // 최소 너비: 120, 최대 너비: 300
            // 문자당 약 8픽셀 추가 (폰트 크기 14 기준)
            final calculatedWidth = (120.0 + (textLength * 8.0)).clamp(120.0, 300.0);
            
            return Padding(
              key: ValueKey('category_$category'),
              padding: EdgeInsets.only(
                right: index < widget.categories.length - 1 ? 12 : 0,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: calculatedWidth, // 검색어 길이에 따라 동적 너비
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: widget.searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.2, // 줄 간격 조정으로 텍스트 잘림 방지
                  ),
                  decoration: InputDecoration(
                    hintText: '검색어 입력...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.2,
                    ),
                    prefixIcon: GestureDetector(
                      onTap: () {
                        // 돋보기 아이콘 클릭 시 검색 실행
                        final searchText = widget.searchController?.text ?? '';
                        if (searchText.trim().isNotEmpty && widget.onSearchSubmitted != null) {
                          widget.onSearchSubmitted!(searchText.trim());
                        }
                        // 키보드 닫기
                        FocusScope.of(context).unfocus();
                      },
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: widget.onSearchClear,
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false, // 배경색 없음
                    contentPadding: const EdgeInsets.symmetric(vertical: 0), // 세로 패딩만 조정
                    isDense: true,
                  ),
                  onChanged: widget.onSearchChanged,
                  onSubmitted: widget.onSearchSubmitted,
                ),
              ),
            );
          }
          
          // 일반 카테고리 버튼
          return Padding(
            key: ValueKey('category_$category'),
            padding: EdgeInsets.only(
              right: index < widget.categories.length - 1 ? 12 : 0,
            ),
            child: InkWell(
              onTap: () => widget.onCategorySelected(category),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  category,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  @override
  void didUpdateWidget(_CategoryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // selectedCategory가 변경되었을 때만 선택 상태 업데이트
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      // AnimatedContainer가 자동으로 애니메이션 처리하므로 setState 불필요
    }
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
                    ? Container(
                        color: Colors.white, // 흰색 배경 추가
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain, // 이미지 전체를 보여주도록 변경
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
                        ),
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
      
      // pinStatusCd가 없거나 오래된 기프티콘만 선택적으로 백그라운드에서 API 호출 (성능 최적화)
      // 백그라운드에서 비동기로 업데이트하여 로딩을 블로킹하지 않음
      final List<Future<void>> updateFutures = [];
      for (final card in ownedCards) {
        final giftCardInfo = card['giftCardInfo'];
        if (giftCardInfo != null && giftCardInfo is Map) {
          final infoMap = Map<String, dynamic>.from(giftCardInfo);
          final trId = infoMap['trId'] ?? card['trId'];
          final lastRefreshed = card['lastRefreshed'] as Timestamp?;
          
          // trId가 있고, 마지막 업데이트가 1시간 이상 전이면 백그라운드에서 API 호출
          // pinStatusCd가 있어도 상태가 변경될 수 있으므로 주기적으로 확인 필요
          final shouldUpdate = (trId != null && trId.toString().isNotEmpty) &&
                              (lastRefreshed == null || 
                               DateTime.now().difference(lastRefreshed.toDate()).inHours >= 1);
          
          if (shouldUpdate) {
            // 백그라운드에서 비동기로 업데이트 (블로킹하지 않음)
            updateFutures.add(
              dataService.refreshGiftCardBarcode(trId.toString()).then((refreshedInfo) {
                if (refreshedInfo != null && refreshedInfo['giftCardInfo'] != null) {
                  final refreshedGiftCardInfo = refreshedInfo['giftCardInfo'] as Map<String, dynamic>;
                  debugPrint('✅ pinStatusCd 백그라운드 업데이트: ${refreshedGiftCardInfo['pinStatusCd']}');
                }
              }).catchError((e) {
                debugPrint('⚠️ 백그라운드 pinStatusCd 업데이트 실패: $e');
              })
            );
          }
        }
      }
      
      // 백그라운드 업데이트는 기다리지 않고 바로 필터링 진행 (사용자 경험 개선)
      // 업데이트는 백그라운드에서 진행되며, 다음 로드 시 반영됨
      if (updateFutures.isNotEmpty) {
        Future.wait(updateFutures).catchError((e) {
          debugPrint('⚠️ 백그라운드 업데이트 오류: $e');
          return <void>[];
        });
      }
      
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
        
        // 원본 바코드/PIN 값 확인 (필터링 전)
        final rawBarcode = infoMap['barcode']?.toString().trim() ?? 
                         infoMap['barcodeNumber']?.toString().trim() ?? 
                         infoMap['barcode_no']?.toString().trim() ?? 
                         infoMap['pinNo']?.toString().trim() ?? '';
        final rawPinNumber = infoMap['pinNumber']?.toString().trim() ?? 
                            infoMap['pin']?.toString().trim() ?? 
                            infoMap['pin_no']?.toString().trim() ?? 
                            infoMap['pinNo']?.toString().trim() ?? '';
        
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
        
        // 사용한 기프티콘 필터링: pinStatusCd 확인 (API 문서 기준)
        // pinStatusCd: 01=발행, 02=교환(사용완료), 03=반품, 04=관리폐기, 05=환불, 06=재발행, 07=구매취소(폐기), 08=기간만료, 등등
        final pinStatusCd = infoMap['pinStatusCd']?.toString().trim() ?? '';
        final pinStatusNm = infoMap['pinStatusNm']?.toString().trim() ?? '';
        
        // 사용 불가능한 상태 코드: 02(교환/사용완료), 03(반품), 04(관리폐기), 05(환불), 07(구매취소/폐기), 08(기간만료), 10(잔액환불), 11(잔액기간만료), 12(기간만료취소), 13(환전), 14(환급), 15(잔액환급), 16(잔액기간만료취소)
        final usedStatusCodes = ['02', '03', '04', '05', '07', '08', '10', '11', '12', '13', '14', '15', '16'];
        final isUsedByPinStatus = usedStatusCodes.contains(pinStatusCd);
        
        // 기존 필터링 조건들 (하위 호환성)
        final status = infoMap['status']?.toString().toLowerCase() ?? '';
        final isUsedByStatus = status == 'used' || 
                              status == '사용됨' || 
                              status == '사용' ||
                              status == 'expired' ||
                              status == '만료됨' ||
                              status == '만료';
        final isUsedFlag = infoMap['isUsed'] == true || infoMap['isUsed'] == 'true';
        final usedAt = infoMap['usedAt'];
        final hasUsedAt = usedAt != null;
        final isBarcodeIssued = rawBarcode.toLowerCase() == '발행' || 
                               rawBarcode.toLowerCase() == '발행됨' || 
                               rawBarcode.toLowerCase() == 'issued' ||
                               rawPinNumber.toLowerCase() == '발행' || 
                               rawPinNumber.toLowerCase() == '발행됨' || 
                               rawPinNumber.toLowerCase() == 'issued';
        final hasNoValidBarcode = (barcode == null || barcode.isEmpty) && 
                                  (pinNumber == null || pinNumber.isEmpty) && 
                                  (barcodeImage == null || barcodeImage.toString().trim().isEmpty);
        
        // trId 확인 (구매 완료 여부)
        final trId = infoMap['trId'] ?? card['trId'];
        final hasTrId = trId != null && trId.toString().trim().isNotEmpty;
        
        // 새로 구매한 상품은 pinStatusCd가 비어있고 바코드가 없을 수 있음 (발행 대기 중)
        // trId가 있으면 구매는 완료된 상태이므로 표시해야 함
        final isPendingIssue = pinStatusCd.isEmpty && hasNoValidBarcode && hasTrId;
        
        // 사용한 기프티콘은 제외 (pinStatusCd 우선 확인)
        // 단, 발행 대기 중인 상품(pinStatusCd가 비어있고 trId가 있는 경우)은 표시
        if (isUsedByPinStatus || isUsedByStatus || isUsedFlag || hasUsedAt || isBarcodeIssued || (hasNoValidBarcode && !isPendingIssue)) {
          // 디버그: 사용한 기프티콘 필터링 로그 (간소화)
          if (isUsedByPinStatus) {
            debugPrint('🚫 사용한 기프티콘 필터링: ${card['goodsName'] ?? '알 수 없음'} (pinStatusCd: $pinStatusCd, pinStatusNm: $pinStatusNm)');
          }
          return false;
        }
        
        // 바코드, PIN, 바코드 이미지 중 하나라도 있거나, 발행 대기 중인 상품이면 표시
        return true;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                  border: Border.all(color: const Color.fromARGB(255, 225, 225, 225)!, width: 1),
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
    
    // 원본 데이터 확인용 디버그 (모든 필드 확인)
    debugPrint('📋 giftCardInfo 원본 데이터 (모든 필드):');
    if (giftCardInfo != null) {
      giftCardInfo.forEach((key, value) {
        debugPrint('   $key: $value');
      });
    } else {
      debugPrint('   giftCardInfo가 null입니다.');
    }
    
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
                    // 유효기간 표시
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            '유효기간: 30일',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
      
      // pinStatusCd가 없거나 오래된 기프티콘만 선택적으로 백그라운드에서 API 호출 (성능 최적화)
      // 백그라운드에서 비동기로 업데이트하여 로딩을 블로킹하지 않음
      final List<Future<void>> updateFutures = [];
      for (final card in ownedCards) {
        final giftCardInfo = card['giftCardInfo'];
        if (giftCardInfo != null && giftCardInfo is Map) {
          final infoMap = Map<String, dynamic>.from(giftCardInfo);
          final trId = infoMap['trId'] ?? card['trId'];
          final lastRefreshed = card['lastRefreshed'] as Timestamp?;
          
          // trId가 있고, 마지막 업데이트가 1시간 이상 전이면 백그라운드에서 API 호출
          // pinStatusCd가 있어도 상태가 변경될 수 있으므로 주기적으로 확인 필요
          final shouldUpdate = (trId != null && trId.toString().isNotEmpty) &&
                              (lastRefreshed == null || 
                               DateTime.now().difference(lastRefreshed.toDate()).inHours >= 1);
          
          if (shouldUpdate) {
            // 백그라운드에서 비동기로 업데이트 (블로킹하지 않음)
            updateFutures.add(
              dataService.refreshGiftCardBarcode(trId.toString()).then((refreshedInfo) {
                if (refreshedInfo != null && refreshedInfo['giftCardInfo'] != null) {
                  final refreshedGiftCardInfo = refreshedInfo['giftCardInfo'] as Map<String, dynamic>;
                  debugPrint('✅ pinStatusCd 백그라운드 업데이트: ${refreshedGiftCardInfo['pinStatusCd']}');
                }
              }).catchError((e) {
                debugPrint('⚠️ 백그라운드 pinStatusCd 업데이트 실패: $e');
              })
            );
          }
        }
      }
      
      // 백그라운드 업데이트는 기다리지 않고 바로 필터링 진행 (사용자 경험 개선)
      // 업데이트는 백그라운드에서 진행되며, 다음 로드 시 반영됨
      if (updateFutures.isNotEmpty) {
        Future.wait(updateFutures).catchError((e) {
          debugPrint('⚠️ 백그라운드 업데이트 오류: $e');
          return <void>[];
        });
      }
      
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
        
        // 원본 바코드/PIN 값 확인 (필터링 전)
        final rawBarcode = infoMap['barcode']?.toString().trim() ?? 
                         infoMap['barcodeNumber']?.toString().trim() ?? 
                         infoMap['barcode_no']?.toString().trim() ?? 
                         infoMap['pinNo']?.toString().trim() ?? '';
        final rawPinNumber = infoMap['pinNumber']?.toString().trim() ?? 
                            infoMap['pin']?.toString().trim() ?? 
                            infoMap['pin_no']?.toString().trim() ?? 
                            infoMap['pinNo']?.toString().trim() ?? '';
        
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
        
        // 사용한 기프티콘 필터링: pinStatusCd 확인 (API 문서 기준)
        // pinStatusCd: 01=발행, 02=교환(사용완료), 03=반품, 04=관리폐기, 05=환불, 06=재발행, 07=구매취소(폐기), 08=기간만료, 등등
        final pinStatusCd = infoMap['pinStatusCd']?.toString().trim() ?? '';
        final pinStatusNm = infoMap['pinStatusNm']?.toString().trim() ?? '';
        
        // 사용 불가능한 상태 코드: 02(교환/사용완료), 03(반품), 04(관리폐기), 05(환불), 07(구매취소/폐기), 08(기간만료), 10(잔액환불), 11(잔액기간만료), 12(기간만료취소), 13(환전), 14(환급), 15(잔액환급), 16(잔액기간만료취소)
        final usedStatusCodes = ['02', '03', '04', '05', '07', '08', '10', '11', '12', '13', '14', '15', '16'];
        final isUsedByPinStatus = usedStatusCodes.contains(pinStatusCd);
        
        // 기존 필터링 조건들 (하위 호환성)
        final status = infoMap['status']?.toString().toLowerCase() ?? '';
        final isUsedByStatus = status == 'used' || 
                              status == '사용됨' || 
                              status == '사용' ||
                              status == 'expired' ||
                              status == '만료됨' ||
                              status == '만료';
        final isUsedFlag = infoMap['isUsed'] == true || infoMap['isUsed'] == 'true';
        final usedAt = infoMap['usedAt'];
        final hasUsedAt = usedAt != null;
        final isBarcodeIssued = rawBarcode.toLowerCase() == '발행' || 
                               rawBarcode.toLowerCase() == '발행됨' || 
                               rawBarcode.toLowerCase() == 'issued' ||
                               rawPinNumber.toLowerCase() == '발행' || 
                               rawPinNumber.toLowerCase() == '발행됨' || 
                               rawPinNumber.toLowerCase() == 'issued';
        final hasNoValidBarcode = (barcode == null || barcode.isEmpty) && 
                                  (pinNumber == null || pinNumber.isEmpty) && 
                                  (barcodeImage == null || barcodeImage.toString().trim().isEmpty);
        
        // trId 확인 (구매 완료 여부)
        final trId = infoMap['trId'] ?? card['trId'];
        final hasTrId = trId != null && trId.toString().trim().isNotEmpty;
        
        // 새로 구매한 상품은 pinStatusCd가 비어있고 바코드가 없을 수 있음 (발행 대기 중)
        // trId가 있으면 구매는 완료된 상태이므로 표시해야 함
        final isPendingIssue = pinStatusCd.isEmpty && hasNoValidBarcode && hasTrId;
        
        // 사용한 기프티콘은 제외 (pinStatusCd 우선 확인)
        // 단, 발행 대기 중인 상품(pinStatusCd가 비어있고 trId가 있는 경우)은 표시
        if (isUsedByPinStatus || isUsedByStatus || isUsedFlag || hasUsedAt || isBarcodeIssued || (hasNoValidBarcode && !isPendingIssue)) {
          // 디버그: 사용한 기프티콘 필터링 로그 (간소화)
          if (isUsedByPinStatus) {
            debugPrint('🚫 사용한 기프티콘 필터링: ${card['goodsName'] ?? '알 수 없음'} (pinStatusCd: $pinStatusCd, pinStatusNm: $pinStatusNm)');
          }
          return false;
        }
        
        // 바코드, PIN, 바코드 이미지 중 하나라도 있거나, 발행 대기 중인 상품이면 표시
        return true;
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


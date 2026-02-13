import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/data_service.dart';
import '../../theme/app_theme.dart';

class GiftCardDetailScreen extends StatefulWidget {
  final String goodsCode;
  final GiftCard? giftCard; // 목록에서 전달받은 기본 정보 (선택사항)

  const GiftCardDetailScreen({
    super.key,
    required this.goodsCode,
    this.giftCard,
  });

  @override
  State<GiftCardDetailScreen> createState() => _GiftCardDetailScreenState();
}

class _GiftCardDetailScreenState extends State<GiftCardDetailScreen> {
  Map<String, dynamic>? _detailData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dataService = Provider.of<DataService>(context, listen: false);
      final detail = await dataService.getGiftCardDetail(widget.goodsCode);

      if (mounted) {
        setState(() {
          _detailData = detail;
          _isLoading = false;
          if (detail == null) {
            _errorMessage = '상세 정보를 불러올 수 없습니다.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '상세 정보를 불러오는 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  // 가격 포맷팅 (콤마 형식)
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // 이미지 URL 가져오기 (고화질 우선, 잘림 방지)
  String _getImageUrl() {
    if (_detailData != null) {
      // 상세 정보에서 고화질 이미지 우선순위: goodsImgB > goodsimg > mmsGoodsimg > goodsImgS
      final imageUrl = (_detailData!['goodsImgB']?.toString().trim() ?? '').isNotEmpty
          ? _detailData!['goodsImgB'].toString().trim()
          : (_detailData!['goodsimg']?.toString().trim() ?? '').isNotEmpty
              ? _detailData!['goodsimg'].toString().trim()
              : (_detailData!['mmsGoodsimg']?.toString().trim() ?? '').isNotEmpty
                  ? _detailData!['mmsGoodsimg'].toString().trim()
                  : (_detailData!['goodsImgS']?.toString().trim() ?? '').isNotEmpty
                      ? _detailData!['goodsImgS'].toString().trim()
                      : '';
      if (imageUrl.isNotEmpty) return imageUrl;
    }
    // 상세 정보에 없으면 목록에서 받은 정보 사용
    return widget.giftCard?.goodsimg ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('기프티콘 상세'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDetail,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이미지 영역 (고화질, 잘림 방지)
                      Container(
                        width: double.infinity,
                        height: 350,
                        color: Colors.grey[100],
                        child: _getImageUrl().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _getImageUrl(),
                                fit: BoxFit.contain, // contain으로 이미지 전체 표시 (잘림 방지)
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 64,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 64,
                              ),
                      ),
                      
                      // 정보 영역
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 브랜드명
                            if ((_detailData?['brandName'] ?? widget.giftCard?.brandName ?? '').isNotEmpty)
                              Text(
                                _detailData?['brandName'] ?? widget.giftCard?.brandName ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            
                            const SizedBox(height: 8),
                            
                            // 상품명
                            Text(
                              _detailData?['goodsName'] ?? widget.giftCard?.goodsName ?? '상품명 없음',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // 가격 정보
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _formatPrice(
                                    _detailData?['discountPrice'] ?? 
                                    widget.giftCard?.discountPrice ?? 0
                                  ),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 코인 아이콘
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'C',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // 원가 (할인가가 있는 경우)
                            if ((_detailData?['salePrice'] ?? widget.giftCard?.salePrice ?? 0) > 
                                (_detailData?['discountPrice'] ?? widget.giftCard?.discountPrice ?? 0))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '원가: ${_formatPrice(_detailData?['salePrice'] ?? widget.giftCard?.salePrice ?? 0)}원',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            
                            const SizedBox(height: 24),
                            
                            // 구분선
                            Divider(color: Colors.grey[300]),
                            
                            const SizedBox(height: 24),
                            
                            // content 필드만 표시
                            if ((_detailData?['content'] ?? '').toString().isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '상품 설명',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _detailData!['content'].toString(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      
                      // 하단 여백 (구매 버튼 공간)
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      // 구매 버튼 (추후 구현)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () {
              // TODO: 구매 기능 구현
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('구매 기능은 곧 추가될 예정입니다.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatPrice(
                    _detailData?['discountPrice'] ?? 
                    widget.giftCard?.discountPrice ?? 0
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                const Text(
                  '구매하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


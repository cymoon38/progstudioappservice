import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class CoinModal extends StatefulWidget {
  const CoinModal({super.key});

  @override
  State<CoinModal> createState() => _CoinModalState();
}

class _CoinModalState extends State<CoinModal> {
  bool _loading = true;
  List<CoinHistoryItem> _items = [];
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCoinBalance();
      _loadHistory();
    });
  }

  Future<void> _updateCoinBalance() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isLoggedIn) {
      await auth.updateCoinBalance();
    }
  }

  Future<void> _loadHistory({bool loadMore = false}) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isLoggedIn) return;

    if (!loadMore) {
      setState(() {
        _loading = true;
        _items = [];
        _lastDoc = null;
        _hasMore = true;
      });
    }

    try {
      final limit = loadMore ? 10 : 5;
      
      Query query = FirebaseFirestore.instance
          .collection('coinHistory')
          .where('userId', isEqualTo: auth.user!.uid)
          .orderBy('timestamp', descending: true)
          .limit(limit + 1);

      if (loadMore && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      
      if (!mounted) return;

      final hasMore = snapshot.docs.length > limit;
      final docsToShow = snapshot.docs.take(limit).toList();

      setState(() {
        if (loadMore) {
          _items.addAll(docsToShow.map((d) => CoinHistoryItem.fromFirestore(d)));
        } else {
          _items = docsToShow.map((d) => CoinHistoryItem.fromFirestore(d)).toList();
        }
        _hasMore = hasMore;
        if (docsToShow.isNotEmpty) {
          _lastDoc = docsToShow.last;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('코인 내역 로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final coins = auth.userData?['coins'] ?? 0;
    final coinsInt = coins is int ? coins : int.tryParse('$coins') ?? 0;
    final coinsFormatted = formatCoinsInMan(coinsInt);

    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.7), // CSS: rgba(0, 0, 0, 0.7)
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 닫기 버튼 (오른쪽 상단)
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF999999),
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 내용
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 코인 잔액 표시 (헤더)
                  Row(
                    children: [
                      // 코인 아이콘 (큰 사이즈)
                      Container(
                        width: 64, // CSS: 4rem
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF6D365).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'C',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24, // CSS: 1.5rem
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24), // CSS: gap: 1.5rem
                      // 코인 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내 코인',
                              style: TextStyle(
                                fontSize: 24, // CSS: 1.5rem
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8), // CSS: margin-bottom: 0.5rem
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  coinsFormatted,
                                  style: const TextStyle(
                                    fontSize: 32, // CSS: 2rem
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor, // #667eea
                                  ),
                                ),
                                const SizedBox(width: 8), // CSS: gap: 0.5rem
                                const Text(
                                  '코인',
                                  style: TextStyle(
                                    fontSize: 16, // CSS: 1rem
                                    color: AppTheme.textSecondary, // #666
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), // CSS: margin-bottom: 1.5rem
                  const Divider(height: 2, thickness: 2, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 24),
                  // 코인 내역
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 200,
                        maxHeight: 400,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _loading && _items.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _items.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(48),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '아직 코인 내역이 없습니다.',
                                          style: TextStyle(
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '미션을 완료하거나 출석체크를 하면 코인을 획득할 수 있습니다.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[400], // #bbb
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification is ScrollEndNotification &&
                                        notification.metrics.pixels >=
                                            notification.metrics.maxScrollExtent * 0.8 &&
                                        _hasMore &&
                                        !_loading) {
                                      _loadHistory(loadMore: true);
                                    }
                                    return false;
                                  },
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _items.length + (_hasMore ? 1 : 0),
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0xFFF0F0F0),
                                    ),
                                    itemBuilder: (context, index) {
                                      if (index >= _items.length) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }
                                      final item = _items[index];
                                      // 날짜 포맷 (로케일 초기화 없이 직접 포맷)
                                      final year = item.timestamp.year;
                                      final month = item.timestamp.month;
                                      final day = item.timestamp.day;
                                      final hour = item.timestamp.hour.toString().padLeft(2, '0');
                                      final minute = item.timestamp.minute.toString().padLeft(2, '0');
                                      final date = '$year년 $month월 $day일 $hour:$minute';
                                      final amountClass = item.amount > 0 ? 'positive' : 'negative';
                                      final amountSign = item.amount > 0 ? '+' : '';
                                      final amountFormatted = formatCoinsInMan(item.amount);

                                      return InkWell(
                                        onTap: () {},
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _getTypeDisplayName(item.type),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.textPrimary,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      date,
                                                      style: const TextStyle(
                                                        fontSize: 13.6, // CSS: 0.85rem
                                                        color: AppTheme.textTertiary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '$amountSign$amountFormatted 코인',
                                                style: TextStyle(
                                                  fontSize: 17.6, // CSS: 1.1rem
                                                  fontWeight: FontWeight.w700,
                                                  color: amountClass == 'positive'
                                                      ? const Color(0xFFA8B5FF) // 연한 보라색
                                                      : AppTheme.errorColor, // #f44336
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeDisplayName(String type) {
    if (type == 'mission_참가') {
      return '미션 참가';
    }
    if (type.startsWith('mission_')) {
      return '미션 완료 보상';
    }
    if (type == 'giftcard_purchase') {
      return '기프티콘 구매';
    }
    if (type == 'item_장작') return '아이템 사용';
    if (type == 'item_목탄') return '아이템 사용';
    if (type == 'item_석탄') return '아이템 사용';
    if (type == '목탄 댓글 채택') return '댓글 채택';
    if (type == '석탄 댓글 채택') return '댓글 채택';
    if (type == '댓글 채택') return '댓글 채택';
    if (type == 'offerwall') return '캠페인 참여';
    return type;
  }
}

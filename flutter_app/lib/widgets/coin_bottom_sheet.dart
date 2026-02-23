import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';

class CoinBottomSheet extends StatefulWidget {
  const CoinBottomSheet({super.key});

  @override
  State<CoinBottomSheet> createState() => _CoinBottomSheetState();
}

class _CoinBottomSheetState extends State<CoinBottomSheet> {
  bool _loading = true;
  List<CoinHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final data = Provider.of<DataService>(context, listen: false);
      final list = await data.getCoinHistory(auth.user!.uid, limit: 20);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코인 내역 로드 오류: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final coins = (auth.userData?['coins'] ?? 0).toString();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'C',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '내 코인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ),
                Text(
                  coins,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 4),
                const Text('코인', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('코인 내역', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (!auth.isLoggedIn)
                      const Text('로그인이 필요합니다.')
                    else if (_loading)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    else if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('아직 코인 내역이 없습니다.', style: TextStyle(color: AppTheme.textTertiary)),
                      )
                    else
                      SizedBox(
                        height: 320,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, i) {
                            final h = _items[i];
                            final sign = h.amount >= 0 ? '+' : '';
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _getTypeDisplayName(h.type),
                                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '$sign${h.amount}',
                                  style: TextStyle(
                                    color: h.amount >= 0 ? const Color(0xFF1F9D55) : AppTheme.errorColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
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
    if (type == 'giftcard_purchase') {
      return '기프티콘 구매';
    }
    if (type == 'item_장작') return '장작 사용';
    if (type == 'item_목탄') return '목탄 사용';
    if (type == 'item_석탄') return '석탄 사용';
    if (type == '목탄 댓글 채택') return '목탄 댓글 채택';
    if (type == '석탄 댓글 채택') return '석탄 댓글 채택';
    if (type == '댓글 채택') {
      return '댓글 채택';
    }
    return type;
  }
}




import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notice_create_modal.dart';
import '../post_detail_screen.dart';
import '../admin/report_list_screen.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotices();
    });
  }

  Future<void> _loadNotices() async {
    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      await dataService.getNotices();
    } catch (e) {
      debugPrint('공지 로딩 오류: $e');
    }
  }

  Future<void> _downloadCoinHistory(BuildContext context) async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      
      // 전체 사용자 평균 코인 보유량 계산
      final averageData = await dataService.getAverageCoinBalance();
      
      // 상위 1000명의 코인 보유량 조회
      final holders = await dataService.getTopCoinHolders(limit: 1000);

      if (holders.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // 로딩 다이얼로그 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('데이터가 없습니다.')),
          );
        }
        return;
      }

      // 엑셀 파일 생성
      final excel = Excel.createExcel();
      
      // 새 시트 생성
      final sheet = excel['코인 내역'];
      
      // 기본 시트 삭제 (새 시트를 만든 후 삭제 가능)
      try {
        if (excel.sheets.keys.contains('Sheet1') && excel.sheets.length > 1) {
          excel.delete('Sheet1');
        }
      } catch (e) {
        debugPrint('기본 시트 삭제 오류 (무시): $e');
      }

      // 평균 코인 보유량 정보 추가 (상단)
      final averageCoins = averageData['averageCoins'];
      final averageCoinsStr = averageCoins is double 
          ? averageCoins.toStringAsFixed(2)
          : (averageCoins is num 
              ? averageCoins.toStringAsFixed(2)
              : '0.00');
      
      sheet.appendRow([
        '전체 사용자 평균 코인 보유량',
        '',
        '',
        '',
        averageCoinsStr,
      ]);
      sheet.appendRow([
        '전체 사용자 수',
        '',
        '',
        '',
        averageData['totalUsers'] ?? 0,
      ]);
      sheet.appendRow([
        '전체 코인 합계',
        '',
        '',
        '',
        averageData['totalCoins'] ?? 0,
      ]);
      sheet.appendRow([]); // 빈 행 추가

      // 헤더 추가
      sheet.appendRow([
        '순위',
        '사용자 ID',
        '사용자명',
        '이메일',
        '보유 코인',
      ]);

      // 데이터 추가
      for (int i = 0; i < holders.length; i++) {
        final holder = holders[i];
        sheet.appendRow([
          i + 1,
          holder['userId'] ?? '',
          holder['username'] ?? '알 수 없음',
          holder['email'] ?? '',
          holder['coins'] ?? 0,
        ]);
      }

      // 파일 저장
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '코인내역_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // 파일 공유
        if (context.mounted) {
          Navigator.pop(context); // 로딩 다이얼로그 닫기
          
          final xFile = XFile(filePath);
          await Share.shareXFiles(
            [xFile],
            subject: '코인 내역',
            text: '상위 1000명의 코인 보유량 내역입니다.',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${holders.length}명의 코인 내역이 다운로드되었습니다.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('코인 내역 다운로드 오류: $e');
      if (context.mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Consumer<DataService>(
          builder: (context, dataService, _) {
            final notices = dataService.notices;

            return RefreshIndicator(
              onRefresh: _loadNotices,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  // 헤더 (화살표 나가기 + 운영자 버튼)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).pop(),
                            color: AppTheme.textPrimary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          ),
                          // 운영자만 공지 작성 및 코인 내역 버튼 표시
                          Consumer<AuthService>(
                            builder: (context, authService, _) {
                              if (!authService.isLoggedIn || !authService.isAdmin()) {
                                return const SizedBox.shrink();
                              }
                              
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        builder: (context) => const NoticeCreateModal(),
                                      );
                                    },
                                    icon: const Icon(Icons.add, size: 12),
                                    label: const Text('공지'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _downloadCoinHistory(context),
                                    icon: const Icon(Icons.download, size: 12),
                                    label: const Text('코인'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ReportListScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.flag, size: 12),
                                    label: const Text('신고'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4B6BFB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 공지 목록
                  if (dataService.isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (notices.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          '공지사항이 없습니다.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : (MediaQuery.of(context).size.width - 800) / 2,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final notice = notices[index];
                            final isFirst = index == 0;
                            final isLast = index == notices.length - 1;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 최상단 글 상단 구분선 / 글 사이 구분선
                                if (isFirst || index > 0)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6E8F0),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                _NoticeCard(notice: notice),
                                // 최하단 글 하단 구분선
                                if (isLast)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6E8F0),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          childCount: notices.length,
                        ),
                      ),
                    ),
                  // 하단 여백
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 60,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Post notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: notice.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 (목록에서는 얇은 글씨)
              Text(
                notice.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


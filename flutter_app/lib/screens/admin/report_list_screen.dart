import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../post_detail_screen.dart';

class ReportListScreen extends StatelessWidget {
  const ReportListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isLoggedIn || !auth.isAdmin()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('신고 내역'),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        body: const Center(
          child: Text('관리자만 접근할 수 있습니다.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('신고 내역'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<List<ReportItem>>(
        future: Provider.of<DataService>(context, listen: false).getReports(limit: 200),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('신고 내역을 불러오는 중 오류가 발생했습니다.\n${snapshot.error}'));
          }
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const Center(child: Text('접수된 신고가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final r = reports[index];
              bool dismissed = false;
              return StatefulBuilder(
                builder: (context, setState) {
                  if (dismissed) {
                    return const SizedBox.shrink();
                  }
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(reportId: r.id),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE6E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.type,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.detail,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '대상: ${r.targetType == 'comment' ? '댓글' : '게시물'} · ${r.targetAuthor}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '신고자: ${r.reporterName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                            tooltip: '이 신고 숨기기',
                            onPressed: () async {
                              try {
                                await Provider.of<DataService>(context, listen: false)
                                    .dismissReport(r.id);
                                setState(() {
                                  dismissed = true;
                                });
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('신고 숨기기에 실패했습니다: $e')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ReportDetailScreen extends StatelessWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신고 상세'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<ReportItem?>(
        future: Provider.of<DataService>(context, listen: false).getReportById(reportId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('신고 상세를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}'));
          }
          final report = snapshot.data;
          if (report == null) {
            return const Center(child: Text('신고 내역을 찾을 수 없습니다.'));
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.type,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '대상: ${report.targetType == 'comment' ? '댓글' : '게시물'} · ${report.targetAuthor}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '신고자: ${report.reporterName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '세부 내용',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      report.detail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: report.targetPostId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '해당 게시물로 이동',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


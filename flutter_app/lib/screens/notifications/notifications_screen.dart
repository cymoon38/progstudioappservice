import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<AppNotification> _items = [];

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
      final list = await data.getUserNotifications(auth.user!.uid, limit: 50);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('알림 로드 오류: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final data = Provider.of<DataService>(context, listen: false);
    await data.markAllNotificationsAsRead(auth.user!.uid);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (auth.isLoggedIn)
            TextButton(
              onPressed: _items.isEmpty ? null : _markAllRead,
              child: const Text('모두 읽음'),
            ),
        ],
      ),
      body: !auth.isLoggedIn
          ? const Center(child: Text('로그인이 필요합니다.'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('알림이 없습니다.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final n = _items[i];
                          return _NotificationTile(
                            item: n,
                            onTap: () async {
                              final data = Provider.of<DataService>(context, listen: false);
                              await data.markNotificationAsRead(n.id);
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PostDetailScreen(postId: n.postId)),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLike = item.type == 'like';
    final icon = isLike ? Icons.favorite : Icons.comment;
    final iconColor = isLike ? AppTheme.likeColor : AppTheme.primaryColor;

    final title = item.postTitle?.isNotEmpty == true ? item.postTitle! : '게시물';
    final author = item.author?.isNotEmpty == true ? item.author! : '누군가';

    final text = isLike
        ? '$author님이 "$title"에 좋아요를 눌렀습니다'
        : '$author님이 "$title"에 댓글을 달았습니다';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.groupCount > 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+${item.groupCount - 1}개 더',
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}




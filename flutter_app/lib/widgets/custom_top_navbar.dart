import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/auth/login_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_modal.dart';

class CustomTopNavbar extends StatelessWidget implements PreferredSizeWidget {
  const CustomTopNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          // 모바일에서는 max-width 제약 제거
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // 모바일 패딩
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 오른쪽 네비게이션 (알림, 프로필)
              Align(
                alignment: Alignment.centerRight,
                child: Consumer<AuthService>(
                  builder: (context, authService, _) {
                    if (!authService.isLoggedIn) {
                      return TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text('로그인'),
                      );
                    }

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 알림 아이콘 (CSS: .notification-icon-wrapper)
                        Consumer<DataService>(
                          builder: (context, dataService, _) {
                            return StreamBuilder<int>(
                              stream: dataService.getUnreadNotificationCountStream(authService.user!.uid),
                              initialData: 0,
                              builder: (context, snapshot) {
                                final unreadCount = snapshot.data ?? 0;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                        Container(
                                      width: 44, // 입체감 + 프로필과 같은 체감 크기
                                      height: 44,
                          decoration: BoxDecoration(
                                        color: Colors.white,
                            shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          // 코인 아이콘처럼 입체감
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.12),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                          // 살짝 하이라이트 느낌
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.7),
                                            blurRadius: 2,
                                            offset: const Offset(0, -1),
                                          ),
                                        ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                                          borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                );
                              },
                                          child: const Center(
                                            child: Icon(
                                  Icons.notifications,
                                  color: AppTheme.primaryColor,
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 알림 배지 (빨간 점, 종 오른쪽 위 곡선에 딱 붙임)
                                    if (unreadCount > 0)
                                      Positioned(
                                        top: 5,
                                        right: 8,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF6B6B),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        // 프로필 드롭다운 (CSS: .profile-dropdown)
                        PopupMenuButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          icon: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.7),
                                  blurRadius: 2,
                                  offset: const Offset(0, -1),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                                size: 26,
                              ),
                            ),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'profile',
                              child: Text('마이페이지'),
                            ),
                            const PopupMenuItem(
                              value: 'logout',
                              child: Text('로그아웃'),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'logout') {
                              await authService.signOut();
                            } else if (value == 'profile') {
                              Navigator.pushNamed(context, '/profile');
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              // 코인 표시 - 왼쪽에 절대 위치 (모바일 스타일)
              // CSS: .nav-right .points-display { position: absolute !important; left: 0 !important; }
              Align(
                alignment: Alignment.centerLeft,
                child: Consumer<AuthService>(
                  builder: (context, authService, _) {
                    if (!authService.isLoggedIn) {
                      return const SizedBox.shrink();
                    }

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.5),
                          builder: (_) => const CoinModal(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.4), // CSS: 0.4rem 0.75rem
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28.8, // CSS: 1.8rem
                              height: 28.8,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                                ),
                                borderRadius: BorderRadius.circular(14.4),
                              ),
                              child: const Center(
                                child: Text(
                                  'C',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.6, // CSS: 0.85rem
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8), // gap: 0.5rem
                            Consumer<AuthService>(
                              builder: (context, authService, _) {
                                final coins = authService.userData?['coins'] ?? 0;
                                return Text(
                                  coins.toString(),
                              style: const TextStyle(
                                fontSize: 14.4, // CSS: 0.9rem
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



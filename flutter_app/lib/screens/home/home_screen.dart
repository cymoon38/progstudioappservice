import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'feed_screen.dart';
import 'popular_screen.dart';
import 'mission_screen.dart';
import 'shop_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_top_navbar.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../../services/auth_service.dart';
import '../../services/viewed_posts_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const PopularScreen(),
    const MissionScreen(),
    const ShopScreen(),
  ];

  void setCurrentIndex(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 사용자 변경 시 본 게시물 서비스 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final viewedPostsService = Provider.of<ViewedPostsService>(context, listen: false);
      viewedPostsService.setUserId(authService.user?.uid);
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const CustomTopNavbar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}



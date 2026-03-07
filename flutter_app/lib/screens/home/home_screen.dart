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
import '../../services/data_service.dart';
import '../../services/viewed_posts_service.dart';
import 'package:adpopcornssp_flutter/adpopcornssp_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _lastSetUid;

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

  void _applyUserId(AuthService authService) {
    final uid = authService.user?.uid;
    if (uid != null && uid.isNotEmpty && uid != _lastSetUid) {
      _lastSetUid = uid;
      AdPopcornSSP.setUserId(uid);
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final viewedPostsService = Provider.of<ViewedPostsService>(context, listen: false);
    viewedPostsService.setUserId(authService.user?.uid);
    _applyUserId(authService);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final viewedPostsService = Provider.of<ViewedPostsService>(context, listen: false);
      viewedPostsService.setUserId(authService.user?.uid);
      _applyUserId(authService);
      authService.addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    try {
      Provider.of<AuthService>(context, listen: false).removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          if (index == 1) {
            Provider.of<DataService>(context, listen: false).getPopularPosts();
          }
        },
      ),
    );
  }
}



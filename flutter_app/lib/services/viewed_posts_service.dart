import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ViewedPostsService extends ChangeNotifier {
  static const String _keyPrefix = 'viewedPosts_';
  Set<String> _viewedPostIds = {};
  String? _currentUserId;

  // 현재 사용자 ID 설정
  void setUserId(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _viewedPostIds.clear();
      if (userId != null) {
        _loadViewedPosts();
      }
    }
  }

  // 본 게시물 목록 로드
  Future<void> _loadViewedPosts() async {
    if (_currentUserId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$_currentUserId';
      final ids = prefs.getStringList(key) ?? const <String>[];
      _viewedPostIds = ids.toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('본 게시물 목록 로드 오류: $e');
    }
  }

  // 본 게시물인지 확인
  bool isViewed(String postId) {
    return _viewedPostIds.contains(postId);
  }

  // 본 게시물로 표시
  Future<void> markAsViewed(String postId) async {
    if (_currentUserId == null) return;
    if (_viewedPostIds.contains(postId)) return;

    _viewedPostIds.add(postId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$_currentUserId';
      final list = _viewedPostIds.toList();
      
      // 최대 1000개까지만 저장 (메모리 절약)
      if (list.length > 1000) {
        list.removeRange(0, list.length - 1000);
        _viewedPostIds = list.toSet();
      }
      
      await prefs.setStringList(key, list);
    } catch (e) {
      debugPrint('본 게시물 표시 오류: $e');
    }
  }

  // 현재 사용자의 본 게시물 정보 삭제 (로그아웃 시)
  Future<void> clearViewedPosts() async {
    if (_currentUserId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$_currentUserId';
      await prefs.remove(key);
      _viewedPostIds.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('본 게시물 정보 삭제 오류: $e');
    }
  }
}

















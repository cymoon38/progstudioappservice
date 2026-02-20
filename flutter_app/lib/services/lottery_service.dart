import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LotteryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 오늘 날짜를 YYYY-MM-DD 형식으로 반환
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // 오늘 추첨이 이미 실행되었는지 확인
  Future<bool> hasLotteryRunToday() async {
    try {
      final today = _getTodayDateString();
      final doc = await _firestore.collection('lotteryResults').doc(today).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        // popularWinner와 normalWinner가 모두 있으면 추첨 완료
        return data?['popularWinner'] != null || data?['normalWinner'] != null;
      }
      return false;
    } catch (e) {
      debugPrint('추첨 실행 여부 확인 오류: $e');
      return false;
    }
  }

  // 오후 4시가 지났는지 확인
  bool isAfter4PM() {
    final now = DateTime.now();
    return now.hour >= 16;
  }

  // 게시물 작성자 UID 목록 가져오기 (중복 제거)
  Future<Set<String>> _getPostAuthors(List<_PostFromFirestore> posts) async {
    final authorUids = <String>{};
    
    for (final post in posts) {
      if (post.authorUid != null && post.authorUid!.isNotEmpty) {
        authorUids.add(post.authorUid!);
      } else if (post.author.isNotEmpty) {
        // authorUid가 없으면 author 이름으로 UID 찾기
        try {
          final userQuery = await _firestore
              .collection('users')
              .where('name', isEqualTo: post.author)
              .limit(1)
              .get();
          
          if (userQuery.docs.isNotEmpty) {
            authorUids.add(userQuery.docs.first.id);
          }
        } catch (e) {
          debugPrint('사용자 UID 찾기 오류: $e (author: ${post.author})');
        }
      }
    }
    
    return authorUids;
  }

  // 추첨 실행
  Future<Map<String, dynamic>?> runLottery({
    required Function(String userId, int amount, String type) addCoins,
  }) async {
    try {
      // 오늘 추첨이 이미 실행되었는지 확인
      final alreadyRun = await hasLotteryRunToday();
      if (alreadyRun) {
        debugPrint('📋 오늘 추첨은 이미 실행되었습니다.');
        return null;
      }

      // 오후 4시가 지났는지 확인
      if (!isAfter4PM()) {
        debugPrint('📋 아직 오후 4시가 되지 않았습니다. (현재 시간: ${DateTime.now().hour}시)');
        return null;
      }

      debugPrint('🎲 추첨 시작...');

      // 1. 인기작품에서 먼저 추첨
      final popularPostsSnapshot = await _firestore
          .collection('posts')
          .where('isPopular', isEqualTo: true)
          .where('type', isNotEqualTo: 'notice') // 공지사항 제외
          .get();

      final popularPosts = popularPostsSnapshot.docs
          .map((doc) => _postFromFirestore(doc))
          .where((post) => post.authorUid != null || post.author.isNotEmpty)
          .toList();

      debugPrint('📊 인기작품 수: ${popularPosts.length}');

      String? popularWinnerUid;
      String? popularWinnerName;
      
      if (popularPosts.isNotEmpty) {
        final popularAuthors = await _getPostAuthors(popularPosts);
        debugPrint('📊 인기작품 작성자 수: ${popularAuthors.length}');
        
        if (popularAuthors.isNotEmpty) {
          final random = Random();
          final winnerList = popularAuthors.toList();
          final winnerIndex = random.nextInt(winnerList.length);
          popularWinnerUid = winnerList[winnerIndex];
          
          // 당첨자 이름 찾기
          try {
            final winnerDoc = await _firestore.collection('users').doc(popularWinnerUid).get();
            if (winnerDoc.exists) {
              popularWinnerName = winnerDoc.data()?['name'] as String? ?? '알 수 없음';
            }
          } catch (e) {
            debugPrint('당첨자 이름 찾기 오류: $e');
            popularWinnerName = '알 수 없음';
          }
          
          // 인기작품 당첨자에게 500코인 지급
          await addCoins(popularWinnerUid, 500, '인기작품 추첨 당첨');
          debugPrint('🎉 인기작품 추첨 당첨자: $popularWinnerName ($popularWinnerUid) - 500코인 지급');
        }
      }

      // 2. 일반 작품에서 추첨 (인기작품 당첨자 제외)
      final allPostsSnapshot = await _firestore
          .collection('posts')
          .where('type', isNotEqualTo: 'notice') // 공지사항 제외
          .get();

      final allPosts = allPostsSnapshot.docs
          .map((doc) => _postFromFirestore(doc))
          .where((post) => post.authorUid != null || post.author.isNotEmpty)
          .toList();

      debugPrint('📊 전체 작품 수: ${allPosts.length}');

      String? normalWinnerUid;
      String? normalWinnerName;
      
      if (allPosts.isNotEmpty) {
        final allAuthors = await _getPostAuthors(allPosts);
        
        // 인기작품 당첨자 제외
        final normalAuthors = popularWinnerUid != null
            ? allAuthors.where((uid) => uid != popularWinnerUid).toSet()
            : allAuthors;
        
        debugPrint('📊 일반작품 작성자 수 (인기작품 당첨자 제외): ${normalAuthors.length}');
        
        if (normalAuthors.isNotEmpty) {
          final random = Random();
          final winnerList = normalAuthors.toList();
          final winnerIndex = random.nextInt(winnerList.length);
          normalWinnerUid = winnerList[winnerIndex];
          
          // 당첨자 이름 찾기
          try {
            final winnerDoc = await _firestore.collection('users').doc(normalWinnerUid).get();
            if (winnerDoc.exists) {
              normalWinnerName = winnerDoc.data()?['name'] as String? ?? '알 수 없음';
            }
          } catch (e) {
            debugPrint('당첨자 이름 찾기 오류: $e');
            normalWinnerName = '알 수 없음';
          }
          
          // 일반작품 당첨자에게 300코인 지급
          await addCoins(normalWinnerUid, 300, '일반작품 추첨 당첨');
          debugPrint('🎉 일반작품 추첨 당첨자: $normalWinnerName ($normalWinnerUid) - 300코인 지급');
        }
      }

      // 추첨 결과 저장
      final today = _getTodayDateString();
      await _firestore.collection('lotteryResults').doc(today).set({
        'date': today,
        'popularWinner': popularWinnerUid != null
            ? {
                'userId': popularWinnerUid,
                'name': popularWinnerName,
                'reward': 500,
              }
            : null,
        'normalWinner': normalWinnerUid != null
            ? {
                'userId': normalWinnerUid,
                'name': normalWinnerName,
                'reward': 300,
              }
            : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 추첨 완료 및 결과 저장');

      return {
        'popularWinner': popularWinnerUid != null
            ? {
                'userId': popularWinnerUid,
                'name': popularWinnerName,
                'reward': 500,
              }
            : null,
        'normalWinner': normalWinnerUid != null
            ? {
                'userId': normalWinnerUid,
                'name': normalWinnerName,
                'reward': 300,
              }
            : null,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ 추첨 실행 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return null;
    }
  }

  // Firestore 문서를 Post 객체로 변환 (간단한 버전)
  _PostFromFirestore _postFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _PostFromFirestore(
      id: doc.id,
      author: data['author']?.toString() ?? '',
      authorUid: data['authorUid']?.toString(),
      type: data['type']?.toString(),
    );
  }
}

// 간단한 Post 클래스 (추첨용)
class _PostFromFirestore {
  final String id;
  final String author;
  final String? authorUid;
  final String? type;

  _PostFromFirestore({
    required this.id,
    required this.author,
    this.authorUid,
    this.type,
  });
}


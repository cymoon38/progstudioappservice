import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  
  // 운영자 여부 확인
  bool isAdmin() {
    if (_userData == null) return false;
    return _userData!['role'] == 'admin' || _userData!['isAdmin'] == true;
  }

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userData = doc.data();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('사용자 데이터 로드 오류: $e');
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await _loadUserData(credential.user!.uid);
      return credential;
    } catch (e) {
      debugPrint('로그인 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserCredential?> signUp(String name, String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await credential.user!.updateProfile(displayName: name);
      
      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'coins': 0,
      });
      
      // 새 유저의 기본 미션 초기화 (first_upload, like_click)
      try {
        await _initializeUserMissions(credential.user!.uid);
      } catch (e) {
        debugPrint('미션 초기화 오류 (무시): $e');
      }
      
      await _loadUserData(credential.user!.uid);
      return credential;
    } catch (e) {
      debugPrint('회원가입 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _userData = null;
      notifyListeners();
    } catch (e) {
      debugPrint('로그아웃 오류: $e');
      rethrow;
    }
  }

  Future<void> checkUsernameExists(String username) async {
    final snapshot = await _firestore
        .collection('users')
        .where('name', isEqualTo: username)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      throw Exception('이미 사용 중인 닉네임입니다.');
    }
  }

  // 코인 잔액 업데이트 (기존 프로그램의 updateCoinBalance 대응)
  Future<void> updateCoinBalance() async {
    if (_user == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userData = doc.data();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('코인 잔액 업데이트 오류: $e');
    }
  }

  // 새 유저의 기본 미션 초기화
  Future<void> _initializeUserMissions(String userId) async {
    try {
      // 미션 목록 가져오기
      final missionsSnapshot = await _firestore
          .collection('missions')
          .where('type', whereIn: ['first_upload', 'like_click'])
          .get();

      if (missionsSnapshot.docs.isEmpty) {
        debugPrint('⚠️ 기본 미션이 없습니다. 미션을 먼저 생성해주세요.');
        return;
      }

      // 각 미션에 대해 userMission 생성
      final batch = _firestore.batch();
      for (final missionDoc in missionsSnapshot.docs) {
        final missionId = missionDoc.id;
        final missionData = missionDoc.data();
        final missionType = missionData['type'] as String? ?? '';

        // userMission 문서 ID 생성 (userId와 missionId 조합)
        final userMissionId = '${userId}_$missionId';
        final userMissionRef = _firestore.collection('userMissions').doc(userMissionId);

        // 이미 존재하는지 확인
        final existingDoc = await userMissionRef.get();
        if (existingDoc.exists) {
          continue; // 이미 존재하면 건너뜀
        }

        // userMission 데이터 생성
        final userMissionData = <String, dynamic>{
          'userId': userId,
          'missionId': missionId,
          'completed': false,
          'progress': 0,
        };

        // like_click 미션의 경우 추가 필드 설정
        if (missionType == 'like_click') {
          userMissionData['likedPostIds'] = <String>[];
          // like_click 미션은 시작 시간이 필요 없음 (즉시 시작 가능)
        }

        batch.set(userMissionRef, userMissionData);
      }

      // 배치 커밋
      await batch.commit();
      debugPrint('✅ 새 유저 미션 초기화 완료: $userId');
    } catch (e) {
      debugPrint('❌ 미션 초기화 오류: $e');
      rethrow;
    }
  }
}




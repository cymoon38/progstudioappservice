import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool get isBanned {
    if (_userData == null) return false;
    final banUntil = _userData!['banUntil'];
    if (banUntil == null) return false;
    if (banUntil is Timestamp) {
      return DateTime.now().isBefore(banUntil.toDate());
    }
    return false;
  }

  DateTime? get banUntil {
    if (_userData == null) return null;
    final value = _userData!['banUntil'];
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
  
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

      final canSignUp = await canSignUpFromDevice();
      if (!canSignUp) {
        throw Exception('한 기기에서는 최대 2개의 계정만 만들 수 있습니다. (탈퇴한 계정 포함)');
      }

      final deviceId = await getDeviceId();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.updateProfile(displayName: name);

      // Firestore에 사용자 정보 저장 (기기 ID 기록 → 탈퇴 시 해당 기기 count 감소용)
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'coins': 0,
        'createdFromDeviceId': deviceId,
      });

      await _registerDeviceSignup(deviceId);
      
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

  /// 탈퇴: Firestore users 문서 삭제, 해당 기기 가입 수 감소 후 로그아웃. 게시물·댓글·대댓글은 삭제하지 않음.
  Future<void> withdrawAccount() async {
    if (_user == null) return;
    final uid = _user!.uid;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final deviceId = userDoc.data()?['createdFromDeviceId'] as String?;

      await _firestore.collection('users').doc(uid).delete();

      if (deviceId != null && deviceId.isNotEmpty) {
        await _decrementDeviceSignupCount(deviceId);
      }

      await _auth.signOut();
      _userData = null;
      notifyListeners();
    } catch (e) {
      debugPrint('탈퇴(회원정보 삭제) 오류: $e');
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

  static const String _deviceIdKey = 'device_id';
  static const int _maxAccountsPerDevice = 2;

  /// 기기당 고유 ID (앱 설치 시 한 번 생성 후 유지)
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextDouble()}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  /// 기기당 회원가입 가능 여부 (탈퇴 포함 최대 2개까지, 2개 모두 탈퇴 시 다시 2개 가능)
  Future<bool> canSignUpFromDevice() async {
    final deviceId = await getDeviceId();
    final doc = await _firestore.collection('deviceRegistrations').doc(deviceId).get();
    final count = (doc.data()?['count'] is int)
        ? (doc.data()!['count'] as int)
        : ((doc.data()?['count'] as num?)?.toInt() ?? 0);
    return count < _maxAccountsPerDevice;
  }

  /// 회원가입 시 기기 등록 (count 증가). signUp 성공 후에만 호출.
  Future<void> _registerDeviceSignup(String deviceId) async {
    final ref = _firestore.collection('deviceRegistrations').doc(deviceId);
    await ref.set({'count': FieldValue.increment(1)}, SetOptions(merge: true));
  }

  /// 탈퇴 시 기기 count 감소 (2개 모두 탈퇴한 기기는 다시 2개 가입 가능)
  Future<void> _decrementDeviceSignupCount(String deviceId) async {
    if (deviceId.isEmpty) return;
    final ref = _firestore.collection('deviceRegistrations').doc(deviceId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final data = doc.data();
    final count = (data?['count'] is int)
        ? (data!['count'] as int)
        : ((data?['count'] as num?)?.toInt() ?? 0);
    if (count <= 0) return;
    await ref.set({'count': FieldValue.increment(-1)}, SetOptions(merge: true));
  }

  /// 이메일 중복 확인 (회원가입 전 호출)
  Future<void> checkEmailExists(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      throw Exception('이미 사용 중인 이메일입니다.');
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




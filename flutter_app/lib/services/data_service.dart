import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'lottery_service.dart';

class Post {
  final String id;
  final String author;
  final String? authorUid;
  final String title;
  final String? caption;
  final String imageUrl;
  final String? originalImageUrl;
  final String? compressedImageUrl;
  final List<String> tags;
  final List<String> likes;
  final List<Comment> comments;
  final DateTime date;
  final int views;
  final String? type;
  final String? originalPostId;
  final bool isPopular;
  final DateTime? popularDate; // 인기작품으로 선정된 날짜
  final bool popularRewarded; // 인기작품 보상/미션 처리 완료 여부 (중복 방지)
  final int? coins;

  Post({
    required this.id,
    required this.author,
    this.authorUid,
    required this.title,
    this.caption,
    required this.imageUrl,
    this.originalImageUrl,
    this.compressedImageUrl,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.date,
    required this.views,
    this.type,
    this.originalPostId,
    this.isPopular = false,
    this.popularDate,
    this.popularRewarded = false,
    this.coins,
  });

  // 대댓글을 포함한 총 댓글 수 계산
  int get totalCommentCount {
    // 대댓글 수를 재귀적으로 계산하는 함수
    int countReplies(List<Comment> replies) {
      int count = replies.length;
      for (final reply in replies) {
        if (reply.replies.isNotEmpty) {
          count += countReplies(reply.replies);
        }
      }
      return count;
    }

    int totalCount = comments.length;
    for (final comment in comments) {
      if (comment.replies.isNotEmpty) {
        totalCount += countReplies(comment.replies);
      }
    }
    return totalCount;
  }

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // 기존 HTML/JS 프로그램에서는 'image' 필드를 사용하므로 하위 호환성 유지
    final imageUrl = data['imageUrl'] ?? data['image'] ?? '';
    return Post(
      id: doc.id,
      author: data['author'] ?? '',
      authorUid: data['authorUid'],
      title: data['title'] ?? '',
      caption: data['caption'],
      imageUrl: imageUrl,
      originalImageUrl: data['originalImageUrl'] ?? data['originalImage'],
      compressedImageUrl: data['compressedImageUrl'] ?? (imageUrl.isNotEmpty ? imageUrl : null),
      tags: List<String>.from(data['tags'] ?? []),
      likes: List<String>.from(data['likes'] ?? []),
      comments: (data['comments'] as List<dynamic>?)
          ?.map((c) => Comment.fromMap(c))
          .toList() ?? [],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      views: data['views'] ?? 0,
      type: data['type'],
      originalPostId: data['originalPostId'],
      isPopular: data['isPopular'] ?? false,
      popularDate: (data['popularDate'] as Timestamp?)?.toDate(),
      popularRewarded: data['popularRewarded'] ?? false,
      coins: data['coins'],
    );
  }
}

class Comment {
  final String id;
  final String author;
  final String? authorUid;
  final String text;
  final DateTime createdAt;
  final List<Comment> replies;
  final bool isAccepted;
  final int? acceptedCoinAmount;

  Comment({
    required this.id,
    required this.author,
    this.authorUid,
    required this.text,
    required this.createdAt,
    required this.replies,
    this.isAccepted = false,
    this.acceptedCoinAmount,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      author: map['author'] ?? '',
      authorUid: map['authorUid'],
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replies: (map['replies'] as List<dynamic>?)
          ?.map((r) => Comment.fromMap(r))
          .toList() ?? [],
      isAccepted: map['isAccepted'] ?? false,
      acceptedCoinAmount: map['acceptedCoinAmount'],
    );
  }
}

class Mission {
  final String id;
  final String title;
  final String description;
  final int reward; // 코인 보상
  final String type; // 'upload', 'like', 'comment', 'popular', 'attendance' 등
  final String? icon; // 아이콘 이름 (선택)
  final bool isRepeatable; // 반복 가능한 미션인지
  final int? targetCount; // 목표 개수 (예: 좋아요 10개 받기)

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.type,
    this.icon,
    this.isRepeatable = false,
    this.targetCount,
  });

  factory Mission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // reward 필드 파싱 (타입 체크)
    int reward = 0;
    if (data['reward'] != null) {
      if (data['reward'] is int) {
        reward = data['reward'] as int;
      } else if (data['reward'] is num) {
        reward = (data['reward'] as num).toInt();
      } else {
        debugPrint('⚠️ Mission.fromFirestore: reward 필드 타입 오류 (${data['reward'].runtimeType}) - ${doc.id}');
      }
    }
    
    
    return Mission(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      reward: reward,
      type: data['type'] ?? '',
      icon: data['icon'],
      isRepeatable: data['isRepeatable'] ?? false,
      targetCount: data['targetCount'] is int ? data['targetCount'] as int : (data['targetCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'reward': reward,
      'type': type,
      if (icon != null) 'icon': icon,
      'isRepeatable': isRepeatable,
      if (targetCount != null) 'targetCount': targetCount,
    };
  }
}

class UserMission {
  final String id;
  final String userId;
  final String missionId;
  final bool completed;
  final DateTime? completedAt;
  final int progress; // 진행도 (예: 좋아요 5/10개)
  final DateTime? startTime; // 미션 시작 시간 (like_click 미션용)
  final List<String> likedPostIds; // 좋아요를 누른 게시물 ID 목록 (like_click 미션용, 중복 방지)

  UserMission({
    required this.id,
    required this.userId,
    required this.missionId,
    this.completed = false,
    this.completedAt,
    this.progress = 0,
    this.startTime,
    this.likedPostIds = const [],
  });

  factory UserMission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserMission(
      id: doc.id,
      userId: data['userId'] ?? '',
      missionId: data['missionId'] ?? '',
      completed: data['completed'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      progress: data['progress'] ?? 0,
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      likedPostIds: (data['likedPostIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String type; // like | comment
  final String postId;
  final String? postTitle;
  final String? author;
  final String? commentText;
  final bool read;
  final bool isReply;
  final DateTime createdAt;
  final int groupCount; // 같은 게시물/타입 묶음 개수

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.postId,
    required this.createdAt,
    this.postTitle,
    this.author,
    this.commentText,
    this.read = false,
    this.isReply = false,
    this.groupCount = 1,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppNotification(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      postId: (data['postId'] ?? '').toString(),
      postTitle: data['postTitle']?.toString(),
      author: data['author']?.toString(),
      commentText: data['commentText']?.toString(),
      read: data['read'] == true,
      isReply: data['isReply'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }
}

class CoinHistoryItem {
  final String id;
  final String userId;
  final int amount;
  final String type;
  final String? postId;
  final DateTime timestamp;

  CoinHistoryItem({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.timestamp,
    this.postId,
  });

  factory CoinHistoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CoinHistoryItem(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      amount: (data['amount'] ?? 0) is int ? (data['amount'] ?? 0) : int.tryParse('${data['amount']}') ?? 0,
      type: (data['type'] ?? '').toString(),
      postId: data['postId']?.toString(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DataService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final LotteryService _lotteryService = LotteryService();

  // userMissions 문서 ID를 고정해 인덱스 없이도 빠르게 upsert 가능하게 함
  String _userMissionDocId(String userId, String missionId) => '${userId}_$missionId';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userMissionsSub;
  
  List<Post> _posts = [];
  List<Post> _popularPosts = [];
  List<Post> _notices = [];
  bool _isLoading = false;

  List<Post> get posts => _posts;
  List<Post> get popularPosts => _popularPosts;
  List<Post> get notices => _notices;
  bool get isLoading => _isLoading;

  Future<List<Post>> getAllPosts({int limit = 100}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // 비용 절감: limit 추가 (기본 100개, 필요시 더 로드)
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();
      
      // 공지글(type: 'notice')은 제외하고 일반 게시물만 필터링
      _posts = snapshot.docs
          .map((doc) => Post.fromFirestore(doc))
          .where((post) => post.type != 'notice')
          .toList();
      notifyListeners();
      return _posts;
    } catch (e) {
      debugPrint('게시물 로드 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 공지사항 가져오기
  Future<List<Post>> getNotices({int limit = 100}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final snapshot = await _firestore
          .collection('posts')
          .where('type', isEqualTo: 'notice')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();
      
      _notices = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      notifyListeners();
      return _notices;
    } catch (e) {
      debugPrint('공지사항 로드 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Post>> getPopularPosts({int limit = 50}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // 비용 절감: 최근 게시물만 가져오기 (200개 제한, 기존 기능 유지)
      // 기존 프로그램과 동일하게: 좋아요 수 기준으로 필터링
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('date', descending: true)
          .limit(200) // 최근 200개만 가져와서 비용 절감
          .get();
      
      // 좋아요 2개 이상인 게시물만 필터링 (기존 프로그램과 동일)
      final allPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      final popularPosts = allPosts.where((post) => post.likes.length >= 2).toList();
      
      // 기존 게시물 중 좋아요가 2개 이상인데 isPopular이 false인 경우:
      // - 트랜잭션으로 "최초 1회만" 선정 처리 (popularRewarded로 중복 방지)
      int updateCount = 0;
      for (final post in popularPosts) {
        if (post.isPopular) continue;
        final postRef = _firestore.collection('posts').doc(post.id);

        try {
          final txResult = await _firestore.runTransaction((tx) async {
            final snap = await tx.get(postRef);
            if (!snap.exists) return <String, dynamic>{'selected': false};
            final data = (snap.data() as Map<String, dynamic>?) ?? {};

            final alreadyRewarded = data['popularRewarded'] == true;
            final likesArr = (data['likes'] as List<dynamic>?) ?? const [];
            final likesCount = likesArr.length;
            final authorUid = data['authorUid']?.toString();
            final authorName = data['author']?.toString();

            // 이미 처리된 경우 스킵
            if (alreadyRewarded) {
              return <String, dynamic>{'selected': false};
            }

            // 좋아요 조건 미달이면 스킵
            if (likesCount < 2) {
              return <String, dynamic>{'selected': false};
            }

            tx.update(postRef, {
              // 이미 isPopular이 true여도, 보상/미션 처리가 안 된 "기존 인기작품"일 수 있어서
              // popularRewarded를 기준으로 최초 1회만 처리한다.
              'isPopular': true,
              // popularDate가 없던 경우만 채워지게 되며, 기존 값이 있으면 덮어써도 무방(정합성에는 영향 없음)
              'popularDate': FieldValue.serverTimestamp(),
              'popularRewarded': true,
              'popularRewardedAt': FieldValue.serverTimestamp(),
            });

            return <String, dynamic>{
              'selected': true,
              'authorUid': authorUid,
              'author': authorName,
            };
          });

          if (txResult['selected'] == true) {
            updateCount++;
            // 작성자 UID 확보 (authorUid가 없을 수 있어서 author로 fallback)
            String? authorUid = txResult['authorUid']?.toString();
            if (authorUid == null || authorUid.isEmpty) {
              final authorName = txResult['author']?.toString();
              if (authorName != null && authorName.isNotEmpty) {
                authorUid = await getUserIdByUsername(authorName);
              }
            }

          }
        } catch (e) {
          debugPrint('인기작품 트랜잭션 업데이트 오류 (무시): $e');
        }
      }

      if (updateCount > 0) {
        debugPrint('✅ 기존 게시물 ${updateCount}개를 인기작품으로 선정했습니다. (트랜잭션, 중복 방지)');
      }
      
      // 좋아요 수 기준으로 정렬 (기존 프로그램과 동일)
      popularPosts.sort((a, b) {
        final likesDiff = b.likes.length - a.likes.length;
        return likesDiff != 0 ? likesDiff : b.date.compareTo(a.date);
      });
      
      _popularPosts = popularPosts.take(limit).toList();
      notifyListeners();
      return _popularPosts;
    } catch (e) {
      debugPrint('인기작품 로드 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return Post.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('게시물 가져오기 오류: $e');
      return null;
    }
  }

  // 조회수 증가 (기존 프로그램과 동일: 로그인한 사용자만)
  Future<void> incrementViews(String postId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      await postRef.update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('조회수 증가 오류: $e');
      // 조회수 증가 실패해도 계속 진행
    }
  }

  // 이미지 압축 (기존 프로그램과 동일: 품질 0.75, 최대 1080px)
  Future<File?> _compressImage(File imageFile) async {
    try {
      // 파일 크기가 500KB 미만이면 압축 불필요
      final fileSize = await imageFile.length();
      if (fileSize < 500000) {
        debugPrint('ℹ️ 압축 불필요: ${fileSize / 1024} KB');
        return imageFile;
      }

      // 임시 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.webp',
      );

      // 이미지 압축 (기존 프로그램과 동일: 품질 0.75, 최대 1080px, WebP 포맷)
      // minWidth/minHeight는 최대 크기로 제한하는 역할을 함
      // WebP 포맷 사용으로 기존 프로그램과 동일한 99% 압축률 달성
      final compressedResult = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 75, // 기존 프로그램: 0.75
        minWidth: 1080, // 최대 너비 1080px로 제한
        minHeight: 1080, // 최대 높이 1080px로 제한
        format: CompressFormat.webp, // WebP 포맷 사용 (기존 프로그램과 동일, 더 나은 압축률)
      );

      if (compressedResult != null) {
        final compressedFile = File(compressedResult.path);
        final compressedSize = await compressedFile.length();
        final sizeReduction = ((fileSize - compressedSize) / fileSize * 100).toStringAsFixed(1);
        final compressionRatio = (compressedSize / fileSize * 100).toStringAsFixed(1);
        
        // 상세한 압축 정보 출력
        final originalMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
        final compressedMB = (compressedSize / 1024 / 1024).toStringAsFixed(2);
        final originalKB = (fileSize / 1024).toStringAsFixed(1);
        final compressedKB = (compressedSize / 1024).toStringAsFixed(1);
        
        debugPrint('═══════════════════════════════════════');
        debugPrint('📊 이미지 압축 결과');
        debugPrint('───────────────────────────────────────');
        debugPrint('📁 원본 크기: $originalMB MB ($originalKB KB)');
        debugPrint('📦 압축 크기: $compressedMB MB ($compressedKB KB)');
        debugPrint('📉 크기 감소: $sizeReduction%');
        debugPrint('📈 압축률: $compressionRatio% (원본 대비)');
        debugPrint('💾 절약된 용량: ${((fileSize - compressedSize) / 1024 / 1024).toStringAsFixed(2)} MB');
        debugPrint('═══════════════════════════════════════');
        
        return compressedFile;
      }

      return imageFile;
    } catch (e) {
      debugPrint('이미지 압축 오류 (원본 사용): $e');
      return imageFile; // 압축 실패 시 원본 사용
    }
  }

  Future<String> uploadImage(File imageFile, String userId, String folder) async {
    try {
      // 이미지 압축
      final compressedFile = await _compressImage(imageFile);
      final fileToUpload = compressedFile ?? imageFile;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$folder/$userId/$fileName');
      
      await ref.putFile(fileToUpload);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('이미지 업로드 오류: $e');
      rethrow;
    }
  }

  // 압축된 이미지와 원본 이미지 모두 업로드 (기존 프로그램과 동일)
  Future<Map<String, String>> uploadImageWithCompression(
    File imageFile,
    String userId,
    String folder,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 압축된 이미지 업로드
      final compressedFile = await _compressImage(imageFile);
      final compressedFileName = '${timestamp}_compressed.webp';
      final compressedRef = _storage.ref().child('$folder/$userId/$compressedFileName');
      await compressedRef.putFile(compressedFile ?? imageFile);
      final compressedUrl = await compressedRef.getDownloadURL();

      // 원본 이미지 업로드 (파일 크기가 500KB 이상일 때만)
      String? originalUrl;
      final fileSize = await imageFile.length();
      if (fileSize > 500000) {
        final originalFileName = '${timestamp}_original.jpg';
        final originalRef = _storage.ref().child('$folder/$userId/$originalFileName');
        await originalRef.putFile(imageFile);
        originalUrl = await originalRef.getDownloadURL();
      }

      return {
        'compressed': compressedUrl,
        if (originalUrl != null) 'original': originalUrl,
      };
    } catch (e) {
      debugPrint('이미지 업로드 오류: $e');
      rethrow;
    }
  }

  Future<void> createPost({
    required String userId,
    required String username,
    required String title,
    String? caption,
    required String imageUrl,
    List<String> tags = const [],
    String? type,
    String? originalPostId,
    String? originalImageUrl,
    String? compressedImageUrl,
  }) async {
    try {
      await _firestore.collection('posts').add({
        'author': username,
        'authorUid': userId,
        'title': title,
        'caption': caption ?? '',
        'imageUrl': imageUrl,
        'tags': tags,
        'likes': [],
        'comments': [],
        'date': FieldValue.serverTimestamp(),
        'views': 0,
        'type': type ?? 'original',
        'originalPostId': originalPostId,
        'originalImageUrl': originalImageUrl, // 원본 이미지 URL (원본 보기용)
        'originalImage': originalImageUrl, // 모작의 원본 그림 (기존 호환성 유지)
        'compressedImageUrl': compressedImageUrl ?? imageUrl,
        'isPopular': false,
      });
      
      // 공지글이 아닌 경우에만 피드에 추가
      if (type != 'notice') {
        // 비용 절감: 로컬에 게시물 추가만 하고 전체 새로고침은 백그라운드에서 처리
        // 새로 생성된 게시물을 로컬 리스트 맨 앞에 추가
        final newPostDoc = await _firestore.collection('posts')
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        if (newPostDoc.docs.isNotEmpty) {
          final newPost = Post.fromFirestore(newPostDoc.docs.first);
          // 공지글이 아닌 경우에만 피드에 추가
          if (newPost.type != 'notice') {
            _posts.insert(0, newPost);
            notifyListeners();
          }
        }
        
        // 백그라운드에서 전체 새로고침 (비용 절감)
        getAllPosts().catchError((e) {
          debugPrint('피드 새로고침 오류 (무시): $e');
          return <Post>[];
        });
      } else {
        // 공지글인 경우 공지 목록에 추가
        final newPostDoc = await _firestore.collection('posts')
            .where('type', isEqualTo: 'notice')
            .orderBy('date', descending: true)
            .limit(1)
            .get();
        if (newPostDoc.docs.isNotEmpty) {
          final newNotice = Post.fromFirestore(newPostDoc.docs.first);
          _notices.insert(0, newNotice);
          notifyListeners();
        }
      }
      
      // 첫 작품 업로드 미션 체크 및 완료 처리
      _checkAndCompleteFirstUploadMission(userId).catchError((e) {
        debugPrint('첫 작품 업로드 미션 체크 오류 (무시): $e');
      });
    } catch (e) {
      debugPrint('게시물 생성 오류: $e');
      rethrow;
    }
  }

  // 좋아요 토글 (기존 프로그램과 동일: username 기반, 인기작품 체크, 알림 생성)
  Future<void> toggleLike(String postId, String userId, String username) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      
      // 로컬에서 게시물 찾기
      Post? post;
      try {
        post = _posts.firstWhere((p) => p.id == postId);
      } catch (e) {
        try {
          post = _popularPosts.firstWhere((p) => p.id == postId);
        } catch (e2) {
          // 로컬에 없으면 Firestore에서 가져오기
          final postDoc = await postRef.get();
          if (!postDoc.exists) {
            debugPrint('⚠️ 로컬에 게시물 없음, Firestore에도 없음: $postId');
            return;
          }
          post = Post.fromFirestore(postDoc);
        }
      }
      
      // post는 위 로직에서 항상 할당되므로 null 체크 불필요 (린트 경고 제거)
      
      final likes = List<String>.from(post.likes);
      final wasLiked = likes.contains(username);
      
      // 이미 좋아요를 눌렀다면 취소 불가 (일반 게시물 포함)
      if (wasLiked) {
        debugPrint('⚠️ 이미 좋아요를 누른 게시물입니다. 취소 불가: $postId');
        return;
      }
      
      // 트랜잭션을 사용하여 원자적 업데이트 보장
      bool transactionSuccess = false;
      List<String>? finalLikes;
      
      try {
        await _firestore.runTransaction((transaction) async {
          // Firestore에서 최신 상태 가져오기
          final postDoc = await transaction.get(postRef);
          if (!postDoc.exists) {
            throw Exception('게시물을 찾을 수 없습니다: $postId');
          }
          
          final data = postDoc.data() as Map<String, dynamic>;
          final currentLikes = List<String>.from(data['likes'] ?? []);
          
          // 중복 체크 (다른 클라이언트에서 이미 추가했을 수 있음)
          if (currentLikes.contains(username)) {
            debugPrint('⚠️ 다른 클라이언트에서 이미 좋아요를 추가했습니다: $postId');
            // 이미 좋아요가 있으면 현재 상태를 반환하고 트랜잭션 성공으로 처리
            finalLikes = currentLikes;
            return;
          }
          
          // 좋아요 추가
          final newLikes = List<String>.from(currentLikes);
          newLikes.add(username);
          finalLikes = newLikes;
          
          // 트랜잭션으로 업데이트
          transaction.update(postRef, {'likes': newLikes});
        });
        
        transactionSuccess = true;
        debugPrint('✅ 좋아요 트랜잭션 성공: $postId');
      } catch (e) {
        debugPrint('❌ 좋아요 트랜잭션 실패: $postId');
        debugPrint('   오류 타입: ${e.runtimeType}');
        debugPrint('   오류 메시지: $e');
        if (e is FirebaseException) {
          debugPrint('   Firebase 오류 코드: ${e.code}');
          debugPrint('   Firebase 오류 메시지: ${e.message}');
        }
        transactionSuccess = false;
        // 트랜잭션 실패 시 원래 상태 유지
        finalLikes = post.likes;
      }
      
      // 트랜잭션 성공 후에만 로컬 상태 업데이트
      if (!transactionSuccess || finalLikes == null) {
        debugPrint('⚠️ 트랜잭션 실패 또는 finalLikes가 null - 로컬 상태 업데이트 안 함: $postId');
        return;
      }
      
      // finalLikes는 null이 아님을 확인했으므로 사용 가능
      final updatedLikes = finalLikes!;
      
      final updatedPost = Post(
        id: post.id,
        author: post.author,
        authorUid: post.authorUid,
        title: post.title,
        caption: post.caption,
        imageUrl: post.imageUrl,
        originalImageUrl: post.originalImageUrl,
        compressedImageUrl: post.compressedImageUrl,
        tags: post.tags,
        likes: updatedLikes,
        comments: post.comments,
        date: post.date,
        views: post.views,
        type: post.type,
        originalPostId: post.originalPostId,
        isPopular: post.isPopular,
        popularDate: post.popularDate,
        popularRewarded: post.popularRewarded,
        coins: post.coins,
      );
      
      // 로컬 리스트 업데이트
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        _posts[postIndex] = updatedPost;
      }
      final popularIndex = _popularPosts.indexWhere((p) => p.id == postId);
      if (popularIndex != -1) {
        _popularPosts[popularIndex] = updatedPost;
      }
      notifyListeners(); // UI 즉시 업데이트
      
      // 좋아요가 2개 이상이면 인기작품 "최초 1회" 처리 시도 (트랜잭션, popularRewarded로 중복 방지)
      final newLikesCount = updatedLikes.length;
      if (newLikesCount >= 2 && !post.popularRewarded) {
        try {
          final txResult = await _firestore.runTransaction((tx) async {
            final snap = await tx.get(postRef);
            if (!snap.exists) return <String, dynamic>{'selected': false};
            final data = (snap.data() as Map<String, dynamic>?) ?? {};

            final alreadyRewarded = data['popularRewarded'] == true;
            final likesArr = (data['likes'] as List<dynamic>?) ?? const [];
            final likesCount = likesArr.length;

            if (alreadyRewarded || likesCount < 2) {
              return <String, dynamic>{'selected': false};
            }

            tx.update(postRef, {
              'isPopular': true,
              'popularDate': FieldValue.serverTimestamp(),
              'popularRewarded': true,
              'popularRewardedAt': FieldValue.serverTimestamp(),
            });

            return <String, dynamic>{
              'selected': true,
              'authorUid': data['authorUid'],
              'author': data['author'],
            };
          });

          if (txResult['selected'] != true) {
            // 이미 다른 경로에서 처리되었거나 조건 미달
            return;
          }

          debugPrint('✅ 인기작품 최초 처리 완료: $postId (좋아요 $newLikesCount개)');

          // 트랜잭션 결과에서 authorUid와 author 가져오기 (최신 데이터)
          String? authorUidFromTx = txResult['authorUid']?.toString();
          String? authorNameFromTx = txResult['author']?.toString();
          
          // authorUid가 없으면 author 이름으로 찾기
          if ((authorUidFromTx == null || authorUidFromTx.isEmpty) && authorNameFromTx != null) {
            authorUidFromTx = await getUserIdByUsername(authorNameFromTx);
            debugPrint('🔍 트랜잭션 결과에서 authorUid가 없어 이름으로 찾음: $authorNameFromTx -> $authorUidFromTx');
          }

          final popularDate = DateTime.now(); // 로컬 표시용(정확한 서버 시간은 popularDate 필드에 저장)
          
          // 인기작품 필드 업데이트 (트랜잭션 결과의 authorUid 사용)
          final popularPost = Post(
            id: updatedPost.id,
            author: updatedPost.author,
            authorUid: authorUidFromTx ?? updatedPost.authorUid,
            title: updatedPost.title,
            caption: updatedPost.caption,
            imageUrl: updatedPost.imageUrl,
            originalImageUrl: updatedPost.originalImageUrl,
            compressedImageUrl: updatedPost.compressedImageUrl,
            tags: updatedPost.tags,
            likes: updatedPost.likes,
            comments: updatedPost.comments,
            date: updatedPost.date,
            views: updatedPost.views,
            type: updatedPost.type,
            originalPostId: updatedPost.originalPostId,
            isPopular: true,
            popularDate: popularDate,
            popularRewarded: true,
            coins: updatedPost.coins,
          );
          final postIdx = _posts.indexWhere((p) => p.id == postId);
          if (postIdx != -1) {
            _posts[postIdx] = popularPost;
          }
          final popIdx = _popularPosts.indexWhere((p) => p.id == postId);
          if (popIdx != -1) {
            _popularPosts[popIdx] = popularPost;
          }
          notifyListeners();
          
          // 코인 지급 (기존 프로그램과 동일)
          try {
            debugPrint('🎉 인기작품 선정! 코인 지급 시작...');
            final authorName = authorNameFromTx ?? updatedPost.author;
            final likers = updatedPost.likes;
            
            // 좋아요를 누른 사람들에게 3코인씩 지급 (글쓴이 본인 제외)
            debugPrint('💰 좋아요 누른 사용자들에게 코인 지급 시작...');
            for (final likerUsername in likers) {
              // 글쓴이 본인은 좋아요 보상에서 제외
              if (likerUsername == authorName) {
                debugPrint('ℹ️ 글쓴이 본인 ($likerUsername)은 좋아요 보상에서 제외됩니다.');
                continue;
              }
              
              try {
                final likerUid = await getUserIdByUsername(likerUsername);
                if (likerUid != null) {
                  await addCoins(
                    userId: likerUid,
                    amount: 3,
                    type: '인기작품 선정 보상 (좋아요)',
                    postId: postId,
                  );
                  debugPrint('✅ 코인 지급 완료: $likerUsername ($likerUid)');
      } else {
                  debugPrint('⚠️ UID를 찾을 수 없음: $likerUsername');
                }
              } catch (e) {
                debugPrint('❌ 좋아요 누른 사용자 코인 지급 오류 ($likerUsername): $e');
              }
            }
            
            // 글쓴이에게 10코인 지급
            debugPrint('💰 글쓴이에게 코인 지급 시작...');
            String? authorUidForCoins = authorUidFromTx;
            
            // authorUid가 여전히 없으면 사용자명으로 찾기
            if (authorUidForCoins == null || authorUidForCoins.isEmpty) {
              authorUidForCoins = await getUserIdByUsername(authorName);
              debugPrint('🔍 authorUid가 없어 이름으로 찾음: $authorName -> $authorUidForCoins');
            }
            
            if (authorUidForCoins != null && authorUidForCoins.isNotEmpty) {
              try {
                await addCoins(
                  userId: authorUidForCoins,
                  amount: 10,
                  type: '인기작품 선정 보상 (작성자)',
                  postId: postId,
                );
                debugPrint('✅ 글쓴이 코인 지급 완료: $authorUidForCoins ($authorName)');
              } catch (e) {
                debugPrint('❌ 글쓴이 코인 지급 오류: $e');
              }
            } else {
              debugPrint('❌ 글쓴이 UID를 찾을 수 없어 코인을 지급할 수 없음: $authorName');
            }
            
            debugPrint('✅ 인기작품 코인 지급 완료');
          } catch (e) {
            debugPrint('❌ 인기작품 코인 지급 오류: $e');
          }
        } catch (e) {
          debugPrint('인기작품 최초 처리 트랜잭션 오류 (무시): $e');
        }
      }
      
      // 미션 진행도 업데이트 (좋아요 3개 누르기 미션 - 좋아요를 누른 사용자)
      // 좋아요를 누를 때는 진행도 증가, 취소할 때는 likedPostIds에서 제거
      // 좋아요를 누르거나 취소할 때 모두 호출 (취소할 때는 likedPostIds에서만 제거)
      updateMissionProgress(
        userId: userId,
        missionType: 'like_click',
        postId: postId, // 중복 방지를 위한 게시물 ID
        isLikeAction: true, // 좋아요를 누른 경우 true
      ).catchError((e) {
        debugPrint('미션 진행도 업데이트 오류 (무시): $e');
      });
      
      // 알림 생성 (비동기, 블로킹하지 않음, authorUid가 있으면 바로 사용)
      if (post.author != username) {
        final postTitle = post.title;
        final authorUid = post.authorUid;
        
        // authorUid가 있으면 바로 사용, 없으면 백그라운드에서 찾기
        if (authorUid != null) {
          createOrUpdateNotification(
            userId: authorUid,
            type: 'like',
            postId: postId,
            postTitle: postTitle,
            author: username,
          ).catchError((e) {
            debugPrint('좋아요 알림 생성 오류 (무시): $e');
            return '';
          });
        } else {
          // authorUid가 없으면 백그라운드에서 찾기 (블로킹하지 않음)
          getUserIdByUsername(post.author).then((uid) {
            if (uid != null) {
              createOrUpdateNotification(
                userId: uid,
                type: 'like',
                postId: postId,
                postTitle: postTitle,
                author: username,
              ).catchError((e) {
                debugPrint('좋아요 알림 생성 오류 (무시): $e');
                return '';
              });
            }
          }).catchError((e) {
            debugPrint('사용자 ID 찾기 오류 (무시): $e');
          });
        }
      }
      
      // 인기작품 선정 시에는 로컬 상태가 이미 업데이트되었으므로 전체 피드 새로고침 불필요
      // (서버 비용 절감: 불필요한 Firestore 읽기 방지)
      // 필요시에만 수동으로 새로고침하거나, 사용자가 pull-to-refresh를 사용하도록 함
    } catch (e) {
      debugPrint('좋아요 토글 오류: $e');
      rethrow;
    }
  }

  Future<void> addComment(String postId, String userId, String username, String text) async {
    try {
      debugPrint('📝 댓글 추가 시작: postId=$postId, userId=$userId, username=$username, text=$text');
      final postRef = _firestore.collection('posts').doc(postId);
      final post = await getPost(postId);
      
      if (post == null) {
        debugPrint('❌ 게시물을 찾을 수 없습니다: $postId');
        throw Exception('게시물을 찾을 수 없습니다.');
      }
      
      debugPrint('✅ 게시물 찾음: ${post.title}, 댓글 수: ${post.comments.length}');
      
      // 댓글을 Map으로 변환하는 헬퍼 함수 (재귀적으로 replies 포함)
      Map<String, dynamic> commentToMap(Comment comment) {
        return {
          'id': comment.id,
          'author': comment.author,
          'authorUid': comment.authorUid,
          'text': comment.text,
          'createdAt': Timestamp.fromDate(comment.createdAt),
          'replies': comment.replies.map((r) => commentToMap(r)).toList(),
          'isAccepted': comment.isAccepted,
          if (comment.acceptedCoinAmount != null) 'acceptedCoinAmount': comment.acceptedCoinAmount,
        };
      }
      
      final comments = post.comments.map((c) => commentToMap(c)).toList();
      
      // FieldValue.serverTimestamp()는 배열 내부에서 지원되지 않으므로
      // Timestamp.fromDate(DateTime.now())를 사용 (기존 프로그램과 동일하게)
      comments.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'author': username,
        'authorUid': userId,
        'text': text,
        'createdAt': Timestamp.fromDate(DateTime.now()), // 기존: firebase.firestore.Timestamp.now()
        'replies': <Map<String, dynamic>>[],
        'isAccepted': false,
      });
      
      await postRef.update({'comments': comments});
      
      // 비용 절감: 로컬 상태만 업데이트하고 전체 새로고침은 백그라운드에서 처리
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final updatedPost = await getPost(postId);
        if (updatedPost != null) {
          _posts[postIndex] = updatedPost;
          notifyListeners();
        }
      }
      
      // 댓글 알림 생성 (게시물 작성자에게, 본인이 작성한 게시물이 아닌 경우)
      if (post.author != username) {
        final authorUid = post.authorUid;
        if (authorUid != null) {
          createOrUpdateNotification(
            userId: authorUid,
            type: 'comment',
            postId: postId,
            postTitle: post.title,
            author: username,
            commentText: text,
          ).catchError((e) {
            debugPrint('댓글 알림 생성 오류 (무시): $e');
            return '';
          });
        } else {
          // authorUid가 없으면 백그라운드에서 찾기
          getUserIdByUsername(post.author).then((uid) {
            if (uid != null) {
              createOrUpdateNotification(
                userId: uid,
                type: 'comment',
                postId: postId,
                postTitle: post.title,
                author: username,
                commentText: text,
              ).catchError((e) {
                debugPrint('댓글 알림 생성 오류 (무시): $e');
                return '';
              });
            }
          }).catchError((e) {
            debugPrint('사용자 ID 찾기 오류 (무시): $e');
          });
        }
      }
      
      // 백그라운드에서 전체 새로고침 (비용 절감)
      getAllPosts().catchError((e) {
        debugPrint('피드 새로고침 오류 (무시): $e');
        return <Post>[];
      });
      
      debugPrint('✅ 댓글 추가 완료');
    } catch (e, stackTrace) {
      debugPrint('❌ 댓글 추가 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 답글 추가 (기존 프로그램의 submitReply, submitNestedReply 대응)
  Future<void> addReply(
    String postId,
    String userId,
    String username,
    String text,
    int commentIndex,
    List<int>? replyPath, // null이면 댓글에 대한 답글, 있으면 중첩 답글
  ) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final post = await getPost(postId);
      
      if (post == null || commentIndex >= post.comments.length) return;
      
      // 댓글을 Map으로 변환 (재귀적으로 replies 포함)
      Map<String, dynamic> commentToMap(Comment comment) {
        return {
          'id': comment.id,
          'author': comment.author,
          'authorUid': comment.authorUid,
          'text': comment.text,
          'createdAt': Timestamp.fromDate(comment.createdAt),
          'replies': comment.replies.map((r) => commentToMap(r)).toList(),
          'isAccepted': comment.isAccepted,
          if (comment.acceptedCoinAmount != null) 'acceptedCoinAmount': comment.acceptedCoinAmount,
        };
      }
      
      final comments = post.comments.map((c) => commentToMap(c)).toList();
      
      // 답글 추가
      final newReply = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'author': username,
        'authorUid': userId,
        'text': text,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'replies': <Map<String, dynamic>>[],
        'isAccepted': false,
      };
      
      if (replyPath == null || replyPath.isEmpty) {
        // 댓글에 대한 답글
        if (comments[commentIndex]['replies'] == null) {
          comments[commentIndex]['replies'] = <Map<String, dynamic>>[];
        }
        (comments[commentIndex]['replies'] as List).add(newReply);
      } else {
        // 중첩 답글 (경로를 따라가서 추가)
        var target = comments[commentIndex];
        for (int i = 0; i < replyPath.length - 1; i++) {
          if (target['replies'] == null) {
            target['replies'] = <Map<String, dynamic>>[];
          }
          target = (target['replies'] as List)[replyPath[i]];
        }
        if (target['replies'] == null) {
          target['replies'] = <Map<String, dynamic>>[];
        }
        (target['replies'] as List).add(newReply);
      }
      
      await postRef.update({'comments': comments});
      
      // 비용 절감: 로컬 상태만 업데이트하고 전체 새로고침은 백그라운드에서 처리
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final updatedPost = await getPost(postId);
        if (updatedPost != null) {
          _posts[postIndex] = updatedPost;
          notifyListeners();
        }
      }
      
      // 답글 알림 생성 (기존 프로그램과 동일)
      final targetComment = post.comments[commentIndex];
      
      // 1. 댓글 작성자에게 알림 (본인이 작성한 댓글이 아닌 경우)
      if (targetComment.author != username) {
        final commentAuthorUid = targetComment.authorUid;
        if (commentAuthorUid != null) {
          createOrUpdateNotification(
            userId: commentAuthorUid,
            type: 'comment',
            postId: postId,
            postTitle: post.title,
            author: username,
            commentText: text,
            isReply: true,
          ).catchError((e) {
            debugPrint('답글 알림 생성 오류 (댓글 작성자, 무시): $e');
            return '';
          });
        } else {
          getUserIdByUsername(targetComment.author).then((uid) {
            if (uid != null) {
              createOrUpdateNotification(
                userId: uid,
                type: 'comment',
                postId: postId,
                postTitle: post.title,
                author: username,
                commentText: text,
                isReply: true,
              ).catchError((e) {
                debugPrint('답글 알림 생성 오류 (댓글 작성자, 무시): $e');
                return '';
              });
            }
          }).catchError((e) {
            debugPrint('댓글 작성자 ID 찾기 오류 (무시): $e');
          });
        }
      }
      
      // 2. 게시물 작성자에게 알림 (본인이 작성한 게시물이 아니고, 댓글 작성자와 다른 경우)
      if (post.author != username && post.author != targetComment.author) {
        final authorUid = post.authorUid;
        if (authorUid != null) {
          createOrUpdateNotification(
            userId: authorUid,
            type: 'comment',
            postId: postId,
            postTitle: post.title,
            author: username,
            commentText: text,
            isReply: true,
          ).catchError((e) {
            debugPrint('답글 알림 생성 오류 (게시물 작성자, 무시): $e');
            return '';
          });
        } else {
          getUserIdByUsername(post.author).then((uid) {
            if (uid != null) {
              createOrUpdateNotification(
                userId: uid,
                type: 'comment',
                postId: postId,
                postTitle: post.title,
                author: username,
                commentText: text,
                isReply: true,
              ).catchError((e) {
                debugPrint('답글 알림 생성 오류 (게시물 작성자, 무시): $e');
                return '';
              });
            }
          }).catchError((e) {
            debugPrint('게시물 작성자 ID 찾기 오류 (무시): $e');
          });
        }
      }
      
      // 백그라운드에서 전체 새로고침 (비용 절감)
      getAllPosts().catchError((e) {
        debugPrint('피드 새로고침 오류 (무시): $e');
        return <Post>[];
      });
    } catch (e) {
      debugPrint('답글 추가 오류: $e');
      rethrow;
    }
  }

  // 댓글 삭제 (기존 프로그램의 deleteComment 대응)
  Future<void> deleteComment(
    String postId,
    int commentIndex,
  ) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final post = await getPost(postId);
      
      if (post == null || commentIndex >= post.comments.length) return;
      
      // 댓글을 Map으로 변환 (재귀적으로 replies 포함)
      Map<String, dynamic> commentToMap(Comment comment) {
        return {
          'id': comment.id,
          'author': comment.author,
          'authorUid': comment.authorUid,
          'text': comment.text,
          'createdAt': Timestamp.fromDate(comment.createdAt),
          'replies': comment.replies.map((r) => commentToMap(r)).toList(),
          'isAccepted': comment.isAccepted,
          if (comment.acceptedCoinAmount != null) 'acceptedCoinAmount': comment.acceptedCoinAmount,
        };
      }
      
      final comments = post.comments.map((c) => commentToMap(c)).toList();
      
      // 댓글 삭제
      comments.removeAt(commentIndex);
      
      await postRef.update({'comments': comments});
      
      // 비용 절감: 로컬 상태만 업데이트하고 전체 새로고침은 백그라운드에서 처리
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final updatedPost = await getPost(postId);
        if (updatedPost != null) {
          _posts[postIndex] = updatedPost;
          notifyListeners();
        }
      }
      
      // 백그라운드에서 전체 새로고침 (비용 절감)
      getAllPosts().catchError((e) {
        debugPrint('피드 새로고침 오류 (무시): $e');
        return <Post>[];
      });
    } catch (e) {
      debugPrint('댓글 삭제 오류: $e');
      rethrow;
    }
  }

  // 답글 삭제 (기존 프로그램의 deleteReply, deleteNestedReply 대응)
  Future<void> deleteReply(
    String postId,
    int commentIndex,
    List<int> replyPath, // 답글 경로
  ) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final post = await getPost(postId);
      
      if (post == null || commentIndex >= post.comments.length) return;
      
      // 댓글을 Map으로 변환 (재귀적으로 replies 포함)
      Map<String, dynamic> commentToMap(Comment comment) {
        return {
          'id': comment.id,
          'author': comment.author,
          'authorUid': comment.authorUid,
          'text': comment.text,
          'createdAt': Timestamp.fromDate(comment.createdAt),
          'replies': comment.replies.map((r) => commentToMap(r)).toList(),
          'isAccepted': comment.isAccepted,
          if (comment.acceptedCoinAmount != null) 'acceptedCoinAmount': comment.acceptedCoinAmount,
        };
      }
      
      final comments = post.comments.map((c) => commentToMap(c)).toList();
      
      // 답글 삭제
      if (replyPath.length == 1) {
        // 첫 번째 레벨 답글
        (comments[commentIndex]['replies'] as List).removeAt(replyPath[0]);
      } else {
        // 중첩 답글
        var target = comments[commentIndex];
        for (int i = 0; i < replyPath.length - 1; i++) {
          target = (target['replies'] as List)[replyPath[i]];
        }
        (target['replies'] as List).removeAt(replyPath.last);
      }
      
      await postRef.update({'comments': comments});
      
      // 비용 절감: 로컬 상태만 업데이트하고 전체 새로고침은 백그라운드에서 처리
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final updatedPost = await getPost(postId);
        if (updatedPost != null) {
          _posts[postIndex] = updatedPost;
          notifyListeners();
        }
      }
      
      // 백그라운드에서 전체 새로고침 (비용 절감)
      getAllPosts().catchError((e) {
        debugPrint('피드 새로고침 오류 (무시): $e');
        return <Post>[];
      });
    } catch (e) {
      debugPrint('답글 삭제 오류: $e');
      rethrow;
    }
  }

  Future<String?> getUserIdByUsername(String username) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('name', isEqualTo: username)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('사용자 ID 찾기 오류: $e');
      return null;
    }
  }

  // 댓글 채택 및 코인 지급 (대댓글 포함)
  Future<void> acceptComment({
    required String postId,
    required String commentId,
    required String commentAuthorUsername,
    required int coinAmount,
    required String postAuthorUid,
    int? commentIndex,
    List<int>? replyPath,
  }) async {
    try {
      // 댓글 작성자의 UID 가져오기
      final commentAuthorUid = await getUserIdByUsername(commentAuthorUsername);
      if (commentAuthorUid == null) {
        throw Exception('댓글 작성자를 찾을 수 없습니다.');
      }

      // 본인 댓글은 채택 불가
      if (commentAuthorUid == postAuthorUid) {
        throw Exception('본인의 댓글은 채택할 수 없습니다.');
      }

      // 게시물 가져오기
      final post = await getPost(postId);
      if (post == null) {
        throw Exception('게시물을 찾을 수 없습니다.');
      }

      // 이미 채택된 댓글/대댓글 수 확인 (최대 3명까지) - 재귀적으로 모든 댓글과 대댓글 확인
      int countAccepted(Comment comment) {
        int count = comment.isAccepted ? 1 : 0;
        for (final reply in comment.replies) {
          count += countAccepted(reply);
        }
        return count;
      }
      
      int acceptedCount = 0;
      for (final comment in post.comments) {
        acceptedCount += countAccepted(comment);
      }
      
      if (acceptedCount >= 3) {
        throw Exception('게시물당 최대 3명까지만 채택할 수 있습니다.');
      }

      // 댓글을 Map으로 변환하는 헬퍼 함수 (대댓글도 처리)
      Map<String, dynamic> commentToMap(Comment comment) {
        // 대댓글인 경우 (replyPath가 있음)
        if (replyPath != null && replyPath.isNotEmpty) {
          // 이 함수는 댓글 레벨에서만 호출되므로, 대댓글 처리는 별도로 해야 함
          return {
            'id': comment.id,
            'author': comment.author,
            'authorUid': comment.authorUid,
            'text': comment.text,
            'createdAt': Timestamp.fromDate(comment.createdAt),
            'replies': comment.replies.map((r) => commentToMap(r)).toList(),
            'isAccepted': comment.isAccepted,
            if (comment.acceptedCoinAmount != null) 'acceptedCoinAmount': comment.acceptedCoinAmount,
          };
        } else {
          // 댓글인 경우
          return {
            'id': comment.id,
            'author': comment.author,
            'authorUid': comment.authorUid,
            'text': comment.text,
            'createdAt': Timestamp.fromDate(comment.createdAt),
            'replies': comment.replies.map((r) => commentToMap(r)).toList(),
            'isAccepted': comment.id == commentId ? true : comment.isAccepted,
            if (comment.id == commentId) 'acceptedCoinAmount': coinAmount,
            if (comment.id != commentId && comment.acceptedCoinAmount != null)
              'acceptedCoinAmount': comment.acceptedCoinAmount,
          };
        }
      }

      // 대댓글을 Map으로 변환하는 헬퍼 함수
      Map<String, dynamic> replyToMap(Comment reply, List<int> path, int currentIndex) {
        if (path.length == 1 && path[0] == currentIndex) {
          // 이 대댓글이 채택 대상인 경우
          return {
            'id': reply.id,
            'author': reply.author,
            'authorUid': reply.authorUid,
            'text': reply.text,
            'createdAt': Timestamp.fromDate(reply.createdAt),
            'replies': reply.replies.map((r) => replyToMap(r, path, currentIndex)).toList(),
            'isAccepted': true,
            'acceptedCoinAmount': coinAmount,
          };
        } else {
          // 일반 대댓글
          return {
            'id': reply.id,
            'author': reply.author,
            'authorUid': reply.authorUid,
            'text': reply.text,
            'createdAt': Timestamp.fromDate(reply.createdAt),
            'replies': reply.replies.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value;
              if (path.length > 1 && path[0] == currentIndex) {
                return replyToMap(r, path.sublist(1), idx);
              }
              return replyToMap(r, path, idx);
            }).toList(),
            'isAccepted': reply.isAccepted,
            if (reply.acceptedCoinAmount != null) 'acceptedCoinAmount': reply.acceptedCoinAmount,
          };
        }
      }

      // 댓글에 채택 표시 추가
      final postRef = _firestore.collection('posts').doc(postId);
      List<Map<String, dynamic>> comments;
      
      if (replyPath != null && replyPath.isNotEmpty && commentIndex != null) {
        // 대댓글 채택인 경우
        comments = post.comments.asMap().entries.map((entry) {
          final idx = entry.key;
          final comment = entry.value;
          if (idx == commentIndex) {
            // 해당 댓글의 대댓글 중 하나를 채택
            return {
              'id': comment.id,
              'author': comment.author,
              'authorUid': comment.authorUid,
              'text': comment.text,
              'createdAt': Timestamp.fromDate(comment.createdAt),
              'replies': comment.replies.asMap().entries.map((replyEntry) {
                final replyIdx = replyEntry.key;
                final reply = replyEntry.value;
                return replyToMap(reply, replyPath, replyIdx);
              }).toList(),
              'isAccepted': comment.isAccepted,
              if (comment.acceptedCoinAmount != null) 'acceptedCoinAmount': comment.acceptedCoinAmount,
            };
          } else {
            return commentToMap(comment);
          }
        }).toList();
      } else {
        // 댓글 채택인 경우
        comments = post.comments.map((c) => commentToMap(c)).toList();
      }

      await postRef.update({'comments': comments});

      // 댓글 작성자에게 코인 지급 (90%만 지급)
      final actualCoinAmount = (coinAmount * 0.9).round();
      await addCoins(
        userId: commentAuthorUid,
        amount: actualCoinAmount,
        type: '댓글 채택',
        postId: postId,
      );

      // 게시물 작성자에게 코인 차감 (댓글 채택) - 전체 금액 차감
      final postAuthorData = await _firestore.collection('users').doc(postAuthorUid).get();
      if (postAuthorData.exists) {
        final currentCoins = (postAuthorData.data()?['coins'] ?? 0) is int
            ? (postAuthorData.data()?['coins'] ?? 0)
            : int.tryParse('${postAuthorData.data()?['coins']}') ?? 0;
        final newCoins = currentCoins - coinAmount;
        
        if (newCoins < 0) {
          throw Exception('코인이 부족합니다.');
        }

        await _firestore.collection('users').doc(postAuthorUid).update({'coins': newCoins});
        
        // 코인 내역 추가 (차감)
        await _firestore.collection('coinHistory').add({
          'userId': postAuthorUid,
          'amount': -coinAmount,
          'type': '댓글 채택',
          'postId': postId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // 알림 생성
      await _firestore.collection('notifications').add({
        'userId': commentAuthorUid,
        'type': 'comment_adopted',
        'postId': postId,
        'postTitle': post.title,
        'author': post.author,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 로컬 상태 업데이트
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final updatedPost = await getPost(postId);
        if (updatedPost != null) {
          _posts[postIndex] = updatedPost;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('댓글 채택 오류: $e');
      rethrow;
    }
  }

  // =========================
  // Search (기존/data.js searchPosts 대응)
  // =========================
  Future<List<Post>> searchPosts(String query, {int limit = 50}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final lower = trimmed.toLowerCase();
    final postsMap = <String, Post>{};

    // 1) tags array-contains
    try {
      final tagSnap = await _firestore
          .collection('posts')
          .where('tags', arrayContains: trimmed)
          .limit(limit)
          .get();
      for (final doc in tagSnap.docs) {
        postsMap[doc.id] = Post.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('태그 검색 오류(무시): $e');
    }

    // 2) title prefix search
    try {
      final titleSnap = await _firestore
          .collection('posts')
          .orderBy('title')
          .where('title', isGreaterThanOrEqualTo: trimmed)
          .where('title', isLessThanOrEqualTo: '$trimmed\uf8ff')
          .limit(limit)
          .get();
      for (final doc in titleSnap.docs) {
        postsMap[doc.id] = Post.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('제목 검색 오류(무시): $e');
    }

    // 3) author prefix search
    try {
      final authorSnap = await _firestore
          .collection('posts')
          .orderBy('author')
          .where('author', isGreaterThanOrEqualTo: trimmed)
          .where('author', isLessThanOrEqualTo: '$trimmed\uf8ff')
          .limit(limit)
          .get();
      for (final doc in authorSnap.docs) {
        postsMap[doc.id] = Post.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('작성자 검색 오류(무시): $e');
    }

    List<Post> results;
    if (postsMap.isNotEmpty) {
      results = postsMap.values.where((p) {
        final title = p.title.toLowerCase();
        final author = p.author.toLowerCase();
        final tagMatches = p.tags.any((t) => t.toLowerCase().contains(lower));
        return title.contains(lower) || author.contains(lower) || tagMatches;
      }).toList();
      results.sort((a, b) => b.date.compareTo(a.date));
      return results.take(limit).toList();
    }

    // fallback: client-side search on feed
    final all = await getAllPosts();
    results = all.where((p) {
      final title = p.title.toLowerCase();
      final author = p.author.toLowerCase();
      final tagMatches = p.tags.any((t) => t.toLowerCase().contains(lower));
      return title.contains(lower) || author.contains(lower) || tagMatches;
    }).toList();
    return results.take(limit).toList();
  }

  // =========================
  // Notifications (기존/data.js notifications 대응)
  // =========================
  Future<List<AppNotification>> getUserNotifications(String userId, {int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final list = snap.docs.map((d) => AppNotification.fromFirestore(d)).toList();
      return _groupNotificationsByPostAndType(list);
    } catch (e) {
      debugPrint('알림 가져오기 오류(폴백 시도): $e');
      final snap = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .limit(limit)
          .get();
      final list = snap.docs.map((d) => AppNotification.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _groupNotificationsByPostAndType(list);
    }
  }

  List<AppNotification> _groupNotificationsByPostAndType(List<AppNotification> notifications) {
    final map = <String, List<AppNotification>>{};
    for (final n in notifications) {
      final key = '${n.postId}_${n.type}';
      map.putIfAbsent(key, () => []).add(n);
    }
    final grouped = <AppNotification>[];
    for (final entry in map.entries) {
      entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final head = entry.value.first;
      grouped.add(AppNotification(
        id: head.id,
        userId: head.userId,
        type: head.type,
        postId: head.postId,
        createdAt: head.createdAt,
        postTitle: head.postTitle,
        author: head.author,
        commentText: head.commentText,
        read: head.read,
        isReply: head.isReply,
        groupCount: entry.value.length,
      ));
    }
    grouped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return grouped;
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    try {
    final snap = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    return snap.size;
    } catch (e) {
      // orderBy 없이 재시도
      try {
        final snap = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('read', isEqualTo: false)
            .get();
        return snap.size;
      } catch (e2) {
        debugPrint('알림 개수 가져오기 오류: $e2');
        return 0;
      }
    }
  }

  // 실시간 알림 개수 스트림 (기존 프로그램의 onSnapshot 대응)
  Stream<int> getUnreadNotificationCountStream(String userId) {
    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) => snapshot.size)
          .handleError((error) {
            debugPrint('알림 스트림 오류 (fallback 시도): $error');
          });
    } catch (e) {
      // orderBy 없이 시도
      debugPrint('알림 스트림 설정 오류 (fallback): $e');
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.size)
          .handleError((error) {
            debugPrint('알림 스트림 fallback 오류: $error');
            return 0;
          });
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'read': true});
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final snap = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    if (snap.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // 알림 생성 또는 업데이트 (기존 프로그램의 createOrUpdateNotification 대응)
  Future<String> createOrUpdateNotification({
    required String userId,
    required String type, // 'like' | 'comment'
    required String postId,
    String? postTitle,
    String? author,
    String? commentText,
    bool isReply = false,
  }) async {
    try {
      // 같은 게시물, 같은 타입의 읽지 않은 알림이 있는지 확인
      final existingSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('postId', isEqualTo: postId)
          .where('type', isEqualTo: type)
          .limit(10)
          .get();

      // 읽지 않은 알림 찾기
      DocumentSnapshot? unreadNotification;
      for (final doc in existingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['read'] != true) {
          unreadNotification = doc;
          break;
        }
      }

      if (unreadNotification != null) {
        // 읽지 않은 알림이 있으면 업데이트 (groupCount 증가는 클라이언트에서 처리)
        await unreadNotification.reference.update({
          'createdAt': FieldValue.serverTimestamp(),
          'author': author,
          if (postTitle != null) 'postTitle': postTitle,
          if (commentText != null) 'commentText': commentText,
          'isReply': isReply,
        });
        return unreadNotification.id;
      } else {
        // 새 알림 생성
        final docRef = await _firestore.collection('notifications').add({
          'userId': userId,
          'type': type,
          'postId': postId,
          if (postTitle != null) 'postTitle': postTitle,
          if (author != null) 'author': author,
          if (commentText != null) 'commentText': commentText,
          'read': false,
          'isReply': isReply,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return docRef.id;
      }
    } catch (e) {
      debugPrint('알림 생성/업데이트 오류: $e');
      rethrow;
    }
  }

  // =========================
  // Coins (기존/data.js addCoins / coinHistory 대응)
  // =========================
  Future<int> addCoins({
    required String userId,
    required int amount,
    required String type,
    String? postId,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    if (!userDoc.exists) throw Exception('사용자 문서가 없습니다.');
    final userData = userDoc.data() ?? {};
    final currentCoins = (userData['coins'] ?? 0) is int ? (userData['coins'] ?? 0) : int.tryParse('${userData['coins']}') ?? 0;
    final newCoins = currentCoins + amount;

    await userRef.update({'coins': newCoins});
    await _firestore.collection('coinHistory').add({
      'userId': userId,
      'amount': amount,
      'type': type,
      if (postId != null) 'postId': postId,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    // 현재 사용자에게 코인을 지급한 경우 AuthService 업데이트
    // (Provider를 통해 접근할 수 없으므로 직접 업데이트하지 않음)
    // 대신 AuthService에서 주기적으로 업데이트하거나, 코인 모달을 열 때 업데이트
    
    return newCoins;
  }

  Future<List<CoinHistoryItem>> getCoinHistory(String userId, {int limit = 10}) async {
    final snap = await _firestore
        .collection('coinHistory')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => CoinHistoryItem.fromFirestore(d)).toList();
  }

  // =========================
  // Lottery (추첨 시스템)
  // =========================
  
  // 최신 추첨 결과 가져오기 (오늘 추첨이 없으면 가장 최근 추첨 결과 반환)
  Future<Map<String, dynamic>> getTodayLotteryResults() async {
    try {
      final today = _getTodayDateString();
      
      // 먼저 오늘 날짜로 조회
      final todayDoc = await _firestore.collection('lotteryResults').doc(today).get();
      
      if (todayDoc.exists) {
        final data = todayDoc.data() as Map<String, dynamic>?;
        final generalWinner = data?['normalWinner'] as Map<String, dynamic>?;
        final popularWinner = data?['popularWinner'] as Map<String, dynamic>?;
        
        // 오늘 당첨자가 하나라도 있으면 오늘 결과 반환
        if (generalWinner != null || popularWinner != null) {
          return {
            'generalWinner': generalWinner?['name'] as String?,
            'generalWinnerUserId': generalWinner?['userId'] as String?,
            'generalWinnerPostId': generalWinner?['postId'] as String?,
            'popularWinner': popularWinner?['name'] as String?,
            'popularWinnerUserId': popularWinner?['userId'] as String?,
            'popularWinnerPostId': popularWinner?['postId'] as String?,
          };
        }
      }
      
      // 오늘 추첨 결과가 없거나 당첨자가 없으면 어제 추첨 결과 확인
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayString = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      
      final yesterdayDoc = await _firestore.collection('lotteryResults').doc(yesterdayString).get();
      if (yesterdayDoc.exists) {
        final data = yesterdayDoc.data() as Map<String, dynamic>?;
        final generalWinner = data?['normalWinner'] as Map<String, dynamic>?;
        final popularWinner = data?['popularWinner'] as Map<String, dynamic>?;
        
        // 어제 당첨자가 하나라도 있으면 어제 결과 반환
        if (generalWinner != null || popularWinner != null) {
          return {
            'generalWinner': generalWinner?['name'] as String?,
            'generalWinnerUserId': generalWinner?['userId'] as String?,
            'generalWinnerPostId': generalWinner?['postId'] as String?,
            'popularWinner': popularWinner?['name'] as String?,
            'popularWinnerUserId': popularWinner?['userId'] as String?,
            'popularWinnerPostId': popularWinner?['postId'] as String?,
          };
        }
      }
      
      // 어제도 없으면 최근 7일 내 추첨 결과 확인 (fallback)
      for (int i = 2; i <= 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final dateString = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        
        final doc = await _firestore.collection('lotteryResults').doc(dateString).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          final generalWinner = data?['normalWinner'] as Map<String, dynamic>?;
          final popularWinner = data?['popularWinner'] as Map<String, dynamic>?;
          
          // 당첨자가 하나라도 있으면 반환
          if (generalWinner != null || popularWinner != null) {
            return {
              'generalWinner': generalWinner?['name'] as String?,
              'generalWinnerUserId': generalWinner?['userId'] as String?,
              'generalWinnerPostId': generalWinner?['postId'] as String?,
              'popularWinner': popularWinner?['name'] as String?,
              'popularWinnerUserId': popularWinner?['userId'] as String?,
              'popularWinnerPostId': popularWinner?['postId'] as String?,
            };
          }
        }
      }
      
      // 최근 7일 내에도 없으면 null 반환
      return {
        'generalWinner': null,
        'generalWinnerUserId': null,
        'generalWinnerPostId': null,
        'popularWinner': null,
        'popularWinnerUserId': null,
        'popularWinnerPostId': null,
      };
    } catch (e) {
      debugPrint('추첨 결과 가져오기 오류: $e');
      return {
        'generalWinner': null,
        'generalWinnerUserId': null,
        'generalWinnerPostId': null,
        'popularWinner': null,
        'popularWinnerUserId': null,
        'popularWinnerPostId': null,
      };
    }
  }
  
  // 당첨자의 게시물 ID 찾기 (최신 게시물)
  Future<String?> getWinnerPostId(String userId, {bool isPopular = false}) async {
    try {
      // authorUid로 먼저 찾기
      var query = _firestore
          .collection('posts')
          .where('authorUid', isEqualTo: userId)
          .where('type', isNotEqualTo: 'notice');
      
      if (isPopular) {
        query = query.where('isPopular', isEqualTo: true);
      }
      
      var snapshot = await query
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      
      // authorUid가 없는 경우 author 이름으로 찾기
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      
      final userName = userDoc.data()?['name'] as String?;
      if (userName == null || userName.isEmpty) return null;
      
      var nameQuery = _firestore
          .collection('posts')
          .where('author', isEqualTo: userName)
          .where('type', isNotEqualTo: 'notice');
      
      if (isPopular) {
        nameQuery = nameQuery.where('isPopular', isEqualTo: true);
      }
      
      final nameSnapshot = await nameQuery
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      
      if (nameSnapshot.docs.isNotEmpty) {
        return nameSnapshot.docs.first.id;
      }
      
      return null;
    } catch (e) {
      debugPrint('당첨자 게시물 찾기 오류: $e');
      return null;
    }
  }
  
  String _getTodayDateString() {
    // 로컬 시간 사용 (기기가 한국 시간으로 설정되어 있다고 가정)
    // Cloud Functions와 동일한 날짜 형식 유지
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  // 추첨 실행 (오후 4시 체크 및 실행)
  Future<void> checkAndRunLottery() async {
    try {
      final result = await _lotteryService.runLottery(
        addCoins: (userId, amount, type) => addCoins(
          userId: userId,
          amount: amount,
          type: type,
        ),
      );
      
      if (result != null) {
        debugPrint('🎉 추첨 완료: 인기작품 당첨자=${result['popularWinner']?['name']}, 일반작품 당첨자=${result['normalWinner']?['name']}');
      }
    } catch (e) {
      debugPrint('추첨 실행 오류: $e');
    }
  }

  // =========================
  // User Posts (기존/data.js getUserPosts 대응)
  // =========================
  Future<List<Post>> getUserPosts(String username) async {
    try {
      if (username.trim().isEmpty) return [];

      final snapshot = await _firestore
          .collection('posts')
          .where('author', isEqualTo: username.trim())
          .orderBy('date', descending: true)
          .get();

      // 쿼리 결과를 바로 반환 (삭제된 게시물은 이미지 로드 실패 시 자동 제거됨)
      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('사용자 게시물 가져오기 오류: $e');
      // orderBy 없이 재시도
      try {
        final snapshot = await _firestore
            .collection('posts')
            .where('author', isEqualTo: username.trim())
            .get();
        
        final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
        posts.sort((a, b) => b.date.compareTo(a.date));
        return posts;
      } catch (e2) {
        debugPrint('사용자 게시물 가져오기 재시도 오류: $e2');
        return [];
      }
    }
  }

  // Firebase Storage URL에서 경로 추출 헬퍼 함수
  String? _extractPathFromUrl(String url) {
    try {
      // Firebase Storage URL 형식: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media&token={token}
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // /v0/b/{bucket}/o/{encodedPath} 형식에서 경로 추출
      if (pathSegments.length >= 4 && pathSegments[0] == 'v0' && pathSegments[1] == 'b' && pathSegments[3] == 'o') {
        // encodedPath 부분을 디코딩
        final encodedPath = pathSegments.sublist(4).join('/');
        return Uri.decodeComponent(encodedPath);
      }
      
      // refFromURL 시도
      try {
        final ref = _storage.refFromURL(url);
        return ref.fullPath;
      } catch (_) {
        // refFromURL 실패 시 URL에서 직접 추출 시도
        final match = RegExp(r'/o/([^?]+)').firstMatch(url);
        if (match != null) {
          return Uri.decodeComponent(match.group(1)!);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('URL에서 경로 추출 오류: $url, $e');
      return null;
    }
  }

  // 이미지 삭제 헬퍼 함수 (경로 추출 후 삭제)
  Future<bool> _deleteImageFromUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return false;
    
    try {
      // 방법 1: refFromURL 시도
      try {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
        debugPrint('✅ 이미지 삭제 성공 (refFromURL): $imageUrl');
        return true;
      } catch (e1) {
        debugPrint('⚠️ refFromURL 실패, 경로 추출 시도: $e1');
        
        // 방법 2: URL에서 경로 추출 후 삭제
        final path = _extractPathFromUrl(imageUrl);
        if (path != null) {
          try {
            final ref = _storage.ref(path);
            await ref.delete();
            debugPrint('✅ 이미지 삭제 성공 (경로 추출): $path');
            return true;
          } catch (e2) {
            debugPrint('❌ 경로로 삭제 실패: $path, $e2');
            return false;
          }
        } else {
          debugPrint('❌ 경로 추출 실패: $imageUrl');
          return false;
        }
      }
    } catch (e) {
      debugPrint('❌ 이미지 삭제 오류: $imageUrl, $e');
      return false;
    }
  }

  // =========================
  // Delete Post (기존/data.js deletePost 대응)
  // =========================
  Future<void> deletePost(String postId) async {
    try {
      // 즉시 로컬에서 제거 (UI 즉시 업데이트)
      _posts.removeWhere((p) => p.id == postId);
      _popularPosts.removeWhere((p) => p.id == postId);
      _notices.removeWhere((p) => p.id == postId);
      notifyListeners();
      
      // 백그라운드에서 실제 삭제 작업 수행
      final post = await getPost(postId);
      if (post == null) {
        debugPrint('⚠️ 게시물을 찾을 수 없음 (이미 삭제됨): $postId');
        return; // 이미 삭제된 경우 그냥 반환
      }

      // 1. Firestore에서 먼저 삭제 (가장 중요 - 바이트 감소를 위해)
      try {
        await _firestore.collection('posts').doc(postId).delete();
        debugPrint('✅ Firestore에서 게시물 삭제 완료: $postId');
        
        // 삭제 확인 (선택적 - 디버깅용)
        final deletedDoc = await _firestore.collection('posts').doc(postId).get();
        if (deletedDoc.exists) {
          debugPrint('⚠️ 경고: 게시물이 여전히 존재합니다. 재시도...');
          // 재시도
          await _firestore.collection('posts').doc(postId).delete();
        } else {
          debugPrint('✅ Firestore 삭제 확인 완료: $postId');
        }
      } catch (firestoreError) {
        debugPrint('❌ Firestore 삭제 오류: $firestoreError');
        // Firestore 삭제 실패 시에도 계속 진행 (이미지는 삭제 시도)
      }

      // 2. 이미지 삭제 (병렬 처리로 속도 향상, 성공 여부 확인)
      final deleteFutures = <Future<bool>>[];
      
      // 메인 이미지 삭제
      if (post.imageUrl.isNotEmpty) {
        deleteFutures.add(_deleteImageFromUrl(post.imageUrl));
      }
      
      // 원본 이미지 삭제
      if (post.originalImageUrl != null && post.originalImageUrl!.isNotEmpty) {
        deleteFutures.add(_deleteImageFromUrl(post.originalImageUrl));
      }
      
      // 압축 이미지 삭제 (메인 이미지와 다를 경우만)
      if (post.compressedImageUrl != null && 
          post.compressedImageUrl!.isNotEmpty &&
          post.compressedImageUrl != post.imageUrl) {
        deleteFutures.add(_deleteImageFromUrl(post.compressedImageUrl));
      }
      
      // 이미지 삭제 실행 및 결과 확인
      if (deleteFutures.isNotEmpty) {
        final results = await Future.wait(deleteFutures);
        final successCount = results.where((r) => r == true).length;
        final totalCount = results.length;
        debugPrint('📊 이미지 삭제 결과: $successCount/$totalCount 성공');
        
        if (successCount < totalCount) {
          debugPrint('⚠️ 일부 이미지 삭제 실패 - Firebase Storage에서 수동 삭제가 필요할 수 있습니다.');
        }
      }
      
      // 피드 새로고침은 백그라운드에서 처리 (비용 절감, 블로킹하지 않음)
      getAllPosts().catchError((e) {
        debugPrint('피드 새로고침 오류 (무시): $e');
        return <Post>[];
      });
      
      // 인기작품 새로고침도 백그라운드에서 처리
      getPopularPosts().catchError((e) {
        debugPrint('인기작품 새로고침 오류 (무시): $e');
        return <Post>[];
      });
      
      // 공지사항 삭제 시 공지사항 목록도 새로고침
      if (post.type == 'notice') {
        getNotices().catchError((e) {
          debugPrint('공지사항 새로고침 오류 (무시): $e');
          return <Post>[];
        });
      }
    } catch (e) {
      debugPrint('❌ 게시물 삭제 오류: $e');
      // 오류 발생해도 로컬에서는 이미 제거되었으므로 rethrow하지 않음
      // (사용자는 이미 화면이 닫혔으므로)
    }
  }

  // =========================
  // Missions (미션 시스템)
  // =========================
  List<Mission> _missions = [];
  Map<String, UserMission> _userMissions = {}; // missionId -> UserMission

  List<Mission> get missions => _missions;
  Map<String, UserMission> get userMissions => _userMissions;

  // 미션 목록 가져오기
  Future<void> getMissions() async {
    try {
      // orderBy 없이 가져오기 (인덱스 문제 방지)
      final snapshot = await _firestore
          .collection('missions')
          .get();
      
      _missions = snapshot.docs.map((doc) => Mission.fromFirestore(doc)).toList();
      
      debugPrint('📋 Firestore에서 가져온 미션 수: ${_missions.length}');
      
      for (var mission in _missions) {
        debugPrint('  - ${mission.id}: ${mission.title} (type: ${mission.type}, reward: ${mission.reward}, isRepeatable: ${mission.isRepeatable}, targetCount: ${mission.targetCount})');
      }
      
      // 보상 순으로 정렬 (로컬에서)
      _missions.sort((a, b) => a.reward.compareTo(b.reward));
      
      // 필수 미션 타입 확인
      final requiredMissionTypes = ['first_upload', 'like_click'];
      final existingTypes = _missions.map((m) => m.type).toSet();
      final missingTypes = requiredMissionTypes.where((type) => !existingTypes.contains(type)).toList();
      
      // 기본 미션이 없거나 필수 미션이 누락된 경우 기본 미션 생성
      if (_missions.isEmpty || missingTypes.isNotEmpty) {
        if (_missions.isEmpty) {
          debugPrint('📋 미션이 없음 - 기본 미션 생성 시작');
        } else {
          debugPrint('📋 누락된 미션 타입: $missingTypes - 기본 미션 생성 시작');
        }
        await _initializeDefaultMissions();
        await getMissions(); // 다시 가져오기
        return;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('미션 목록 가져오기 오류: $e');
      // 기본 미션 생성 시도
      if (_missions.isEmpty) {
        try {
          await _initializeDefaultMissions();
        } catch (e2) {
          debugPrint('기본 미션 생성 오류: $e2');
        }
      }
    }
  }

  // 기본 미션 초기화
  Future<void> _initializeDefaultMissions() async {
    final defaultMissions = [
      {
        'title': '첫 작품 업로드하기',
        'description': '첫 작품을 업로드하면 300코인을 받을 수 있습니다',
        'reward': 300,
        'type': 'first_upload',
        'isRepeatable': false,
      },
      {
        'title': '좋아요 3개 누르기',
        'description': '다른 작품에 좋아요를 3개 누르면 코인을 받을 수 있습니다',
        'reward': 300,
        'type': 'like_click',
        'isRepeatable': true,
        'targetCount': 3,
      },
    ];

    // 기존 미션 확인
    final existingMissions = await _firestore.collection('missions').get();
    final existingTypes = existingMissions.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['type'] as String?)
        .where((type) => type != null)
        .toSet();

    // 존재하지 않는 미션만 생성
    for (final mission in defaultMissions) {
      final missionType = mission['type'] as String;
      if (!existingTypes.contains(missionType)) {
        debugPrint('📋 새 미션 생성: $missionType');
        await _firestore.collection('missions').add(mission);
      } else {
        debugPrint('📋 미션 이미 존재: $missionType - 건너뜀');
      }
    }
  }

  // 사용자의 미션 완료 상태 가져오기
  Future<void> getUserMissions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userMissions')
          .where('userId', isEqualTo: userId)
          .get();

      final Map<String, UserMission> result = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final missionId = data['missionId'] as String? ?? '';
        if (missionId.isEmpty) continue;

        final newMission = UserMission.fromFirestore(doc);
        final existing = result[missionId];

        if (existing == null) {
          result[missionId] = newMission;
          continue;
        }

        // 0단계: 진행도가 더 높은 문서를 항상 우선 (진행도가 거꾸로 내려가지 않도록)
        if (newMission.progress > existing.progress) {
          result[missionId] = newMission;
          continue;
        }
        if (newMission.progress < existing.progress) {
          // 기존 문서의 진행도가 더 높으면 그대로 유지
          continue;
        }

        // 1단계: docId가 우리 규칙(userId_missionId)과 일치하는 문서를 우선
        final preferredDocId = _userMissionDocId(userId, missionId);
        final isNewPreferredId = doc.id == preferredDocId;
        final isExistingPreferredId = existing.id == preferredDocId;

        if (isNewPreferredId && !isExistingPreferredId) {
          result[missionId] = newMission;
          continue;
        }

        // 2단계: startTime이 더 최신인 문서를 우선
        final newStart = newMission.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final existingStart = existing.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (newStart.isAfter(existingStart)) {
          result[missionId] = newMission;
        }
      }

      _userMissions = result;

      // 디버그: Firestore에서 불러온 미션 진행도 로그
      for (final entry in _userMissions.entries) {
        debugPrint('📊 [getUserMissions] missionId=${entry.key}, progress=${entry.value.progress}, completed=${entry.value.completed}');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('사용자 미션 상태 가져오기 오류: $e');
    }
  }

  // 실시간으로 사용자 미션 상태를 감시 (다른 기기에서 진행도가 변경될 때도 즉시 반영)
  void listenUserMissions(String userId) {
    // 기존 구독 해제
    _userMissionsSub?.cancel();

    _userMissionsSub = _firestore
        .collection('userMissions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
      (snapshot) {
        try {
          final Map<String, UserMission> result = {};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final missionId = data['missionId'] as String? ?? '';
            if (missionId.isEmpty) continue;

            final newMission = UserMission.fromFirestore(doc);
            final existing = result[missionId];

            if (existing == null) {
              result[missionId] = newMission;
              continue;
            }

            final preferredDocId = _userMissionDocId(userId, missionId);
            final isNewPreferredId = doc.id == preferredDocId;
            final isExistingPreferredId = existing.id == preferredDocId;

            if (isNewPreferredId && !isExistingPreferredId) {
              result[missionId] = newMission;
              continue;
            }

            final newStart = newMission.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final existingStart = existing.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);

            if (newStart.isAfter(existingStart)) {
              result[missionId] = newMission;
            }
          }

          _userMissions = result;
          // 디버그: 실시간 스냅샷으로부터 미션 진행도 로그
          for (final entry in _userMissions.entries) {
            debugPrint('📡 [listenUserMissions] missionId=${entry.key}, progress=${entry.value.progress}, completed=${entry.value.completed}');
          }
          notifyListeners();
        } catch (e) {
          debugPrint('실시간 사용자 미션 상태 처리 오류: $e');
        }
      },
      onError: (error) {
        debugPrint('❌ userMissions 스트림 오류: $error');
        // 권한 오류인 경우 스트림을 재시작하지 않고, get()으로 폴백
        if (error.toString().contains('permission-denied')) {
          debugPrint('⚠️ 권한 오류로 인해 스트림을 중단하고 get()으로 폴백합니다.');
          // 스트림은 중단하고, 필요시 getUserMissions()를 호출하여 수동으로 업데이트
        }
      },
    );
  }

  // 미션 시작 처리 (like_click 미션용)
  Future<bool> startMission({
    required String userId,
    required String missionId,
  }) async {
    try {
      debugPrint('🚀 [startMission] 시작: userId=$userId, missionId=$missionId');
      
      // 미션 목록이 비어있으면 먼저 로드
      if (_missions.isEmpty) {
        debugPrint('📋 [startMission] 미션 목록이 비어있음, 로드 중...');
        await getMissions();
        debugPrint('📋 [startMission] 미션 목록 로드 완료: ${_missions.length}개');
      }
      
      final mission = _missions.firstWhere((m) => m.id == missionId);
      debugPrint('✅ [startMission] 미션 찾음: ${mission.title} (type: ${mission.type})');
      
      final docRef = _firestore.collection('userMissions').doc(_userMissionDocId(userId, missionId));
      debugPrint('📄 [startMission] 문서 참조: ${docRef.path}');

      // 현재 미션 상태 확인
      final snapshot = await docRef.get();
      debugPrint('🔍 [startMission] 문서 확인: missionId=$missionId, userId=$userId, exists=${snapshot.exists}');
      
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final bool completed = data['completed'] == true;
        final bool hasStartTime = data['startTime'] != null;
        final existingUserId = data['userId'] as String?;
        
        debugPrint('🔍 [startMission] 문서 데이터: existingUserId=$existingUserId, completed=$completed, hasStartTime=$hasStartTime');

        // 이미 진행 중인 미션이라면 (startTime 있고, 아직 completed 아님) 진행도를 유지하고 그대로 성공 처리
        if (hasStartTime && !completed) {
          debugPrint('ℹ️ 이미 진행 중인 미션입니다. 진행도 유지: missionId=$missionId, userId=$userId');
          return true;
        }
        
        // 문서가 존재하므로 update만 사용 (userId는 변경하지 않음)
        debugPrint('🔄 [startMission] update 시도: missionId=$missionId, userId=$userId, existingUserId=$existingUserId');
        final updateData = <String, dynamic>{
          'startTime': FieldValue.serverTimestamp(),
          'progress': 0,
          'completed': false,
        };
        if (mission.type == 'like_click') {
          updateData['likedPostIds'] = [];
        }
        await docRef.update(updateData);
        debugPrint('✅ [startMission] update 성공');
      } else {
        // 문서가 없으면 생성 (일반적으로는 _initializeUserMissions에서 이미 생성됨)
        debugPrint('📝 [startMission] 문서 없음, 생성 시도: missionId=$missionId, userId=$userId');
        final dataToSet = <String, dynamic>{
          'userId': userId,
          'missionId': missionId,
          'startTime': FieldValue.serverTimestamp(),
          'progress': 0,
          'completed': false,
        };
        if (mission.type == 'like_click') {
          dataToSet['likedPostIds'] = [];
        }
        await docRef.set(dataToSet);
        debugPrint('✅ [startMission] create 성공');
      }

      // 로컬 상태 업데이트
      debugPrint('🔄 [startMission] 로컬 상태 업데이트 중...');
      await getUserMissions(userId);
      debugPrint('✅ [startMission] 완료');
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [startMission] 오류 발생: $e');
      debugPrint('❌ [startMission] 스택 트레이스: $stackTrace');
      return false;
    }
  }

  Future<bool> cancelMission({
    required String userId,
    required String missionId,
  }) async {
    try {
      final mission = _missions.firstWhere((m) => m.id == missionId);
      final docRef = _firestore.collection('userMissions').doc(_userMissionDocId(userId, missionId));

      final updateData = <String, dynamic>{
        'progress': 0,
        'completed': false,
        'startTime': FieldValue.delete(),
      };
        if (mission.type == 'like_click') {
          updateData['likedPostIds'] = [];
        }

      // 우선 기존 문서를 삭제하고 완전히 초기화
      try {
        await docRef.delete();
      } catch (_) {}

      await docRef.set(updateData, SetOptions(merge: true));
      await getUserMissions(userId);
      return true;
    } catch (e) {
      debugPrint('미션 취소 오류: $e');
      return false;
    }
  }

  // 미션 완료 처리
  Future<bool> completeMission({
    required String userId,
    required String missionId,
    required String missionType,
  }) async {
    try {
      // 이미 완료했는지 확인 (반복 불가능한 미션인 경우)
      final mission = _missions.firstWhere((m) => m.id == missionId);
      
      // Firestore에서 최신 미션 상태 확인
      final docRef = _firestore.collection('userMissions').doc(_userMissionDocId(userId, missionId));
      final snapshot = await docRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final bool completed = data['completed'] == true;
        final bool hasStartTime = data['startTime'] != null;
        
        // 이미 완료한 미션 (반복 불가능한 경우)
        if (completed && !mission.isRepeatable) {
          return false;
        }
        
        // like_click 미션의 경우, 미션이 시작되지 않았으면 완료 불가
        if (mission.type == 'like_click' && !hasStartTime) {
          debugPrint('⚠️ 미션이 시작되지 않았습니다. 미션 참가하기 버튼을 눌러 미션을 시작하세요. (userId=$userId, missionId=$missionId)');
          return false;
        }
      } else {
        // 미션이 시작되지 않았으면 완료 불가
        // 단, first_upload 미션은 userMission이 없어도 완료 가능 (자동 완료)
        if (mission.type == 'like_click') {
          debugPrint('⚠️ 미션이 시작되지 않았습니다. 미션 참가하기 버튼을 눌러 미션을 시작하세요. (userId=$userId, missionId=$missionId)');
          return false;
        }
        // first_upload 미션의 경우 userMission이 없으면 생성
        if (mission.type == 'first_upload') {
          await docRef.set({
            'userId': userId,
            'missionId': missionId,
            'completed': false,
            'progress': 0,
          }, SetOptions(merge: true));
          debugPrint('✅ first_upload 미션 userMission 생성: $userId');
        }
      }

      // 코인 지급을 먼저 시도 (실패하면 미션 완료 상태를 저장하지 않음)
      debugPrint('💰 미션 완료 - 코인 지급 시도: userId=$userId, missionId=$missionId, missionType=$missionType, reward=${mission.reward}');
      try {
        await addCoins(
          userId: userId,
          amount: mission.reward,
          type: 'mission_$missionType',
        );
        debugPrint('✅ 미션 완료 - 코인 지급 완료: ${mission.reward}코인');
      } catch (e) {
        debugPrint('❌ 미션 완료 - 코인 지급 실패: $e');
        debugPrint('❌ 코인 지급 실패로 인해 미션 완료 처리를 중단합니다.');
        return false; // 코인 지급 실패 시 미션 완료 처리 중단
      }

      // 코인 지급 성공 후 미션 완료 기록 (고정 docId로 upsert)
      final updateData = <String, dynamic>{
        'userId': userId,
        'missionId': missionId,
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      };
      // 재참가 가능한 미션이면 진행도를 0으로 리셋하고 startTime도 삭제
      if (mission.isRepeatable) {
        updateData['progress'] = 0;
        updateData['startTime'] = FieldValue.delete();
        if (mission.type == 'like_click') {
          updateData['likedPostIds'] = [];
        }
      } else {
        // 반복 불가 미션은 완료 시 progress를 1로 두는 기존 동작 유지
        updateData['progress'] = 1;
      }
      
      try {
        await docRef.set(updateData, SetOptions(merge: true));
        debugPrint('✅ 미션 완료 상태 저장 완료: userId=$userId, missionId=$missionId');
      } catch (e) {
        debugPrint('❌ 미션 완료 상태 저장 실패: $e');
        // 코인은 이미 지급되었으므로, 미션 완료 상태 저장 실패는 로그만 남기고 계속 진행
        // (다음에 다시 시도할 수 있도록)
      }

      // 로컬 상태 업데이트
      await getUserMissions(userId);
      
      return true;
    } catch (e) {
      debugPrint('미션 완료 처리 오류: $e');
      return false;
    }
  }

  // 미션 진행도 업데이트 (자동 완료 체크)
  Future<void> updateMissionProgress({
    required String userId,
    required String missionType,
    int progress = 1,
    String? postId, // like_click 미션의 경우 중복 방지를 위한 게시물 ID
    bool? isLikeAction, // like_click 미션의 경우, 좋아요를 누른 경우 true, 취소한 경우 false
  }) async {
    try {
      // 해당 타입의 미션 찾기
      final missions = _missions.where((m) => m.type == missionType).toList();
      if (missions.isEmpty) return;

      for (final mission in missions) {
        // 항상 Firestore에서 해당 userId + missionId 조합의 현재 상태를 읽어와서 사용
        // (좋아요를 누른 사용자의 기기에서도 작성자 미션이 정확히 반영되도록 하기 위함)
        UserMission? userMission;
        try {
          final umDoc = await _firestore
              .collection('userMissions')
              .doc(_userMissionDocId(userId, mission.id))
              .get();
          if (umDoc.exists) {
            userMission = UserMission.fromFirestore(umDoc);
          }
        } catch (e) {
          debugPrint('⚠️ userMissions 읽기 오류 (무시): $e (userId=$userId, missionId=${mission.id})');
        }
        
        // like_click 미션의 경우, 미션이 시작되었는지 확인
        if (mission.type == 'like_click') {
          if (userMission == null || userMission.startTime == null) {
            // 미션이 시작되지 않았으면 카운트하지 않음 (수동으로 미션 참가 버튼을 눌러야 함)
            debugPrint('⚠️ ${mission.title} 미션이 시작되지 않았습니다. 미션 참가하기 버튼을 눌러 미션을 시작하세요. (userId=$userId)');
            continue;
          }
        }
        
        // 재참가 가능한 미션이 완료된 경우 진행도를 0부터 시작
        int baseProgress = 0;
        List<String> likedPostIds = [];
        if (userMission != null) {
          if (mission.isRepeatable && userMission.completed) {
            // 재참가 가능한 미션이 완료된 경우 진행도 리셋
            baseProgress = 0;
            likedPostIds = [];
          } else {
            baseProgress = userMission.progress;
            likedPostIds = List<String>.from(userMission.likedPostIds);
          }
        }
        
        // like_click 미션의 경우, 중복 카운트 방지 및 좋아요 취소 처리
        if (mission.type == 'like_click' && postId != null) {
          if (isLikeAction == true) {
            // 좋아요를 누른 경우
            if (likedPostIds.contains(postId)) {
              // 이미 좋아요를 누른 게시물이면 카운트하지 않음
              debugPrint('⚠️ 이미 좋아요를 누른 게시물입니다. 중복 카운트 방지: $postId');
              continue;
            }
            // 새로운 게시물에 좋아요를 누른 경우에만 카운트
            likedPostIds.add(postId);
          } else if (isLikeAction == false) {
            // 좋아요를 취소한 경우 - likedPostIds에서 제거하지 않음 (중복 방지를 위해 유지)
            // 진행도도 감소하지 않음
            // likedPostIds에 남아있으면 나중에 다시 누를 때 카운트되지 않음
            debugPrint('📋 좋아요 취소: $postId (likedPostIds 유지 - 중복 방지)');
            // 좋아요 취소 시에는 아무것도 하지 않음 (likedPostIds와 진행도 유지)
            continue;
          }
        }
        
        // 진행도 증가 로직
        // - like_click 미션: isLikeAction == true일 때만 진행도 증가
        // - 기타 미션: 무조건 진행도 증가
        final currentProgress = (mission.type == 'like_click' && isLikeAction != true)
            ? baseProgress  // like_click 미션에서 좋아요를 누르지 않은 경우 진행도 증가 안 함
            : baseProgress + progress;  // 나머지 경우 진행도 증가
        final targetCount = mission.targetCount ?? 1;
        
        debugPrint('📊 ${mission.title} 미션 진행도: baseProgress=$baseProgress, progress=$progress, likedPostIds.length=${likedPostIds.length}, currentProgress=$currentProgress, targetCount=$targetCount');
        
        // 목표 달성 여부 확인
        final isCompleted = currentProgress >= targetCount;
        
        if (isCompleted && (userMission == null || !userMission.completed || mission.isRepeatable)) {
          // 미션 완료 처리
          await completeMission(
            userId: userId,
            missionId: mission.id,
            missionType: missionType,
          );
        } else if (!isCompleted) {
          // 진행도만 업데이트
          final docRef = _firestore
              .collection('userMissions')
              .doc(_userMissionDocId(userId, mission.id));

          final updateData = <String, dynamic>{
            'userId': userId,
            'missionId': mission.id,
            'progress': currentProgress,
            'completed': false,
          };
          if (mission.type == 'like_click') {
            updateData['likedPostIds'] = likedPostIds;
          }
          await docRef.set(updateData, SetOptions(merge: true));
        }
      }

      // 로컬 상태 업데이트
      await getUserMissions(userId);
    } catch (e) {
      debugPrint('미션 진행도 업데이트 오류: $e');
    }
  }

  // 사용자가 이미 작품을 업로드했는지 확인
  Future<bool> hasUserUploadedPost(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('authorUid', isEqualTo: userId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('사용자 작품 업로드 확인 오류: $e');
      return false;
    }
  }

  // 첫 작품 업로드 미션 체크 및 완료 처리
  Future<void> _checkAndCompleteFirstUploadMission(String userId) async {
    try {
      // 미션 목록이 비어있으면 먼저 로드
      if (_missions.isEmpty) {
        await getMissions();
      }
      
      // 현재 업로드한 게시물 수 확인
      final snapshot = await _firestore
          .collection('posts')
          .where('authorUid', isEqualTo: userId)
          .get();
      
      // 정확히 1개면 첫 업로드
      if (snapshot.docs.length == 1) {
        // 첫 작품 업로드 미션 찾기
        final firstUploadMission = _missions.firstWhere(
          (m) => m.type == 'first_upload',
          orElse: () => Mission(
            id: '',
            title: '',
            description: '',
            reward: 0,
            type: '',
          ),
        );
        
        if (firstUploadMission.id.isNotEmpty) {
          // userMission이 없으면 생성
          final userMissionId = _userMissionDocId(userId, firstUploadMission.id);
          final userMissionRef = _firestore.collection('userMissions').doc(userMissionId);
          
          UserMission? userMission;
          try {
            final userMissionDoc = await userMissionRef.get();
            if (userMissionDoc.exists) {
              userMission = UserMission.fromFirestore(userMissionDoc);
            }
          } catch (e) {
            debugPrint('⚠️ userMission 조회 오류 (무시하고 계속 진행): $e');
          }
          
          if (userMission == null) {
            // userMission 생성
            try {
              await userMissionRef.set({
                'userId': userId,
                'missionId': firstUploadMission.id,
                'completed': false,
                'progress': 0,
              });
              debugPrint('✅ 첫 작품 업로드 미션 userMission 생성: $userId');
            } catch (e) {
              debugPrint('❌ userMission 생성 오류: $e');
              // 생성 실패해도 계속 진행 (다음에 다시 시도)
            }
          }
          
          // 이미 완료했는지 확인
          final isCompleted = userMission?.completed ?? false;
          
          if (!isCompleted) {
            // 미션 완료 처리
            final success = await completeMission(
              userId: userId,
              missionId: firstUploadMission.id,
              missionType: 'first_upload',
            );
            
            if (success) {
              debugPrint('✅ 첫 작품 업로드 미션 완료: $userId (300코인 지급)');
              
              // 사용자 미션 상태 새로고침 (완료 상태 반영)
              await getUserMissions(userId);
              
              // _userMissions가 업데이트되었으므로 getAvailableMissions가 즉시 반영됨
              // UI 업데이트 (미션 목록에서 즉시 제거)
              notifyListeners();
              
              debugPrint('✅ 미션 목록 UI 업데이트 완료 - 첫 작품 업로드 미션이 제거되었습니다.');
            } else {
              debugPrint('❌ 첫 작품 업로드 미션 완료 실패: $userId');
            }
          } else {
            debugPrint('ℹ️ 이미 완료한 첫 작품 업로드 미션: $userId');
          }
        } else {
          debugPrint('⚠️ 첫 작품 업로드 미션을 찾을 수 없습니다.');
        }
      }
    } catch (e) {
      debugPrint('첫 작품 업로드 미션 체크 오류: $e');
      debugPrint('스택 트레이스: ${StackTrace.current}');
    }
  }

  // 사용자에게 표시할 미션 목록 가져오기 (조건부 필터링)
  Future<List<Mission>> getAvailableMissions(String? userId) async {
    try {
      // _missions가 비어있으면 다시 로드
      if (_missions.isEmpty) {
        debugPrint('📋 _missions가 비어있음 - 다시 로드');
        await getMissions();
      }
      
      debugPrint('📋 전체 미션 수: ${_missions.length}');
      debugPrint('📋 미션 타입들: ${_missions.map((m) => m.type).toList()}');
      
      
      if (userId == null) {
        // 로그인하지 않은 경우 첫 작품 업로드 미션만 표시
        final firstUploadMissions = _missions.where((m) => 
          m.type.toLowerCase() == 'first_upload' || 
          m.type == 'first_upload'
        ).toList();
        debugPrint('📋 로그인하지 않음 - 첫 작품 업로드 미션 표시');
        return firstUploadMissions;
      }

      // 첫 작품 업로드 미션은 사용자가 아직 업로드하지 않은 경우에만 표시
      bool hasUploaded = false;
      try {
        hasUploaded = await hasUserUploadedPost(userId);
        debugPrint('📋 사용자 업로드 여부: $hasUploaded');
      } catch (e) {
        debugPrint('사용자 업로드 확인 오류 (무시): $e');
        // 오류 발생 시 false로 처리
      }

      final List<Mission> result = [];
      
      // 표시할 미션 타입 목록 (first_upload, like_click만 표시)
      final allowedMissionTypes = ['first_upload', 'like_click'];
      
      // 모든 미션 필터링
      for (final mission in _missions) {
        // 허용된 미션 타입만 표시
        if (!allowedMissionTypes.contains(mission.type)) {
          debugPrint('📋 허용되지 않은 미션 타입 제외: ${mission.id} - ${mission.type}');
          continue;
        }
        
        // 첫 작품 업로드 미션 필터링
        if (mission.type == 'first_upload') {
          // 이미 업로드했으면 표시하지 않음
          if (hasUploaded) {
            debugPrint('📋 이미 업로드함 - 미션 제외: ${mission.id}');
            continue;
          }
          
          // 완료한 first_upload 미션도 표시하지 않음
          final userMission = _userMissions[mission.id];
          if (userMission != null && userMission.completed) {
            debugPrint('📋 이미 완료한 first_upload 미션 제외: ${mission.id}');
            continue;
          }
        }
        
        // 모든 미션 표시 (재참가 가능 여부와 관계없이)
        debugPrint('📋 미션 표시: ${mission.id} - ${mission.title}');
        result.add(mission);
      }
      
      debugPrint('📋 최종 표시할 미션 수: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('사용 가능한 미션 가져오기 오류: $e');
      return [];
    }
  }

  // 완료한 미션 수와 총 획득 포인트 계산 (coinHistory에서 실제 획득 기록 기반)
  Future<int> getCompletedMissionCount(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      // coinHistory에서 해당 사용자의 모든 코인 내역을 가져옴
      final snapshot = await _firestore
          .collection('coinHistory')
          .where('userId', isEqualTo: userId)
          .get();
      
      // 클라이언트 측에서 'mission_'으로 시작하는 항목만 필터링
      final missionHistory = snapshot.docs.where((doc) {
        final data = doc.data();
        final type = data['type']?.toString() ?? '';
        return type.startsWith('mission_');
      }).toList();
      
      final count = missionHistory.length;
      debugPrint('📊 완료한 미션 수 계산 (coinHistory 기반): userId=$userId, count=$count');
      return count;
    } catch (e) {
      debugPrint('완료한 미션 수 계산 오류: $e');
      // 오류 발생 시 기존 방식으로 폴백
      final count = _userMissions.values.where((um) => um.completed).length;
      return count;
    }
  }

  Future<int> getTotalMissionReward(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      // coinHistory에서 해당 사용자의 모든 코인 내역을 가져옴
      final snapshot = await _firestore
          .collection('coinHistory')
          .where('userId', isEqualTo: userId)
          .get();
      
      // 클라이언트 측에서 'mission_'으로 시작하는 항목만 필터링하고 합산
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString() ?? '';
        if (type.startsWith('mission_')) {
          int amount = 0;
          if (data['amount'] != null) {
            if (data['amount'] is int) {
              amount = data['amount'] as int;
            } else if (data['amount'] is num) {
              amount = (data['amount'] as num).toInt();
            } else {
              amount = int.tryParse('${data['amount']}') ?? 0;
            }
          }
          total += amount;
        }
      }
      
      debugPrint('📊 총 획득 코인 (coinHistory 기반): userId=$userId, total=$total');
      return total;
    } catch (e) {
      debugPrint('획득한 코인 계산 오류: $e');
      // 오류 발생 시 기존 방식으로 폴백
      int total = 0;
      for (final entry in _userMissions.entries) {
        final userMission = entry.value;
        if (userMission.completed) {
          final mission = _missions.firstWhere(
            (m) => m.id == entry.key,
            orElse: () => Mission(
              id: entry.key,
              title: '',
              description: '',
              reward: 0,
              type: '',
            ),
          );
          total += mission.reward;
        }
      }
      return total;
    }
  }

  // 관리자용: 상위 1000명의 코인 보유량 조회
  Future<List<Map<String, dynamic>>> getTopCoinHolders({int limit = 1000}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('coins', descending: true)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> holders = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final coins = (data['coins'] ?? 0) is int 
            ? (data['coins'] ?? 0) 
            : int.tryParse('${data['coins']}') ?? 0;
        
        holders.add({
          'userId': doc.id,
          'username': data['name'] ?? data['username'] ?? data['email'] ?? '알 수 없음',
          'email': data['email'] ?? '',
          'coins': coins,
        });
      }

      return holders;
    } catch (e) {
      debugPrint('상위 코인 보유자 조회 오류: $e');
      rethrow;
    }
  }

  // 관리자용: 모든 사용자의 평균 코인 보유량 계산
  Future<Map<String, dynamic>> getAverageCoinBalance() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      
      if (snapshot.docs.isEmpty) {
        return {
          'averageCoins': 0.0,
          'totalUsers': 0,
          'totalCoins': 0,
        };
      }

      int totalCoins = 0;
      int userCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final coinsValue = data['coins'] ?? 0;
        final coins = coinsValue is int 
            ? coinsValue 
            : (coinsValue is num 
                ? coinsValue.toInt() 
                : int.tryParse('$coinsValue') ?? 0);
        totalCoins += coins;
        userCount++;
      }

      final averageCoins = userCount > 0 ? totalCoins / userCount : 0.0;

      return {
        'averageCoins': averageCoins,
        'totalUsers': userCount,
        'totalCoins': totalCoins,
      };
    } catch (e) {
      debugPrint('평균 코인 보유량 계산 오류: $e');
      rethrow;
    }
  }

  // =========================
  // 기프티콘 (Gift Card)
  // =========================

  // 기프티콘 상품 모델
  static GiftCard fromGiftCardMap(Map<String, dynamic> data) {
    // 이미지 URL 우선순위: goodsimg > mmsGoodsimg > goodsImgS > goodsImgB
    final imageUrl = (data['goodsimg']?.toString().trim() ?? '').isNotEmpty
        ? data['goodsimg'].toString().trim()
        : (data['mmsGoodsimg']?.toString().trim() ?? '').isNotEmpty
            ? data['mmsGoodsimg'].toString().trim()
            : (data['goodsImgS']?.toString().trim() ?? '').isNotEmpty
                ? data['goodsImgS'].toString().trim()
                : (data['goodsImgB']?.toString().trim() ?? '').isNotEmpty
                    ? data['goodsImgB'].toString().trim()
                    : '';
    
    debugPrint('🖼️ 이미지 URL 매핑:');
    debugPrint('   goodsimg=${data['goodsimg']}');
    debugPrint('   mmsGoodsimg=${data['mmsGoodsimg']}');
    debugPrint('   goodsImgS=${data['goodsImgS']}');
    debugPrint('   goodsImgB=${data['goodsImgB']}');
    debugPrint('   최종 이미지 URL=$imageUrl');
    debugPrint('   상품명=${data['goodsName']}');
    
    return GiftCard(
      goodsCode: (data['goodsCode'] ?? '').toString(),
      goodsName: (data['goodsName'] ?? '').toString(),
      salePrice: (data['salePrice'] ?? 0) is int 
          ? (data['salePrice'] ?? 0) 
          : int.tryParse('${data['salePrice']}') ?? 0,
      discountPrice: (data['discountPrice'] ?? 0) is int 
          ? (data['discountPrice'] ?? 0) 
          : int.tryParse('${data['discountPrice']}') ?? 0,
      goodsimg: imageUrl,
      brandName: (data['brandName'] ?? '').toString(),
      goodsTypeNm: (data['goodsTypeNm'] ?? '').toString(),
    );
  }

  // 기프티콘 목록 조회
  Future<List<GiftCard>> getGiftCardList({int start = 1, int size = 20}) async {
    try {
      debugPrint('🔍 기프티콘 목록 조회 시작...');
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getGiftCardList');
      
      debugPrint('📞 Cloud Function 호출 중...');
      final result = await callable.call({
        'start': start,
        'size': size,
      });

      debugPrint('✅ Cloud Function 응답 받음: ${result.data}');
      
      // 안전한 타입 변환
      final dynamic responseData = result.data;
      if (responseData == null) {
        debugPrint('❌ 응답 데이터가 null입니다.');
        return [];
      }
      
      // Map으로 변환 (타입 안전하게)
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        responseData is Map ? responseData : {}
      );
      
      if (data['success'] == true) {
        final dynamic goodsListData = data['goodsList'];
        final List<dynamic> goodsList = goodsListData is List 
            ? goodsListData 
            : [];
        
        debugPrint('📦 기프티콘 개수: ${goodsList.length}');
        
        // 각 항목을 안전하게 변환
        final List<GiftCard> cards = [];
        for (final item in goodsList) {
          try {
            if (item is Map) {
              final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
              cards.add(fromGiftCardMap(itemMap));
            } else {
              debugPrint('⚠️ 유효하지 않은 상품 데이터 건너뛰기: $item');
            }
          } catch (e) {
            debugPrint('⚠️ 상품 데이터 변환 오류: $e - $item');
          }
        }
        
        debugPrint('✅ 기프티콘 목록 변환 완료: ${cards.length}개');
        return cards;
      } else {
        debugPrint('❌ 기프티콘 목록 조회 실패: ${data['error']}');
        debugPrint('📋 전체 응답: $data');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 기프티콘 목록 조회 오류: $e');
      debugPrint('📋 스택 트레이스: $stackTrace');
      return [];
    }
  }

  // Firestore에서 캐시된 기프티콘 목록 조회
  Future<List<GiftCard>> getCachedGiftCardList({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('giftcards')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return fromGiftCardMap(data);
      }).toList();
    } catch (e) {
      debugPrint('캐시된 기프티콘 목록 조회 오류: $e');
      return [];
    }
  }

  // 기프티콘 상세 정보 조회
  Future<Map<String, dynamic>?> getGiftCardDetail(String goodsCode) async {
    try {
      debugPrint('🔍 기프티콘 상세 정보 조회 시작... goodsCode: $goodsCode');
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getGiftCardDetail');
      
      debugPrint('📞 Cloud Function 호출 중...');
      final result = await callable.call({
        'goodsCode': goodsCode,
      });

      debugPrint('✅ Cloud Function 응답 받음: ${result.data}');
      debugPrint('📋 응답 데이터 타입: ${result.data.runtimeType}');
      
      // 안전한 타입 변환
      final dynamic responseData = result.data;
      if (responseData == null) {
        debugPrint('❌ 응답 데이터가 null입니다.');
        return null;
      }
      
      // Map으로 변환 (타입 안전하게)
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        responseData is Map ? responseData : {}
      );
      
      debugPrint('📋 파싱된 데이터: $data');
      debugPrint('📋 success 값: ${data['success']}');
      debugPrint('📋 goodsDetail 값: ${data['goodsDetail']}');
      debugPrint('📋 goodsDetail 타입: ${data['goodsDetail']?.runtimeType}');
      
      if (data['success'] == true) {
        final dynamic goodsDetail = data['goodsDetail'];
        if (goodsDetail != null) {
          if (goodsDetail is Map) {
            debugPrint('✅ 기프티콘 상세 정보 조회 성공');
            debugPrint('📋 goodsDetail 키 목록: ${(goodsDetail as Map).keys.toList()}');
            return Map<String, dynamic>.from(goodsDetail);
          } else {
            debugPrint('⚠️ goodsDetail이 Map이 아닙니다. 타입: ${goodsDetail.runtimeType}');
            debugPrint('⚠️ goodsDetail 값: $goodsDetail');
            // Map이 아니어도 일단 반환 시도
            return {'rawData': goodsDetail};
          }
        } else {
          debugPrint('⚠️ goodsDetail이 null입니다.');
          debugPrint('📋 전체 응답 데이터: $data');
          return null;
        }
      } else {
        debugPrint('❌ 기프티콘 상세 정보 조회 실패: ${data['error']}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 기프티콘 상세 정보 조회 오류: $e');
      debugPrint('📋 스택 트레이스: $stackTrace');
      return null;
    }
  }
}

// 기프티콘 모델
class GiftCard {
  final String goodsCode;
  final String goodsName;
  final int salePrice;
  final int discountPrice;
  final String goodsimg;
  final String brandName;
  final String goodsTypeNm;

  GiftCard({
    required this.goodsCode,
    required this.goodsName,
    required this.salePrice,
    required this.discountPrice,
    required this.goodsimg,
    required this.brandName,
    required this.goodsTypeNm,
  });
}




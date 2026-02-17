# Firestore 설정 가이드

## 1. 보안 규칙 (Security Rules)

보안 규칙은 `firestore_rules.txt` 파일에 정의되어 있으며, 이미 올바르게 설정되어 있습니다.

### 주요 설정 확인 사항:

✅ **posts 컬렉션**
- `isPopular`, `popularDate`, `popularRewarded`, `popularRewardedAt` 필드 업데이트 허용됨
- 모든 인증된 사용자가 좋아요 및 인기작품 관련 필드를 업데이트할 수 있음

✅ **userMissions 컬렉션**
- 모든 인증된 사용자가 읽기/쓰기 가능 (미션 진행도 업데이트용)
- `userId`, `missionId`, `progress`, `startTime`, `completed`, `likedPostIds` 필드 업데이트 허용됨

✅ **coinHistory 컬렉션**
- 모든 인증된 사용자가 생성 가능 (코인 지급용)
- 본인의 내역만 읽기 가능

## 2. 필요한 복합 인덱스 (Composite Indexes)

다음 쿼리들을 사용하기 위해 Firestore 콘솔에서 복합 인덱스를 생성해야 합니다.

### 2.1. posts 컬렉션

#### 인덱스 1: 공지사항 조회
```
컬렉션: posts
필드:
  - type: Ascending
  - date: Descending
```

**쿼리 위치**: `data_service.dart` - `getNotices()` 함수
```dart
.where('type', isEqualTo: 'notice')
.orderBy('date', descending: true)
```

#### 인덱스 2: 사용자 게시물 조회
```
컬렉션: posts
필드:
  - author: Ascending
  - date: Descending
```

**쿼리 위치**: `data_service.dart` - `getUserPosts()` 함수
```dart
.where('author', isEqualTo: username)
.orderBy('date', descending: true)
```

### 2.2. notifications 컬렉션

#### 인덱스 3: 읽지 않은 알림 조회
```
컬렉션: notifications
필드:
  - userId: Ascending
  - read: Ascending
  - createdAt: Descending
```

**쿼리 위치**: `data_service.dart` - `getUserNotifications()` 함수
```dart
.where('userId', isEqualTo: userId)
.where('read', isEqualTo: false)
.orderBy('createdAt', descending: true)
```

### 2.3. coinHistory 컬렉션

#### 인덱스 4: 코인 내역 조회
```
컬렉션: coinHistory
필드:
  - userId: Ascending
  - timestamp: Descending
```

**쿼리 위치**: `data_service.dart` - `getCoinHistory()` 함수
```dart
.where('userId', isEqualTo: userId)
.orderBy('timestamp', descending: true)
```

## 3. 인덱스 생성 방법

### 방법 1: Firebase 콘솔에서 수동 생성

1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. 프로젝트 선택
3. **Firestore Database** → **인덱스** 탭으로 이동
4. **인덱스 만들기** 버튼 클릭
5. 위의 각 인덱스 정보를 입력하여 생성

### 방법 2: 에러 메시지에서 자동 생성 링크 사용

앱을 실행하고 위의 쿼리를 사용하는 기능을 사용하면, Firestore가 자동으로 인덱스 생성 링크를 제공합니다.

에러 메시지 예시:
```
The query requires an index. You can create it here: https://console.firebase.google.com/...
```

해당 링크를 클릭하면 자동으로 인덱스 생성 페이지로 이동합니다.

## 4. 자동 생성되는 인덱스

다음 쿼리들은 단일 필드 쿼리이므로 자동으로 인덱스가 생성됩니다:

- `userMissions.where('userId', isEqualTo: userId)` - 자동 생성됨
- `posts.where('authorUid', isEqualTo: userId)` - 자동 생성됨

## 5. 확인 사항

✅ 보안 규칙이 올바르게 설정되어 있는지 확인
✅ 필요한 복합 인덱스가 모두 생성되었는지 확인
✅ 인덱스 생성 후 몇 분 정도 기다려야 인덱스가 활성화됨

## 6. 문제 해결

### 인덱스 관련 오류가 발생하는 경우:

1. **에러 메시지 확인**: Firestore가 제공하는 인덱스 생성 링크를 사용
2. **인덱스 상태 확인**: Firebase 콘솔에서 인덱스가 "활성화됨" 상태인지 확인
3. **대기 시간**: 인덱스 생성 후 최대 5분 정도 기다려야 할 수 있음

### 보안 규칙 관련 오류가 발생하는 경우:

1. `firestore_rules.txt` 파일 내용 확인
2. Firebase 콘솔에서 보안 규칙 배포 확인
3. 규칙 시뮬레이터로 테스트


























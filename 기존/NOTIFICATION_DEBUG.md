# 알림 기능 디버깅 가이드

## 현재 상태 확인

브라우저 콘솔에 Firebase 초기화 메시지가 정상적으로 표시되고 있습니다.

## 알림 기능 테스트 방법

### 1단계: 게시물 업로드 테스트
1. 로그인한 상태에서 새 게시물을 업로드하세요
2. 브라우저 콘솔(F12)에서 다음 메시지 확인:
   - `✅ 게시물 생성 완료: [게시물ID]`
   - 게시물에 `authorUid` 필드가 저장되었는지 확인

### 2단계: 좋아요/댓글 테스트
1. **다른 계정으로 로그인** (또는 다른 브라우저/시크릿 모드 사용)
2. 첫 번째 계정이 업로드한 게시물에 좋아요 또는 댓글 추가
3. 브라우저 콘솔에서 다음 메시지 확인:
   - `✅ 알림 생성 성공: [UID]` ← 이 메시지가 보여야 함
   - 또는 `⚠️ 게시물 작성자의 UID를 찾을 수 없습니다` ← 이 메시지가 보이면 문제

### 3단계: 알림 확인
1. **첫 번째 계정으로 다시 로그인**
2. 네비게이션 바의 알림 아이콘(🔔) 확인
3. 빨간 배지에 숫자가 표시되는지 확인
4. 알림 아이콘 클릭하여 알림 목록 확인

## 문제 해결 체크리스트

### ✅ Firestore 보안 규칙 확인
Firebase Console > Firestore Database > 규칙 탭에서:
```javascript
match /notifications/{notificationId} {
  allow read: if request.auth != null && 
                 request.auth.uid == resource.data.userId;
  allow create: if request.auth != null;
  allow update: if request.auth != null && 
                   request.auth.uid == resource.data.userId;
  allow delete: if request.auth != null && 
                   request.auth.uid == resource.data.userId;
}
```
이 규칙이 추가되어 있고 **게시** 버튼을 눌렀는지 확인하세요.

### ✅ Firestore 인덱스 확인
Firebase Console > Firestore Database > 인덱스 탭에서:
- `notifications` 컬렉션에 인덱스 2개가 "사용 설정됨" 상태인지 확인

### ✅ Firestore 데이터 확인
Firebase Console > Firestore Database > 데이터 탭에서:
1. `posts` 컬렉션에서 최근 업로드한 게시물 확인
   - `authorUid` 필드가 있는지 확인
2. `notifications` 컬렉션 확인
   - 알림이 생성되었는지 확인
   - `userId` 필드가 올바른 UID인지 확인

## 콘솔에서 확인할 메시지

### 정상 작동 시:
```
✅ Firebase 초기화 성공
✅ Firebase 서비스 초기화 성공
✅ 게시물 생성 완료: [게시물ID]
✅ 알림 생성 성공: [작성자UID]
```

### 문제 발생 시:
```
❌ 알림 생성 오류: [오류 메시지]
⚠️ 게시물 작성자의 UID를 찾을 수 없습니다: [작성자 이름]
```

## 수동 테스트 방법

브라우저 콘솔에서 직접 테스트:

```javascript
// 현재 사용자 확인
const currentUser = firebaseAuth.currentUser;
console.log('현재 사용자:', currentUser.uid, currentUser.email);

// 알림 생성 테스트
window.dataManager.createNotification({
  userId: currentUser.uid, // 본인에게 알림 생성
  type: 'like',
  postId: 'test-post-id',
  postTitle: '테스트 게시물',
  author: '테스트 사용자'
}).then(() => {
  console.log('✅ 테스트 알림 생성 성공');
}).catch(err => {
  console.error('❌ 테스트 알림 생성 실패:', err);
});
```

## 다음 단계

1. 다른 계정으로 로그인하여 좋아요/댓글 추가
2. 브라우저 콘솔에서 `✅ 알림 생성 성공` 메시지 확인
3. 첫 번째 계정으로 로그인하여 알림 아이콘 확인

문제가 계속되면 브라우저 콘솔의 오류 메시지를 알려주세요.












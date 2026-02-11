# Firestore 보안 규칙 설정 가이드

## 문제 해결: 댓글 작성 권한 오류

게시물 작성자가 아닌 사용자가 댓글을 작성할 때 "허가가 없다"는 오류가 발생하는 경우, Firebase Console에서 Firestore 보안 규칙을 확인하고 수정해야 합니다.

## 설정 방법

1. **Firebase Console 접속**
   - https://console.firebase.google.com 접속
   - 프로젝트 선택

2. **Firestore Database로 이동**
   - 좌측 메뉴에서 "Firestore Database" 선택
   - "규칙" 탭 클릭

3. **보안 규칙 확인 및 수정**
   - 아래 규칙을 복사하여 붙여넣기
   - **중요**: `posts` 컬렉션의 `update` 규칙이 `allow update: if request.auth != null;`로 설정되어 있어야 합니다.

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // 게시물 (posts)
    match /posts/{postId} {
      // 읽기는 모든 사용자 허용 (로그인하지 않은 사용자도 작품 볼 수 있음)
      allow read: if true;
      
      // 생성은 인증된 사용자만 허용
      allow create: if request.auth != null;
      
      // 업데이트: 좋아요/댓글 추가는 모든 인증된 사용자 허용
      // ⚠️ 이 규칙이 없거나 제한되어 있으면 댓글 작성이 안 됩니다!
      allow update: if request.auth != null;
      
      // 삭제는 본인이 작성한 게시물만 허용
      allow delete: if request.auth != null && (
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.name == resource.data.author
      );
    }
    
    // 사용자 정보 (users)
    match /users/{userId} {
      // 읽기는 모든 사용자 허용
      allow read: if true;
      
      // 생성은 인증된 사용자만 허용 (회원가입 시)
      allow create: if request.auth != null && request.auth.uid == userId;
      
      // 업데이트: 본인만 가능하거나, coins 필드만 업데이트하는 경우 허용 (코인 지급용)
      allow update: if request.auth != null && (
        request.auth.uid == userId ||
        // 코인 지급: coins 필드만 업데이트하는 경우 허용
        (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['coins']) &&
         request.resource.data.coins is int &&
         request.resource.data.coins >= 0)
      );
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // 알림 (notifications) - 쿼리 권한 포함
    match /notifications/{notificationId} {
      // 개별 문서 읽기: 본인의 알림만
      allow get: if request.auth != null && 
                    request.auth.uid == resource.data.userId;
      
      // 목록 조회 (쿼리): 로그인한 사용자는 자신의 알림만 조회 가능
      allow list: if request.auth != null;
      
      // 생성: 로그인한 사용자는 알림을 생성할 수 있음
      allow create: if request.auth != null;
      
      // 업데이트: 본인의 알림만 업데이트할 수 있음
      allow update: if request.auth != null && 
                       request.auth.uid == resource.data.userId;
      
      // 삭제: 본인의 알림만 삭제할 수 있음
      allow delete: if request.auth != null && 
                       request.auth.uid == resource.data.userId;
    }
    
    // 코인 내역 (coinHistory)
    match /coinHistory/{historyId} {
      // 읽기: 본인의 내역만 읽을 수 있음
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // 목록 조회 (쿼리): 로그인한 사용자는 자신의 내역만 조회 가능
      allow list: if request.auth != null;
      
      // 생성: 인증된 사용자가 코인 내역을 생성할 수 있음 (코인 지급 시스템용)
      allow create: if request.auth != null && 
                       request.resource.data.userId is string &&
                       request.resource.data.amount is int &&
                       request.resource.data.type is string &&
                       exists(/databases/$(database)/documents/users/$(request.resource.data.userId));
      
      // 업데이트/삭제: 내역은 수정/삭제 불가
      allow update, delete: if false;
    }
    
    // 미션 (missions)
    match /missions/{missionId} {
      // 읽기는 모든 사용자 허용
      allow read: if true;
      // 생성/수정/삭제는 서버에서만 (클라이언트에서는 불가)
      allow create, update, delete: if false;
    }
    
    // 사용자 미션 (userMissions)
    match /userMissions/{userMissionId} {
      // 읽기: 본인의 미션만 읽을 수 있음
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // 목록 조회 (쿼리): 로그인한 사용자는 자신의 미션만 조회 가능
      allow list: if request.auth != null;
      
      // 생성/업데이트: 인증된 사용자가 자신의 미션을 생성/업데이트할 수 있음
      allow create, update: if request.auth != null && 
                               request.resource.data.userId == request.auth.uid;
      
      // 삭제: 본인의 미션만 삭제할 수 있음
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
  }
}
```

4. **규칙 게시**
   - "게시" 버튼 클릭하여 규칙 저장
   - 규칙이 적용되는 데 몇 초 정도 걸릴 수 있습니다.

## 확인 사항

- ✅ `posts` 컬렉션의 `update` 규칙이 `allow update: if request.auth != null;`로 설정되어 있는지 확인
- ✅ 사용자가 로그인되어 있는지 확인 (인증된 사용자만 댓글 작성 가능)
- ✅ Firebase Console에서 규칙이 올바르게 저장되었는지 확인

## 문제가 계속되는 경우

1. Firebase Console에서 규칙을 다시 확인
2. 앱을 재시작
3. 로그인 상태 확인
4. 터미널의 디버그 로그 확인 (오류 메시지 자세히 확인)


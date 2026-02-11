# Firestore 보안 규칙 (완전한 버전)

Firebase Console > Firestore Database > Rules 탭에 다음 규칙을 복사해서 붙여넣으세요.

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
      
      // 수정/삭제는 본인만 허용
      allow update, delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // 알림 (notifications)
    match /notifications/{notificationId} {
      // 읽기: 본인의 알림만 읽을 수 있음
      allow read: if request.auth != null && 
                     request.auth.uid == resource.data.userId;
      
      // 생성: 로그인한 사용자는 알림을 생성할 수 있음
      // (본인 게시물에 좋아요/댓글이 달렸을 때)
      allow create: if request.auth != null;
      
      // 업데이트: 본인의 알림만 업데이트할 수 있음 (읽음 처리)
      allow update: if request.auth != null && 
                       request.auth.uid == resource.data.userId;
      
      // 삭제: 본인의 알림만 삭제할 수 있음
      allow delete: if request.auth != null && 
                       request.auth.uid == resource.data.userId;
    }
  }
}
```

## 적용 방법

1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택
3. 왼쪽 메뉴에서 **Firestore Database** 클릭
4. 상단 탭에서 **Rules** (규칙) 클릭
5. 위의 전체 규칙을 복사해서 붙여넣기
6. **게시** (Publish) 버튼 클릭하여 규칙 저장

## 규칙 설명

### 게시물 (posts)
- **읽기**: 모든 사용자 허용 (비로그인 사용자도 작품 볼 수 있음)
- **생성**: 로그인한 사용자만 가능
- **업데이트**: 로그인한 사용자만 가능 (좋아요/댓글 추가)
- **삭제**: 본인이 작성한 게시물만 삭제 가능

### 사용자 정보 (users)
- **읽기**: 모든 사용자 허용
- **생성**: 회원가입 시 본인 UID로만 생성 가능
- **수정/삭제**: 본인만 가능

### 알림 (notifications)
- **읽기**: 본인의 알림만 읽을 수 있음
- **생성**: 로그인한 사용자는 알림을 생성할 수 있음
- **업데이트**: 본인의 알림만 읽음 처리 가능
- **삭제**: 본인의 알림만 삭제 가능

## 주의사항

- 규칙을 변경한 후 반드시 **게시** 버튼을 클릭해야 적용됩니다
- 규칙 변경 후 몇 초 정도 소요될 수 있습니다
- 프로덕션 환경에서는 더 엄격한 규칙을 권장합니다

## 문제 해결

### 규칙 적용 후 오류가 발생하는 경우:
1. 브라우저 콘솔(F12)에서 오류 메시지 확인
2. Firebase Console > Firestore Database > 규칙 탭에서 규칙 문법 확인
3. 규칙 편집기의 오류 표시 확인

### 알림이 생성되지 않는 경우:
1. `notifications` 컬렉션 규칙이 올바르게 적용되었는지 확인
2. `allow create: if request.auth != null;` 규칙이 있는지 확인
3. 브라우저 콘솔에서 `❌ 알림 생성 오류` 메시지 확인












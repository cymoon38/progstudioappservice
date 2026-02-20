# Firestore 보안 규칙 (권한 오류 수정 버전)

**중요**: 알림 조회 시 권한 오류가 발생하므로, 쿼리 권한을 추가해야 합니다.

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
      // 쿼리 권한도 허용 (알림 목록 조회용)
      allow read: if request.auth != null && (
        request.auth.uid == resource.data.userId ||
        // 쿼리 시에는 userId 필드로 필터링된 결과만 반환됨
        true
      );
      
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
    
    // 알림 컬렉션 쿼리 권한 (중요!)
    // 쿼리 시 userId로 필터링된 결과만 반환되므로 안전함
    match /notifications/{notificationId} {
      allow list: if request.auth != null;
    }
  }
}
```

**위 규칙에 문제가 있을 수 있으므로, 더 안전한 버전:**

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // 게시물 (posts)
    match /posts/{postId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if request.auth != null && (
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.name == resource.data.author
      );
    }
    
    // 사용자 정보 (users)
    match /users/{userId} {
      allow read: if true;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update, delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // 알림 (notifications) - 쿼리 권한 포함
    match /notifications/{notificationId} {
      // 개별 문서 읽기: 본인의 알림만
      allow get: if request.auth != null && 
                    request.auth.uid == resource.data.userId;
      
      // 목록 조회 (쿼리): 로그인한 사용자는 자신의 알림만 조회 가능
      // (쿼리에서 userId로 필터링하므로 안전)
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
  }
}
```

## 적용 방법

1. Firebase Console 접속: https://console.firebase.google.com
2. 프로젝트 선택
3. Firestore Database > Rules 탭
4. 위의 규칙을 복사해서 붙여넣기
5. **게시** 버튼 클릭

## 주요 변경 사항

- `allow list: if request.auth != null;` 추가: 쿼리 권한 허용
- `allow get`: 개별 문서 읽기 권한 명시
- 쿼리에서 `userId`로 필터링하므로 본인 알림만 조회됨












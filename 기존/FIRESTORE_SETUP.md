# Firestore 설정 가이드

## 필수 설정 사항

### 1. Firestore 인덱스 생성 (중요!)

마이페이지에서 사용자별 게시물을 조회할 때 복합 인덱스가 필요합니다.

#### 자동 생성 (권장):
1. 브라우저 콘솔에서 에러 메시지 확인
2. 에러 메시지에 포함된 링크를 클릭
3. Firebase Console에서 인덱스 생성 버튼 클릭

#### 수동 생성:
1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택
3. 왼쪽 메뉴에서 **Firestore Database** 클릭
4. 상단 탭에서 **Indexes** 클릭
5. **Create Index** 버튼 클릭
6. 다음 정보 입력:
   - Collection ID: `posts`
   - Fields to index:
     - Field: `author`, Order: `Ascending`
     - Field: `date`, Order: `Descending`
   - Query scope: `Collection`
7. **Create** 버튼 클릭
8. 인덱스 생성 완료까지 1-2분 대기

### 2. Firestore 보안 규칙 설정

Firebase Console > Firestore Database > Rules에서 다음 규칙 설정:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 정보 읽기/쓰기
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 게시물 읽기 (모두 가능)
    match /posts/{postId} {
      allow read: if true;
      allow create: if request.auth != null && 
                       request.resource.data.author is string &&
                       request.resource.data.author != '';
      allow update: if request.auth != null;
      allow delete: if request.auth != null;
    }
  }
}
```

**중요**: 프로덕션 환경에서는 더 엄격한 규칙을 권장합니다.

### 3. Storage 보안 규칙 설정 (선택)

Firebase Console > Storage > Rules에서 이미지 업로드를 위한 규칙 설정:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /posts/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 문제 해결

### 게시물이 표시되지 않는 경우:

1. **브라우저 콘솔 확인** (F12 > Console)
   - 에러 메시지 확인
   - "✅ 사용자 게시물 로드 시작" 메시지 확인
   - "✅ 로드된 게시물 개수" 확인

2. **Firestore 데이터 확인**
   - Firebase Console > Firestore Database > posts 컬렉션
   - `author` 필드가 정확한 사용자 이름인지 확인
   - `date` 필드가 존재하는지 확인

3. **사용자 정보 확인**
   - Firebase Console > Firestore Database > users 컬렉션
   - 현재 로그인한 사용자의 `name` 필드 확인
   - posts의 `author` 필드와 일치하는지 확인

4. **인덱스 생성 확인**
   - Firebase Console > Firestore Database > Indexes
   - `posts` 컬렉션에 `author`(Ascending) + `date`(Descending) 인덱스가 있는지 확인

## 체크리스트

- [ ] Firestore 인덱스 생성 완료
- [ ] Firestore 보안 규칙 설정 완료
- [ ] Storage 보안 규칙 설정 완료
- [ ] 브라우저 콘솔에서 에러 확인
- [ ] posts 컬렉션의 author 필드 확인
- [ ] users 컬렉션의 name 필드 확인















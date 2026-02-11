# 알림 기능 Firestore 설정 가이드

알림 기능이 정상적으로 작동하려면 Firestore에서 다음 설정이 필요합니다.

## 1. Firestore 보안 규칙 설정

Firebase Console > Firestore Database > 규칙 탭에서 다음 규칙을 추가하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 기존 규칙들...
    
    // 알림 컬렉션 규칙
    match /notifications/{notificationId} {
      // 읽기: 본인의 알림만 읽을 수 있음
      allow read: if request.auth != null && 
                     request.auth.uid == resource.data.userId;
      
      // 쓰기: 로그인한 사용자는 알림을 생성할 수 있음
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

## 2. Firestore 인덱스 생성

Firebase Console > Firestore Database > Indexes 탭에서 다음 인덱스를 생성하세요:

### 인덱스 1: 알림 목록 조회용
- **컬렉션 ID**: `notifications`
- **필드 추가**:
  1. `userId` (오름차순)
  2. `createdAt` (내림차순)
- **쿼리 범위**: 컬렉션

### 인덱스 2: 읽지 않은 알림 개수 조회용
- **컬렉션 ID**: `notifications`
- **필드 추가**:
  1. `userId` (오름차순)
  2. `read` (오름차순)
  3. `createdAt` (내림차순)
- **쿼리 범위**: 컬렉션

### 인덱스 3: 실시간 알림 리스너용
- **컬렉션 ID**: `notifications`
- **필드 추가**:
  1. `userId` (오름차순)
  2. `read` (오름차순)
  3. `createdAt` (내림차순)
- **쿼리 범위**: 컬렉션

## 3. 인덱스 생성 방법

1. Firebase Console에 로그인
2. 프로젝트 선택
3. 왼쪽 메뉴에서 **Firestore Database** 클릭
4. **Indexes** 탭 클릭
5. **인덱스 만들기** 버튼 클릭
6. 위의 인덱스 정보를 입력하고 생성

또는 브라우저 콘솔에서 인덱스 오류가 발생하면, 오류 메시지에 포함된 링크를 클릭하면 자동으로 인덱스 생성 페이지로 이동합니다.

## 4. 확인 사항

### 보안 규칙 확인
- Firebase Console > Firestore Database > 규칙 탭에서 규칙이 올바르게 저장되었는지 확인
- **게시** 버튼을 클릭하여 규칙을 활성화해야 합니다

### 인덱스 생성 확인
- Firebase Console > Firestore Database > Indexes 탭에서 인덱스가 생성 중이거나 완료되었는지 확인
- 인덱스 생성에는 몇 분이 걸릴 수 있습니다

### 테스트 방법
1. 다른 사용자 계정으로 로그인
2. 본인 게시물에 좋아요 또는 댓글 추가
3. 알림 아이콘(🔔)에 빨간 배지가 표시되는지 확인
4. 알림 아이콘을 클릭하여 알림 목록이 표시되는지 확인

## 5. 문제 해결

### 알림이 생성되지 않는 경우
- 브라우저 콘솔(F12)에서 오류 메시지 확인
- Firestore 보안 규칙이 올바르게 설정되었는지 확인
- `notifications` 컬렉션이 Firestore에 생성되는지 확인

### 인덱스 오류가 발생하는 경우
- 브라우저 콘솔의 오류 메시지에 포함된 링크를 클릭하여 인덱스 생성
- 또는 위의 인덱스 정보를 수동으로 생성

### 알림이 표시되지 않는 경우
- Firestore 보안 규칙에서 `read` 권한이 올바르게 설정되었는지 확인
- `userId` 필드가 올바르게 저장되고 있는지 확인 (Firestore Console에서 확인)

## 6. 알림 데이터 구조

알림 문서는 다음과 같은 구조를 가집니다:

```javascript
{
  userId: "사용자_UID",           // 알림을 받을 사용자
  type: "like" | "comment",        // 알림 유형
  postId: "게시물_ID",             // 관련 게시물 ID
  postTitle: "게시물 제목",         // 게시물 제목
  author: "작성자_이름",            // 좋아요/댓글을 단 사용자
  read: false,                     // 읽음 여부
  createdAt: Timestamp,            // 생성 시간
  commentText: "댓글 내용"          // 댓글인 경우에만 존재
}
```












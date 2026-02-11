# 문제1: `author` 필드 불일치 문제 상세 설명

## 🔍 문제의 원인

마이페이지에서 내 작품이 표시되지 않는 가장 흔한 원인은 **게시물을 업로드할 때 사용한 `author` 이름**과 **마이페이지에서 찾는 사용자 이름**이 다를 때입니다.

### 데이터 흐름

#### 1️⃣ 회원가입 시 (auth.js)
```javascript
// Firestore의 users 컬렉션에 저장
{
  name: "홍길동",        // ← 회원가입 폼에서 입력한 닉네임
  email: "hong@example.com",
  postCount: 0
}
```

#### 2️⃣ 게시물 업로드 시 (app.js)
```javascript
// 사용자 정보 가져오기
const userInfo = await getUserInfo(currentUser.uid);
const username = userInfo ? userInfo.name : (currentUser.displayName || currentUser.email.split('@')[0]);

// 게시물 데이터 생성
{
  author: username,  // ← 이 값이 posts 컬렉션에 저장됨
  title: "제목",
  image: "이미지URL",
  ...
}
```

**문제 발생 시나리오:**

| 시나리오 | users.name | 게시물 업로드 시 author | 마이페이지에서 찾는 이름 | 결과 |
|---------|-----------|---------------------|-------------------|------|
| ✅ 정상 | "홍길동" | "홍길동" | "홍길동" | ✅ 표시됨 |
| ❌ 문제1 | "홍길동" | "user123" | "홍길동" | ❌ 표시 안 됨 |
| ❌ 문제2 | "홍길동" | "홍길동" | "user123" | ❌ 표시 안 됨 |
| ❌ 문제3 | "홍길동 " | "홍길동" | "홍길동" | ❌ 공백 차이로 불일치 |

### 왜 이런 문제가 발생하나요?

#### 원인 1: `getUserInfo`가 실패하는 경우
```javascript
// app.js의 handleUpload 함수
const userInfo = await getUserInfo(currentUser.uid);
const username = userInfo ? userInfo.name : (currentUser.displayName || currentUser.email.split('@')[0]);
```

- `userInfo`가 `null`이면 → `currentUser.displayName` 또는 `email.split('@')[0]` 사용
- 예: email이 "hong123@gmail.com"이면 → "hong123"이 `author`로 저장됨
- 하지만 마이페이지에서는 Firestore의 `users.name` ("홍길동")을 찾으므로 → 불일치!

#### 원인 2: 공백(whitespace) 차이
```javascript
// 업로드 시
author: "홍길동"  // 정확히 "홍길동"

// 마이페이지에서
username: "홍길동 "  // 끝에 공백이 있음
// 또는
username: " 홍길동"  // 앞에 공백이 있음
```

- JavaScript의 `trim()`을 사용해도 Firestore에 이미 저장된 값은 변경되지 않음
- 기존 게시물은 이전 이름으로 저장되어 있을 수 있음

#### 원인 3: 닉네임 변경
- 사용자가 닉네임을 변경했지만, 기존 게시물의 `author`는 변경되지 않음
- 새 게시물은 새 닉네임으로 저장되지만, 마이페이지에서는 새 닉네임만 찾음

## 🔧 해결 방법

### 방법 1: 브라우저 콘솔로 확인 (권장)

1. **브라우저 개발자 도구 열기** (F12)
2. **Console 탭** 클릭
3. **마이페이지 접속**
4. **콘솔 메시지 확인:**

```
📋 사용자 정보: {
  username: "홍길동",     // ← 마이페이지에서 찾는 이름
  uid: "abc123...",
  email: "hong@example.com",
  ...
}
```

```
🔍 Firestore의 샘플 게시물 (처음 5개): [
  {
    id: "post1",
    author: "hong123",    // ← 실제 저장된 author
    title: "작품1"
  },
  {
    id: "post2",
    author: "홍길동",     // ← 정확한 author
    title: "작품2"
  }
]
```

5. **비교:**
   - `username`과 `author` 필드가 **정확히 일치**하는지 확인
   - 대소문자, 공백, 특수문자까지 모두 일치해야 함

### 방법 2: Firebase Console에서 직접 확인

#### Step 1: Firestore의 users 컬렉션 확인
1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택
3. **Firestore Database** > **Data** 탭
4. **users** 컬렉션 클릭
5. 현재 로그인한 사용자의 문서 찾기 (UID로 찾기)
6. **`name`** 필드 값 확인 → 예: `"홍길동"`

#### Step 2: Firestore의 posts 컬렉션 확인
1. **posts** 컬렉션 클릭
2. 게시물들 확인
3. **`author`** 필드 값 확인 → 예: `"hong123"` 또는 `"홍길동"`

#### Step 3: 비교
- **users 컬렉션의 `name`** = `"홍길동"`
- **posts 컬렉션의 `author`** = `"hong123"` ❌ 불일치!

### 방법 3: 코드로 자동 확인 및 수정

콘솔에서 다음 코드를 실행하면 불일치하는 게시물을 찾을 수 있습니다:

```javascript
// Firebase Console의 콘솔에서 실행하거나
// 브라우저 콘솔에서 실행 (db와 firebaseAuth가 접근 가능한 경우)

async function checkAuthorMismatch() {
    const user = firebaseAuth.currentUser;
    if (!user) {
        console.log('로그인이 필요합니다.');
        return;
    }
    
    // 사용자 정보 가져오기
    const userDoc = await db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
        console.log('사용자 정보를 찾을 수 없습니다.');
        return;
    }
    
    const userName = userDoc.data().name;
    console.log('✅ 사용자 이름:', userName);
    
    // 모든 게시물 가져오기
    const allPosts = await db.collection('posts').get();
    const myPosts = [];
    const mismatchedPosts = [];
    
    allPosts.forEach(doc => {
        const post = doc.data();
        if (post.author === userName) {
            myPosts.push({ id: doc.id, author: post.author, title: post.title });
        } else if (post.author && post.author.toLowerCase().includes(userName.toLowerCase())) {
            mismatchedPosts.push({ id: doc.id, author: post.author, title: post.title });
        }
    });
    
    console.log('✅ 일치하는 게시물:', myPosts.length, '개');
    console.log('⚠️ 불일치하는 게시물 (유사):', mismatchedPosts);
    
    if (mismatchedPosts.length > 0) {
        console.log('💡 해결: Firebase Console에서 posts 컬렉션의 author 필드를 "' + userName + '"로 수정하세요.');
    }
}

// 실행
checkAuthorMismatch();
```

## 🛠️ 수정 방법

### 방법 A: Firebase Console에서 직접 수정 (빠름)

1. Firebase Console > Firestore > posts 컬렉션
2. 불일치하는 게시물 클릭
3. **`author`** 필드 클릭
4. 올바른 사용자 이름으로 수정 (users 컬렉션의 `name`과 동일하게)
5. **Update** 클릭

### 방법 B: 기존 게시물의 author를 일괄 수정 (권장)

Firebase Console의 콘솔에서 실행:

```javascript
// 주의: 이 코드는 모든 게시물의 author를 현재 사용자 이름으로 변경합니다.
// 테스트 후 실행하세요!

async function fixAllPostAuthors() {
    const user = firebaseAuth.currentUser;
    if (!user) {
        console.log('로그인이 필요합니다.');
        return;
    }
    
    // 사용자 정보 가져오기
    const userDoc = await db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
        console.log('사용자 정보를 찾을 수 없습니다.');
        return;
    }
    
    const correctName = userDoc.data().name;
    console.log('✅ 올바른 사용자 이름:', correctName);
    
    // 현재 사용자가 작성한 모든 게시물 찾기 (UID로 추정)
    // 또는 모든 게시물을 확인하여 author 수정
    const allPosts = await db.collection('posts').get();
    const batch = db.batch();
    let count = 0;
    
    allPosts.forEach(doc => {
        const post = doc.data();
        // author가 잘못된 경우 수정
        // 주의: 이 로직은 실제 상황에 맞게 조정 필요
        if (post.author && post.author !== correctName) {
            // 예: email 기반으로 추정
            const emailPrefix = user.email.split('@')[0];
            if (post.author === emailPrefix || post.author === user.displayName) {
                batch.update(doc.ref, { author: correctName });
                count++;
            }
        }
    });
    
    if (count > 0) {
        await batch.commit();
        console.log('✅', count, '개 게시물의 author 필드를 수정했습니다.');
    } else {
        console.log('수정할 게시물이 없습니다.');
    }
}

// 실행 전 확인!
// fixAllPostAuthors();
```

### 방법 C: 앞으로 업로드되는 게시물이 올바른 author를 사용하도록 보장

이미 코드에서 처리하고 있지만, 더 확실하게 하려면:

```javascript
// app.js의 handleUpload 함수에서
const userInfo = await getUserInfo(currentUser.uid);

// 항상 Firestore의 name을 우선 사용
let username;
if (userInfo && userInfo.name) {
    username = userInfo.name.trim();  // 공백 제거
} else {
    // Firestore에 사용자 정보가 없으면 생성
    console.warn('⚠️ Firestore에 사용자 정보가 없습니다. 생성 중...');
    const name = currentUser.displayName || currentUser.email.split('@')[0];
    await db.collection('users').doc(currentUser.uid).set({
        name: name.trim(),
        email: currentUser.email,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        postCount: 0
    }, { merge: true });
    username = name.trim();
}
```

## 📋 체크리스트

문제 해결을 위해 확인해야 할 항목:

- [ ] Firebase Console > Firestore > users 컬렉션에서 `name` 필드 확인
- [ ] Firebase Console > Firestore > posts 컬렉션에서 `author` 필드 확인
- [ ] 두 값이 **정확히 일치**하는지 확인 (공백, 대소문자 포함)
- [ ] 브라우저 콘솔의 "📋 사용자 정보" 확인
- [ ] 브라우저 콘솔의 "🔍 Firestore의 샘플 게시물" 확인
- [ ] 불일치하는 게시물이 있으면 수정

## 🎯 예상 시나리오별 해결

### 시나리오 1: 일부 게시물만 표시 안 됨
- **원인**: 일부 게시물의 `author`가 다른 이름으로 저장됨
- **해결**: Firebase Console에서 해당 게시물의 `author` 필드 수정

### 시나리오 2: 모든 게시물이 표시 안 됨
- **원인**: 모든 게시물의 `author`가 잘못된 이름으로 저장됨
- **해결**: 일괄 수정 스크립트 실행 또는 각 게시물 수동 수정

### 시나리오 3: 새로 업로드한 게시물만 표시 안 됨
- **원인**: `getUserInfo`가 실패하여 잘못된 `author` 사용
- **해결**: 코드 수정 (방법 C 참고)

## 💡 예방 방법

앞으로 이런 문제를 방지하려면:

1. **항상 Firestore의 `users.name`을 사용**
2. **업로드 전에 사용자 정보 확인 로직 추가**
3. **author 저장 시 `trim()` 사용하여 공백 제거**
4. **콘솔에 저장되는 author 값을 로그로 출력**















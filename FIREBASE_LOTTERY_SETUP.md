# Firebase 추첨 시스템 설정 가이드 (상세)

## 📋 목차
1. [Firebase CLI 설치 및 로그인](#1-firebase-cli-설치-및-로그인)
2. [프로젝트 초기화](#2-프로젝트-초기화)
3. [Cloud Functions 설정](#3-cloud-functions-설정)
4. [Firestore 보안 규칙 확인](#4-firestore-보안-규칙-확인)
5. [Cloud Functions 배포](#5-cloud-functions-배포)
6. [배포 확인 및 테스트](#6-배포-확인-및-테스트)
7. [문제 해결](#7-문제-해결)

---

## 1. Firebase CLI 설치 및 로그인

### 1.1 Node.js 설치 확인

Cloud Functions는 Node.js가 필요합니다. 먼저 Node.js가 설치되어 있는지 확인하세요.

**Windows:**
```bash
node --version
npm --version
```

버전이 표시되지 않으면 [Node.js 공식 사이트](https://nodejs.org/)에서 다운로드하여 설치하세요.
- LTS 버전 권장 (v18 이상)

### 1.2 Firebase CLI 설치

터미널(명령 프롬프트)을 열고 다음 명령어를 실행하세요:

```bash
npm install -g firebase-tools
```

설치가 완료되면 다음 명령어로 확인:

```bash
firebase --version
```

### 1.3 Firebase 로그인

```bash
firebase login
```

브라우저가 자동으로 열리며 Google 계정으로 로그인하세요.
- Firebase 프로젝트에 접근 권한이 있는 계정으로 로그인해야 합니다.

로그인 확인:
```bash
firebase projects:list
```

프로젝트 목록에 `community-b19fb`가 보이면 성공입니다.

---

## 2. 프로젝트 초기화

### 2.1 프로젝트 디렉토리로 이동

```bash
cd C:\Users\ASUS\Desktop\flutter_project
```

### 2.2 Firebase 프로젝트 초기화

**이미 `firebase.json` 파일이 있다면 이 단계를 건너뛰세요.**

```bash
firebase init
```

다음과 같이 선택하세요:

1. **"What do you want to set up for this directory?"**
   - `Functions: Configure and deploy Cloud Functions` 선택 (스페이스바로 선택, Enter로 확인)

2. **"Select a default Firebase project for this directory"**
   - `community-b19fb` 선택 (또는 사용할 프로젝트 선택)

3. **"What language would you like to use to write Cloud Functions?"**
   - `JavaScript` 선택

4. **"Do you want to use ESLint to catch probable bugs and enforce style?"**
   - `Yes` 선택 (코드 품질 향상)

5. **"Do you want to install dependencies with npm now?"**
   - `Yes` 선택

초기화가 완료되면 `firebase.json` 파일과 `functions` 폴더가 생성됩니다.

---

## 3. Cloud Functions 설정

### 3.1 functions 폴더 확인

프로젝트 루트에 `functions` 폴더가 있는지 확인하세요:

```
flutter_project/
  ├── functions/
  │   ├── index.js
  │   ├── package.json
  │   └── ...
  └── ...
```

### 3.2 package.json 확인

`functions/package.json` 파일이 올바른지 확인하세요:

```json
{
  "name": "functions",
  "description": "Cloud Functions for Firebase",
  "scripts": {
    "lint": "eslint .",
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  },
  "devDependencies": {
    "eslint": "^8.15.0",
    "eslint-config-google": "^0.14.0"
  },
  "private": true
}
```

### 3.3 의존성 설치

`functions` 폴더로 이동하여 의존성을 설치하세요:

```bash
cd functions
npm install
```

설치가 완료되면 `node_modules` 폴더가 생성됩니다.

### 3.4 index.js 확인

`functions/index.js` 파일이 올바르게 작성되어 있는지 확인하세요.
- 파일이 이미 생성되어 있다면 그대로 사용하면 됩니다.

---

## 4. Firestore 보안 규칙 확인

### 4.1 Firebase Console에서 확인

1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택 (`community-b19fb`)
3. 왼쪽 메뉴에서 **Firestore Database** 클릭
4. 상단 탭에서 **규칙** 클릭

### 4.2 lotteryResults 컬렉션 규칙 확인

다음 규칙이 포함되어 있어야 합니다:

```javascript
// 추첨 결과 (lotteryResults)
match /lotteryResults/{date} {
  // 읽기: 모든 인증된 사용자 허용
  allow read: if request.auth != null;
  
  // 생성: 인증된 사용자가 추첨 결과를 생성할 수 있음 (추첨 시스템용)
  allow create: if request.auth != null &&
                   request.resource.data.date is string &&
                   request.resource.data.createdAt is timestamp;
  
  // 수정/삭제: 불가 (추첨 결과는 수정/삭제 불가)
  allow update, delete: if false;
}
```

**주의:** Cloud Functions는 서버 권한으로 실행되므로 보안 규칙을 우회합니다. 하지만 클라이언트에서 읽을 때는 이 규칙이 적용됩니다.

### 4.3 보안 규칙 배포

`firestore.rules` 파일을 수정했다면 배포하세요:

```bash
# 프로젝트 루트에서
firebase deploy --only firestore:rules
```

---

## 5. Cloud Functions 배포

### 5.1 배포 전 확인사항

1. **Node.js 버전 확인**
   ```bash
   node --version
   ```
   - v18 이상이어야 합니다.

2. **의존성 설치 확인**
   ```bash
   cd functions
   npm list
   ```
   - `firebase-admin`과 `firebase-functions`가 설치되어 있어야 합니다.

3. **코드 문법 확인 (선택사항)**
   ```bash
   npm run lint
   ```

### 5.2 Cloud Functions 배포

**방법 1: functions 폴더에서 배포**
```bash
cd functions
npm run deploy
```

**방법 2: 프로젝트 루트에서 배포**
```bash
# 프로젝트 루트에서
firebase deploy --only functions
```

**방법 3: 특정 함수만 배포**
```bash
firebase deploy --only functions:runDailyLottery
```

### 5.3 배포 과정

배포가 시작되면 다음과 같은 과정이 진행됩니다:

1. **코드 업로드**: `functions` 폴더의 코드를 Firebase에 업로드
2. **의존성 설치**: 서버에서 `npm install` 실행
3. **함수 생성**: `runDailyLottery` 함수 생성
4. **스케줄 설정**: 매일 오후 4시(한국 시간)에 실행되도록 스케줄 설정

배포가 완료되면 다음과 같은 메시지가 표시됩니다:

```
✔  functions[runDailyLottery(us-central1)] Successful create operation.
Function URL (runDailyLottery): https://...
```

---

## 6. 배포 확인 및 테스트

### 6.1 Firebase Console에서 확인

1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택
3. 왼쪽 메뉴에서 **Functions** 클릭
4. `runDailyLottery` 함수가 표시되는지 확인
5. 함수를 클릭하여 상세 정보 확인:
   - **트리거**: `Cloud Scheduler` (매일 오후 4시)
   - **지역**: `us-central1` (또는 설정한 지역)
   - **상태**: `활성`

### 6.2 수동 실행 (테스트)

**방법 1: Firebase Console에서**
1. Functions 페이지에서 `runDailyLottery` 함수 클릭
2. **테스트** 탭 클릭
3. **테스트 실행** 버튼 클릭
4. 로그에서 결과 확인

**방법 2: Firebase CLI에서**
```bash
firebase functions:shell
```

그 다음:
```javascript
runDailyLottery()
```

### 6.3 로그 확인

```bash
firebase functions:log
```

또는 특정 함수의 로그만 확인:
```bash
firebase functions:log --only runDailyLottery
```

### 6.4 추첨 결과 확인

1. Firebase Console > Firestore Database 접속
2. `lotteryResults` 컬렉션 확인
3. 오늘 날짜(YYYY-MM-DD 형식)의 문서가 생성되었는지 확인
4. 문서 내용 확인:
   - `popularWinner`: 인기작품 당첨자 정보
   - `normalWinner`: 일반작품 당첨자 정보

### 6.5 코인 지급 확인

1. Firestore Database > `users` 컬렉션
2. 당첨자의 `coins` 필드가 증가했는지 확인
3. `coinHistory` 컬렉션에서 코인 지급 내역 확인

---

## 7. 문제 해결

### 7.1 배포 오류

**오류: "Permission denied"**
- Firebase 로그인이 되어 있는지 확인: `firebase login`
- 프로젝트에 대한 권한이 있는지 확인: `firebase projects:list`

**오류: "Functions did not deploy"**
- `functions` 폴더에 `index.js` 파일이 있는지 확인
- `package.json`의 `main` 필드가 `index.js`인지 확인
- Node.js 버전이 18 이상인지 확인

**오류: "Module not found"**
- `functions` 폴더에서 `npm install` 실행
- `package.json`의 의존성이 올바른지 확인

### 7.2 함수가 실행되지 않음

**스케줄이 설정되지 않음**
- Firebase Console > Functions에서 함수 확인
- Cloud Scheduler에서 스케줄 확인:
  1. Firebase Console > Functions
  2. 함수 클릭
  3. "트리거" 섹션에서 스케줄 확인

**시간대 문제**
- `functions/index.js`에서 시간대가 `Asia/Seoul`로 설정되어 있는지 확인:
  ```javascript
  .timeZone('Asia/Seoul')
  ```

### 7.3 추첨이 중복 실행됨

**같은 날 여러 번 실행되는 경우**
- `lotteryResults` 컬렉션의 중복 방지 로직 확인
- 함수 로그에서 중복 실행 원인 확인

### 7.4 코인이 지급되지 않음

**보안 규칙 문제**
- Firestore 보안 규칙에서 `coinHistory` 컬렉션의 `create` 권한 확인
- `users` 컬렉션의 `update` 권한 확인

**함수 실행 오류**
- Functions 로그에서 오류 메시지 확인
- 당첨자 UID가 올바른지 확인

---

## 8. 추가 설정 (선택사항)

### 8.1 Cloud Functions 지역 설정

기본적으로 `us-central1`에 배포됩니다. 한국에 가까운 지역으로 변경하려면:

`functions/index.js`에서:
```javascript
exports.runDailyLottery = functions
    .region('asia-northeast3') // 서울
    .pubsub
    .schedule('0 7 * * *')
    .timeZone('Asia/Seoul')
    .onRun(async (context) => {
      // ...
    });
```

### 8.2 알림 설정 (선택사항)

추첨 당첨자에게 알림을 보내려면 `functions/index.js`의 `runLottery` 함수에 알림 생성 코드를 추가하세요.

---

## 9. 비용 정보

### Cloud Functions 무료 할당량
- **호출**: 월 200만 회 무료
- **계산 시간**: 월 400,000 GB-초 무료
- **네트워크**: 월 5GB 무료

### 예상 비용
- 추첨은 매일 1회만 실행되므로 무료 할당량 내에서 충분합니다.
- 월 약 30회 호출 = 무료

---

## 10. 체크리스트

배포 전 확인사항:

- [ ] Node.js v18 이상 설치됨
- [ ] Firebase CLI 설치 및 로그인 완료
- [ ] `firebase.json` 파일 존재
- [ ] `functions` 폴더에 `index.js` 파일 존재
- [ ] `functions/package.json` 파일 확인
- [ ] `functions` 폴더에서 `npm install` 실행 완료
- [ ] Firestore 보안 규칙에 `lotteryResults` 규칙 추가됨
- [ ] `firebase deploy --only functions` 실행 완료
- [ ] Firebase Console에서 함수 확인 완료
- [ ] 테스트 실행으로 정상 작동 확인 완료

---

## 도움이 필요하신가요?

문제가 발생하면:
1. Firebase Console > Functions > 로그에서 오류 확인
2. `firebase functions:log` 명령어로 로그 확인
3. Firebase 지원팀에 문의



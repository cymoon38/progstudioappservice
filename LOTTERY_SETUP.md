# 추첨 시스템 Cloud Functions 설정 가이드 (간단 버전)

> **더 자세한 가이드는 `FIREBASE_LOTTERY_SETUP.md` 파일을 참고하세요.**

## 빠른 시작

### 1. Firebase CLI 설치 및 로그인

```bash
npm install -g firebase-tools
firebase login
```

### 2. 프로젝트 초기화 (이미 초기화되어 있다면 건너뛰기)

```bash
cd flutter_project
firebase init functions
```

선택사항:
- 언어: **JavaScript**
- ESLint 사용: **Yes**
- 의존성 설치: **Yes**

### 3. 의존성 설치

```bash
cd functions
npm install
```

### 4. Cloud Functions 배포

```bash
# functions 폴더에서
npm run deploy

# 또는 프로젝트 루트에서
firebase deploy --only functions
```

### 5. 배포 확인

[Firebase Console](https://console.firebase.google.com) > Functions에서 `runDailyLottery` 함수 확인

## 작동 방식

- ✅ 매일 오후 4시 (한국 시간)에 자동으로 추첨 실행
- ✅ 인기작품에서 1명 추첨 → 500코인 지급
- ✅ 일반작품에서 1명 추첨 (인기작품 당첨자 제외) → 300코인 지급
- ✅ 같은 날에는 중복 실행 방지
- ✅ 다음날에는 같은 사용자도 다시 추첨될 수 있음

## 로그 확인

```bash
firebase functions:log
```

## 수동 실행 (테스트용)

**Firebase Console에서:**
1. Functions > runDailyLottery 클릭
2. "테스트" 탭 클릭
3. "테스트 실행" 버튼 클릭

**CLI에서:**
```bash
firebase functions:shell
> runDailyLottery()
```

## 문제 해결

자세한 문제 해결 방법은 `FIREBASE_LOTTERY_SETUP.md` 파일의 "문제 해결" 섹션을 참고하세요.

## 참고사항

- Cloud Functions는 무료 플랜에서도 매월 200만 회 호출까지 무료입니다.
- 추첨은 매일 1회만 실행되므로 비용 걱정 없이 사용할 수 있습니다.


# Giftshowbiz API 구매 테스트 설정 가이드

## 📋 개요

Giftshowbiz API를 사용한 기프티콘 구매 기능을 테스트하기 위한 설정 가이드입니다.

## 🔑 환경 설정

### 1. 개발 환경 vs 상용 환경

Giftshowbiz API는 두 가지 환경을 제공합니다:

#### 개발 환경 (테스트)
- **`dev_yn: 'Y'`** 사용
- 실제 결제 없이 테스트 가능
- 개발용 인증 키 사용
- 테스트 계정으로 구매 가능

#### 상용 환경 (운영)
- **`dev_yn: 'N'`** 사용 (현재 설정)
- 실제 결제 발생
- 상용 인증 키 사용
- 실제 고객 구매 처리

### 2. 현재 코드 상태

**`functions/index.js`**에서:
```javascript
// 현재 설정 (상용 환경)
dev_yn: 'N'  // 상용 환경
```

**인증 키:**
```javascript
// 상용 키 (하드코딩됨)
GIFTSHOWBIZ_AUTH_CODE: 'REAL56bf67edd37e4733af8ddba2d5387150'
GIFTSHOWBIZ_AUTH_TOKEN: '3RXSN9gtle+bE63cH3vnSg=='
```

## 🧪 테스트 설정 방법

### 방법 1: 코드에서 직접 변경 (간단한 테스트)

#### 1단계: `functions/index.js` 수정

**`getGiftCardList` 함수:**
```javascript
// 기존
formData.append('dev_yn', 'N');

// 테스트용으로 변경
formData.append('dev_yn', 'Y');
```

**`getGiftCardDetail` 함수:**
```javascript
// 기존
dev_yn: 'N',

// 테스트용으로 변경
dev_yn: 'Y',
```

**구매 함수 (추가 예정):**
```javascript
// 구매 API 호출 시
dev_yn: 'Y',  // 테스트 환경
```

#### 2단계: 개발 환경 인증 키로 변경

**`getSecret` 함수 수정:**
```javascript
function getSecret(secretName) {
  // 테스트 환경 키 사용
  if (secretName === 'GIFTSHOWBIZ_AUTH_CODE') {
    return 'DEVca...';  // 개발 환경 키 (Giftshowbiz에서 발급받은 키)
  }
  if (secretName === 'GIFTSHOWBIZ_AUTH_TOKEN') {
    return 'eai/...';  // 개발 환경 토큰
  }
  return process.env[secretName] || '';
}
```

#### 3단계: Cloud Functions 재배포
```bash
cd functions
firebase deploy --only functions:getGiftCardList
firebase deploy --only functions:getGiftCardDetail
# 구매 함수도 배포
```

### 방법 2: 환경 변수 사용 (권장)

#### 1단계: 환경 변수 설정

**로컬 테스트용 `.env` 파일 생성** (선택사항):
```env
GIFTSHOWBIZ_ENV=dev  # 또는 'prod'
GIFTSHOWBIZ_AUTH_CODE_DEV=DEVca...
GIFTSHOWBIZ_AUTH_TOKEN_DEV=eai/...
GIFTSHOWBIZ_AUTH_CODE_PROD=REAL56bf67edd37e4733af8ddba2d5387150
GIFTSHOWBIZ_AUTH_TOKEN_PROD=3RXSN9gtle+bE63cH3vnSg==
```

#### 2단계: `functions/index.js` 수정

```javascript
// 환경 변수에서 환경 설정 가져오기
const GIFTSHOWBIZ_ENV = process.env.GIFTSHOWBIZ_ENV || 'prod'; // 기본값: 상용
const IS_DEV = GIFTSHOWBIZ_ENV === 'dev';

function getSecret(secretName) {
  if (IS_DEV) {
    // 개발 환경 키
    if (secretName === 'GIFTSHOWBIZ_AUTH_CODE') {
      return process.env.GIFTSHOWBIZ_AUTH_CODE_DEV || 'DEVca...';
    }
    if (secretName === 'GIFTSHOWBIZ_AUTH_TOKEN') {
      return process.env.GIFTSHOWBIZ_AUTH_TOKEN_DEV || 'eai/...';
    }
  } else {
    // 상용 환경 키
    if (secretName === 'GIFTSHOWBIZ_AUTH_CODE') {
      return process.env.GIFTSHOWBIZ_AUTH_CODE_PROD || 'REAL56bf67edd37e4733af8ddba2d5387150';
    }
    if (secretName === 'GIFTSHOWBIZ_AUTH_TOKEN') {
      return process.env.GIFTSHOWBIZ_AUTH_TOKEN_PROD || '3RXSN9gtle+bE63cH3vnSg==';
    }
  }
  return process.env[secretName] || '';
}

// API 호출 시
const devYn = IS_DEV ? 'Y' : 'N';
formData.append('dev_yn', devYn);
```

#### 3단계: Firebase Functions 환경 변수 설정

**로컬 테스트:**
```bash
# .env 파일 사용 (firebase-functions에서 지원)
# 또는 직접 export
export GIFTSHOWBIZ_ENV=dev
```

**Firebase 배포 시:**
```bash
# Firebase Console에서 설정하거나
firebase functions:config:set giftshowbiz.env=dev
```

### 방법 3: 별도 테스트 함수 생성 (가장 안전)

#### 1단계: 테스트 전용 함수 생성

**`functions/index.js`에 추가:**
```javascript
// 테스트 환경용 함수 (별도 배포)
exports.getGiftCardListTest = functions.https.onCall(async (data, context) => {
  // 개발 환경 설정
  const devYn = 'Y';
  const authCode = 'DEVca...';  // 개발 키
  const authToken = 'eai/...';  // 개발 토큰
  
  // 나머지 로직은 동일
  // ...
});
```

#### 2단계: Flutter 앱에서 테스트 함수 호출

**테스트 모드 전환:**
```dart
// data_service.dart
Future<List<GiftCard>> getGiftCardList({int start = 1, int size = 20, bool isTest = false}) async {
  final callable = functions.httpsCallable(
    isTest ? 'getGiftCardListTest' : 'getGiftCardList'
  );
  // ...
}
```

## 📝 구매 API 테스트 시 주의사항

### 1. 테스트 계정 사용
- Giftshowbiz에서 제공하는 테스트 계정 사용
- 실제 결제 정보는 사용하지 않음

### 2. 테스트 상품 선택
- 개발 환경(`dev_yn: 'Y'`)에서는 테스트용 상품만 구매 가능
- 실제 상품은 구매되지 않음

### 3. 구매 API 파라미터
```javascript
{
  api_code: '0201',  // 구매 API 코드 (Giftshowbiz 문서 확인)
  custom_auth_code: authCode,
  custom_auth_token: authToken,
  dev_yn: 'Y',  // 테스트 환경
  goodsCode: '상품코드',
  quantity: 1,
  // 기타 필수 파라미터
}
```

### 4. 에러 처리
- 테스트 환경에서도 실제 API 응답을 받음
- 에러 코드는 Giftshowbiz 문서 참조
- 로깅을 충분히 남겨 디버깅 용이하게

## 🔄 테스트 → 상용 전환

### 체크리스트

1. **코드 확인**
   - [ ] 모든 `dev_yn` 파라미터를 `'N'`으로 변경
   - [ ] 상용 인증 키로 변경
   - [ ] 테스트 코드 제거 또는 주석 처리

2. **환경 변수 확인**
   - [ ] `GIFTSHOWBIZ_ENV=prod` 설정
   - [ ] 상용 키가 올바르게 설정되었는지 확인

3. **배포 전 테스트**
   - [ ] 로컬에서 상용 환경으로 테스트
   - [ ] 구매 API가 정상 작동하는지 확인

4. **배포**
   ```bash
   firebase deploy --only functions
   ```

5. **배포 후 확인**
   - [ ] 실제 상품 목록이 정상적으로 표시되는지
   - [ ] 구매 기능이 정상 작동하는지
   - [ ] 로그에서 에러가 없는지 확인

## 📚 참고 자료

1. **Giftshowbiz API 문서**
   - 개발/상용 환경 차이점
   - 테스트 계정 발급 방법
   - API 코드 목록 (구매: 0201 등)

2. **Firebase Functions 환경 변수**
   - `firebase functions:config:set` 사용법
   - Secret Manager 사용법 (더 안전)

3. **로깅**
   - Cloud Functions 로그 확인
   - Firebase Console > Functions > 로그

## ⚠️ 주의사항

1. **상용 키 보안**
   - 상용 키는 절대 코드에 하드코딩하지 않기
   - Firebase Secret Manager 사용 권장
   - Git에 커밋하지 않기

2. **테스트 후 복구**
   - 테스트 완료 후 반드시 상용 환경으로 복구
   - 테스트 코드는 별도 브랜치에서 관리

3. **비용 관리**
   - 테스트 환경에서도 일부 비용이 발생할 수 있음
   - Giftshowbiz 정책 확인

## 🚀 빠른 테스트 시작

1. `functions/index.js`에서 `dev_yn: 'N'` → `dev_yn: 'Y'` 변경
2. 개발 환경 키로 변경
3. `firebase deploy --only functions:getGiftCardList`
4. 앱에서 테스트

테스트 완료 후 반드시 원래대로 복구!







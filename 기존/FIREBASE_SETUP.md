# Firebase 코인 시스템 설정 가이드

## 🔐 Firestore 보안 규칙 설정

Firebase Console > Firestore Database > 규칙 탭에서 다음 규칙을 사용하세요.

**전체 규칙 파일은 `firestore.rules` 파일에 저장되어 있습니다.**

### 주요 추가 사항:

1. **coinHistory 컬렉션 규칙 추가**
   - 읽기: 자신의 내역만 읽을 수 있음
   - 생성: 인증된 사용자가 자신의 내역을 생성할 수 있음
   - 수정/삭제: 불가

2. **users 컬렉션 규칙 수정**
   - 기존: 본인만 업데이트 가능
   - 수정: 본인 또는 coins 필드만 업데이트하는 경우 허용 (코인 지급용)

3. **posts 컬렉션 규칙**
   - 기존 규칙 유지 (이미 update가 허용되어 있어 isPopular 필드 업데이트 가능)

## 📊 Firestore 인덱스 생성

Firebase Console > Firestore Database > 인덱스 탭에서 다음 인덱스를 생성하세요.

### 1. coinHistory 컬렉션 인덱스

**컬렉션 ID**: `coinHistory`

**필드 추가**:
- `userId` (오름차순)
- `timestamp` (내림차순)

**쿼리 범위**: 컬렉션

**인덱스 생성 이유**: 
```javascript
db.collection('coinHistory')
  .where('userId', '==', userId)
  .orderBy('timestamp', 'desc')
  .limit(20)
```

## 📝 기존 사용자 데이터 초기화

기존 사용자들에게 `coins` 필드가 없을 수 있으므로, 필요시 초기화하세요.

### 방법 1: Firebase Console에서 수동 초기화
1. Firestore Database > users 컬렉션
2. 각 사용자 문서에 `coins: 0` 필드 추가

### 방법 2: 코드로 자동 초기화 (선택사항)
앱 실행 시 자동으로 초기화되도록 `updateCoinBalance()` 함수에서 처리됨.

## ✅ 확인 사항

### 1. Firestore 보안 규칙 확인
- [ ] coinHistory 컬렉션 읽기/쓰기 규칙 설정
- [ ] users 컬렉션 coins 필드 업데이트 규칙 설정
- [ ] posts 컬렉션 isPopular 필드 업데이트 규칙 설정

### 2. Firestore 인덱스 확인
- [ ] coinHistory 컬렉션 인덱스 생성 (userId + timestamp)

### 3. 테스트
- [ ] 코인 내역 조회 테스트
- [ ] 인기작품 선정 시 코인 지급 테스트
- [ ] 코인 잔액 업데이트 테스트

## 🚨 주의사항

1. **보안 규칙**: 코인 지급은 서버 측에서만 처리하는 것이 안전하지만, 현재는 클라이언트에서 처리하므로 보안 규칙을 엄격하게 설정하세요.

2. **인덱스**: 인덱스가 생성되지 않으면 쿼리 오류가 발생할 수 있습니다. 오류 메시지에 인덱스 생성 링크가 포함되어 있으니 클릭하여 생성하세요.

3. **기존 데이터**: 기존 게시물에는 `isPopular` 필드가 없을 수 있으므로, 인기작품으로 선정될 때 자동으로 추가됩니다.


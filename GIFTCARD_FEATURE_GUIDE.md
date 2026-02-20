# 기프티콘 상세보기 및 구매 기능 구현 가이드

## 📋 개요

기프티콘 상세보기 화면과 구매 기능을 구현하기 위한 단계별 가이드입니다.

## 🎯 구현 단계

### 1단계: 기프티콘 상세보기 화면 생성

#### 1.1 새 화면 파일 생성
- 파일 경로: `flutter_app/lib/screens/home/giftcard_detail_screen.dart`
- 화면 구조:
  - 상단: AppBar (뒤로가기 버튼)
  - 이미지 영역: 기프티콘 상품 이미지 (큰 크기)
  - 정보 영역: 브랜드명, 상품명, 가격, 상세 설명
  - 구매 버튼: 하단 고정

#### 1.2 DataService에 상세 정보 조회 함수 추가
- `getGiftCardDetail(String goodsCode)` 함수 추가
- Cloud Function `getGiftCardDetail` 호출
- 반환 타입: `Map<String, dynamic>` 또는 `GiftCardDetail` 모델

#### 1.3 GiftCard 모델 확장 (선택사항)
- 상세 정보를 위한 필드 추가:
  - `description`: 상품 설명
  - `validityPeriod`: 유효기간
  - `usageInfo`: 사용 방법
  - 기타 상세 정보

### 2단계: 기프티콘 아이템 클릭 이벤트 추가

#### 2.1 `_GiftCardItem` 위젯 수정
- `Card` 위젯을 `InkWell` 또는 `GestureDetector`로 감싸기
- `onTap` 콜백 추가
- 클릭 시 `GiftCardDetailScreen`으로 네비게이션

#### 2.2 네비게이션 구현
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GiftCardDetailScreen(goodsCode: giftCard.goodsCode),
  ),
);
```

### 3단계: 구매 기능 구현

#### 3.1 Cloud Function에 구매 API 추가
- 파일: `functions/index.js`
- 함수명: `purchaseGiftCard`
- Giftshowbiz API 구매 엔드포인트 호출
- 필수 파라미터:
  - `goodsCode`: 상품 코드
  - `userId`: 구매자 ID
  - `quantity`: 수량 (기본값: 1)

#### 3.2 DataService에 구매 함수 추가
- `purchaseGiftCard(String goodsCode, int quantity)` 함수 추가
- Cloud Function `purchaseGiftCard` 호출
- 구매 성공 시:
  1. 사용자 코인 차감
  2. 구매 내역 Firestore에 저장
  3. 보유 기프티콘 목록 업데이트

#### 3.3 Firestore 데이터 구조 설계

**구매 내역 컬렉션 (`purchases`)**
```
purchases/{purchaseId}
{
  userId: string,
  goodsCode: string,
  goodsName: string,
  quantity: number,
  totalPrice: number,
  purchaseDate: timestamp,
  status: string, // 'pending', 'completed', 'cancelled'
  gifticonCode: string, // Giftshowbiz에서 발급받은 기프티콘 코드
  gifticonUrl: string, // 기프티콘 사용 URL
  expiryDate: timestamp, // 유효기간
}
```

**보유 기프티콘 컬렉션 (`ownedGiftCards`)**
```
ownedGiftCards/{giftCardId}
{
  userId: string,
  goodsCode: string,
  goodsName: string,
  purchaseId: string, // purchases 컬렉션 참조
  gifticonCode: string,
  gifticonUrl: string,
  purchaseDate: timestamp,
  expiryDate: timestamp,
  isUsed: boolean,
  usedDate: timestamp (nullable),
}
```

#### 3.4 구매 프로세스
1. 사용자 코인 잔액 확인
2. 구매 가능 여부 확인 (코인 부족 시 오류)
3. Giftshowbiz API 호출하여 구매
4. 구매 성공 시:
   - 사용자 코인 차감 (`addCoins` 함수 사용, 음수 값)
   - `purchases` 컬렉션에 구매 내역 저장
   - `ownedGiftCards` 컬렉션에 보유 기프티콘 추가
   - 코인 내역(`coinHistory`)에 차감 기록 추가

### 4단계: 보유중 탭 구현

#### 4.1 보유 기프티콘 조회 함수 추가
- `DataService`에 `getOwnedGiftCards(String userId)` 함수 추가
- Firestore `ownedGiftCards` 컬렉션에서 `userId`로 필터링
- `isUsed == false`인 것만 표시 (선택사항)

#### 4.2 보유중 탭 UI 구현
- `shop_screen.dart`의 `_buildOwnedTab()` 함수 구현
- `GridView` 또는 `ListView`로 보유 기프티콘 표시
- 각 아이템에:
  - 기프티콘 이미지
  - 상품명
  - 유효기간
  - 사용하기 버튼 (선택사항)

### 5단계: Firestore 보안 규칙 추가

#### 5.1 `purchases` 컬렉션 규칙
```javascript
match /purchases/{purchaseId} {
  allow read: if request.auth != null && 
                resource.data.userId == request.auth.uid;
  allow create: if request.auth != null && 
                  request.resource.data.userId == request.auth.uid;
  allow update, delete: if false; // 구매 내역은 수정/삭제 불가
}
```

#### 5.2 `ownedGiftCards` 컬렉션 규칙
```javascript
match /ownedGiftCards/{giftCardId} {
  allow read: if request.auth != null && 
                resource.data.userId == request.auth.uid;
  allow create: if request.auth != null && 
                  request.resource.data.userId == request.auth.uid;
  allow update: if request.auth != null && 
                  resource.data.userId == request.auth.uid &&
                  request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isUsed', 'usedDate']);
  allow delete: if false; // 보유 기프티콘은 삭제 불가
}
```

## 📝 구현 체크리스트

### Flutter 앱
- [ ] `GiftCardDetailScreen` 화면 생성
- [ ] `_GiftCardItem`에 클릭 이벤트 추가
- [ ] `DataService.getGiftCardDetail()` 함수 추가
- [ ] `DataService.purchaseGiftCard()` 함수 추가
- [ ] `DataService.getOwnedGiftCards()` 함수 추가
- [ ] 구매 확인 다이얼로그 구현
- [ ] 구매 성공/실패 알림 처리
- [ ] 보유중 탭 UI 구현

### Cloud Functions
- [ ] `purchaseGiftCard` 함수 구현
- [ ] Giftshowbiz 구매 API 연동
- [ ] 구매 성공 시 Firestore에 데이터 저장
- [ ] 에러 처리 및 로깅

### Firestore
- [ ] `purchases` 컬렉션 보안 규칙 추가
- [ ] `ownedGiftCards` 컬렉션 보안 규칙 추가
- [ ] 필요시 인덱스 추가

## 🔗 참고사항

1. **Giftshowbiz API 문서 확인**
   - 구매 API 엔드포인트
   - 필수 파라미터
   - 응답 형식
   - 에러 코드

2. **코인 차감 처리**
   - `addCoins` 함수를 음수 값으로 호출하여 차감
   - 또는 별도의 `deductCoins` 함수 생성

3. **구매 내역 관리**
   - 구매 취소 기능 (선택사항)
   - 환불 처리 (선택사항)

4. **기프티콘 사용 처리**
   - 사용하기 버튼 클릭 시 `isUsed = true`로 업데이트
   - Giftshowbiz API로 사용 처리 (필요시)

## 🚀 다음 단계

1. 기프티콘 상세보기 화면부터 구현
2. 구매 기능은 상세보기 화면 완성 후 구현
3. 보유중 탭은 구매 기능 완성 후 구현









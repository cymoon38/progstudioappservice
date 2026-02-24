# 애드팝콘 오퍼월 충전소 연동 가이드

애드팝콘 오퍼월을 연동해 사용자가 미션(설치/가입 등)을 완료하면 코인을 지급하는 **오퍼월 충전소**를 설정하는 방법입니다.

**공식 연동 가이드:** [애드팝콘 리워드 콜백 서버 연동 가이드](https://adpopcorn.notion.site/5b35743dd96240a99f89e466a3e92da8)

---

## 1. 전체 흐름

1. **앱** → 사용자가 "오퍼월 충전소" 진입 → 애드팝콘 SDK로 오퍼월 화면 오픈 (유저 식별자 = Firebase UID 전달)
2. **사용자** → 미션 수행 (앱 설치, 가입 등)
3. **애드팝콘 서버** → 미션 완료 시 **우리 서버(콜백 URL)** 로 GET 요청으로 리워드 지급 정보 전달
4. **우리 서버(Firebase Functions)** → SignedValue 검증, 중복/유저 검증 후 코인 지급 → JSON 응답

---

## 2. 애드팝콘 관리자 설정 (콜백 서버 설정)

관리자 화면에서 **콜백 서버 설정**을 다음처럼 입력합니다.

| 항목 | 입력 내용 |
|------|-----------|
| **스테이징 서버 주소** | 테스트용 URL (예: `https://us-central1-<프로젝트ID>.cloudfunctions.net/adpopcornRewardCallback` 같은 함수 URL을 테스트용으로 사용 가능) |
| **라이브 서버 주소** | 실제 서비스용 URL (배포된 Cloud Functions HTTP URL) |
| **통신 방식** | **GET** (가이드 권장) |
| **보안 프로토콜** | **TLS** (HTTPS) |

- **콜백 URL**은 나중에 Firebase Functions에 만든 **HTTP 엔드포인트 주소**를 넣으면 됩니다.
- 애드팝콘에서 **HASH KEY**를 발급받아, 서버에서 SignedValue 검증 시 사용합니다. (Secret Manager 등에 저장 권장)

---

## 3. 콜백 응답 규약 (반드시 준수)

애드팝콘이 콜백을 보내면, 우리 서버는 **반드시 아래 JSON 형식**으로 응답해야 합니다.

| 상황 | Result | ResultCode | ResultMsg |
|------|--------|------------|-----------|
| 리워드 지급 성공 | `true` | `1` | `"success"` |
| 보안성 검증 실패 (SignedValue 불일치) | `false` | `1100` | `"invalid signed value"` |
| 리워드 중복 지급 (이미 처리한 rewardKey) | `false` | `3100` | `"duplicate transaction"` |
| 유저 검증 실패 (존재하지 않는 유저) | `false` | `3200` | `"invalid user"` |
| 기타 예외 | `false` | `4000` | 영어 메시지 |

- **Content-Type:** `application/json`
- **ResultMsg**는 예외 시에도 **영어**로 설정해야 합니다.

---

## 4. SignedValue 검증 (필수)

- 애드팝콘은 **기본 콜백 파라미터**(`usn`, `rewardkey`, `quantity`, `campaignkey`)를 **plainText**로 하고, **HASH KEY**로 **HMAC-MD5** 암호화한 값을 **SignedValue**로 보냅니다.
- 우리 서버에서도 **동일한 파라미터 + 동일한 HASH KEY**로 HMAC-MD5를 계산해, 애드팝콘이 보낸 SignedValue와 **일치할 때만** 리워드 지급을 진행합니다.
- 불일치 시 → `Result: false, ResultCode: 1100, ResultMsg: "invalid signed value"` 반환.

---

## 5. 서버 구현 시 처리 순서 (Firebase Functions)

1. **GET 쿼리 파라미터 수신**  
   - `usn` (유저 식별자, 우리는 Firebase UID 사용 권장)  
   - `rewardkey` (캠페인별 유일 키, 중복 지급 방지용)  
   - `quantity` (지급할 리워드 양 = 코인 수)  
   - `campaignkey` (캠페인 식별)  
   - `SignedValue` (위 파라미터로 HMAC-MD5 한 값)

2. **SignedValue 검증**  
   - HASH KEY(Secret Manager 등에서 조회)로 동일 방식 HMAC-MD5 계산 후 비교.

3. **리워드 중복 방지**  
   - Firestore 등에 `rewardkey` 저장. 이미 존재하면 → `3100` (duplicate transaction) 반환.

4. **유저 검증**  
   - `usn`으로 `users` 컬렉션 문서 존재 여부 확인. 없으면 → `3200` (invalid user) 반환.

5. **코인 지급**  
   - 기존 `addCoins(uid, quantity, 'offerwall', 메시지)` 같은 함수로 지급.  
   - `coinHistory`에 `type: 'offerwall'`, 필요 시 `rewardkey`/`campaignkey` 저장.

6. **JSON 응답**  
   - 성공: `{"Result":true,"ResultCode":1,"ResultMsg":"success"}`  
   - 실패: 위 표의 Result/ResultCode/ResultMsg에 맞게 반환.

---

## 6. Firebase Functions HTTP 엔드포인트

- 애드팝콘이 **우리 서버를 호출**해야 하므로 **Callable(onCall)** 이 아니라 **HTTP(onRequest)** 로 만들어야 합니다.
- URL 예:  
  `https://us-central1-<프로젝트ID>.cloudfunctions.net/adpopcornRewardCallback`
- 이 URL을 애드팝콘 관리자 **콜백 URL(스테이징/라이브)** 에 그대로 등록합니다.

---

## 7. Flutter 앱 (오퍼월 충전소)

1. **패키지**  
   - `pubspec.yaml`에 `adpopcornreward: ^1.0.5` 추가 후 `flutter pub get`.

2. **앱 키·해시키 설정**  
   - `lib/config/adpopcorn_config.dart`에 애드팝콘 관리자에서 발급한 **앱 키(App Key)** 와 **해시키(Hash Key)** 를 입력.
   - `appKey`, `hashKey`가 비어 있으면 오퍼월 버튼은 노출되지 않음.

3. **초기화**  
   - `main.dart`에서 Firebase 초기화 직후 `AdPopcornReward.setAppKeyAndHashKey(appKey, hashKey)` 호출 (이미 연동됨).

4. **오퍼월 충전소 진입**  
   - 코인 모달(내 코인)에 "오퍼월 충전소" 버튼이 있음. 탭 시 `setUserId(Firebase UID)` 후 `openOfferwall()` 호출.
   - 오퍼월을 닫으면 코인 잔액·내역 자동 갱신.

5. **Android / iOS 네이티브 설정**  
   - 애드팝콘 [Flutter 연동 가이드](https://www.notion.so/adpopcorn/Flutter-1e7c968583f24484879784d106ab0084)에서 앱 키 등 네이티브 설정 필요 여부 확인.

6. **테스트**  
   - 스테이징 콜백 URL로 먼저 연동 후, 애드팝콘 관리자 화면의 **프로토콜 테스트**로 샘플 리워드가 우리 콜백으로 오는지 확인.

---

## 8. 체크리스트

- [ ] 애드팝콘 관리자: 콜백 URL(스테이징/라이브), 통신방식 GET, 보안 프로토콜 TLS 설정
- [ ] HASH KEY 발급·보관 (예: Firebase Secret Manager)
- [ ] Firebase Functions에 `adpopcornRewardCallback` 같은 HTTP(onRequest) 함수 추가
- [ ] 콜백에서 SignedValue 검증 → rewardKey 중복 체크 → 유저 검증 → addCoins → JSON 응답
- [ ] Firestore에 rewardKey 저장 (중복 방지)
- [ ] Flutter: 오퍼월 충전소 UI + SDK 초기화/오퍼월 오픈 시 Firebase UID 전달
- [ ] 프로토콜 테스트로 콜백 수신·응답 확인 후 라이브 전환

이 순서대로 진행하면 애드팝콘 오퍼월로 미션 완료 시 코인이 자동 지급되는 **오퍼월 충전소**를 구성할 수 있습니다.

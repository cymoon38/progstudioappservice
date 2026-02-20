# 그림 커뮤니티 Flutter 앱

웹 프로젝트를 Flutter로 포팅한 모바일 앱입니다.

## 주요 기능

- 로그인/회원가입
- 피드 (최신 작품)
- 인기작품
- 게시물 상세 (좋아요, 댓글)
- 작품 업로드
- 마이페이지
- 코인 시스템
- 알림 (추후 구현)

## 설정 방법

1. Flutter SDK 설치 확인
```bash
flutter --version
```

2. 의존성 설치
```bash
cd flutter_app
flutter pub get
```

3. Firebase 설정
- `lib/main.dart`의 Firebase 설정이 이미 포함되어 있습니다.
- Android/iOS 네이티브 설정은 별도로 필요합니다.

4. 실행
```bash
flutter run
```

## 다음 단계

- [ ] AdMob 광고 연동
- [ ] Google Play Billing (인앱결제) 연동
- [ ] 푸시 알림 설정
- [ ] 이미지 크롭 기능
- [ ] 검색 기능
- [ ] 미션/상점 화면




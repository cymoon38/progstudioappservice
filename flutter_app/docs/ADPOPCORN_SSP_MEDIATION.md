# 애드팝콘 SSP 미디에이션 연동 가이드

가이드: [Android 미디에이션](https://adpopcornssp.gitbook.io/ssp-sdk/android/android) / [iOS 미디에이션](https://adpopcornssp.gitbook.io/ssp-sdk/ios/undefined-12)

## Android (적용 완료)

- **`android/build.gradle`**: AdFit, Pangle, Cauly, Coupang, Mintegral 등 미디에이션 저장소 추가됨.
- **`android/app/build.gradle`**: AdMob(`play-services-ads:24.8.0`), AdFit(`ads-base:3.21.10`) 의존성 추가.  
  NAM, AppLovin, UnityAds, Vungle, FAN, Fyber, Mezzo, Cauly, Mintegral, Pangle, MobWith, Coupang 등은 주석으로 적어 두었으니 필요 시 주석 해제.
- **`AndroidManifest.xml`**: AdMob `APPLICATION_ID` 메타데이터 추가됨.  
  현재 **테스트 ID** 사용 중이므로, **상용 배포 시** AdMob 콘솔 또는 애드팝콘 사업팀에서 발급한 앱 ID로 교체해야 함.

애드팝콘 SSP `loadAd` 한 번으로 미디에이션에 연결된 네트워크 광고가 채워지며, 네이티브 광고 레이아웃은 `adpopcornssp_flutter` 플러그인 내부에서 처리됨.

### 전면 비디오 광고 (업로드 중 재생)

- **위치**: 작품 업로드 시 (`lib/widgets/upload_modal.dart`)
- **API**: `loadInterstitialVideo` → `showInterstitialVideo` ([Flutter 가이드](https://adpopcornssp.gitbook.io/ssp-sdk/flutter))
- **플레이스먼트**: SSP 콘솔에서 **전면 비디오** 형식으로 플레이스먼트를 생성한 뒤, `upload_modal.dart`의 `_kUploadInterstitialVideoPlacementId` 값을 해당 플레이스먼트 ID로 교체해야 함. (현재 `UPLOAD_VIDEO`는 placeholder)

---

## iOS (수동 작업 필요)

미디에이션을 쓰려면 **Adapter**를 다운로드해 프로젝트에 넣어야 함.

### 1) 미디에이션 Adapter 다운로드

- [iOS Mediation Adapter 최신 버전](https://github.com/IGAWorksDev/AdPopcornSDK/raw/refs/heads/master/AdPopcornSSP/02-ios-sdk/MediationAdapter/AdPopcornSSPMediationAdapter_260212.zip)  
- 이전 버전이 필요하면 [SDK·Mediation 호환성](https://adpopcornssp.gitbook.io/ssp-sdk/ios/undefined-12/sdk-mediation-ver) 에서 다운로드.

### 2) Adapter 추가

- 다운로드한 zip 압축 해제 후, 사용할 미디에이션 업체별 `.h`/`.m`(또는 framework) 파일을 Xcode **Runner** 타깃에 추가.

### 3) Bridge Header

- `Runner-Bridging-Header.h`에 각 업체 어댑터 헤더 추가.  
  예:  
  `#import "AdMobAdapter.h"`  
  (실제 파일 경로는 프로젝트 구조에 맞게 수정)

### 4) CocoaPods로 네트워크 SDK 추가

- `ios/Podfile`이 있다면(또는 `flutter pub get` 후 생성된 Podfile) Runner 타깃에 예시:
  ```ruby
  pod 'Google-Mobile-Ads-SDK'   # AdMob
  ```
- 그 다음 `ios` 폴더에서 `pod install` 실행.

### 5) AdMob 초기화 (이미 준비됨)

- `ios/Runner/Info.plist`: `GADApplicationIdentifier`, `SKAdNetworkItems` 추가됨(테스트 ID 기준).  
  상용 앱은 AdMob 앱 ID 및 필요한 SKAdNetwork ID로 교체.
- `ios/Runner/AppDelegate.swift`: AdMob 초기화 코드가 주석으로 들어가 있음.  
  Pod 및 Adapter 연동 후 다음을 **주석 해제**:
  - `import GoogleMobileAds`
  - `GADMobileAds.sharedInstance().start(completionHandler: nil)`

### 6) 네트워크별 추가 설정

- AdMob, FAN, NAM 등 각 네트워크별 **SkAdNetwork ID**, **초기화 코드**는 해당 가이드에 따라 앱에 직접 적용해야 함.  
  [iOS 미디에이션](https://adpopcornssp.gitbook.io/ssp-sdk/ios/undefined-12) 하단 “네트워크별 상세 설정” 링크 참고.

---

## 참고

- 미디에이션 연동 **전에** 애드팝콘 SSP 기본 연동이 되어 있어야 함.
- SSP 버전과 각 미디에이션 업체 **호환 버전**을 가이드에서 확인한 뒤 연동할 것.
- 상용 앱에서는 **테스트 ID**를 반드시 실제 앱/광고 ID로 교체할 것.

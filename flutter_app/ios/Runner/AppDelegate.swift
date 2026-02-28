import UIKit
import Flutter
// AdMob 미디에이션 사용 시 주석 해제 및 Podfile에 pod 'Google-Mobile-Ads-SDK' 추가
// import GoogleMobileAds

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // AdMob 미디에이션: Pod 및 Adapter 연동 후 주석 해제
    // GADMobileAds.sharedInstance().start(completionHandler: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

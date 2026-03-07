import 'package:flutter/services.dart';

/// 오퍼월 리워드/개인정보 동의 등 네이티브 API (MainActivity MethodChannel)
class OfferwallRewardService {
  static const _channel = MethodChannel('com.example.flutter_app/offerwall_reward');

  /// 가이드 개인정보 동의 처리 API. 오퍼월 사용 전 또는 앱에서 동의를 받은 후 호출.
  /// Android: Adpopcorn(Extension).setAgreePrivacy(agreed) 호출, iOS: 무시.
  static Future<void> setAgreePrivacy(bool agreed) async {
    try {
      await _channel.invokeMethod('setAgreePrivacy', {'agreed': agreed});
    } on PlatformException catch (_) {
      // iOS 등 미구현 플랫폼에서는 무시
    }
  }
}

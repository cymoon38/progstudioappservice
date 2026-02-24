/// 애드팝콘 오퍼월 SDK 설정
class AdPopcornConfig {
  static const String appKey = '719270341';
  static const String hashKey = 'f0914cb6664e4991';
  static bool get isConfigured => appKey.isNotEmpty && hashKey.isNotEmpty;
}

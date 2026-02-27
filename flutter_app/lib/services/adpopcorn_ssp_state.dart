import 'package:flutter/foundation.dart';

/// 네이티브 광고 로드 실패 시 앱 전역에서 공유 (MyApp MethodChannel 핸들러에서 설정)
final ValueNotifier<bool> adPopcornNativeAdLoadFailed = ValueNotifier(false);

import 'package:flutter/foundation.dart';

/// 네이티브 광고 로드 실패 시 앱 전역에서 공유 (MyApp MethodChannel 핸들러에서 설정)
final ValueNotifier<bool> adPopcornNativeAdLoadFailed = ValueNotifier(false);

/// 미션 페이지 상단 네이티브 광고(플레이스먼트 RBaJEGYiBLNXqNs) 로드 실패 시 공유
final ValueNotifier<bool> adPopcornMissionNativeAdLoadFailed = ValueNotifier(false);

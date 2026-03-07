import 'package:intl/intl.dart';

/// 코인 수를 만 단위로 표시 (만 단위는 내림, 예: 1000020 → "100만", 19999 → "1만", 9999 → "9,999")
String formatCoinsInMan(int value) {
  final absValue = value.abs();
  final sign = value < 0 ? '-' : '';
  if (absValue < 10000) {
    return '$sign${NumberFormat('#,###').format(absValue)}';
  }
  final man = (absValue / 10000).floor();
  return '$sign$man만';
}

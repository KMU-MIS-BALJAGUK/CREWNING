import 'dart:developer' as developer;
import 'package:flutter/material.dart';

/// 에러를 처리하여 화면에 스낵바로 표시하고 터미널(콘솔)에도 출력합니다.
void showError(BuildContext context, Object? error, {String? fallbackMessage}) {
  final message = (error == null) ? (fallbackMessage ?? '에러가 발생했습니다.') : error.toString();

  // 콘솔에 출력 (보다 안정적인 로그 남김)
  developer.log('Error: $message', level: 1000);
  // debugPrint도 함께 출력
  // ignore: avoid_print
  print('Error: $message');

  // UI로도 알림 표시
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

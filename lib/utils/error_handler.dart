import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 에러를 처리하여 화면에 스낵바로 표시하고 터미널(콘솔)에도 출력합니다.
void showError(BuildContext context, Object? error, {String? fallbackMessage}) {
  final message = (error == null) ? (fallbackMessage ?? '에러가 발생했습니다.') : error.toString();

  // 콘솔에 출력 (보다 안정적인 로그 남김)
  developer.log('Error: $message', level: 1000);
  // debugPrint도 함께 출력
  // ignore: avoid_print
  print('Error: $message');

  // ALREADY_PENDING 또는 이미 신청 관련 메시지라면 다이얼로그로 표시
  final lower = message.toLowerCase();
  final isAlreadyPending = lower.contains('already_pending') ||
      lower.contains('application already exists') ||
      lower.contains('이미 신청') ||
      lower.contains('already exists');

  if (context.mounted) {
    if (isAlreadyPending) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('신청 불가'),
          content: const Text('이미 신청 중인 크루가 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

void showSnackBarSafely(BuildContext context, SnackBar snack) {
  try {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(snack);
      } catch (_) {
        // context may be deactivated; ignore to avoid crash
      }
    });
  } catch (_) {
    // ignore
  }
}

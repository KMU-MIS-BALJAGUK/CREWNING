import 'package:flutter/material.dart';

import '../../../running/controllers/running_controller.dart';
import '../../../running/utils/formatters.dart';
import 'kakao_map_view.dart';
import 'running_stats_panel.dart';

class RunningFinishView extends StatelessWidget {
  const RunningFinishView({
    super.key,
    required this.controller,
    required this.kakaoKey,
    required this.onConfirm,
  });

  final RunningController controller;
  final String kakaoKey;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = controller.pendingRecord;
    final path = summary?.path.isNotEmpty == true
        ? summary!.path
        : controller.currentPath;

    // ignore: avoid_print
    print(
      '[RunningFinishView] summaryPath=${summary?.path.length ?? 0}, controllerPath=${controller.currentPath.length}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: KakaoMapView(
              kakaoJavascriptKey: kakaoKey,
              path: path,
              focus: path.lastOrNull,
              interactive: true,
              hideCurrentMarker: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RunningStatsPanel(
            distanceKm: controller.distanceKm,
            pace: controller.paceMinPerKm,
            duration: controller.elapsed,
            calories: controller.calories,
          ),
        ),
        if (summary?.startTime != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              formatDateTime(summary!.startTime),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: ElevatedButton(
            onPressed: controller.isSaving ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: controller.isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('확인'),
          ),
        ),
      ],
    );
  }
}

extension _ListExt<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

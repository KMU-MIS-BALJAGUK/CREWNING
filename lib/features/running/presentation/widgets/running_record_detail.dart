import 'package:flutter/material.dart';

import '../../../running/models/running_models.dart';
import '../../../running/utils/formatters.dart';
import 'kakao_map_view.dart';
import 'running_stats_panel.dart';

class RunningRecordDetailView extends StatelessWidget {
  const RunningRecordDetailView({
    super.key,
    required this.record,
    required this.kakaoKey,
  });

  final RunningRecordModel record;
  final String kakaoKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ignore: avoid_print
    print(
      '[RunningRecordDetailView] recordId=${record.recordId} pathLength=${record.path.length}',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('러닝 기록')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: KakaoMapView(
                kakaoJavascriptKey: kakaoKey,
                path: record.path,
                focus: record.path.lastOrNull,
                interactive: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: RunningStatsPanel(
              distanceKm: record.distanceKm,
              pace: record.paceMinPerKm,
              duration: record.duration,
              calories: record.calories,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시작: ${formatDateTime(record.startTime)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '종료: ${formatDateTime(record.endTime)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

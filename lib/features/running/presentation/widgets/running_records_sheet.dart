import 'package:flutter/material.dart';

import '../../../running/models/running_models.dart';
import '../../../running/utils/formatters.dart';

class RunningRecordsSheet extends StatelessWidget {
  const RunningRecordsSheet({
    super.key,
    required this.records,
    required this.loading,
    required this.onRefresh,
    required this.onRecordTap,
  });

  final List<RunningRecordModel> records;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<RunningRecordModel> onRecordTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '나의 러닝 기록',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                ? const Center(child: Text('아직 러닝 기록이 없습니다.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return _RunningRecordTile(
                        record: record,
                        onTap: () => onRecordTap(record),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RunningRecordTile extends StatelessWidget {
  const _RunningRecordTile({required this.record, required this.onTap});

  final RunningRecordModel record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDateTime(record.startTime),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RecordMetric(
                    label: '거리',
                    value: '${formatDistance(record.distanceKm)} km',
                  ),
                  _RecordMetric(
                    label: '평균 페이스',
                    value: formatPace(record.paceMinPerKm),
                  ),
                  _RecordMetric(
                    label: '시간',
                    value: formatDuration(record.duration),
                  ),
                  _RecordMetric(label: '칼로리', value: '${record.calories} kcal'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordMetric extends StatelessWidget {
  const _RecordMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

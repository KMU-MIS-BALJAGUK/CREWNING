import 'package:flutter/material.dart';

import '../../../running/utils/formatters.dart';

class RunningStatsPanel extends StatelessWidget {
  const RunningStatsPanel({
    super.key,
    required this.distanceKm,
    required this.pace,
    required this.duration,
    required this.calories,
  });

  final double distanceKm;
  final double pace;
  final Duration duration;
  final int calories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelColor = theme.colorScheme.surface.withValues(alpha: 0.92);
    return Card(
      elevation: 0,
      color: panelColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(label: '거리', value: '${formatDistance(distanceKm)} km'),
            _Divider(color: theme.colorScheme.outlineVariant),
            _StatItem(label: '평균 페이스', value: formatPace(pace)),
            _Divider(color: theme.colorScheme.outlineVariant),
            _StatItem(label: '시간', value: formatDuration(duration)),
            _Divider(color: theme.colorScheme.outlineVariant),
            _StatItem(label: '칼로리', value: '$calories kcal'),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
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

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1.5, height: 48, color: color);
  }
}

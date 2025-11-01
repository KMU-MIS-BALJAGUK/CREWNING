import 'package:intl/intl.dart';

String formatDistance(double distanceKm) {
  return distanceKm >= 100
      ? distanceKm.toStringAsFixed(1)
      : distanceKm.toStringAsFixed(2);
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String formatPace(double paceMinPerKm) {
  if (paceMinPerKm <= 0) {
    return '--\'--"';
  }
  final totalSeconds = (paceMinPerKm * 60).round();
  final minutes = (totalSeconds ~/ 60).toString();
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return "$minutes'$seconds\"";
}

String formatDateTime(DateTime? time) {
  if (time == null) return '-';
  return DateFormat('yyyy.MM.dd HH:mm').format(time.toLocal());
}

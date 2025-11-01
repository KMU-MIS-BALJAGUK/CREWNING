import 'dart:convert';

class RunningPathPoint {
  const RunningPathPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {'lat': latitude, 'lng': longitude};

  static RunningPathPoint fromJson(Map<String, dynamic> json) {
    return RunningPathPoint(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
    );
  }
}

class RunningRecordModel {
  const RunningRecordModel({
    required this.recordId,
    required this.userId,
    required this.distanceKm,
    required this.calories,
    required this.paceMinPerKm,
    required this.elapsedSeconds,
    required this.startTime,
    required this.endTime,
    required this.path,
  });

  final int recordId;
  final int userId;
  final double distanceKm;
  final int calories;
  final double paceMinPerKm;
  final int elapsedSeconds;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<RunningPathPoint> path;

  Duration get duration => Duration(seconds: elapsedSeconds);

  Map<String, dynamic> toInsertPayload() {
    return {
      'user_id': userId,
      'distance': distanceKm,
      'calories': calories,
      'pace': paceMinPerKm,
      'elapsed_seconds': elapsedSeconds,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'path': path.map((e) => e.toJson()).toList(),
    };
  }

  static RunningRecordModel fromMap(Map<String, dynamic> map) {
    final dynamic rawPath = map['path'];
    final List<RunningPathPoint> decodedPath;
    if (rawPath == null) {
      decodedPath = const [];
    } else if (rawPath is String) {
      decodedPath = (jsonDecode(rawPath) as List)
          .map((e) => RunningPathPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (rawPath is List) {
      decodedPath = rawPath
          .map((e) => RunningPathPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (rawPath is Map<String, dynamic>) {
      decodedPath = rawPath.values
          .map((e) => RunningPathPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      decodedPath = const [];
    }

    return RunningRecordModel(
      recordId: map['record_id'] as int,
      userId: map['user_id'] as int,
      distanceKm: (map['distance'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      paceMinPerKm: (map['pace'] as num?)?.toDouble() ?? 0,
      elapsedSeconds:
          (map['elapsed_seconds'] as num?)?.toInt() ??
          _durationSecondsFromTimes(
            map['start_time'] as String?,
            map['end_time'] as String?,
          ),
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'] as String)
          : null,
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'] as String)
          : null,
      path: decodedPath,
    );
  }

  RunningRecordModel copyWith({
    int? recordId,
    int? userId,
    double? distanceKm,
    int? calories,
    double? paceMinPerKm,
    int? elapsedSeconds,
    DateTime? startTime,
    DateTime? endTime,
    List<RunningPathPoint>? path,
  }) {
    return RunningRecordModel(
      recordId: recordId ?? this.recordId,
      userId: userId ?? this.userId,
      distanceKm: distanceKm ?? this.distanceKm,
      calories: calories ?? this.calories,
      paceMinPerKm: paceMinPerKm ?? this.paceMinPerKm,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      path: path ?? this.path,
    );
  }

  static int _durationSecondsFromTimes(String? start, String? end) {
    if (start == null || end == null) return 0;
    final startDt = DateTime.tryParse(start);
    final endDt = DateTime.tryParse(end);
    if (startDt == null || endDt == null) return 0;
    return endDt.difference(startDt).inSeconds;
  }
}

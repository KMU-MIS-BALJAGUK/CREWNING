import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/running_models.dart';

class RunningRepository {
  RunningRepository(this._client);

  final SupabaseClient _client;
  int? _cachedUserId;

  Future<int> _resolveUserId() async {
    if (_cachedUserId != null) {
      return _cachedUserId!;
    }
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final response = await _client
        .from('user')
        .select('user_id')
        .eq('auth_user_id', authUser.id)
        .maybeSingle();

    if (response == null) {
      throw StateError('유저 정보를 찾을 수 없습니다.');
    }

    final userId = response['user_id'] as int;
    _cachedUserId = userId;
    return userId;
  }

  Future<List<RunningRecordModel>> fetchRunningRecords() async {
    final userId = await _resolveUserId();
    final data = await _client
        .from('running_record')
        .select(
          'record_id, user_id, distance, calories, pace, elapsed_seconds, start_time, end_time, path',
        )
        .eq('user_id', userId)
        .order('start_time', ascending: false);

    return (data as List<dynamic>)
        .map(
          (item) => RunningRecordModel.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<RunningRecordModel> createRunningRecord({
    required double distanceKm,
    required int calories,
    required double paceMinPerKm,
    required Duration elapsed,
    required DateTime start,
    required DateTime end,
    required List<RunningPathPoint> path,
  }) async {
    final userId = await _resolveUserId();

    final payload = {
      'user_id': userId,
      'distance': distanceKm,
      'calories': calories,
      'pace': paceMinPerKm,
      'elapsed_seconds': elapsed.inSeconds,
      'start_time': start.toIso8601String(),
      'end_time': end.toIso8601String(),
      'path': path.map((p) => p.toJson()).toList(),
    };

    final response = await _client
        .from('running_record')
        .insert(payload)
        .select()
        .single();

    return RunningRecordModel.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }
}

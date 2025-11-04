import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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

    final safeDistance = distanceKm.isFinite ? distanceKm : 0.0;
    final safeCalories = math.min(math.max(calories, 0), 1000000);
    final safePace = paceMinPerKm.isFinite
        ? paceMinPerKm.clamp(0, 999.99).toDouble()
        : 0.0;

    final payload = {
      'user_id': userId,
      'distance': safeDistance,
      'calories': safeCalories,
      'pace': safePace,
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

    final savedMap = Map<String, dynamic>.from(response as Map);
    final saved = RunningRecordModel.fromMap(savedMap);

    // call set-start-area Edge Function to set start_area based on start coordinate
    try {
      if (path.isNotEmpty) {
        final startPoint = path.first;
        final authUid = _client.auth.currentUser?.id;
        if (authUid != null) {
          final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
          if (supabaseUrl.isNotEmpty) {
            final functionsUrl = supabaseUrl.replaceFirst('.supabase.co', '.functions.supabase.co') + '/set-start-area';
            final body = jsonEncode({
              'record_id': savedMap['record_id'] ?? saved.recordId,
              'lat': startPoint.latitude,
              'lng': startPoint.longitude,
              'caller_auth_uid': authUid,
            });
            final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
            final headersMap = <String, String>{'Content-Type': 'application/json'};
            if (anonKey != null && anonKey.isNotEmpty) {
              headersMap['Authorization'] = 'Bearer $anonKey';
              headersMap['apikey'] = anonKey;
            }

            final resp = await http.post(
              Uri.parse(functionsUrl),
              headers: headersMap,
              body: body,
            );
            // ignore failures but log for debugging
            // ignore: avoid_print
            print('set-start-area status=${resp.statusCode} body=${resp.body}');
          }
        }
      }
    } catch (e) {
      // ignore errors but log
      // ignore: avoid_print
      print('set-start-area error: $e');
    }

    return saved;
  }

  // Call this when a run finishes to compute score and update user totals.
  Future<void> finalizeRunningRecord({
    required int recordId,
    required double distanceKm,
    required int elapsedSeconds,
  }) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.isEmpty) return;

    final authUid = _client.auth.currentUser?.id;
    if (authUid == null) return;

    final finalizeUrl = supabaseUrl.replaceFirst('.supabase.co', '.functions.supabase.co') + '/finalize-running';
    final finalizeBody = jsonEncode({
      'record_id': recordId,
      'distance_m': (distanceKm * 1000).round(),
      'elapsed_s': elapsedSeconds,
      'caller_auth_uid': authUid,
    });

    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    final headersMap = <String, String>{'Content-Type': 'application/json'};
    if (anonKey != null && anonKey.isNotEmpty) {
      headersMap['Authorization'] = 'Bearer $anonKey';
      headersMap['apikey'] = anonKey;
    }

    try {
      final resp = await http.post(
        Uri.parse(finalizeUrl),
        headers: headersMap,
        body: finalizeBody,
      );
      // ignore failures but log for debugging
      // ignore: avoid_print
      print('finalize-running status=${resp.statusCode} body=${resp.body}');
    } catch (e) {
      // ignore but log
      // ignore: avoid_print
      print('finalize-running error: $e');
    }
  }
}

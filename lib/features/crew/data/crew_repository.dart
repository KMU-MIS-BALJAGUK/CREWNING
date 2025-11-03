import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/crew_models.dart';

class CrewRepository {
  CrewRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _weeklyRpc = 'get_weekly_crew_rankings';
  static const _totalRpc = 'get_total_crew_rankings';
  static const _summaryRpc = 'get_my_crew_summary';
  static const _overviewRpc = 'get_crew_overview';
  static const _membersRpc = 'get_crew_members';
  static const _createCrewRpc = 'create_crew';
  static const _logoBucket = 'crew-logos';

  Future<List<CrewRankingEntry>> fetchWeeklyRankings({
    int offset = 0,
    int limit = 100,
    String? weekId,
  }) async {
    final response = await _client.rpc(
      _weeklyRpc,
      params: {
        if (weekId != null) 'target_week': weekId,
        'fetch_limit': limit,
        'fetch_offset': offset,
      },
    );
    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map(mapWeeklyRanking).toList();
  }

  Future<List<CrewRankingEntry>> fetchTotalRankings({
    int offset = 0,
    int limit = 100,
  }) async {
    final response = await _client.rpc(
      _totalRpc,
      params: {
        'fetch_limit': limit,
        'fetch_offset': offset,
      },
    );
    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map(mapTotalRanking).toList();
  }

  Future<CrewSummary?> fetchMyCrewSummary({String? weekId}) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    final response = await _client.rpc(
      _summaryRpc,
      params: {
        'p_auth_user_id': authUser.id,
        if (weekId != null) 'target_week': weekId,
      },
    );
    if (response == null) return null;
    final list = (response as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return mapSummary(list.first);
  }

  Future<CrewSummary> fetchCrewOverview(int crewId, {String? weekId}) async {
    final response = await _client.rpc(
      _overviewRpc,
      params: {
        'p_crew_id': crewId,
        if (weekId != null) 'target_week': weekId,
      },
    );
    final list = (response as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      throw Exception('Crew overview not found');
    }
    return mapSummary(list.first)!;
  }

  Future<List<CrewMemberEntry>> fetchCrewMembers(int crewId) async {
    final authUser = _client.auth.currentUser;
    final response = await _client.rpc(
      _membersRpc,
      params: {'p_crew_id': crewId, 'p_auth_user_id': authUser?.id},
    );
    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map(mapMember).toList();
  }

  Future<List<AreaOption>> fetchAreas() async {
    final response = await _client.rpc('get_area_options');
    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map(mapArea).toList();
  }

  Future<CrewSummary> createCrew({
    required String crewName,
    required List<int> areaIds,
    String? introduction,
    String? logoUrl,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('로그인이 필요합니다.');
    }
    final response = await _client.rpc(
      _createCrewRpc,
      params: {
        'p_auth_user_id': authUser.id,
        'p_crew_name': crewName,
        'p_logo_url': logoUrl,
        'p_area_ids': areaIds.isEmpty ? null : areaIds,
        'p_introduction': introduction,
      },
    );
    final list = (response as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      throw Exception('크루 생성에 실패했습니다.');
    }
    final summary = mapSummary(list.first)!;
    return summary;
  }

  Future<String?> uploadCrewLogo(XFile file) async {
    final bytes = await file.readAsBytes();
    final extension = file.path.split('.').last.toLowerCase();
    final fileName =
        'crew_${DateTime.now().millisecondsSinceEpoch}.${extension.isEmpty ? 'jpg' : extension}';
    return uploadCrewLogoBytes(bytes, fileName, lookupMime(extension));
  }

  Future<String?> uploadCrewLogoBytes(
    Uint8List bytes,
    String fileName,
    String? contentType,
  ) async {
    final storage = _client.storage.from(_logoBucket);
    final path = 'logos/$fileName';
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: true,
        contentType: contentType,
      ),
    );
    return storage.getPublicUrl(path);
  }

  String? lookupMime(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  // 새로 추가: 현재 사용자를 크루에서 탈퇴시킴 (user.crew_id 를 null로 설정)
  Future<void> leaveCrew() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('로그인이 필요합니다.');
    }

    // 서버 사이드 leave_crew RPC를 호출합니다. 서버에서 리더/멤버 조건 및 크루 삭제를 처리합니다.
    final res = await _client.rpc('leave_crew', params: {
      'p_auth_user_id': authUser.id,
    });
    // Supabase RPC는 예외를 Throw하지 않고 에러 객체를 반환할 수 있으므로 응답 검사 필요 없음
    // 만약 에러가 발생하면 SDK가 예외를 던지므로 여기서는 별도 처리 불필요
    return;
  }

  Future<void> kickMember({
    required int crewId,
    required int targetUserId,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw Exception('로그인이 필요합니다.');
    await _client.rpc('kick_member', params: {
      'p_crew_id': crewId,
      'p_target_user_id': targetUserId,
      'p_auth_user_id': authUser.id,
    });
  }

  Future<void> delegateLeader({
    required int crewId,
    required int newLeaderUserId,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw Exception('로그인이 필요합니다.');
    await _client.rpc('delegate_leader', params: {
      'p_crew_id': crewId,
      'p_new_leader_user_id': newLeaderUserId,
      'p_auth_user_id': authUser.id,
    });
  }

  // Supabase local user lookup: auth_user_id (uuid) -> user_id (int)
  Future<int> _getLocalUserId(String authUserId) async {
    final res = await _client
        .from('user')
        .select('user_id')
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    if (res == null) {
      throw Exception('내부 사용자 정보를 찾을 수 없습니다. 프로필을 생성해 주세요.');
    }
    if (res is Map && res['user_id'] != null) {
      return (res['user_id'] as num).toInt();
    }
    throw Exception('내부 사용자 ID를 확인할 수 없습니다.');
  }

  /// 신청: Edge Function으로 신청 요청을 보냅니다.
  Future<bool> applyCrew({
    required int crewId,
    String? message,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw Exception('로그인이 필요합니다.');

    final session = _client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) throw Exception('로그인 세션이 필요합니다.');

    // 로그: auth uid 및 localUserId 매핑 시도는 남겨두되, Edge Function에 위임
    print('applyCrew - auth uid: ${authUser.id}');

    final uri = Uri.parse('https://uzteyczbmedsjqgrgega.supabase.co/functions/v1/apply-crew');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $token');

      final payload = {
        'crew_id': crewId,
        if (message != null) 'introduction': message,
      };
      final bodyStr = jsonEncode(payload);
      print('applyCrew - calling edge function with payload: $bodyStr');
      req.add(utf8.encode(bodyStr));

      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();
      print('applyCrew - edge response status: ${resp.statusCode}, body: $respBody');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return true;
      }

      // Edge Function이 이미 신청이 존재함을 JSON 바디로 반환하는 경우를 처리합니다.
      try {
        final parsed = jsonDecode(respBody);
        if (parsed is Map) {
          final err = parsed['error'];
          final application = parsed['application'];
          if ((err is String && err.contains('Application already exists')) ||
              (application is Map && application['status'] == 'pending')) {
            throw Exception('ALREADY_PENDING');
          }
        }
      } catch (_) {
        // 파싱 실패해도 무시하고 아래 처리로 넘어감
      }

      if (resp.statusCode == 409) {
        throw Exception('ALREADY_PENDING');
      }

      throw Exception('Edge function error: $respBody');
    } finally {
      client.close(force: true);
    }
  }

  // 현재 사용자의 대기중 신청 조회
  Future<Map<String, dynamic>?> fetchMyPendingApplication() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    try {
      final localUserId = await _getLocalUserId(authUser.id);
      final res = await _client
          .from('register')
          .select()
          .eq('user_id', localUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);
      if (res is List && res.isNotEmpty) return (res.first as Map<String, dynamic>);
      return null;
    } catch (_) {
      return null;
    }
  }

  // 대기중 신청 취소
  Future<bool> cancelApplication() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw Exception('로그인이 필요합니다.');
    try {
      final localUserId = await _getLocalUserId(authUser.id);
      final res = await _client
          .from('register')
          .delete()
          .match({'user_id': localUserId, 'status': 'pending'})
          .select();
      if (res is List && res.isNotEmpty) return true;
      return false;
    } catch (_) {
      return false;
    }
  }
}

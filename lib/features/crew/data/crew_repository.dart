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
    final response = await _client.rpc(
      _membersRpc,
      params: {'p_crew_id': crewId},
    );
    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map(mapMember).toList();
  }

  Future<List<AreaOption>> fetchAreas() async {
    final data = await _client
        .from('area')
        .select('area_id, name')
        .order('name')
        .limit(200);
    return (data as List<dynamic>)
        .map((e) => mapArea(Map<String, dynamic>.from(e as Map)))
        .toList();
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
}

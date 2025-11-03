class CrewRankingEntry {
  const CrewRankingEntry({
    required this.rank,
    required this.crewId,
    required this.crewName,
    required this.logoUrl,
    required this.memberCount,
    required this.score,
    this.totalScore = 0,
    this.weeklyScore = 0,
    this.isWeekly = true,
  });

  final int rank;
  final int crewId;
  final String crewName;
  final String? logoUrl;
  final int memberCount;
  final int score;
  final int totalScore;
  final num weeklyScore;
  final bool isWeekly;
}

class CrewSummary {
  const CrewSummary({
    required this.crewId,
    required this.crewName,
    required this.logoUrl,
    required this.memberCount,
    required this.maxMember,
    required this.weeklyScore,
    required this.weeklyRank,
    required this.totalScore,
    required this.totalRank,
    this.introduction,
  });

  final int crewId;
  final String crewName;
  final String? logoUrl;
  final int memberCount;
  final int maxMember;
  final num weeklyScore;
  final int? weeklyRank;
  final int totalScore;
  final int? totalRank;
  final String? introduction;

  bool get hasWeeklyScore => weeklyRank != null;
}

class CrewMemberEntry {
  const CrewMemberEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.isLeader,
    required this.isMyself,
    required this.weeklyScore,
    required this.totalScore,
  });

  final int rank;
  final int userId;
  final String userName;
  final bool isLeader;
  final bool isMyself;
  final int weeklyScore;
  final int totalScore;
}

class AreaOption {
  const AreaOption({
    required this.areaId,
    required this.name,
  });

  final int areaId;
  final String name;
}

CrewRankingEntry mapWeeklyRanking(Map<String, dynamic> data) {
  return CrewRankingEntry(
    rank: (data['rank'] as num).toInt(),
    crewId: (data['crew_id'] as num).toInt(),
    crewName: data['crew_name'] as String,
    logoUrl: data['logo_url'] as String?,
    memberCount: (data['member_count'] as num?)?.toInt() ?? 0,
    score: (data['weekly_score'] as num?)?.round() ?? 0,
    weeklyScore: data['weekly_score'] as num? ?? 0,
    totalScore: (data['total_score'] as num?)?.toInt() ?? 0,
    isWeekly: true,
  );
}

CrewRankingEntry mapTotalRanking(Map<String, dynamic> data) {
  final total = (data['total_score'] as num?)?.toInt() ?? 0;
  return CrewRankingEntry(
    rank: (data['rank'] as num).toInt(),
    crewId: (data['crew_id'] as num).toInt(),
    crewName: data['crew_name'] as String,
    logoUrl: data['logo_url'] as String?,
    memberCount: (data['member_count'] as num?)?.toInt() ?? 0,
    score: total,
    totalScore: total,
    weeklyScore: (data['weekly_score'] as num?) ?? 0,
    isWeekly: false,
  );
}

CrewSummary? mapSummary(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return null;
  return CrewSummary(
    crewId: (data['crew_id'] as num).toInt(),
    crewName: data['crew_name'] as String,
    logoUrl: data['logo_url'] as String?,
    memberCount: (data['member_count'] as num?)?.toInt() ?? 0,
    maxMember: (data['max_member'] as num?)?.toInt() ?? 20,
    weeklyScore: data['weekly_score'] as num? ?? 0,
    weeklyRank: (data['weekly_rank'] as num?)?.toInt(),
    totalScore: (data['total_score'] as num?)?.toInt() ?? 0,
    totalRank: (data['total_rank'] as num?)?.toInt(),
    introduction: data['introduction'] as String?,
  );
}

CrewMemberEntry mapMember(Map<String, dynamic> data) {
  return CrewMemberEntry(
    rank: (data['rank'] as num).toInt(),
    userId: (data['user_id'] as num).toInt(),
    userName: data['user_name'] as String,
    isLeader: data['is_leader'] as bool? ?? false,
    isMyself: data['is_myself'] as bool? ?? false,
    weeklyScore: (data['weekly_score'] as num?)?.toInt() ?? 0,
    totalScore: (data['total_score'] as num?)?.toInt() ?? 0,
  );
}

AreaOption mapArea(Map<String, dynamic> data) {
  return AreaOption(
    areaId: (data['area_id'] as num).toInt(),
    name: data['name'] as String,
  );
}

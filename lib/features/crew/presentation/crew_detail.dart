import 'package:flutter/material.dart';

import '../../crew/data/crew_repository.dart';
import '../../crew/models/crew_models.dart';
import 'crew_widgets.dart';
import 'package:crewning/utils/error_handler.dart';

Future<bool?> showCrewDetailDialog(
  BuildContext context, {
  required CrewRepository repository,
  required int crewId,
  required String crewName,
  required bool viewerHasCrew,
  AreaOption? initialArea,
  List<AreaOption>? areas,
}) {
  return showDialog<bool?>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withAlpha((0.7 * 255).round()),
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: _CrewDetailContent(
          repository: repository,
          crewId: crewId,
          crewName: crewName,
          viewerHasCrew: viewerHasCrew,
          initialArea: initialArea,
          areas: areas,
        ),
      );
    },
  );
}

class _CrewDetailContent extends StatefulWidget {
  const _CrewDetailContent({
    required this.repository,
    required this.crewId,
    required this.crewName,
    required this.viewerHasCrew,
    this.initialArea,
    this.areas,
  });

  final CrewRepository repository;
  final int crewId;
  final String crewName;
  final bool viewerHasCrew;
  final AreaOption? initialArea;
  final List<AreaOption>? areas;

  @override
  State<_CrewDetailContent> createState() => _CrewDetailContentState();
}

class _CrewDetailContentState extends State<_CrewDetailContent> {
  late Future<Map<String, dynamic>> _future;
  AreaOption? _selectedArea;
  List<AreaOption>? _areas;
  bool _areasLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedArea = widget.initialArea;
    _areas = widget.areas;
    _future = _load(areaName: _selectedArea?.name);
    if (_areas == null) {
      _loadAreas();
    }
  }

  Future<void> _loadAreas() async {
    setState(() {
      _areasLoading = true;
    });
    final previousAreaId = _selectedArea?.areaId;
    try {
      final areas = await widget.repository.fetchAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        if (_selectedArea != null) {
          final matched = areas.where((a) => a.areaId == _selectedArea!.areaId);
          _selectedArea = matched.isNotEmpty ? matched.first : null;
        }
        if (_selectedArea?.areaId != previousAreaId) {
          _future = _load(areaName: _selectedArea?.name);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _areasLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _load({String? areaName}) async {
    final trimmedArea = areaName?.trim();
    final areaParam = (trimmedArea == null || trimmedArea.isEmpty) ? null : trimmedArea;
    final overview = await widget.repository.fetchCrewOverview(
      crewId: widget.crewId,
      areaName: areaParam,
    );
    final members = await widget.repository.fetchCrewMembers(
      widget.crewId,
      areaName: areaParam,
    );
    return {
      'overview': overview,
      'members': members,
    };
  }

  void _changeArea(AreaOption? newArea) {
    if (_selectedArea?.areaId == newArea?.areaId) return;
    setState(() {
      _selectedArea = newArea;
      _future = _load(areaName: newArea?.name);
    });
  }

  Widget _buildAreaFilter(BuildContext context, ThemeData theme) {
    final options = _areas ?? const <AreaOption>[];
    final dropdownItems = <DropdownMenuItem<AreaOption?>>[
      const DropdownMenuItem<AreaOption?>(
        value: null,
        child: Text('전체 지역'),
      ),
      ...options.map(
        (area) => DropdownMenuItem<AreaOption?>(
          value: area,
          child: Text(area.name),
        ),
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.55;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AreaOption?>(
                      isExpanded: true,
                      value: _selectedArea,
                      hint: Text(
                        _areasLoading ? '지역 정보를 불러오는 중...' : '전체 지역',
                        style: theme.textTheme.bodyMedium,
                      ),
                      items: dropdownItems,
                      onChanged: _areasLoading ? null : _changeArea,
                    ),
                  ),
                ),
                if (_selectedArea != null)
                  IconButton(
                    tooltip: '지역 초기화',
                    icon: const Icon(Icons.close),
                    onPressed: _areasLoading ? null : () => _changeArea(null),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final areaFilter = _buildAreaFilter(context, theme);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Material(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '크루 정보를 불러오지 못했습니다.\n${snapshot.error}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final overview = snapshot.data!['overview'] as CrewSummary;
        final members = (snapshot.data!['members'] as List<CrewMemberEntry>).toList();
        final bool isViewerMember = members.any((m) => m.isMyself == true);
        // 뷰어가 현재 보고 있는 크루의 리더인지 여부
        final bool viewerIsLeader = members.any((m) => m.isMyself == true && m.isLeader == true);
        // 화면에 표시할 순위는 누적 점수(totalScore) 기준 내림차순으로 재계산
        final sortedMembers = [...members]..sort((a, b) => b.totalScore.compareTo(a.totalScore));
        return Material(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
           
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: theme.colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CrewLogo(
                            url: overview.logoUrl,
                            name: overview.crewName,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  overview.crewName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${overview.memberCount}/${overview.maxMember} 명',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '주간 ${overview.weeklyRank ?? '-'}위 · 점수 ${overview.weeklyScore}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '누적 ${overview.totalRank ?? '-'}위 · 점수 ${overview.totalScore}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      if (isViewerMember)
                        Positioned(
                          right: 0,
                          bottom: -6,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(44, 28),
                              side: const BorderSide(color: Colors.white, width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('크루 탈퇴'),
                                  content: const Text('크루를 정말 탈퇴하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('탈퇴'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              // 뷰어가 리더인 경우 추가 검사
                              final int memberCount = members.length;
                              final bool viewerIsLeaderLocal = viewerIsLeader;
                              if (viewerIsLeaderLocal) {
                                if (memberCount > 1) {
                                  // 리더이면서 다른 멤버가 있으면 위임 필요 안내
                                  if (!mounted) return;
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('리더 권한 필요'),
                                      content: const Text('다른 사람에게 리더를 위임해야합니다.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('확인'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                } else {
                                  // 리더이면서 본인만 남아있다면 크루 삭제 경고
                                  final proceed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('크루 삭제 안내'),
                                      content: const Text('크루내 남은 멤버가 없어 크루가 삭제됩니다. 탈퇴하시겠습니까?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: const Text('취소'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: const Text('탈퇴'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (proceed != true) return;
                                  try {
                                    await widget.repository.leaveCrew();
                                    if (!mounted) return;
                                    // show message before popping to avoid using a deactivated context
                                    showError(context, '크루 탈퇴 및 크루 삭제(예정) 처리되었습니다.');
                                    Navigator.of(context).pop(true);
                                  } catch (error) {
                                    if (!mounted) return;
                                    // 오류 처리: iOS에서 4xx는 UI에 표시하지 않고 로그로 대체
                                    // lib/utils/error_handler.showError 를 사용
                                    showError(context, '크루 탈퇴에 실패했습니다: $error');
                                  }
                                  return;
                                }
                              }
                              // 일반 멤버 탈퇴 흐름
                              try {
                                await widget.repository.leaveCrew();
                                if (!mounted) return;
                                // show message before popping to avoid deactivated context
                                showError(context, '크루 탈퇴가 완료되었습니다.');
                                Navigator.of(context).pop(true);
                              } catch (error) {
                                if (!mounted) return;
                                // 오류 처리: iOS에서 4xx는 UI에 표시하지 않고 로그로 대체
                                // lib/utils/error_handler.showError 를 사용
                                showError(context, '크루 탈퇴에 실패했습니다: $error');
                              }
                            },
                            child: const Text('탈퇴', style: TextStyle(color: Colors.white)),
                          ),
                        )
                      else
                        Positioned(
                          right: 0,
                          bottom: -6,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(44, 28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () async {
                              if (widget.viewerHasCrew) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('신청 불가'),
                                    content: const Text('이미 크루에 소속되어 있습니다.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('확인'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              // 가입 신청 모달 표시
                              final msg = await showDialog<String?>(
                                context: context,
                                builder: (ctx) => _ApplyCrewDialog(),
                              );
                              if (msg == null) return;
                              try {
                                final success = await widget.repository.applyCrew(crewId: overview.crewId, message: msg);
                                if (!mounted) return;
                                if (success) {
                                  // 신청이 성공하면 이 다이얼로그를 닫고 부모에게 변경 사실을 알립니다.
                                  Navigator.of(context).pop(true);
                                } else {
                                  showError(context, '가입 신청이 전송되었으나, 서버에 기록이 확인되지 않았습니다.');
                                }
                              } on Exception catch (e) {
                                if (!mounted) return;
                                if (e.toString().contains('ALREADY_PENDING')) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('신청 불가'),
                                      content: const Text('이미 신청 중인 크루가 있습니다.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('확인'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  showError(context, '가입 신청에 실패했습니다: $e');
                                }
                              } catch (e) {
                                if (!mounted) return;
                                showError(context, '가입 신청에 실패했습니다: $e');
                              }
                            },
                            child: const Text('가입 신청하기'),
                          ),
                      ),
                    ],
                  ),
                ),
                areaFilter,
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: sortedMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = sortedMembers[index];
                      final displayRank = index + 1; // 1-based rank by totalScore desc
                      return Row(
                        children: [
                          Expanded(child: _CrewMemberTile(member: member, repository: widget.repository, crewId: widget.crewId, viewerIsLeader: viewerIsLeader, displayRank: displayRank)),
                          if (member.isLeader == false) Container(),
                          // 실제 표시 로직은 아래에서 대체
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CrewMemberTile extends StatelessWidget {
  const _CrewMemberTile({required this.member, required this.repository, required this.crewId, required this.viewerIsLeader, required this.displayRank});

  final CrewMemberEntry member;
  final CrewRepository repository;
  final int crewId;
  final bool viewerIsLeader;
  final int displayRank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLeader = member.isLeader;
    return Container(
      decoration: BoxDecoration(
        color: isLeader
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLeader
              ? theme.colorScheme.primary.withAlpha((0.6 * 255).round())
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#${displayRank}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        member.userName,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (member.isMyself == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '나',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      if (member.isLeader)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '리더',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '주간 ${member.weeklyScore}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '누적 ${member.totalScore}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 팝업 메뉴는 해당 크루의 뷰어가 리더일 때만 표시
            if (!isLeader && viewerIsLeader)
              PopupMenuButton(
                icon: const Icon(Icons.more_horiz),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delegate',
                    child: Row(
                      children: const [
                        Icon(Icons.person_add, size: 16),
                        SizedBox(width: 8),
                        Text('리더로 위임하기'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'kick',
                    child: Row(
                      children: const [
                        Icon(Icons.remove_circle, size: 16),
                        SizedBox(width: 8),
                        Text('방출하기'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'delegate') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('리더 위임'),
                        content: const Text('이 멤버에게 리더 권한을 위임하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('위임'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await repository.delegateLeader(crewId: crewId, newLeaderUserId: member.userId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('리더 권한이 위임되었습니다.')),
                        );
                        print('리더 권한이 위임되었습니다.');
                        // 성공 시 부모에게 변경이 발생했음을 알림
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('리더 위임에 실패했습니다: $error')),
                        );
                        print('리더 위임에 실패했습니다: $error');
                      }
                    }
                  } else if (value == 'kick') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('멤버 방출'),
                        content: const Text('이 멤버를 크루에서 방출하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('방출'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await repository.kickMember(crewId: crewId, targetUserId: member.userId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('멤버가 방출되었습니다.')),
                        );
                        print('멤버가 방출되었습니다.');
                        // 성공 시 부모에게 변경이 발생했음을 알림
                        Navigator.of(context).pop(true);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('멤버 방출에 실패했습니다: $error')),
                        );
                        print('멤버 방출에 실패했습니다: $error');
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ApplyCrewDialog extends StatefulWidget {
  @override
  State<_ApplyCrewDialog> createState() => _ApplyCrewDialogState();
}

class _ApplyCrewDialogState extends State<_ApplyCrewDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('가입 신청'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: '신청글 (필수 - 최대 30자)',
        ),
        maxLines: 3,
        maxLength: 30,
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() {
                    _submitting = true;
                  });
                  // 폼 닫으면서 메시지 반환
                  final msg = _controller.text.trim();
                  Navigator.of(context).pop(msg.isEmpty ? null : msg);
                },
          child: const Text('전송'),
        ),
      ],
    );
  }
}

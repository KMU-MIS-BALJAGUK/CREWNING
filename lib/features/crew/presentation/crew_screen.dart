import 'dart:collection';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:crewning/utils/error_handler.dart';

import '../../crew/data/crew_repository.dart';
import '../../crew/models/crew_models.dart';
import 'crew_widgets.dart';
import 'create_crew_dialog.dart';
import 'crew_detail.dart';

class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen>
    with SingleTickerProviderStateMixin {
  final CrewRepository _repository = CrewRepository();
  late TabController _tabController;

  final ScrollController _weeklyController = ScrollController();
  final ScrollController _totalController = ScrollController();

  final List<CrewRankingEntry> _weeklyEntries = [];
  final List<CrewRankingEntry> _totalEntries = [];

  bool _weeklyLoading = false;
  bool _weeklyHasMore = true;
  bool _totalLoading = false;
  bool _totalHasMore = true;
  bool _initialLoading = true;
  bool _summaryLoading = true;
  Map<String, dynamic>? _pendingApplication;
  String? _pendingCrewName;

  CrewSummary? _myCrewSummary;
  List<AreaOption>? _areas;
  AreaOption? _selectedArea;
  bool _areasLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _weeklyController.addListener(_weeklyScrollListener);
    _totalController.addListener(_totalScrollListener);
    _loadInitial();
  }

  Widget _buildAreaFilter(BuildContext context, ThemeData theme) {
    final options = _areas ?? const <AreaOption>[];
    final items = <DropdownMenuItem<AreaOption?>>[
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
    final menuMaxHeight = MediaQuery.of(context).size.height * 0.45;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                Icon(
                  Icons.place_outlined,
                  color: theme.colorScheme.primary,
                ),
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
                      items: items,
                      menuMaxHeight: menuMaxHeight,
                      onChanged: _areasLoading
                          ? null
                          : (value) {
                              _changeArea(value);
                            },
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

  Widget _buildMyCrewCard() {
    if (_summaryLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_myCrewSummary != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: _PinnedCrewCard(
          summary: _myCrewSummary!,
          onTap: () => _openCrewDetail(
            _myCrewSummary!.crewId,
            _myCrewSummary!.crewName,
          ),
        ),
      );
    }

    if (_pendingApplication != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${_pendingCrewName ?? '크루'}에 신청 중입니다.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('신청 취소'),
                    content: const Text('정말 신청을 취소하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    final ok = await _repository.cancelApplication();
                    if (ok) {
                      if (!mounted) return;
                      showSnackBarSafely(
                        context,
                        const SnackBar(content: Text('신청이 취소되었습니다.')),
                      );
                      setState(() {
                        _pendingApplication = null;
                        _pendingCrewName = null;
                      });
                      await Future.wait([
                        _loadSummary(),
                        _loadWeekly(refresh: true),
                        _loadTotal(refresh: true),
                      ]);
                    } else {
                      throw Exception('취소 실패');
                    }
                  } catch (e) {
                    _showError(e);
                  }
                }
              },
              child: const Text('신청취소'),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Text(
        '크루에 참가하여 크루닝에 참가하세요',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildRankingHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAreaFilter(context, theme),
        _buildMyCrewCard(),
      ],
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _summaryLoading = true;
    });
    await Future.wait([
      _loadAreas(),
      _loadWeekly(refresh: true),
      _loadTotal(refresh: true),
      _loadSummary(),
      _loadPendingApplication(),
    ]);
    if (mounted) {
      setState(() {
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadAreas() async {
    setState(() {
      _areasLoading = true;
    });
    try {
      final areas = await _repository.fetchAreas();
      if (mounted) {
        setState(() {
          _areas = areas;
          if (_selectedArea != null) {
            AreaOption? matched;
            try {
              matched = areas.firstWhere(
                (element) => element.areaId == _selectedArea!.areaId,
              );
            } catch (_) {
              matched = null;
            }
            _selectedArea = matched;
          }
        });
      }
    } catch (error) {
      // 지역 목록 로딩은 치명적이지 않으므로 오류를 무시하고 계속 진행
    } finally {
      if (mounted) {
        setState(() {
          _areasLoading = false;
        });
      }
    }
  }

  Future<void> _changeArea(AreaOption? newArea) async {
    if (_selectedArea?.areaId == newArea?.areaId) {
      return;
    }
    setState(() {
      _selectedArea = newArea;
    });
    await Future.wait([
      _loadWeekly(refresh: true),
      _loadTotal(refresh: true),
    ]);
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _repository.fetchMyCrewSummary();
      setState(() {
        _myCrewSummary = summary;
        _summaryLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _summaryLoading = false;
      });
      _showError(error);
    }
  }

  Future<void> _loadWeekly({bool refresh = false}) async {
    if (_weeklyLoading) return;
    setState(() {
      _weeklyLoading = true;
      if (refresh) {
        _weeklyHasMore = true;
      }
    });
    try {
      final offset = refresh ? 0 : _weeklyEntries.length;
      final areaName = _selectedArea?.name.trim();
      final entries = await _repository.fetchWeeklyRankings(
        offset: offset,
        limit: 100,
        areaName: areaName?.isEmpty == true ? null : areaName,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _weeklyEntries
            ..clear()
            ..addAll(entries);
        } else {
          _weeklyEntries.addAll(entries);
        }
        _weeklyHasMore = entries.length == 100;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _weeklyLoading = false;
        });
      }
    }
  }

  Future<void> _loadTotal({bool refresh = false}) async {
    if (_totalLoading) return;
    setState(() {
      _totalLoading = true;
      if (refresh) {
        _totalHasMore = true;
      }
    });
    try {
      final offset = refresh ? 0 : _totalEntries.length;
      final areaName = _selectedArea?.name.trim();
      final entries = await _repository.fetchTotalRankings(
        offset: offset,
        limit: 100,
        areaName: areaName?.isEmpty == true ? null : areaName,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _totalEntries
            ..clear()
            ..addAll(entries);
        } else {
          _totalEntries.addAll(entries);
        }
        _totalHasMore = entries.length == 100;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _totalLoading = false;
        });
      }
    }
  }

  Future<void> _loadPendingApplication() async {
    try {
      final pending = await _repository.fetchMyPendingApplication();
      String? crewName;
      if (pending != null && pending['crew_id'] != null) {
        try {
          final summary = await _repository.fetchCrewOverview(
            crewId: pending['crew_id'] as int,
          );
          crewName = summary.crewName;
        } catch (_) {
          crewName = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _pendingApplication = pending;
        _pendingCrewName = crewName;
      });
    } catch (e) {
      // ignore silently
    }
  }

  void _weeklyScrollListener() {
    if (!_weeklyHasMore || _weeklyLoading) return;
    if (_weeklyController.position.pixels >=
        _weeklyController.position.maxScrollExtent - 200) {
      _loadWeekly();
    }
  }

  void _totalScrollListener() {
    if (!_totalHasMore || _totalLoading) return;
    if (_totalController.position.pixels >=
        _totalController.position.maxScrollExtent - 200) {
      _loadTotal();
    }
  }

  void _showError(Object error) {
    // 로그와 UI 알림을 모두 처리
    if (!mounted) return;
    showError(context, error);
  }

  Future<void> _showCreateDialog() async {
    // 이미 크루에 소속되어 있으면 생성 다이얼로그 대신 안내 알림을 띄움
    if (_myCrewSummary != null) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('알림'),
          content: const Text('이미 크루에 소속되어 있습니다. 먼저 크루를 탈퇴해주세요.'),
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

    _areas ??= await _repository.fetchAreas();
    if (!mounted) return;
    final summary = await showCrewCreateDialog(
      context,
      repository: _repository,
      areas: _areas!,
    );
    if (summary != null) {
      setState(() {
        _myCrewSummary = summary;
      });
      // 생성 후 요약·랭킹·대기신청을 모두 새로고침합니다.
      await Future.wait([
        _loadSummary(),
        _loadWeekly(refresh: true),
        _loadTotal(refresh: true),
        _loadPendingApplication(),
      ]);
    }
  }

  Future<void> _openCrewDetail(int crewId, String crewName) async {
    final changed = await showCrewDetailDialog(
      context,
      repository: _repository,
      crewId: crewId,
      crewName: crewName,
      viewerHasCrew: _myCrewSummary != null,
      initialArea: _selectedArea,
      areas: _areas,
    );
    if (changed == true) {
      if (!mounted) return;
      // 요약 및 랭킹 목록을 새로고침
      await Future.wait([
        _loadSummary(),
        _loadWeekly(refresh: true),
        _loadTotal(refresh: true),
      ]);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weeklyController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '위클리 랭킹'),
                Tab(text: '전체 랭킹'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RankingTabView(
                  controller: _weeklyController,
                  entries: _weeklyEntries,
                  loading: _weeklyLoading,
                  hasMore: _weeklyHasMore,
                  myCrew: _myCrewSummary,
                  isWeekly: true,
                  onRefresh: () async {
                    await Future.wait([
                      _loadWeekly(refresh: true),
                      _loadSummary(),
                    ]);
                  },
                  onTapCrew: _openCrewDetail,
                  header: _buildRankingHeader(context, theme),
                ),
                _RankingTabView(
                  controller: _totalController,
                  entries: _totalEntries,
                  loading: _totalLoading,
                  hasMore: _totalHasMore,
                  myCrew: _myCrewSummary,
                  isWeekly: false,
                  onRefresh: () async {
                    await Future.wait([
                      _loadTotal(refresh: true),
                      _loadSummary(),
                    ]);
                  },
                  onTapCrew: _openCrewDetail,
                  header: _buildRankingHeader(context, theme),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          // Show refresh FAB always. Show create FAB only if not in a crew.
          // If in crew and leader, show '신청자' FAB instead of create FAB.
          final bool inCrew = _myCrewSummary != null;
          // Avoid referencing leaderUserId on CrewSummary (model doesn't have that field).
          // Determine leadership when opening applicants via repository.fetchCrewMembers if needed.
          final bool viewerIsLeader = false;

          return Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(width: 16),
              FloatingActionButton(
                heroTag: 'refreshFab',
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () async {
                  try {
                    await _loadInitial();
                    if (!mounted) return;
                    showSnackBarSafely(context, const SnackBar(content: Text('새로고침 완료')));
                  } catch (e) {
                    _showError(e);
                  }
                },
                child: const Icon(Icons.refresh),
              ),
              const Spacer(),
              if (!inCrew) ...[
                FloatingActionButton.extended(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('크루 생성'),
                ),
              ] else ...[
                // If user is in a crew and leader, show applicants button. Otherwise show nothing.
                FloatingActionButton.extended(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => _ApplicantsDialog(repository: _repository, crewSummary: _myCrewSummary!),
                    );
                  },
                  icon: const Icon(Icons.person_search),
                  label: const Text('신청자'),
                ),
              ],
              const SizedBox(width: 16),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _RankingTabView extends StatelessWidget {
  const _RankingTabView({
    required this.controller,
    required this.entries,
    required this.loading,
    required this.hasMore,
    required this.myCrew,
    required this.isWeekly,
    required this.onRefresh,
    required this.onTapCrew,
    required this.header,
  });

  final ScrollController controller;
  final List<CrewRankingEntry> entries;
  final bool loading;
  final bool hasMore;
  final CrewSummary? myCrew;
  final bool isWeekly;
  final Future<void> Function() onRefresh;
  final void Function(int crewId, String crewName) onTapCrew;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final list = entries;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: list.length + 2 + (loading || hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return header;
          }
          final adjustedIndex = index - 1;
          if (adjustedIndex < list.length) {
            final entry = list[adjustedIndex];
            final isMyCrew = myCrew?.crewId == entry.crewId;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: CrewRankingCard(
                entry: entry,
                isWeekly: isWeekly,
                isMyCrew: isMyCrew,
                onTap: () => onTapCrew(entry.crewId, entry.crewName),
              ),
            );
          }
          if (hasMore || loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox(height: 80);
        },
      ),
    );
  }
}

class CrewRankingCard extends StatelessWidget {
  const CrewRankingCard({
    super.key,
    required this.entry,
    required this.isWeekly,
    required this.isMyCrew,
    required this.onTap,
  });

  final CrewRankingEntry entry;
  final bool isWeekly;
  final bool isMyCrew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isMyCrew
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final textColor = isMyCrew
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final score = isWeekly ? entry.score : entry.totalScore;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '#${entry.rank}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              CrewLogo(url: entry.logoUrl, name: entry.crewName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.crewName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.memberCount}/20 명',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor.withAlpha((0.8 * 255).round()),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isWeekly ? '주간 점수' : '누적 점수',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                  Text(
                    score.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedCrewCard extends StatelessWidget {
  const _PinnedCrewCard({
    required this.summary,
    required this.onTap,
  });

  final CrewSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined),
              const SizedBox(width: 12),
              CrewLogo(url: summary.logoUrl, name: summary.crewName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.crewName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.memberCount}/${summary.maxMember} 명',
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '주간 ${summary.weeklyRank ?? '-'}위',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '누적 ${summary.totalRank ?? '-'}위',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 위쪽에 있는 크루 로고, 생성 다이얼로그, 크루 상세화면 및 멤버 타일 관련 구현은
// 각각의 파일로 분리되었습니다:
// - crew_widgets.dart (크루 로고)
// - create_crew_dialog.dart (크루 생성 다이얼로그)
// - crew_detail.dart (크루 상세 및 멤버 타일)

class _ApplicantsDialog extends StatefulWidget {
  const _ApplicantsDialog({
    required this.repository,
    required this.crewSummary,
  });

  final CrewRepository repository;
  final CrewSummary crewSummary;

  @override
  State<_ApplicantsDialog> createState() => _ApplicantsDialogState();
}

class _ApplicantsDialogState extends State<_ApplicantsDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.fetchApplicants(widget.crewSummary.crewId);
      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('${widget.crewSummary.crewName} 신청자', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (!_loading)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final regId = item['register_id'] as int?;
                    final created = item['created_at']?.toString() ?? '';
                    final user = (item['user'] as Map<String, dynamic>?) ?? {};
                    final userName = user['name'] ?? '익명';
                    final intro = item['introduction']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: _ApplicantTile(
                        registerId: regId,
                        createdAt: created,
                        userName: userName,
                        introduction: intro,
                        onApprove: () async {
                          try {
                            await widget.repository.approveApplicant(regId!);
                            await _load();
                          } catch (e) {
                            showError(context, e);
                          }
                        },
                        onReject: () async {
                          try {
                            await widget.repository.rejectApplicant(regId!);
                            await _load();
                          } catch (e) {
                            showError(context, e);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantTile extends StatefulWidget {
  const _ApplicantTile({this.registerId, required this.createdAt, required this.userName, required this.introduction, required this.onApprove, required this.onReject});
  final int? registerId;
  final String createdAt;
  final String userName;
  final String introduction;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  State<_ApplicantTile> createState() => _ApplicantTileState();
}

class _ApplicantTileState extends State<_ApplicantTile> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final dateStr = widget.createdAt.isNotEmpty ? widget.createdAt.split('T').first.replaceAll('-', '/') : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('${dateStr}  ${widget.userName}')),
            IconButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ),
          ],
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(widget.introduction.isNotEmpty ? widget.introduction : '소개 없음'),
          ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () async => await widget.onApprove(),
              child: const Text('수락'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async => await widget.onReject(),
              child: const Text('거절'),
            ),
          ],
        ),
      ],
    );
  }
}

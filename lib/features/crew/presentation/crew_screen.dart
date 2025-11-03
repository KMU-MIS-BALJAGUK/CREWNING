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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _weeklyController.addListener(_weeklyScrollListener);
    _totalController.addListener(_totalScrollListener);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _summaryLoading = true;
    });
    await Future.wait([
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
      final entries = await _repository.fetchWeeklyRankings(
        offset: offset,
        limit: 100,
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
      final entries = await _repository.fetchTotalRankings(
        offset: offset,
        limit: 100,
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
          final summary = await _repository.fetchCrewOverview(pending['crew_id'] as int);
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
      await Future.wait([
        _loadWeekly(refresh: true),
        _loadTotal(refresh: true),
      ]);
    }
  }

  Future<void> _openCrewDetail(int crewId, String crewName) async {
    final changed = await showCrewDetailDialog(
      context,
      repository: _repository,
      crewId: crewId,
      crewName: crewName,
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

    final myCrewCard = _summaryLoading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        : _myCrewSummary != null
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _PinnedCrewCard(
                  summary: _myCrewSummary!,
                  onTap: () => _openCrewDetail(
                    _myCrewSummary!.crewId,
                    _myCrewSummary!.crewName,
                  ),
                ),
              )
            : (_pendingApplication != null)
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${_pendingCrewName ?? '크루'}에 신청 중입니다.',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신청이 취소되었습니다.')));
                                  setState(() {
                                    _pendingApplication = null;
                                    _pendingCrewName = null;
                                  });
                                  await Future.wait([_loadSummary(), _loadWeekly(refresh: true), _loadTotal(refresh: true)]);
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
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Text(
                      '크루에 참가하여 크루닝에 참가하세요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  );

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
                  header: myCrewCard,
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
                  header: myCrewCard,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('크루 생성'),
      ),
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
                      style: theme.textTheme.bodySmall,
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

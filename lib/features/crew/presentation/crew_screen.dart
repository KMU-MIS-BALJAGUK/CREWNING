import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../crew/data/crew_repository.dart';
import '../../crew/models/crew_models.dart';

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
    if (!mounted) return;
    final message = error.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showCreateDialog() async {
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
    await showCrewDetailDialog(
      context,
      repository: _repository,
      crewId: crewId,
      crewName: crewName,
    );
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
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Text(
                  '크루에 참가하여 크루닝에 참가하세요',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('크루'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '위클리 랭킹'),
            Tab(text: '전체 랭킹'),
          ],
        ),
      ),
      body: TabBarView(
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
              _CrewLogo(url: entry.logoUrl, name: entry.crewName),
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
              _CrewLogo(url: summary.logoUrl, name: summary.crewName),
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

class _CrewLogo extends StatelessWidget {
  const _CrewLogo({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(initials),
              )
            : _placeholder(initials),
      ),
    );
  }

  Widget _placeholder(String initials) {
    return Container(
      color: Colors.blueGrey.shade100,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}

Future<CrewSummary?> showCrewCreateDialog(
  BuildContext context, {
  required CrewRepository repository,
  required List<AreaOption> areas,
}) async {
  final picker = ImagePicker();
  String crewName = '';
  final Set<int> selectedAreaIds = {};
  String? introduction;
  XFile? selectedFile;
  Uint8List? previewBytes;
  bool submitting = false;

  Future<void> pickImage(StateSetter setState) async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        selectedFile = file;
        previewBytes = bytes;
      });
    }
  }

  final result = await showDialog<CrewSummary>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final isValid = crewName.trim().length >= 2 &&
              crewName.trim().length <= 10 &&
              selectedAreaIds.isNotEmpty;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '크루 생성',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: '크루명 (2~10자)',
                        ),
                        maxLength: 10,
                        onChanged: (value) {
                          setState(() {
                            crewName = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '크루 로고',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: submitting ? null : () => pickImage(setState),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: previewBytes != null
                                ? Image.memory(
                                    previewBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : const Text('이미지 선택'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '크루 활동 지역 (최대 3개)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: areas.map((area) {
                          final selected = selectedAreaIds.contains(area.areaId);
                          return ChoiceChip(
                            label: Text(area.name),
                            selected: selected,
                            onSelected: submitting
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value) {
                                        if (selectedAreaIds.length < 3) {
                                          selectedAreaIds.add(area.areaId);
                                        }
                                      } else {
                                        selectedAreaIds.remove(area.areaId);
                                      }
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        enabled: !submitting,
                        maxLines: null,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: '크루 한줄 소개 (선택)',
                        ),
                        onChanged: (value) {
                          setState(() {
                            introduction = value.isEmpty ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text('취소'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: !isValid || submitting
                                  ? null
                                  : () async {
                                      setState(() {
                                        submitting = true;
                                      });
                                      try {
                                        String? logoUrl;
                                        if (selectedFile != null) {
                                          logoUrl = await repository
                                              .uploadCrewLogo(selectedFile!);
                                        }
                                        final summary =
                                            await repository.createCrew(
                                          crewName: crewName.trim(),
                                          areaIds: (selectedAreaIds.toList()
                                            ..sort()),
                                          introduction: introduction,
                                          logoUrl: logoUrl,
                                        );
                                        if (context.mounted) {
                                          Navigator.of(context).pop(summary);
                                        }
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text(error.toString()),
                                          ),
                                        );
                                      } finally {
                                        if (context.mounted) {
                                          setState(() {
                                            submitting = false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: isValid
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                    : Colors.grey,
                              ),
                              child: submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('확인'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}

Future<void> showCrewDetailDialog(
  BuildContext context, {
  required CrewRepository repository,
  required int crewId,
  required String crewName,
}) {
  return showDialog<void>(
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
  });

  final CrewRepository repository;
  final int crewId;
  final String crewName;

  @override
  State<_CrewDetailContent> createState() => _CrewDetailContentState();
}

class _CrewDetailContentState extends State<_CrewDetailContent> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final overview = await widget.repository.fetchCrewOverview(widget.crewId);
    final members = await widget.repository.fetchCrewMembers(widget.crewId);
    return {
      'overview': overview,
      'members': members,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        final members =
            (snapshot.data!['members'] as List<CrewMemberEntry>).toList();
        return Material(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: min(MediaQuery.of(context).size.width * 0.9, 420),
            height: min(MediaQuery.of(context).size.height * 0.85, 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: theme.colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CrewLogo(
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
                ),
                if (overview.introduction != null &&
                    overview.introduction!.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Text(
                      overview.introduction!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return _CrewMemberTile(member: member);
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
  const _CrewMemberTile({required this.member});

  final CrewMemberEntry member;

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
                '#${member.rank}',
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
          ],
        ),
      ),
    );
  }
}

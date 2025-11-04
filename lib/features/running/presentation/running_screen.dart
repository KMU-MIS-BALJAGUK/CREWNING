import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../running/controllers/running_controller.dart';
import '../../running/data/running_repository.dart';
import '../../running/models/running_models.dart';
import 'widgets/kakao_map_view.dart';
import 'widgets/running_finish_view.dart';
import 'widgets/running_record_detail.dart';
import 'widgets/running_records_sheet.dart';
import 'widgets/running_stats_panel.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key, this.focusRequests});

  final ValueNotifier<int>? focusRequests;

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  late final RunningController _controller;
  Timer? _holdTimer;
  bool _stopTriggered = false;
  bool _initializing = true;
  String? _errorMessage;
  bool _mapInteractive = true;
  Future<void> Function()? _mapRefocus;
  ValueNotifier<int>? _focusRequests;
  int _lastProcessedFocusRequest = 0;
  bool _pendingCenterRequest = false;

  String get _kakaoKey =>
      dotenv.env['KAKAO_MAP_JAVASCRIPT_KEY'] ??
      dotenv.env['KAKAO_MAP_REST_API_KEY'] ??
      '';

  @override
  void initState() {
    super.initState();
    _controller = RunningController(
      RunningRepository(Supabase.instance.client),
    );
    _controller.addListener(_listener);
    _focusRequests = widget.focusRequests;
    _focusRequests?.addListener(_handleFocusRequests);
    final initialRequest = _focusRequests?.value ?? 0;
    _lastProcessedFocusRequest = initialRequest;
    if (initialRequest > 0) {
      _pendingCenterRequest = true;
    }
    _initialize();
  }

  @override
  void didUpdateWidget(covariant RunningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequests != widget.focusRequests) {
      oldWidget.focusRequests?.removeListener(_handleFocusRequests);
      _focusRequests = widget.focusRequests;
      _focusRequests?.addListener(_handleFocusRequests);
      final newValue = _focusRequests?.value;
      if (newValue != null && newValue > _lastProcessedFocusRequest) {
        _pendingCenterRequest = true;
      }
      _handleFocusRequests();
    }
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
    } catch (error) {
      _errorMessage = '러닝 기능을 초기화하지 못했습니다: $error';
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  void _listener() {
    if (mounted) {
      setState(() {});
      if (_pendingCenterRequest && _controller.currentLocation != null) {
        _triggerCenterOnUser();
      }
    }
  }

  @override
  void dispose() {
    _focusRequests?.removeListener(_handleFocusRequests);
    _holdTimer?.cancel();
    _controller.removeListener(_listener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }

    if (_controller.phase == RunningPhase.finished) {
      return Scaffold(
        body: SafeArea(
          child: RunningFinishView(
            controller: _controller,
            kakaoKey: _kakaoKey,
            onConfirm: () async {
              await _controller.confirmRun();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('러닝 기록이 저장되었습니다.')));
            },
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _controller.currentLocation == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: Colors.grey.shade300),
                  ),
                  Positioned.fill(
                    child: _kakaoKey.isEmpty
                        ? const Center(child: Text('카카오 맵 키가 설정되지 않았습니다.'))
                        : KakaoMapView(
                            kakaoJavascriptKey: _kakaoKey,
                            path: _controller.currentPath,
                            focus: _controller.currentLocation,
                            interactive: _mapInteractive,
                            fitPathToBounds: false,
                            autoCenter: false,
                            onReady: (refocus) {
                              if (!mounted) return;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                final previousRefocus = _mapRefocus;
                                _mapRefocus = refocus;
                                final shouldRefocus = _pendingCenterRequest &&
                                    _controller.currentLocation != null;
                                if (shouldRefocus) {
                                  _pendingCenterRequest = false;
                                  refocus();
                                }
                                if (previousRefocus != _mapRefocus) {
                                  setState(() {});
                                }
                              });
                            },
                          ),
                  ),
                  Positioned(
                    bottom: 120,
                    left: 20,
                    child: SafeArea(
                      child: Builder(
                        builder: (context) {
                          final canFocus = _controller.currentLocation != null;
                          return FloatingActionButton(
                            heroTag: 'running_map_focus',
                            backgroundColor: Colors.white,
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            mini: true,
                            tooltip: '내 위치로 이동',
                            onPressed: canFocus ? _triggerCenterOnUser : null,
                            child: const Icon(Icons.my_location),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: _RecordsButton(onTap: _openRecordsSheet),
                  ),
                  if (_controller.phase == RunningPhase.running ||
                      _controller.phase == RunningPhase.paused)
                    Positioned(
                      top: 120,
                      left: 20,
                      right: 20,
                      child: RunningStatsPanel(
                        distanceKm: _controller.distanceKm,
                        pace: _controller.paceMinPerKm,
                        duration: _controller.elapsed,
                        calories: _controller.calories,
                      ),
                    ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: _buildCenterControls(),
                  ),
                  if (_controller.phase == RunningPhase.countdown)
                    _CountdownOverlay(value: _controller.countdownValue),
                ],
              ),
      ),
    );
  }

  Widget _buildCenterControls() {
    switch (_controller.phase) {
      case RunningPhase.idle:
        return _PrimaryCircleButton(
          label: '시작',
          color: Colors.lightBlueAccent,
          onTap: _handleStartTap,
        );
      case RunningPhase.countdown:
        return const SizedBox.shrink();
      case RunningPhase.running:
        return _PrimaryCircleButton(
          label: '일시 정지',
          color: Colors.orangeAccent,
          onTap: _controller.pauseRun,
        );
      case RunningPhase.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SecondaryCircleButton(
              label: '종료',
              color: Colors.black87,
              onTap: _showHoldHint,
              onLongPressed: _handleHoldToStop,
              onLongPressCancel: _cancelHoldToStop,
            ),
            const SizedBox(width: 28),
            _PrimaryCircleButton(
              label: '재시작',
              color: Colors.lightBlueAccent,
              onTap: _controller.resumeRun,
              size: 88,
            ),
          ],
        );
      case RunningPhase.finished:
        return const SizedBox.shrink();
    }
  }

  void _handleHoldToStop() {
    _holdTimer?.cancel();
    _stopTriggered = false;
    _holdTimer = Timer(const Duration(seconds: 1), () async {
      _holdTimer?.cancel();
      _holdTimer = null;
      _stopTriggered = true;
      await _controller.stopRun();
    });
  }

  void _cancelHoldToStop() {
    final hadTimer = _holdTimer != null;
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!_stopTriggered && hadTimer) {
      _showHoldHint();
    }
  }

  void _showHoldHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('종료 버튼을 길게 눌러 운동을 종료합니다.')),
    );
  }

  void _handleFocusRequests() {
    final notifier = _focusRequests;
    if (notifier == null) return;
    final currentValue = notifier.value;
    if (currentValue == _lastProcessedFocusRequest) return;
    _lastProcessedFocusRequest = currentValue;
    _triggerCenterOnUser();
  }

  void _triggerCenterOnUser() {
    final refocus = _mapRefocus;
    final hasLocation = _controller.currentLocation != null;
    if (refocus != null && hasLocation) {
      _pendingCenterRequest = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await refocus();
      });
    } else {
      _pendingCenterRequest = true;
    }
  }

  Future<void> _openRecordsSheet() async {
    if (mounted) {
      setState(() => _mapInteractive = false);
    }
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return RunningRecordsSheet(
            records: _controller.records,
            loading: _controller.recordsLoading,
            onRefresh: () async {
              await _controller.refreshRecords();
              if (context.mounted) {
                Navigator.of(context).pop();
                _openRecordsSheet();
              }
            },
            onRecordTap: (record) {
              Navigator.of(context).pop();
              _openRecordDetail(record);
            },
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _mapInteractive = true);
      }
    }
  }

  Future<void> _openRecordDetail(RunningRecordModel record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RunningRecordDetailView(record: record, kakaoKey: _kakaoKey),
      ),
    );
  }

  Future<void> _handleStartTap() async {
    try {
      await _controller.startRun();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _RecordsButton extends StatelessWidget {
  const _RecordsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.history),
      label: const Text('나의 기록'),
    );
  }
}

class _PrimaryCircleButton extends StatelessWidget {
  const _PrimaryCircleButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 120,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryCircleButton extends StatelessWidget {
  const _SecondaryCircleButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.onLongPressed,
    required this.onLongPressCancel,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPressed;
  final VoidCallback onLongPressCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onLongPressed(),
      onLongPressEnd: (_) => onLongPressCancel(),
      onTapDown: (_) {},
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 96,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

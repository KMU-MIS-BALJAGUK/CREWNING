import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/running_repository.dart';
import '../models/running_models.dart';

enum RunningPhase { idle, countdown, running, paused, finished }

class RunningController extends ChangeNotifier {
  RunningController(this._repository);

  final RunningRepository _repository;

  RunningPhase phase = RunningPhase.idle;
  int _countdownValue = 3;
  Duration _elapsed = Duration.zero;
  double _distanceMeters = 0;
  int _calories = 0;
  double _paceMinPerKm = 0;

  DateTime? _startTime;
  DateTime? _endTime;
  Timer? _countdownTimer;
  Timer? _elapsedTimer;
  StreamSubscription<Position>? _positionSubscription;

  bool _isSaving = false;
  bool _recordsLoading = false;

  RunningRecordModel? _pendingRecord;
  RunningPathPoint? _currentLocation;
  final List<RunningPathPoint> _path = [];
  final List<RunningRecordModel> _records = [];

  int get countdownValue => _countdownValue;
  Duration get elapsed => _elapsed;
  double get distanceKm => _distanceMeters / 1000;
  int get calories => _calories;
  double get paceMinPerKm => _paceMinPerKm;
  List<RunningPathPoint> get currentPath => List.unmodifiable(_path);
  RunningPathPoint? get currentLocation => _currentLocation;
  List<RunningRecordModel> get records => List.unmodifiable(_records);
  bool get recordsLoading => _recordsLoading;
  bool get isSaving => _isSaving;
  RunningRecordModel? get pendingRecord => _pendingRecord;

  Future<void> initialize() async {
    await _ensureLocationPermission();
    await _prefetchLocation();
    await refreshRecords();
  }

  Future<void> refreshRecords() async {
    try {
      _recordsLoading = true;
      notifyListeners();
      final fetched = await _repository.fetchRunningRecords();
      _records
        ..clear()
        ..addAll(fetched);
    } finally {
      _recordsLoading = false;
      notifyListeners();
    }
  }

  Future<void> startRun() async {
    if (phase != RunningPhase.idle) return;
    if (!await _ensureLocationPermission()) {
      throw StateError('위치 권한이 필요합니다.');
    }

    phase = RunningPhase.countdown;
    _countdownValue = 3;
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (
      Timer timer,
    ) async {
      if (_countdownValue <= 1) {
        timer.cancel();
        await _beginRun();
      } else {
        _countdownValue -= 1;
        notifyListeners();
      }
    });
  }

  Future<void> pauseRun() async {
    if (phase != RunningPhase.running) return;
    phase = RunningPhase.paused;
    await _stopTracking();
    notifyListeners();
  }

  Future<void> resumeRun() async {
    if (phase != RunningPhase.paused) return;
    await _startTracking();
    phase = RunningPhase.running;
    notifyListeners();
  }

  Future<void> stopRun() async {
    if (phase != RunningPhase.running && phase != RunningPhase.paused) {
      return;
    }
    await _stopTracking();
    _endTime = DateTime.now();
    phase = RunningPhase.finished;
    _pendingRecord = RunningRecordModel(
      recordId: -1,
      userId: -1,
      distanceKm: distanceKm,
      calories: calories,
      paceMinPerKm: paceMinPerKm,
      elapsedSeconds: elapsed.inSeconds,
      startTime: _startTime,
      endTime: _endTime,
      path: List.of(_path),
    );
    notifyListeners();
  }

  Future<void> cancelRun() async {
    await _stopTracking();
    _reset();
    notifyListeners();
  }

  Future<void> confirmRun() async {
    if (_pendingRecord == null || _startTime == null || _endTime == null) {
      return;
    }
    _isSaving = true;
    notifyListeners();
    try {
      final saved = await _repository.createRunningRecord(
        distanceKm: distanceKm,
        calories: calories,
        paceMinPerKm: paceMinPerKm,
        elapsed: elapsed,
        start: _startTime!,
        end: _endTime!,
        path: List.of(_path),
      );
      _records.insert(0, saved);
      _reset();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void selectRecord(RunningRecordModel record) {
    _pendingRecord = record;
    notifyListeners();
  }

  void clearSelectedRecord() {
    _pendingRecord = null;
    notifyListeners();
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _prefetchLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _currentLocation = RunningPathPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      notifyListeners();
    } catch (_) {
      // ignore errors during warm-up
    }
  }

  Future<void> _beginRun() async {
    _path.clear();
    _distanceMeters = 0;
    _calories = 0;
    _paceMinPerKm = 0;
    _elapsed = Duration.zero;
    _startTime = DateTime.now();
    _endTime = null;
    _pendingRecord = null;

    await _startTracking();
    phase = RunningPhase.running;
    notifyListeners();
  }

  Future<void> _startTracking() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateElapsed(),
    );

    final initial = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    _addPosition(initial);

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 4,
      ),
    ).listen(_addPosition);
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _addPosition(Position position) {
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return;
    }

    final point = RunningPathPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _currentLocation = point;

    if (_path.isNotEmpty) {
      final prev = _path.last;
      final segment = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        point.latitude,
        point.longitude,
      );
      if (!segment.isNaN && segment.isFinite) {
        // ignore noise when standing still
        if (segment < 1.0) {
          _distanceMeters += segment * 0.2;
        } else if (segment < 5.0) {
          _distanceMeters += segment * 0.6;
        } else if (segment < 50.0) {
          _distanceMeters += segment;
        } else if (_path.length > 1) {
          // big jump: treat as teleport and keep path but do not increase distance
        } else {
          // first segment can be large if GPS locks late; still add but clamp
          _distanceMeters += min(segment, 30.0);
        }
      }
    }

    _path.add(point);
    _updateDerivedMetrics();
    notifyListeners();
  }

  void _updateElapsed() {
    if (_startTime == null) return;
    _elapsed = DateTime.now().difference(_startTime!);
    _updateDerivedMetrics();
    notifyListeners();
  }

  void _updateDerivedMetrics() {
    _distanceMeters = max(_distanceMeters, 0);
    if (distanceKm < 0.05) {
      _paceMinPerKm = 0;
    } else {
      final km = distanceKm;
      _paceMinPerKm = (_elapsed.inSeconds / 60) / km;
      if (!_paceMinPerKm.isFinite || _paceMinPerKm < 0) {
        _paceMinPerKm = 0;
      }
      _paceMinPerKm = _paceMinPerKm.clamp(0, 999.99).toDouble();
    }
    _calories = (distanceKm * 60).round();
  }

  void _reset() {
    phase = RunningPhase.idle;
    _countdownValue = 3;
    _elapsed = Duration.zero;
    _distanceMeters = 0;
    _calories = 0;
    _paceMinPerKm = 0;
    _startTime = null;
    _endTime = null;
    _pendingRecord = null;
    _path.clear();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}

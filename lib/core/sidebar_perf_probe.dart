import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:pure_music/core/utils.dart';

/// 侧栏展开/收起时记下帧时间。
class SidebarPerfProbe {
  static final instance = SidebarPerfProbe._();
  SidebarPerfProbe._();

  static bool get _enabled => kDebugMode || kProfileMode;

  int _toggles = 0;
  int _frames = 0;
  int _jank = 0;
  int _totalMicros = 0;
  int _maxMicros = 0;
  int _maxAt = 0;
  final List<int> _jankAt = [];
  int _listenGen = 0;
  bool _listening = false;

  int get toggles => _toggles;

  void reset() {
    _stopListen();
    _toggles = 0;
    _frames = 0;
    _jank = 0;
    _totalMicros = 0;
    _maxMicros = 0;
    _maxAt = 0;
    _jankAt.clear();
    _listenGen++;
  }


  Map<String, Object?> snapshot() {
    final avgMs = _frames <= 0 ? 0.0 : (_totalMicros / _frames) / 1000;
    return {
      'toggles': _toggles,
      'frames': _frames,
      'avgFrameMs': double.parse(avgMs.toStringAsFixed(1)),
      'jank': _jank,
      'jankAt': List<int>.from(_jankAt),
      'maxFrameMs': double.parse((_maxMicros / 1000).toStringAsFixed(1)),
      'maxAt': _maxAt,
    };
  }

  void onToggleStarted({Duration listenFor = const Duration(milliseconds: 350)}) {
    if (!_enabled) return;
    _toggles++;
    _listenGen++;
    final gen = _listenGen;
    if (!_listening) {
      _listening = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
    Future<void>.delayed(listenFor, () {
      if (gen != _listenGen) return;
      _stopListen();
      writeReportIfRequested();
    });
  }

  void writeReportIfRequested() {
    final path = Platform.environment['PURE_MUSIC_SIDEBAR_PERF_REPORT'];
    if (path == null || path.isEmpty) return;
    try {
      File(path).writeAsStringSync('${jsonEncode(snapshot())}\n');
    } catch (error, trace) {
      log.app.warn(
        'legacy',
        '[perf] sidebar write report failed: $error',
        stackTrace: trace,
      );
    }
  }

  void _stopListen() {
    if (!_listening) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _listening = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final total = timing.buildDuration + timing.rasterDuration;
      _frames++;
      _totalMicros += total.inMicroseconds;
      if (total.inMicroseconds > _maxMicros) {
        _maxMicros = total.inMicroseconds;
        _maxAt = _toggles;
      }
      if (total > const Duration(milliseconds: 18)) {
        _jank++;
        _jankAt.add(_toggles);
      }
    }
  }
}

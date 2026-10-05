import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_music/core/paths.dart' as app_paths;
import 'package:pure_music/core/sidebar_perf_probe.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/audio_library.dart';

/// profile/debug 且编译了 PERF_AUTO_SIDEBAR_ROUND_TRIPS 时自动展开/收起侧栏。
class SidebarPerfAuto {
  static const roundTrips = int.fromEnvironment(
    'PERF_AUTO_SIDEBAR_ROUND_TRIPS',
    defaultValue: 0,
  );

  static bool get enabled => roundTrips > 0 && (kDebugMode || kProfileMode);

  static VoidCallback? _toggle;

  static void bindToggle(VoidCallback toggle) => _toggle = toggle;

  static void unbindToggle() => _toggle = null;

  static void schedule() {
    if (!enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_run());
    });
  }

  static Future<void> _run() async {
    final reportPath = Platform.environment['PURE_MUSIC_SIDEBAR_PERF_REPORT'];
    try {
      await _waitForRouter();
      await _waitForLibrary();
      _openAlbums();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await _waitForToggle();
      final width = _windowWidth();
      if (width <= 640) {
        await _fail('窗口太窄（${width.round()}px），侧栏是抽屉，没法测展开收起', reportPath);
        return;
      }
      const gap = Duration(
        milliseconds: int.fromEnvironment(
          'PERF_AUTO_SIDEBAR_GAP_MS',
          defaultValue: 500,
        ),
      );
      final probe = SidebarPerfProbe.instance;
      for (var i = 0; i < roundTrips * 2; i++) {
        probe.onToggleStarted();
        _toggle!.call();
        await Future<void>.delayed(gap);
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      probe.writeReportIfRequested();
      log.app.info(
        'legacy',
        '[perf] sidebar auto finished roundTrips=$roundTrips toggles=${probe.toggles}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      exit(0);
    } catch (error, trace) {
      log.app.error(
        'legacy',
        '[perf] sidebar auto failed: $error',
        stackTrace: trace,
      );
      await _fail('$error', reportPath);
    }
  }

  static void _openAlbums() {
    final ctx = routerKey.currentContext;
    if (ctx == null) return;
    GoRouter.of(ctx).go(app_paths.ALBUMS_PAGE);
  }

  static double _windowWidth() {
    final ctx = routerKey.currentContext;
    if (ctx == null) return 0;
    return MediaQuery.sizeOf(ctx).width;
  }

  static Future<void> _waitForRouter() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      if (routerKey.currentContext != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('路由还没起来');
  }

  static Future<void> _waitForLibrary() async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      if (AudioLibrary.instance.audioCollection.length >= 2) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (AudioLibrary.instance.audioCollection.length < 2) {
      throw StateError('曲库是空的，列表页没有内容');
    }
  }

  static Future<void> _waitForToggle() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      if (_toggle != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw StateError('侧栏还没挂上展开收起');
  }

  static Future<void> _fail(String reason, String? reportPath) async {
    if (reportPath != null && reportPath.isNotEmpty) {
      try {
        File(reportPath).writeAsStringSync(
          '${jsonEncode({'error': reason, 'toggles': SidebarPerfProbe.instance.toggles})}\n',
        );
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    exit(2);
  }
}

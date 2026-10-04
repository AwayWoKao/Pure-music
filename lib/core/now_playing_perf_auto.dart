import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_music/core/now_playing_perf_probe.dart';
import 'package:pure_music/core/paths.dart' as app_paths;
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/play_service/play_service.dart';

/// 仅 profile/debug 且编译进 PERF_AUTO_SONG_SWITCHES 时自动切歌，给脚本收数。
class NowPlayingPerfAuto {
  static const switchCount = int.fromEnvironment(
    'PERF_AUTO_SONG_SWITCHES',
    defaultValue: 0,
  );

  static bool get enabled => switchCount > 0 && (kDebugMode || kProfileMode);

  static void schedule() {
    if (!enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_run());
    });
  }

  static Future<void> _run() async {
    final reportPath = Platform.environment['PURE_MUSIC_PERF_REPORT'];
    try {
      await _waitForRouter();
      final playlist = await _waitForPlaylist();
      if (playlist.length < switchCount) {
        await _fail(
          '曲库只有 ${playlist.length} 首，不够切 $switchCount 首',
          reportPath,
        );
        return;
      }
      _openNowPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final playback = PlayService.instance.playbackService;
      playback.play(0, playlist);
      const gap = Duration(
        milliseconds: int.fromEnvironment(
          'PERF_AUTO_GAP_MS',
          defaultValue: 8000,
        ),
      );
      for (var i = 1; i < switchCount; i++) {
        await Future<void>.delayed(gap);
        playback.nextAudio();
      }
      await Future<void>.delayed(const Duration(seconds: 4));
      NowPlayingPerfProbe.instance.writeReportIfRequested();
      log.app.info('legacy', '[perf] auto finished switches=$switchCount');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      exit(0);
    } catch (error, trace) {
      log.app.error('legacy', '[perf] auto failed: $error', stackTrace: trace);
      await _fail('$error', reportPath);
    }
  }

  static void _openNowPlaying() {
    final ctx = routerKey.currentContext;
    if (ctx == null) return;
    GoRouter.of(ctx).go(app_paths.NOW_PLAYING_PAGE);
  }

  static Future<void> _waitForRouter() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      if (routerKey.currentContext != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('窗口还没起来');
  }

  static Future<List<Audio>> _waitForPlaylist() async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      final audios = AudioLibrary.instance.audioCollection;
      if (audios.length >= switchCount) return List<Audio>.of(audios);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return List<Audio>.of(AudioLibrary.instance.audioCollection);
  }

  static Future<void> _fail(String reason, String? reportPath) async {
    if (reportPath != null && reportPath.isNotEmpty) {
      try {
        File(reportPath).writeAsStringSync(
          '${jsonEncode({'error': reason, 'songChanges': NowPlayingPerfProbe.instance.songChanges})}\n',
        );
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    exit(2);
  }
}

import 'package:pure_music/core/cache.dart';
import 'package:pure_music/core/database.dart';
import 'package:pure_music/core/matcher.dart';
import 'package:pure_music/core/settings.dart';
import 'package:pure_music/core/theme.dart';
import 'package:pure_music/core/system_volume_service.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:pure_music/play_service/audio_echo_log_recorder.dart';
import 'package:pure_music/play_service/desktop_lyric_service.dart';
import 'package:pure_music/play_service/lyric_service.dart';
import 'package:pure_music/play_service/playback_service.dart';

export 'package:pure_music/play_service/playback_service.dart';

class PlayService {
  PlaybackService? _playbackService;
  LyricService? _lyricService;
  DesktopLyricService? _desktopLyricService;

  PlaybackService get playbackService =>
      _playbackService ??= PlaybackService(this);
  LyricService get lyricService => _lyricService ??= LyricService(this);
  DesktopLyricService get desktopLyricService =>
      _desktopLyricService ??= DesktopLyricService(this);

  PlayService._();

  static PlayService? _instance;
  static bool get isInitialized => _instance != null;
  static PlaybackService? get existingPlaybackService =>
      _instance?._playbackService;
  static DesktopLyricService? get existingDesktopLyricService =>
      _instance?._desktopLyricService;
  static bool get hasInitializedPlaybackSession =>
      _instance?._playbackService?.nowPlaying != null;

  static PlayService get instance {
    _instance ??= PlayService._();
    return _instance!;
  }

  bool get hasPlaybackSession => _playbackService?.nowPlaying != null;

  Future<void> close() async {
    await _closeDesktopLyric();
    await _stopEchoLog();
    LyricViewController.disposeIfInitialized();
    _disposeLyricService();
    await _closePlayback();
    ThemeProvider.instance.dispose();
    SystemVolumeService.instance.dispose();
    AlbumColorCache.instance.dispose();
    CoverImageCache.instance.dispose();
    AudioLibrary.instance.dispose();
    AppDb.instance.dispose();
    AppSettings.closeGithub();
    clearLyricCaches();
    _instance = null;
  }

  Future<void> _closeDesktopLyric() async {
    final desktopLyric = _desktopLyricService;
    if (desktopLyric == null) return;
    try {
      await desktopLyric.killDesktopLyric().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          log.app.warn('legacy', 'desktopLyricService.close timeout');
        },
      );
    } catch (e) {
      log.app.warn('legacy', 'desktopLyricService.close error: $e');
    }
  }

  Future<void> _stopEchoLog() async {
    try {
      await AudioEchoLogRecorder.instance.stop().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          log.app.warn('legacy', 'AudioEchoLogRecorder.stop timeout');
        },
      );
    } catch (e) {
      log.app.warn('legacy', 'AudioEchoLogRecorder.stop error: $e');
    }
  }

  void _disposeLyricService() {
    final lyric = _lyricService;
    if (lyric == null) return;
    try {
      lyric.dispose();
    } catch (e) {
      log.app.warn('legacy', 'lyricService.dispose error: $e');
    }
  }

  Future<void> _closePlayback() async {
    final playback = _playbackService;
    if (playback == null) return;
    try {
      await playback.close();
    } catch (e) {
      log.app.warn('legacy', 'playbackService.close error: $e');
    }
  }
}

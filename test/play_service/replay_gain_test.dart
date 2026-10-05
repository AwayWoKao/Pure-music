import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/play_service/playback_service.dart';
import 'package:pure_music/native/bass/bass_player.dart';

void main() {
  test('parses replaygain tags with or without dB', () {
    expect(PlaybackService.parseReplayGainDb('-6.32 dB'), -6.32);
    expect(PlaybackService.parseReplayGainDb('+1.5dB'), 1.5);
    expect(PlaybackService.parseReplayGainDb(' 0.0 '), 0.0);
    expect(PlaybackService.parseReplayGainDb(''), isNull);
    expect(PlaybackService.parseReplayGainDb('nope'), isNull);
  });

  test('track mode prefers track gain then album', () {
    expect(
      PlaybackService.selectReplayGainDb(
        mode: ReplayGainMode.track,
        trackGain: '-3.0 dB',
        albumGain: '-8.0 dB',
      ),
      -3.0,
    );
    expect(
      PlaybackService.selectReplayGainDb(
        mode: ReplayGainMode.track,
        trackGain: null,
        albumGain: '-8.0 dB',
      ),
      -8.0,
    );
  });

  test('album mode prefers album gain then track', () {
    expect(
      PlaybackService.selectReplayGainDb(
        mode: ReplayGainMode.album,
        trackGain: '-3.0 dB',
        albumGain: '-8.0 dB',
      ),
      -8.0,
    );
    expect(
      PlaybackService.selectReplayGainDb(
        mode: ReplayGainMode.album,
        trackGain: '-3.0 dB',
        albumGain: '',
      ),
      -3.0,
    );
  });

  test('skip leading silence only uses a short cached intro', () {
    expect(
      PlaybackService.skipLeadingSilenceSeekSeconds(
        audibleStartMs: 200,
        durationMs: 180000,
      ),
      isNull,
    );
    expect(
      PlaybackService.skipLeadingSilenceSeekSeconds(
        audibleStartMs: 1500,
        durationMs: 180000,
      ),
      1.5,
    );
    expect(
      PlaybackService.skipLeadingSilenceSeekSeconds(
        audibleStartMs: 40000,
        durationMs: 180000,
      ),
      isNull,
    );
  });

  test('parses audible start from analysis profile json', () {
    expect(
      PlaybackService.audibleStartMsFromProfileJson(
        '{"audible_start_ms":1200}',
      ),
      1200,
    );
    expect(PlaybackService.audibleStartMsFromProfileJson('nope'), isNull);
  });

  test('smart transition explanation uses existing plan modes', () {
    expect(
      PlaybackService.smartTransitionExplanation('silence_trim'),
      '已跳过尾部静音',
    );
    expect(PlaybackService.smartTransitionExplanation('unknown'), isNull);
  });

  test('midi path detection', () {
    expect(BassPlayer.isMidiPath(r'C:\song.mid'), isTrue);
    expect(BassPlayer.isMidiPath(r'C:\song.mp3'), isFalse);
  });
}

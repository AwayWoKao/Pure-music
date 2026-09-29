import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/native/bass/bass.dart' as bass;
import 'package:pure_music/native/bass/bass_player.dart';
import 'package:pure_music/play_service/playback_service.dart';

void main() {
  test('fade/gapless handled completion does not auto-advance', () {
    expect(
      PlaybackService.shouldAutoAdvanceOnCompleted(
        smartHandled: false,
        transitionHandled: true,
        currentState: PlayerState.stopped,
      ),
      isFalse,
    );
  });

  test('stale completed while already playing does not auto-advance', () {
    expect(
      PlaybackService.shouldAutoAdvanceOnCompleted(
        smartHandled: false,
        transitionHandled: false,
        currentState: PlayerState.playing,
      ),
      isFalse,
    );
  });

  test('unhandled completion still auto-advances', () {
    expect(
      PlaybackService.shouldAutoAdvanceOnCompleted(
        smartHandled: false,
        transitionHandled: false,
        currentState: PlayerState.stopped,
      ),
      isTrue,
    );
  });

  test('smart-handled completion does not auto-advance', () {
    expect(
      PlaybackService.shouldAutoAdvanceOnCompleted(
        smartHandled: true,
        transitionHandled: false,
        currentState: PlayerState.stopped,
      ),
      isFalse,
    );
  });

  test('max fade lead starts before the file ends', () {
    expect(
      BassPlayer.transitionTriggerLeadMs(
        crossfade: false,
        fadeOutMs: 10000,
        fadeInMs: 10000,
      ),
      10000 + BassPlayer.transitionEndMarginMs,
    );
    expect(
      BassPlayer.transitionTriggerLeadMs(
        crossfade: true,
        fadeOutMs: 0,
        fadeInMs: 0,
      ),
      1 + BassPlayer.transitionEndMarginMs,
    );
  });

  test('suppressed stop is not latched as an already-sent completion', () {
    expect(
      BassPlayer.playbackStateToEmit(
        lastNotified: PlayerState.playing,
        current: PlayerState.stopped,
        suppressCompletion: true,
      ),
      isNull,
    );
    expect(
      BassPlayer.playbackStateToEmit(
        lastNotified: PlayerState.playing,
        current: PlayerState.stopped,
        suppressCompletion: false,
      ),
      PlayerState.completed,
    );
  });

  test('fade cleanup keeps the live source and only restarts a stopped mixer', () {
    expect(
      BassPlayer.shouldReleaseFadedSource(
        handle: 7,
        currentHandle: 7,
        queuedHandle: null,
      ),
      isFalse,
    );
    expect(
      BassPlayer.shouldReleaseFadedSource(
        handle: 7,
        currentHandle: 8,
        queuedHandle: 9,
      ),
      isTrue,
    );
    expect(
      BassPlayer.shouldRestartStoppedMixer(bass.BASS_ACTIVE_STOPPED),
      isTrue,
    );
    expect(
      BassPlayer.shouldRestartStoppedMixer(bass.BASS_ACTIVE_PAUSED),
      isFalse,
    );
    expect(
      BassPlayer.shouldRestartStoppedMixer(bass.BASS_ACTIVE_PLAYING),
      isFalse,
    );
    expect(
      BassPlayer.shouldKeepLiveFadedSource(
        stillLive: true,
        scheduledGeneration: 4,
        currentGeneration: 4,
      ),
      isFalse,
    );
    expect(
      BassPlayer.shouldKeepLiveFadedSource(
        stillLive: true,
        scheduledGeneration: 4,
        currentGeneration: 5,
      ),
      isTrue,
    );
    expect(
      BassPlayer.shouldKeepLiveFadedSource(
        stillLive: false,
        scheduledGeneration: 4,
        currentGeneration: 5,
      ),
      isFalse,
    );
  });
}

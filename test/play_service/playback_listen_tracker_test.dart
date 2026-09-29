import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/play_service/playback_listen_tracker.dart';

void main() {
  test('tracks valid playback deltas and threshold state', () {
    final tracker = PlaybackListenTracker();
    tracker.reset(
      durationSec: 10,
      lastFmStartedAt: 100,
      lastFmThresholdMs: 9000,
    );

    expect(tracker.sessionToken, 1);
    expect(tracker.updatePosition(positionSec: 1, isPlaying: false), 0);
    expect(tracker.updatePosition(positionSec: 2, isPlaying: true), 1);
    expect(tracker.shouldRecordListen, isFalse);
    expect(tracker.shouldQueueScrobble, isFalse);

    for (var position = 3; position <= 10; position++) {
      tracker.updatePosition(positionSec: position.toDouble(), isPlaying: true);
    }

    expect(tracker.shouldRecordListen, isTrue);
    expect(tracker.shouldQueueScrobble, isTrue);
    expect(tracker.lastFmStartedAt, 100);

    tracker.markListenRecorded();
    tracker.markScrobbleQueued();
    expect(tracker.shouldRecordListen, isFalse);
    expect(tracker.shouldQueueScrobble, isFalse);
  });

  test('ignores invalid deltas but keeps the latest playback position', () {
    final tracker = PlaybackListenTracker();
    tracker.reset(
      durationSec: 120,
      lastFmStartedAt: 100,
      lastFmThresholdMs: -1,
    );

    expect(tracker.updatePosition(positionSec: 1, isPlaying: true), 1);
    expect(tracker.updatePosition(positionSec: 5, isPlaying: true), 0);
    expect(tracker.updatePosition(positionSec: 6, isPlaying: true), 1);
    expect(tracker.listenAccumulatedSec, 2);
  });
}

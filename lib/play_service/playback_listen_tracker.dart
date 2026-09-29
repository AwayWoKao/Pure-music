import 'dart:math' as math;

class PlaybackListenTracker {
  int _sessionToken = 0;
  double _listenAccumulatedSec = 0;
  double _lastPositionSec = 0;
  double _listenThresholdSec = 0;
  bool _listenRecorded = false;
  double _lastFmAccumulatedSec = 0;
  bool _lastFmQueued = false;
  int _lastFmStartedAt = 0;
  int _lastFmThresholdMs = -1;

  int get sessionToken => _sessionToken;
  double get listenAccumulatedSec => _listenAccumulatedSec;
  int get lastFmStartedAt => _lastFmStartedAt;

  bool get shouldRecordListen =>
      !_listenRecorded &&
      _listenThresholdSec > 0 &&
      _listenAccumulatedSec >= _listenThresholdSec;

  bool get shouldQueueScrobble =>
      !_lastFmQueued &&
      _lastFmThresholdMs >= 0 &&
      _lastFmAccumulatedSec * 1000 >= _lastFmThresholdMs;

  void reset({
    required double durationSec,
    required int lastFmStartedAt,
    required int lastFmThresholdMs,
  }) {
    _sessionToken++;
    _listenAccumulatedSec = 0;
    _lastPositionSec = 0;
    _listenRecorded = false;
    _listenThresholdSec = durationSec > 0
        ? math.min(60.0, 0.9 * durationSec)
        : 0;
    _lastFmAccumulatedSec = 0;
    _lastFmQueued = false;
    _lastFmStartedAt = lastFmStartedAt;
    _lastFmThresholdMs = lastFmThresholdMs;
  }

  double updatePosition({
    required double positionSec,
    required bool isPlaying,
  }) {
    if (!isPlaying) {
      _lastPositionSec = positionSec;
      return 0;
    }

    final delta = positionSec - _lastPositionSec;
    _lastPositionSec = positionSec;
    if (delta <= 0 || delta > 2.0) return 0;

    if (!_listenRecorded && _listenThresholdSec > 0) {
      _listenAccumulatedSec += delta;
    }
    _lastFmAccumulatedSec += delta;
    return delta;
  }

  void markListenRecorded() {
    _listenRecorded = true;
  }

  void markScrobbleQueued() {
    _lastFmQueued = true;
  }
}

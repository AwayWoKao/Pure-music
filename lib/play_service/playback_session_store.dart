import 'package:flutter/foundation.dart';
import 'package:pure_music/core/preference.dart';

class PlaybackSessionSnapshot {
  factory PlaybackSessionSnapshot({
    required String lastAudioPath,
    required List<String> lastPlaylistPaths,
    required int lastPlaylistIndex,
    required bool lastShuffleActive,
    required List<String> lastOriginalPlaylistPaths,
    required double lastPositionSeconds,
  }) => PlaybackSessionSnapshot._(
    lastAudioPath: lastAudioPath,
    lastPlaylistPaths: List.unmodifiable(lastPlaylistPaths),
    lastPlaylistIndex: lastPlaylistIndex,
    lastShuffleActive: lastShuffleActive,
    lastOriginalPlaylistPaths: List.unmodifiable(lastOriginalPlaylistPaths),
    lastPositionSeconds: lastPositionSeconds,
  );

  const PlaybackSessionSnapshot._({
    required this.lastAudioPath,
    required this.lastPlaylistPaths,
    required this.lastPlaylistIndex,
    required this.lastShuffleActive,
    required this.lastOriginalPlaylistPaths,
    required this.lastPositionSeconds,
  });

  static const empty = PlaybackSessionSnapshot._(
    lastAudioPath: '',
    lastPlaylistPaths: <String>[],
    lastPlaylistIndex: 0,
    lastShuffleActive: false,
    lastOriginalPlaylistPaths: <String>[],
    lastPositionSeconds: 0.0,
  );

  factory PlaybackSessionSnapshot.fromPreference(
    PlaybackPreference preference,
  ) {
    return PlaybackSessionSnapshot(
      lastAudioPath: preference.lastAudioPath,
      lastPlaylistPaths: List.unmodifiable(preference.lastPlaylistPaths),
      lastPlaylistIndex: preference.lastPlaylistIndex,
      lastShuffleActive: preference.lastShuffleActive,
      lastOriginalPlaylistPaths: List.unmodifiable(
        preference.lastOriginalPlaylistPaths,
      ),
      lastPositionSeconds: preference.lastPositionSeconds,
    );
  }

  final String lastAudioPath;
  final List<String> lastPlaylistPaths;
  final int lastPlaylistIndex;
  final bool lastShuffleActive;
  final List<String> lastOriginalPlaylistPaths;
  final double lastPositionSeconds;

  PlaybackSessionSnapshot copyWith({
    String? lastAudioPath,
    List<String>? lastPlaylistPaths,
    int? lastPlaylistIndex,
    bool? lastShuffleActive,
    List<String>? lastOriginalPlaylistPaths,
    double? lastPositionSeconds,
  }) {
    return PlaybackSessionSnapshot(
      lastAudioPath: lastAudioPath ?? this.lastAudioPath,
      lastPlaylistPaths: List.unmodifiable(
        lastPlaylistPaths ?? this.lastPlaylistPaths,
      ),
      lastPlaylistIndex: lastPlaylistIndex ?? this.lastPlaylistIndex,
      lastShuffleActive: lastShuffleActive ?? this.lastShuffleActive,
      lastOriginalPlaylistPaths: List.unmodifiable(
        lastOriginalPlaylistPaths ?? this.lastOriginalPlaylistPaths,
      ),
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
    );
  }

  void applyTo(PlaybackPreference preference) {
    preference
      ..lastAudioPath = lastAudioPath
      ..lastPlaylistPaths = List.of(lastPlaylistPaths)
      ..lastPlaylistIndex = lastPlaylistIndex
      ..lastShuffleActive = lastShuffleActive
      ..lastOriginalPlaylistPaths = List.of(lastOriginalPlaylistPaths)
      ..lastPositionSeconds = lastPositionSeconds;
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackSessionSnapshot &&
      lastAudioPath == other.lastAudioPath &&
      listEquals(lastPlaylistPaths, other.lastPlaylistPaths) &&
      lastPlaylistIndex == other.lastPlaylistIndex &&
      lastShuffleActive == other.lastShuffleActive &&
      listEquals(lastOriginalPlaylistPaths, other.lastOriginalPlaylistPaths) &&
      lastPositionSeconds == other.lastPositionSeconds;

  @override
  int get hashCode => Object.hash(
    lastAudioPath,
    Object.hashAll(lastPlaylistPaths),
    lastPlaylistIndex,
    lastShuffleActive,
    Object.hashAll(lastOriginalPlaylistPaths),
    lastPositionSeconds,
  );
}

class PlaybackSessionStore {
  PlaybackSessionStore({
    required PlaybackPreference preference,
    required Future<bool> Function() save,
  }) : _preference = preference,
       _save = save;

  final PlaybackPreference _preference;
  final Future<bool> Function() _save;

  PlaybackSessionSnapshot get snapshot =>
      PlaybackSessionSnapshot.fromPreference(_preference);

  Future<bool> save(PlaybackSessionSnapshot session) async {
    session.applyTo(_preference);
    return _save();
  }

  Future<bool> clear() => save(PlaybackSessionSnapshot.empty);
}

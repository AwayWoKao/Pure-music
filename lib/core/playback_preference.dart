part of 'preference.dart';

class PlaybackPreference {
  PlayMode playMode;
  double volumeDsp;
  List<double> eqGains;
  int eqBandModelVersion;
  bool eqEnabled;
  double eqPreampDb;
  bool eqAutoGainEnabled;
  double eqAutoHeadroomDb;
  List<EqPreset> eqPresets;
  AudioDspSettings audioDspSettings;
  String lastAudioPath;
  List<String> lastPlaylistPaths;
  int lastPlaylistIndex;
  bool lastShuffleActive;
  List<String> lastOriginalPlaylistPaths;
  double lastPositionSeconds;
  bool reinitOnSetSource;
  bool replayGainEnabled;
  TransitionMode transitionMode;
  int transitionFadeOutMs;
  int transitionFadeInMs;

  PlaybackPreference(
    this.playMode,
    this.volumeDsp,
    this.eqGains,
    this.eqPresets, {
    this.eqBandModelVersion = currentEqBandModelVersion,
    this.eqEnabled = true,
    this.audioDspSettings = const AudioDspSettings(),
    this.replayGainEnabled = false,
    this.eqPreampDb = 0.0,
    this.eqAutoGainEnabled = true,
    this.eqAutoHeadroomDb = 1.0,
    this.lastAudioPath = '',
    this.lastPlaylistPaths = const [],
    this.lastPlaylistIndex = 0,
    this.lastShuffleActive = false,
    this.lastOriginalPlaylistPaths = const [],
    this.lastPositionSeconds = 0.0,
    this.reinitOnSetSource = false,
    this.transitionMode = TransitionMode.seamless,
    this.transitionFadeOutMs = 300,
    this.transitionFadeInMs = 200,
  });

  Map<String, dynamic> toMap() => {
    'playMode': playMode.name,
    'volumeDsp': volumeDsp,
    'eqGains': eqGains,
    'eqBandModelVersion': currentEqBandModelVersion,
    'eqEnabled': eqEnabled,
    'eqPreampDb': eqPreampDb,
    'eqAutoGainEnabled': eqAutoGainEnabled,
    'eqAutoHeadroomDb': eqAutoHeadroomDb,
    'eqPresets': eqPresets.map((e) => e.toMap()).toList(),
    'audioDspSettings': audioDspSettings.toMap(),
    'lastAudioPath': lastAudioPath,
    'lastPlaylistPaths': lastPlaylistPaths,
    'lastPlaylistIndex': lastPlaylistIndex,
    'lastShuffleActive': lastShuffleActive,
    'lastOriginalPlaylistPaths': lastOriginalPlaylistPaths,
    'lastPositionSeconds': lastPositionSeconds,
    'reinitOnSetSource': reinitOnSetSource,
    'replayGainEnabled': replayGainEnabled,
    'transitionMode': transitionMode.name,
    'transitionFadeOutMs': transitionFadeOutMs,
    'transitionFadeInMs': transitionFadeInMs,
  };

  factory PlaybackPreference.fromMap(Object? value) {
    final map = value is Map ? value : const <String, dynamic>{};
    final lastPlaylistPaths = _normalizedPathStringList(
      map['lastPlaylistPaths'],
    );
    final lastPlaylistIndex = _normalizedBoundedInt(
      map['lastPlaylistIndex'],
      defaultValue: 0,
      min: 0,
      max: lastPlaylistPaths.isEmpty ? 0 : lastPlaylistPaths.length - 1,
    );
    final lastOriginalPlaylistPaths = _normalizedPathStringList(
      map['lastOriginalPlaylistPaths'],
    );
    final storedEqBandVersion = _normalizedBoundedInt(
      map['eqBandModelVersion'],
      defaultValue: legacyEqBandModelVersion,
      min: legacyEqBandModelVersion,
      max: currentEqBandModelVersion,
    );
    return PlaybackPreference(
      _playModeFromStoredValue(map['playMode']) ?? PlayMode.forward,
      _normalizedVolumeDsp(map['volumeDsp']),
      migrateEqGains(map['eqGains'], fromVersion: storedEqBandVersion),
      _eqPresetsFromStoredValue(map['eqPresets']),
      eqBandModelVersion: currentEqBandModelVersion,
      eqEnabled: _normalizedBool(map['eqEnabled'], defaultValue: true),
      audioDspSettings: AudioDspSettings.fromMap(map['audioDspSettings']),
      eqPreampDb: normalizedEqPreampDb(map['eqPreampDb']),
      eqAutoGainEnabled: _normalizedBool(
        map['eqAutoGainEnabled'],
        defaultValue: true,
      ),
      eqAutoHeadroomDb: _normalizedBoundedDouble(
        map['eqAutoHeadroomDb'],
        defaultValue: 1.0,
        min: 0.0,
        max: 24.0,
      ),
      lastAudioPath: _normalizedPathString(map['lastAudioPath']),
      lastPlaylistPaths: lastPlaylistPaths,
      lastPlaylistIndex: lastPlaylistIndex,
      lastShuffleActive: _normalizedBool(
        map['lastShuffleActive'],
        defaultValue: false,
      ),
      lastOriginalPlaylistPaths: lastOriginalPlaylistPaths,
      lastPositionSeconds: _normalizedBoundedDouble(
        map['lastPositionSeconds'],
        defaultValue: 0.0,
        min: 0.0,
        max: 24 * 60 * 60,
      ),
      reinitOnSetSource: _normalizedBool(
        map['reinitOnSetSource'],
        defaultValue: false,
      ),
      replayGainEnabled: _normalizedBool(
        map['replayGainEnabled'],
        defaultValue: false,
      ),
      transitionMode: _transitionModeFromStored(map),
      transitionFadeOutMs: _normalizedBoundedInt(
        map['transitionFadeOutMs'],
        defaultValue: 300,
        min: 0,
        max: 10000,
      ),
      transitionFadeInMs: _normalizedBoundedInt(
        map['transitionFadeInMs'],
        defaultValue: 200,
        min: 0,
        max: 10000,
      ),
    );
  }
}

class PlaybackPreferenceCodec {
  const PlaybackPreferenceCodec._();

  static PlaybackPreference decode(Object? value) =>
      PlaybackPreference.fromMap(value);

  static Map<String, dynamic> encode(PlaybackPreference value) => value.toMap();
}

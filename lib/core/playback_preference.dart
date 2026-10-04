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
    final session = _sessionFromMap(map);
    final eq = _eqFromMap(map);
    final transition = _transitionFromMap(map);
    return PlaybackPreference(
      _playModeFromStoredValue(map['playMode']) ?? PlayMode.forward,
      _normalizedVolumeDsp(map['volumeDsp']),
      eq.gains,
      eq.presets,
      eqBandModelVersion: currentEqBandModelVersion,
      eqEnabled: eq.enabled,
      audioDspSettings: eq.dsp,
      eqPreampDb: eq.preampDb,
      eqAutoGainEnabled: eq.autoGainEnabled,
      eqAutoHeadroomDb: eq.autoHeadroomDb,
      lastAudioPath: session.lastAudioPath,
      lastPlaylistPaths: session.lastPlaylistPaths,
      lastPlaylistIndex: session.lastPlaylistIndex,
      lastShuffleActive: session.lastShuffleActive,
      lastOriginalPlaylistPaths: session.lastOriginalPlaylistPaths,
      lastPositionSeconds: session.lastPositionSeconds,
      reinitOnSetSource: session.reinitOnSetSource,
      replayGainEnabled: session.replayGainEnabled,
      transitionMode: transition.mode,
      transitionFadeOutMs: transition.fadeOutMs,
      transitionFadeInMs: transition.fadeInMs,
    );
  }

  static ({
    String lastAudioPath,
    List<String> lastPlaylistPaths,
    int lastPlaylistIndex,
    bool lastShuffleActive,
    List<String> lastOriginalPlaylistPaths,
    double lastPositionSeconds,
    bool reinitOnSetSource,
    bool replayGainEnabled,
  })
  _sessionFromMap(Map map) {
    final lastPlaylistPaths = _normalizedPathStringList(
      map['lastPlaylistPaths'],
    );
    return (
      lastAudioPath: _normalizedPathString(map['lastAudioPath']),
      lastPlaylistPaths: lastPlaylistPaths,
      lastPlaylistIndex: _normalizedBoundedInt(
        map['lastPlaylistIndex'],
        defaultValue: 0,
        min: 0,
        max: lastPlaylistPaths.isEmpty ? 0 : lastPlaylistPaths.length - 1,
      ),
      lastShuffleActive: _normalizedBool(
        map['lastShuffleActive'],
        defaultValue: false,
      ),
      lastOriginalPlaylistPaths: _normalizedPathStringList(
        map['lastOriginalPlaylistPaths'],
      ),
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
    );
  }

  static ({
    List<double> gains,
    List<EqPreset> presets,
    bool enabled,
    AudioDspSettings dsp,
    double preampDb,
    bool autoGainEnabled,
    double autoHeadroomDb,
  })
  _eqFromMap(Map map) {
    return (
      gains: migrateEqGains(
        map['eqGains'],
        fromVersion: _storedEqBandVersion(map),
      ),
      presets: _eqPresetsFromStoredValue(map['eqPresets']),
      enabled: _normalizedBool(map['eqEnabled'], defaultValue: true),
      dsp: AudioDspSettings.fromMap(map['audioDspSettings']),
      preampDb: normalizedEqPreampDb(map['eqPreampDb']),
      autoGainEnabled: _normalizedBool(
        map['eqAutoGainEnabled'],
        defaultValue: true,
      ),
      autoHeadroomDb: _normalizedBoundedDouble(
        map['eqAutoHeadroomDb'],
        defaultValue: 1.0,
        min: 0.0,
        max: 24.0,
      ),
    );
  }

  static ({TransitionMode mode, int fadeOutMs, int fadeInMs})
  _transitionFromMap(Map map) {
    return (
      mode: _transitionModeFromStored(map),
      fadeOutMs: _normalizedBoundedInt(
        map['transitionFadeOutMs'],
        defaultValue: 300,
        min: 0,
        max: 10000,
      ),
      fadeInMs: _normalizedBoundedInt(
        map['transitionFadeInMs'],
        defaultValue: 200,
        min: 0,
        max: 10000,
      ),
    );
  }

  static int _storedEqBandVersion(Map map) {
    return _normalizedBoundedInt(
      map['eqBandModelVersion'],
      defaultValue: legacyEqBandModelVersion,
      min: legacyEqBandModelVersion,
      max: currentEqBandModelVersion,
    );
  }
}

class PlaybackPreferenceCodec {
  const PlaybackPreferenceCodec._();

  static PlaybackPreference decode(Object? value) =>
      PlaybackPreference.fromMap(value);

  static Map<String, dynamic> encode(PlaybackPreference value) => value.toMap();
}

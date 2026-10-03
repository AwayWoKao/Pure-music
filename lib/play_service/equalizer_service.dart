import 'package:pure_music/core/equalizer_action_state.dart';
import 'package:pure_music/core/audio_dsp_settings.dart';
import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/play_service/audio_echo_log_recorder.dart';
import 'package:pure_music/native/bass/bass_player.dart';

final class _EqRuntimeSnapshot {
  const _EqRuntimeSnapshot({
    required this.gains,
    required this.eqEnabled,
    required this.preampDb,
    required this.eqAutoGainEnabled,
    required this.eqAutoHeadroomDb,
    required this.audioDspSettings,
    required this.presets,
  });

  final List<double> gains;
  final bool eqEnabled;
  final double preampDb;
  final bool eqAutoGainEnabled;
  final double eqAutoHeadroomDb;
  final AudioDspSettings audioDspSettings;
  final List<EqPreset> presets;
}

/// EQ 控制服务，从 PlaybackService 提取
/// 管理均衡器增益、预设、自动增益和输出增益应用
class EqualizerService {
  final BassPlayer _player;
  final PlaybackPreference _pref;

  EqualizerService(this._player, this._pref) {
    _player.setEqEnabled(_pref.eqEnabled);
    _player.setEqPreampDb(_pref.eqPreampDb);
    _player.applyEqGains(_pref.eqGains, smooth: false);
    final effects = _pref.audioDspSettings.normalized();
    _pref.audioDspSettings = effects;
    _player.setAudioEffects(effects);
    _applyOutputGain(smooth: true);
  }

  double get eqPreampDb => _pref.eqPreampDb;
  bool get eqAutoGainEnabled => _pref.eqAutoGainEnabled;
  double get eqAutoHeadroomDb => _pref.eqAutoHeadroomDb;
  double get eqAutoGainDb => eqAutoGainEnabled ? _computeEqAutoGainDb() : 0.0;
  List<double> get eqGains => _player.eqGains;
  List<EqPreset> get eqPresets => _pref.eqPresets;
  bool get eqEnabled => _pref.eqEnabled;
  AudioDspSettings get audioEffects => _pref.audioDspSettings;

  double _computeEqAutoGainDb() {
    return computeEqAutoGainDb(
      eqEnabled: _pref.eqEnabled,
      gains: _player.eqGains,
      preampDb: _pref.eqPreampDb,
      autoHeadroomDb: eqAutoHeadroomDb,
      sampleRate: _player.streamSampleRate,
      useDx8Fallback: !_player.isBassFxLoaded,
    );
  }

  void _applyOutputGain({bool smooth = false}) {
    final preampDb = _pref.eqEnabled ? eqPreampDb : 0.0;
    final autoGainDb = _pref.eqEnabled && eqAutoGainEnabled
        ? eqAutoGainDb
        : 0.0;
    final targetVolume = eqOutputVolume(
      volumeDsp: _pref.volumeDsp,
      totalDb: preampDb + autoGainDb,
    );
    if (smooth) {
      _player.fadeToVolumeDsp(targetVolume);
    } else {
      _player.setVolumeDsp(targetVolume);
    }
  }

  void refreshEQ() {
    _player.refreshEQ();
    _applyOutputGain(smooth: true);
  }

  void setEQ(int band, double gain) {
    log.bass.info('legacy', '[action] setEQ band=$band gain=$gain');
    AudioEchoLogRecorder.instance.mark(
      'setEQ',
      extra: {'band': band, 'gain': gain},
    );
    final next = gain.isFinite
        ? gain.clamp(eqGainMinDb, eqGainMaxDb).toDouble()
        : 0.0;
    _player.setEQ(band, next);
    if (band >= 0 && band < _pref.eqGains.length) {
      _pref.eqGains[band] = next;
    }
    _applyOutputGain(smooth: true);
  }

  void setEqEnabled(bool enabled) {
    if (_pref.eqEnabled == enabled) return;
    _pref.eqEnabled = enabled;
    _player.setEqEnabled(enabled);
    _applyOutputGain(smooth: true);
  }

  void setAudioEffects(AudioDspSettings settings) {
    final normalized = settings.normalized();
    _pref.audioDspSettings = normalized;
    _player.setAudioEffects(normalized);
  }

  List<String> disableForExclusiveMode() {
    final disabled = <String>[];
    if (!_player.isEqNeutral) {
      _pref.eqEnabled = false;
      _player.setEqEnabled(false);
      _applyOutputGain();
      disabled.add('EQ');
    }
    if (!_player.isDspNeutral) {
      final effects = _pref.audioDspSettings.copyWith(
        enabled: false,
        limiterEnabled: false,
      );
      _pref.audioDspSettings = effects;
      _player.setAudioEffects(effects);
      disabled.add('DSP');
    }
    return disabled;
  }

  void setEqPreampDb(double value) {
    final next = value.isFinite ? value.clamp(-24.0, 24.0).toDouble() : 0.0;
    if (_pref.eqPreampDb == next) return;
    _pref.eqPreampDb = next;
    _player.setEqPreampDb(next);
    _applyOutputGain(smooth: true);
  }

  void setEqAutoGainEnabled(bool enabled) {
    if (_pref.eqAutoGainEnabled == enabled) return;
    _pref.eqAutoGainEnabled = enabled;
    _applyOutputGain(smooth: true);
  }

  void setEqAutoHeadroomDb(double value) {
    final next = value.isFinite ? value.clamp(0.0, 24.0).toDouble() : 0.0;
    if (_pref.eqAutoHeadroomDb == next) return;
    _pref.eqAutoHeadroomDb = next;
    _applyOutputGain(smooth: true);
  }

  Future<bool> saveEqPreset(String name) {
    return saveEqPresetBatch([
      EqPreset(
        name,
        List<double>.from(_player.eqGains),
        eqEnabled: _pref.eqEnabled,
        preampDb: _pref.eqPreampDb,
        eqAutoGainEnabled: _pref.eqAutoGainEnabled,
        eqAutoHeadroomDb: _pref.eqAutoHeadroomDb,
        audioDspSettings: _pref.audioDspSettings,
      ),
    ]);
  }

  Future<bool> saveEqPresetBatch(Iterable<EqPreset> presets) async {
    final snapshots = _normalizePresetSnapshots(presets);
    if (snapshots.isEmpty) return false;

    final oldPresets = List<EqPreset>.from(_pref.eqPresets);
    _replacePresets(snapshots);
    final saved = await AppPreference.instance.save();
    if (!saved) _pref.eqPresets = oldPresets;
    return saved;
  }

  Future<bool> importEqPresetsAndApplyLast(Iterable<EqPreset> presets) async {
    final snapshots = _normalizePresetSnapshots(presets);
    if (snapshots.isEmpty) return false;

    return _applyAndSave(() {
      _replacePresets(snapshots);
      final last = snapshots.last;
      _applySnapshot(
        gains: last.gains,
        eqEnabled: last.hasAudioState ? last.eqEnabled : null,
        preampDb: last.hasAudioState ? last.preampDb : null,
        eqAutoGainEnabled: last.hasAudioState ? last.eqAutoGainEnabled : null,
        eqAutoHeadroomDb: last.hasAudioState ? last.eqAutoHeadroomDb : null,
        audioDspSettings: last.hasAudioState ? last.audioDspSettings : null,
      );
    });
  }

  List<EqPreset> _normalizePresetSnapshots(Iterable<EqPreset> presets) {
    final snapshots = <EqPreset>[];
    for (final preset in presets) {
      final name = normalizedEqPresetName(preset.name);
      if (name.isEmpty) continue;
      snapshots.add(
        EqPreset(
          name,
          normalizedEqGains(preset.gains),
          bandModelVersion: currentEqBandModelVersion,
          hasAudioState: preset.hasAudioState,
          eqEnabled: preset.eqEnabled,
          preampDb: normalizedEqPreampDb(preset.preampDb),
          eqAutoGainEnabled: preset.eqAutoGainEnabled,
          eqAutoHeadroomDb: preset.eqAutoHeadroomDb.clamp(0.0, 24.0).toDouble(),
          audioDspSettings: preset.audioDspSettings.normalized(),
        ),
      );
    }
    return snapshots;
  }

  void _replacePresets(Iterable<EqPreset> snapshots) {
    for (final snapshot in snapshots) {
      final key = eqPresetNameKey(snapshot.name);
      final existingIndex = _pref.eqPresets.indexWhere(
        (e) => eqPresetNameKey(e.name) == key,
      );
      if (existingIndex >= 0) {
        final existing = _pref.eqPresets[existingIndex];
        _pref.eqPresets[existingIndex] = _copyEqPreset(
          snapshot,
          name: normalizedEqPresetName(existing.name),
        );
      } else {
        _pref.eqPresets.add(_copyEqPreset(snapshot));
      }
    }
  }

  EqPreset _copyEqPreset(EqPreset preset, {String? name}) {
    return EqPreset(
      name ?? preset.name,
      List<double>.from(preset.gains),
      bandModelVersion: currentEqBandModelVersion,
      hasAudioState: preset.hasAudioState,
      eqEnabled: preset.eqEnabled,
      preampDb: preset.preampDb,
      eqAutoGainEnabled: preset.eqAutoGainEnabled,
      eqAutoHeadroomDb: preset.eqAutoHeadroomDb,
      audioDspSettings: preset.audioDspSettings,
    );
  }

  Future<bool> removeEqPreset(String name) async {
    final oldPresets = List<EqPreset>.from(_pref.eqPresets);
    _pref.eqPresets.removeWhere(
      (e) => shouldRemoveEqPresetName(storedName: e.name, targetName: name),
    );
    final saved = await AppPreference.instance.save();
    if (!saved) _pref.eqPresets = oldPresets;
    return saved;
  }

  Future<bool> applyEqPreset(EqPreset preset) async {
    return _applyAndSave(() {
      _applySnapshot(
        gains: preset.gains,
        eqEnabled: preset.hasAudioState ? preset.eqEnabled : null,
        preampDb: preset.hasAudioState ? preset.preampDb : null,
        eqAutoGainEnabled: preset.hasAudioState
            ? preset.eqAutoGainEnabled
            : null,
        eqAutoHeadroomDb: preset.hasAudioState ? preset.eqAutoHeadroomDb : null,
        audioDspSettings: preset.hasAudioState ? preset.audioDspSettings : null,
      );
    });
  }

  void applyEqGainsSnapshot(List<double> gains, {double? preampDb}) {
    _applySnapshot(gains: gains, preampDb: preampDb);
  }

  Future<bool> applyBuiltInAudioPreset(BuiltInAudioPreset preset) async {
    return _applyAndSave(() {
      _applySnapshot(
        gains: preset.gains,
        eqEnabled: true,
        preampDb: preset.preampDb,
        eqAutoGainEnabled: true,
        eqAutoHeadroomDb: _pref.eqAutoHeadroomDb,
      );
    });
  }

  _EqRuntimeSnapshot _captureRuntimeSnapshot() {
    return _EqRuntimeSnapshot(
      gains: List<double>.from(_player.eqGains),
      eqEnabled: _pref.eqEnabled,
      preampDb: _pref.eqPreampDb,
      eqAutoGainEnabled: _pref.eqAutoGainEnabled,
      eqAutoHeadroomDb: _pref.eqAutoHeadroomDb,
      audioDspSettings: _pref.audioDspSettings,
      presets: List<EqPreset>.from(_pref.eqPresets),
    );
  }

  void _restoreRuntimeSnapshot(_EqRuntimeSnapshot snapshot) {
    _pref.eqPresets = List<EqPreset>.from(snapshot.presets);
    _applySnapshot(
      gains: snapshot.gains,
      eqEnabled: snapshot.eqEnabled,
      preampDb: snapshot.preampDb,
      eqAutoGainEnabled: snapshot.eqAutoGainEnabled,
      eqAutoHeadroomDb: snapshot.eqAutoHeadroomDb,
      audioDspSettings: snapshot.audioDspSettings,
    );
  }

  Future<bool> _applyAndSave(void Function() apply) async {
    final previous = _captureRuntimeSnapshot();
    try {
      apply();
      final saved = await AppPreference.instance.save();
      if (!saved) _restoreRuntimeSnapshot(previous);
      return saved;
    } catch (error, trace) {
      log.bass.error('legacy', '应用 EQ 预设失败', error: error, stackTrace: trace);
      try {
        _restoreRuntimeSnapshot(previous);
      } catch (restoreError, restoreTrace) {
        log.bass.error('legacy', '回滚 EQ 预设失败', error: restoreError, stackTrace: restoreTrace);
      }
      return false;
    }
  }

  void _applySnapshot({
    required Iterable<double> gains,
    bool? eqEnabled,
    double? preampDb,
    bool? eqAutoGainEnabled,
    double? eqAutoHeadroomDb,
    AudioDspSettings? audioDspSettings,
  }) {
    final nextGains = normalizedEqGains(gains);
    final nextPreampDb = preampDb == null
        ? _pref.eqPreampDb
        : preampDb.clamp(eqPreampMinDb, eqPreampMaxDb).toDouble();
    final currentVolume = _player.volumeDsp;
    if (currentVolume > 0.0 && currentVolume.isFinite) {
      _player.setVolumeDsp(
        (currentVolume * 0.25).clamp(0.0, eqOutputVolumeMax).toDouble(),
      );
    }

    if (eqEnabled != null) _pref.eqEnabled = eqEnabled;
    if (preampDb != null) {
      _pref.eqPreampDb = nextPreampDb;
    }
    if (eqAutoGainEnabled != null) {
      _pref.eqAutoGainEnabled = eqAutoGainEnabled;
    }
    if (eqAutoHeadroomDb != null) {
      _pref.eqAutoHeadroomDb = eqAutoHeadroomDb.clamp(0.0, 24.0).toDouble();
    }
    if (audioDspSettings != null) {
      _pref.audioDspSettings = audioDspSettings.normalized();
    }

    _player.setEqEnabled(_pref.eqEnabled);
    _player.setEqPreampDb(_pref.eqPreampDb);
    _player.setAudioEffects(_pref.audioDspSettings);
    _pref.eqGains = nextGains;
    _player.applyEqGains(nextGains, smooth: false);
    _applyOutputGain(smooth: true);
  }

  /// 重新应用输出增益（当 volumeDsp 变化时调用）
  void reapplyOutputGain() {
    _applyOutputGain();
  }
}

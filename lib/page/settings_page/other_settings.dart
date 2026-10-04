import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/settings.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/component/settings_tile.dart';
import 'package:pure_music/play_service/audio_echo_log_recorder.dart';
import 'package:pure_music/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class RememberPlaybackPositionControl extends StatefulWidget {
  const RememberPlaybackPositionControl({super.key});

  @override
  State<RememberPlaybackPositionControl> createState() =>
      _RememberPlaybackPositionControlState();
}

class _RememberPlaybackPositionControlState
    extends State<RememberPlaybackPositionControl> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: '记住播放进度',
      subtitle: settings.rememberPlaybackPosition
          ? '下次启动从退出前的位置继续'
          : '下次启动从歌曲开头播放',
      action: Switch(
        value: settings.rememberPlaybackPosition,
        onChanged: (value) {
          setState(() => settings.rememberPlaybackPosition = value);
          settings.saveSettings();
        },
      ),
    );
  }
}

class ReplayGainControl extends StatefulWidget {
  const ReplayGainControl({super.key});

  @override
  State<ReplayGainControl> createState() => _ReplayGainControlState();
}

class _ReplayGainControlState extends State<ReplayGainControl> {
  final pref = AppPreference.instance.playbackPref;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: 'ReplayGain',
      action: Switch(
        value: pref.replayGainEnabled,
        onChanged: (value) async {
          setState(() => pref.replayGainEnabled = value);
          PlayService.instance.playbackService.setReplayGainEnabled(value);
          await AppPreference.instance.save();
        },
      ),
    );
  }
}

class TransitionControl extends StatefulWidget {
  const TransitionControl({super.key});

  @override
  State<TransitionControl> createState() => _TransitionControlState();
}

class _TransitionControlState extends State<TransitionControl> {
  final pref = AppPreference.instance.playbackPref;

  Future<void> _apply(void Function() mutate) async {
    setState(mutate);
    PlayService.instance.playbackService.refreshTransitionPreparation();
    await AppPreference.instance.save();
  }

  @override
  Widget build(BuildContext context) {
    final mode = pref.transitionMode;
    return Column(
      children: [
        _modeTile(mode),
        if (mode != TransitionMode.seamless && mode != TransitionMode.smart)
          ..._durationTiles(),
      ],
    );
  }

  Widget _modeTile(TransitionMode mode) {
    return SettingsTile(
      description: '切歌过渡',
      subtitle: switch (mode) {
        TransitionMode.seamless => '曲目结束时无缝衔接',
        TransitionMode.fade =>
          '淡出 ${pref.transitionFadeOutMs}ms / 淡入 ${pref.transitionFadeInMs}ms',
        TransitionMode.crossfade =>
          '淡出 ${pref.transitionFadeOutMs}ms / 淡入 ${pref.transitionFadeInMs}ms',
        TransitionMode.smart => '根据歌曲内容自动选择衔接方式',
      },
      action: SegmentedButton<TransitionMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: TransitionMode.seamless, label: Text('无缝衔接')),
          ButtonSegment(value: TransitionMode.fade, label: Text('淡入淡出')),
          ButtonSegment(value: TransitionMode.crossfade, label: Text('交叉淡化')),
          ButtonSegment(value: TransitionMode.smart, label: Text('智能衔接')),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => _apply(() {
          pref.transitionMode = selection.first;
        }),
      ),
    );
  }

  List<Widget> _durationTiles() {
    return [
      const SizedBox(height: 16),
      _msSliderTile(
        description: '淡出时长',
        valueMs: pref.transitionFadeOutMs,
        onChanged: (v) => setState(() => pref.transitionFadeOutMs = v),
        onChangeEnd: (v) => _apply(() => pref.transitionFadeOutMs = v),
      ),
      const SizedBox(height: 16),
      _msSliderTile(
        description: '淡入时长',
        valueMs: pref.transitionFadeInMs,
        onChanged: (v) => setState(() => pref.transitionFadeInMs = v),
        onChangeEnd: (v) => _apply(() => pref.transitionFadeInMs = v),
      ),
    ];
  }

  Widget _msSliderTile({
    required String description,
    required int valueMs,
    required ValueChanged<int> onChanged,
    required ValueChanged<int> onChangeEnd,
  }) {
    return SettingsTile(
      description: description,
      subtitle: '${valueMs}ms',
      action: SizedBox(
        width: 160,
        child: Slider(
          value: valueMs.toDouble(),
          min: 0,
          max: 10000,
          divisions: 20,
          label: '${valueMs}ms',
          onChanged: (v) => onChanged(v.round()),
          onChangeEnd: (v) => onChangeEnd(v.round()),
        ),
      ),
    );
  }
}

class AudioEchoLogRecordControl extends StatefulWidget {
  const AudioEchoLogRecordControl({super.key});

  @override
  State<AudioEchoLogRecordControl> createState() =>
      _AudioEchoLogRecordControlState();
}

class _AudioEchoLogRecordControlState extends State<AudioEchoLogRecordControl> {
  final recorder = AudioEchoLogRecorder.instance;
  bool _isChangingRecording = false;


  Future<void> _snapshotLog() async {
    recorder.snapshot(tag: 'manual');
    await recorder.flush();
    if (!mounted) return;
    showTextOnSnackBar('已写入快照');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRecording = recorder.isRecording;
    final isBusy = _isChangingRecording;
    return SettingsTile(
      description: '回声排查日志',
      action: Wrap(
        spacing: 4.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _statusChip(scheme, isRecording, isBusy),
          IconButton(
            tooltip: '写入快照',
            onPressed: isRecording && !isBusy ? _snapshotLog : null,
            icon: const Icon(Symbols.bookmark),
          ),
          IconButton(
            tooltip: '打开日志目录',
            onPressed: () async {
              final opened = await recorder.openLogDir();
              if (!context.mounted) return;
              showTextOnSnackBar(opened ? '已打开日志目录' : '日志目录打开失败');
            },
            icon: const Icon(Symbols.folder),
          ),
          Switch(
            value: isRecording,
            onChanged: isBusy ? null : _toggleRecording,
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ColorScheme scheme, bool isRecording, bool isBusy) {
    final statusLabel = isBusy
        ? isRecording
              ? '正在停止'
              : '正在开启'
        : isRecording
        ? '录制中'
        : '未开启';
    final color = isRecording
        ? scheme.onTertiaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      height: 32.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: isRecording
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: AppRadius.mdCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy)
            SizedBox(
              width: 14.0,
              height: 14.0,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: color),
            )
          else
            Icon(
              isRecording ? Symbols.radio_button_checked : Symbols.circle,
              size: 14.0,
              color: color,
            ),
          const SizedBox(width: 6.0),
          Text(statusLabel, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Future<void> _toggleRecording(bool value) async {
    setState(() => _isChangingRecording = true);
    try {
      if (value) {
        await recorder.start();
      } else {
        await recorder.stop();
      }
    } catch (_) {
      if (mounted) {
        showTextOnSnackBar(value ? '日志录制启动失败' : '日志录制停止失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isChangingRecording = false);
      }
    }
  }
}

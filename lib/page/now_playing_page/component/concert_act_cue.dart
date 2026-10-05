import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_music/component/motion.dart';
import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/play_service/play_service.dart';
import 'package:pure_music/services/concert_session.dart';

/// 切幕时短暂打出幕名，不阻挡操作。
class ConcertActCue extends StatefulWidget {
  const ConcertActCue({super.key});

  @override
  State<ConcertActCue> createState() => _ConcertActCueState();
}

class _ConcertActCueState extends State<ConcertActCue> {
  String _act = '';
  bool _show = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    ConcertSession.instance.addListener(_sync);
    PlayService.instance.playbackService.nowPlayingNotifier.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  void _sync() {
    final session = ConcertSession.instance;
    if (!session.isActive) {
      if (_show) setState(() => _show = false);
      return;
    }
    final act = session.consumeActAnnouncement(
      PlayService.instance.playbackService.playlistIndex,
    );
    if (act == null) return;
    _hideTimer?.cancel();
    setState(() {
      _act = act;
      _show = true;
    });
    _hideTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    ConcertSession.instance.removeListener(_sync);
    PlayService.instance.playbackService.nowPlayingNotifier.removeListener(
      _sync,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_act.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 72,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _show ? 1 : 0,
          duration: MotionDuration.base,
          curve: MotionCurve.standard,
          child: Text(
            _act,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: AppType.weightSemibold,
              letterSpacing: 8,
              color: scheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

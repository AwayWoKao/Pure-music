import 'package:flutter/material.dart';
import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/play_service/play_service.dart';
import 'package:pure_music/services/concert_session.dart';

/// 开演后显示当前幕和场次进度。
class ConcertActLabel extends StatelessWidget {
  const ConcertActLabel({
    super.key,
    this.compact = false,
    this.textAlign = TextAlign.center,
  });

  final bool compact;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConcertSession.instance,
      builder: (context, _) {
        final session = ConcertSession.instance;
        if (!session.isActive) return const SizedBox.shrink();
        return ValueListenableBuilder<Audio?>(
          valueListenable:
              PlayService.instance.playbackService.nowPlayingNotifier,
          builder: (context, _, _) {
            final playback = PlayService.instance.playbackService;
            final act = session.actAt(playback.playlistIndex);
            if (act == null) return const SizedBox.shrink();
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: EdgeInsets.only(bottom: compact ? 2 : 8),
              child: Text(
                '$act · ${playback.playlistIndex + 1} / ${session.length}',
                textAlign: textAlign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? AppType.microlabel : AppType.caption,
                  fontWeight: AppType.weightSemibold,
                  letterSpacing: compact ? 0.4 : 1.2,
                  color: scheme.primary,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

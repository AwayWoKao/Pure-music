import 'app_log.dart';

double? nextDiagnosticAt({
  required double? previous,
  required double sample,
  required double length,
  required bool playing,
}) {
  if (!playing) return previous;
  if (!sample.isFinite || !length.isFinite || length <= 1) return previous;
  if (sample <= 0.05 &&
      previous != null &&
      previous > 5 &&
      length > 30) {
    return previous;
  }
  return sample;
}

bool completedBeforeEnd({required double position, required double length}) {
  if (!position.isFinite || !length.isFinite || length <= 0) return false;
  return length - position > 3 && position < length * 0.9;
}

class SongOrigin {
  const SongOrigin({
    required this.at,
    required this.length,
    required this.from,
    required this.fromIndex,
    required this.lengthSource,
  });

  final double at;
  final double length;
  final String? from;
  final int? fromIndex;
  final String lengthSource;
}

void logSongChanged({
  required String reason,
  required String to,
  required int index,
  required SongOrigin? origin,
}) {
  final fields = <String, Object?>{
    'reason': reason,
    'to': to,
    'index': index,
  };
  if (origin == null) {
    fields['clock'] = 'missing';
  } else {
    fields.addAll({
      'at': origin.at,
      'length': origin.length,
      'from': origin.from,
      'fromIndex': origin.fromIndex,
      'lengthSource': origin.lengthSource,
    });
  }
  log.playback.info('song.changed', '切到 $to', fields: fields);
  if (origin == null || origin.lengthSource == 'tag') return;
  if (reason == 'completed' &&
      completedBeforeEnd(position: origin.at, length: origin.length)) {
    log.playback.warn(
      'song.advanced_early',
      '歌曲未到结尾就切换',
      fields: {
        'at': origin.at,
        'length': origin.length,
        'title': origin.from,
      },
    );
  }
}

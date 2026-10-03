import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/log_format.dart';
import 'package:pure_music/core/log/log_record.dart';

void main() {
  test('multi-word message stays intact around fields', () {
    final record = LogRecord(
      time: DateTime(2026, 10, 2, 14, 17, 19, 165),
      level: LogLevel.warn,
      module: LogModule.playback,
      event: 'song.advanced_early',
      message: '歌曲未到结尾就切换',
      fields: {'at': 5.5, 'title': 'Night Drive'},
      stackTrace: StackTrace.fromString('#0 PlaybackService._commitSongChange'),
    );

    final text = formatRecord(record);
    expect(
      text.split('\n').first,
      '2026-10-02T14:17:19.165 WARN playback song.advanced_early | '
      'at=5.5 title="Night Drive" | 歌曲未到结尾就切换',
    );
    expect(text, contains('\n  #0 PlaybackService._commitSongChange'));
    final parsed = parseLog(text).single;
    expect(parsed.message, '歌曲未到结尾就切换');
    expect(parsed.fields['at'], 5.5);
    expect(parsed.fields['title'], 'Night Drive');
    expect(parsed.time.hour, 14);
    expect(parsed.time.isUtc, isFalse);
  });

  test('message with spaces and an embedded separator round-trips', () {
    final record = LogRecord(
      time: DateTime(2026, 10, 2, 14, 17, 19, 165),
      level: LogLevel.info,
      module: LogModule.playback,
      event: 'song.changed',
      message: '切到 Night Drive | live',
      fields: {'reason': 'completed', 'to': 'Night Drive'},
    );
    final parsed = parseLog(formatRecord(record)).single;
    expect(parsed.message, '切到 Night Drive | live');
    expect(parsed.fields['reason'], 'completed');
    expect(parsed.fields['to'], 'Night Drive');
  });

  test('empty fields use a dash and unknown lines are skipped', () {
    const text = '''
SESSION|pid=1
2026-10-02T14:17:19.165 INFO app legacy | - | [action] nextAudio
NOT A LOG LINE
''';
    final parsed = parseLog(text).single;
    expect(parsed.event, 'legacy');
    expect(parsed.fields, isEmpty);
    expect(parsed.message, '[action] nextAudio');
    expect(LogModule.onlineLyric.wire, 'online_lyric');
    expect(parseLogModule('nope'), LogModule.app);
  });
}

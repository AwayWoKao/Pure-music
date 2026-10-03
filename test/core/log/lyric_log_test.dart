import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/app_log.dart';
import 'package:pure_music/core/log/log_record.dart';
import 'package:pure_music/lyric/lyric_loader.dart';

void main() {
  tearDown(LogMemory.instance.clear);

  test('a miss is one info record without a candidate path', () {
    log.write(
      lyricLoadRecord(found: false, source: 'none', lines: 0, elapsedMs: 12),
    );
    final record = LogMemory.instance.records.single;
    expect(record.event, 'lyric.missing');
    expect(record.level, LogLevel.info);
    expect(record.fields['source'], 'none');
  });

  test('a hit is one info record carrying the line count', () {
    log.write(
      lyricLoadRecord(
        found: true,
        source: 'embedded',
        lines: 58,
        elapsedMs: 30,
      ),
    );
    final record = LogMemory.instance.records.single;
    expect(record.event, 'lyric.loaded');
    expect(record.level, LogLevel.info);
    expect(record.fields['lines'], 58);
    expect(record.message, isNot(contains(r'\')));
    expect(record.message, isNot(contains('/')));
  });
}

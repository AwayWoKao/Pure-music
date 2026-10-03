import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/log_record.dart';
import 'package:pure_music/core/log/rust_log_line.dart';

void main() {
  final now = DateTime(2026, 10, 2, 14, 17, 19, 165);

  test('structured rust lines keep their level and target', () {
    final parsed = parseRustLogLine(
      'DEBUG|smtc|Display refreshed - Night Drive',
      now: now,
    );
    expect(parsed, isNotNull);
    expect(parsed!.level, LogLevel.debug);
    expect(parsed.module, LogModule.smtc);
    expect(parsed.event, 'legacy');
    expect(parsed.message, 'Display refreshed - Night Drive');
    expect(parsed.time, now);
  });

  test('unstructured lines and blocked targets are dropped', () {
    expect(parseRustLogLine('not structured', now: now), isNull);
    expect(parseRustLogLine('INFO|reqwest|connected', now: now), isNull);
  });

  test('targets map onto the shared modules', () {
    expect(
      parseRustLogLine('WARN|tag|metadata read failed', now: now)!.module,
      LogModule.lyric,
    );
    expect(
      parseRustLogLine('INFO|library|indexed', now: now)!.module,
      LogModule.library,
    );
    expect(
      parseRustLogLine('WARN|font|missing', now: now)!.module,
      LogModule.rust,
    );
  });
}

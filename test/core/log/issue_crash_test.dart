import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/issue_crash.dart';

void main() {
  test('same unhandled error is folded with count and latest stack', () {
    const stack = '#0      TtmlTimeline._lastEnd=\n'
        '#1      new TtmlTimeline (package:pure_music/lyric/ttml_timeline.dart:17)';
    final raw = [
      r'CRASH_LOG_PATH=D:\logs\crash.log',
      'TRUNCATED|omittedChars=12',
      'd (package:flutter/src/widgets/framework.dart:4037)',
      '2026-09-29T20:53:02.929394|UNHANDLED|source=flutter|pid=14836',
      'LateInitializationError: Field \'_lastEnd@1\' has already been initialized.',
      stack,
      '2026-09-29T20:53:03.042770|UNHANDLED|source=flutter|pid=14836',
      'LateInitializationError: Field \'_lastEnd@1\' has already been initialized.',
      stack,
      '2026-09-29T20:53:28.422978|UNHANDLED|source=flutter|pid=14836',
      'LateInitializationError: Field \'_lastEnd@1\' has already been initialized.',
      stack,
    ].join('\n');

    final rendered = renderIssueCrashLog(raw);
    expect(rendered, contains(r'CRASH_LOG_PATH=D:\logs\crash.log'));
    expect(rendered, contains('total=3 unique=1'));
    expect(
      rendered,
      contains('-- ×3 2026-09-29T20:53:02.929394 until 2026-09-29T20:53:28.422978 --'),
    );
    expect(
      'LateInitializationError'.allMatches(rendered),
      hasLength(1),
    );
    expect(rendered, contains('2026-09-29T20:53:28.422978|UNHANDLED|'));
    expect(rendered, isNot(contains('TRUNCATED|')));
    expect(
      rendered,
      isNot(contains('d (package:flutter/src/widgets/framework.dart:4037)')),
    );
  });

  test('truncateIssueTail starts on a new line', () {
    const content = 'aaaa\nbbbb\ncccc\ndddd\n';
    final truncated = truncateIssueTail(content, 8);
    expect(truncated, startsWith('TRUNCATED|omittedChars='));
    expect(truncated.endsWith('dddd\n'), isTrue);
    expect(truncated, isNot(contains('cccc')));
  });
}

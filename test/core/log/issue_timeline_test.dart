import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/issue_timeline.dart';
import 'package:pure_music/core/log/log_record.dart';

LogRecord _record({
  required int minute,
  int second = 0,
  required LogLevel level,
  required LogModule module,
  required String event,
  required String message,
  Map<String, Object?> fields = const {},
}) {
  return LogRecord(
    time: DateTime(2026, 10, 2, 14, minute, second),
    level: level,
    module: module,
    event: event,
    message: message,
    fields: fields,
  );
}

void main() {
  test('folds only uninterrupted repeats and keeps debug out of titles', () {
    final records = <LogRecord>[
      for (var i = 0; i < 12; i++)
        _record(
          minute: i * 3,
          level: LogLevel.warn,
          module: LogModule.memory,
          event: 'legacy',
          message: '[mem] RSS 257MB > 220, tier-2 cleanup',
        ),
      for (var i = 0; i < 34; i++)
        _record(
          minute: 40,
          second: i * 3,
          level: LogLevel.debug,
          module: LogModule.smtc,
          event: 'display.refresh',
          message: 'Display refreshed',
          fields: const {'title': 'Night Drive'},
        ),
      _record(
        minute: 41,
        second: 58,
        level: LogLevel.debug,
        module: LogModule.lyric,
        event: 'lyric.candidate',
        message: 'candidate not found',
      ),
      _record(
        minute: 42,
        level: LogLevel.info,
        module: LogModule.playback,
        event: 'song.changed',
        message: '切到 Night Drive',
        fields: const {'reason': 'completed', 'at': 5.5, 'length': 176},
      ),
      _record(
        minute: 42,
        level: LogLevel.warn,
        module: LogModule.playback,
        event: 'song.advanced_early',
        message: '歌曲未到结尾就切换',
      ),
      _record(
        minute: 43,
        level: LogLevel.info,
        module: LogModule.desktopLyric,
        event: 'legacy',
        message: 'sendLyricLineMessage line=4',
      ),
      _record(
        minute: 44,
        second: 58,
        level: LogLevel.debug,
        module: LogModule.lyric,
        event: 'lyric.candidate',
        message: 'fuzzy miss',
      ),
      _record(
        minute: 45,
        level: LogLevel.warn,
        module: LogModule.lyric,
        event: 'legacy',
        message: 'lyric parse failed',
      ),
      _record(
        minute: 46,
        level: LogLevel.warn,
        module: LogModule.memory,
        event: 'legacy',
        message: '[mem] RSS 257MB > 220, tier-2 cleanup',
      ),
      _record(
        minute: 47,
        level: LogLevel.info,
        module: LogModule.playback,
        event: 'song.changed',
        message: '切到别的歌',
        fields: const {'reason': 'user.next'},
      ),
      _record(
        minute: 48,
        level: LogLevel.warn,
        module: LogModule.memory,
        event: 'legacy',
        message: '[mem] RSS 257MB > 220, tier-2 cleanup',
      ),
    ];

    final rendered = renderIssueLog(records);
    final problems = rendered
        .split('-- problems --')[1]
        .split('-- timeline --')
        .first;
    final timeline = rendered
        .split('-- timeline --')[1]
        .split('-- detail')
        .first;

    expect(
      '×12 until 2026-10-02T14:33:00.000'.allMatches(timeline),
      hasLength(1),
    );
    final foldedAt = timeline.indexOf('×12 until');
    final songAt = timeline.indexOf('song.changed');
    expect(foldedAt, greaterThanOrEqualTo(0));
    expect(foldedAt, lessThan(songAt));
    expect(timeline, contains('2026-10-02T14:00:00.000'));

    expect(
      '[mem] RSS 257MB > 220, tier-2 cleanup'.allMatches(timeline),
      hasLength(3),
    );
    expect(timeline, isNot(contains('display.refresh')));
    expect(timeline, isNot(contains('candidate not found')));
    expect(timeline, contains('song.changed'));
    expect(timeline, contains('reason=completed'));
    expect(timeline, contains('song.advanced_early'));
    expect(rendered, isNot(contains('sendLyricLineMessage')));

    expect(problems, contains('×14 until 2026-10-02T14:48:00.000'));
    expect(
      '[mem] RSS 257MB > 220, tier-2 cleanup'.allMatches(problems),
      hasLength(1),
    );
    expect(problems, contains('song.advanced_early'));
    expect(problems, contains('lyric parse failed'));
    expect(problems, isNot(contains('song.changed')));
    expect(
      problems.indexOf('[mem]'),
      lessThan(problems.indexOf('lyric parse failed')),
    );
    expect(
      problems.indexOf('lyric parse failed'),
      lessThan(problems.indexOf('song.advanced_early')),
    );

    final detail = rendered.split('-- detail').skip(1).join('\n');
    expect(detail, contains('fuzzy miss'));
    expect(detail, isNot(contains('candidate not found')));

    final summary = RegExp(r'warn=(\d+)').firstMatch(rendered);
    expect(summary, isNotNull);
    expect(int.parse(summary!.group(1)!), greaterThanOrEqualTo(14));
  });

  test('problems puts errors first and reports omitted unique warns', () {
    final records = <LogRecord>[
      _record(
        minute: 1,
        level: LogLevel.error,
        module: LogModule.bass,
        event: 'legacy',
        message: 'plugin load failed',
      ),
      for (var i = 0; i < 33; i++)
        _record(
          minute: 2,
          second: i,
          level: LogLevel.warn,
          module: LogModule.memory,
          event: 'legacy',
          message: 'unique warn $i',
        ),
      _record(
        minute: 3,
        level: LogLevel.error,
        module: LogModule.bass,
        event: 'legacy',
        message: 'plugin load failed',
      ),
    ];

    final rendered = renderIssueLog(records);
    final problems = rendered
        .split('-- problems --')[1]
        .split('-- timeline --')
        .first;
    expect(problems, contains('omitted=1'));
    expect(problems, contains('×2 until 2026-10-02T14:03:00.000'));
    expect(
      problems.indexOf('plugin load failed'),
      lessThan(problems.indexOf('unique warn')),
    );
    expect(problems, contains('unique warn 32'));
    expect(problems, isNot(contains('unique warn 0')));
    expect(rendered, isNot(contains('problems=-')));
  });

  test('empty problems line when there is no warn or error', () {
    final rendered = renderIssueLog([
      _record(
        minute: 1,
        level: LogLevel.info,
        module: LogModule.playback,
        event: 'song.changed',
        message: '切到 Night Drive',
      ),
    ]);
    expect(rendered, contains('problems=-'));
    expect(rendered, isNot(contains('-- problems --')));
  });

  test(
    'fitIssueLogToBudget keeps newest infos without shrinking one by one',
    () {
      final records = <LogRecord>[
        for (var i = 0; i < 40; i++)
          _record(
            minute: i,
            level: LogLevel.warn,
            module: LogModule.memory,
            event: 'legacy',
            message: '[mem] RSS ${200 + i}MB > 220, tier-2 cleanup',
          ),
        for (var i = 0; i < 80; i++)
          _record(
            minute: 50,
            second: i % 60,
            level: LogLevel.info,
            module: LogModule.playback,
            event: 'song.changed',
            message: 'play $i',
          ),
      ];
      final fitted = fitIssueLogToBudget(records, 12000);
      expect(fitted.length, lessThanOrEqualTo(12000));
      expect(fitted, contains('-- problems --'));
      expect(fitted, contains('play 79'));
    },
  );
}

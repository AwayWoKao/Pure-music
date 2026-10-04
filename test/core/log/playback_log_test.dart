import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/app_log.dart';
import 'package:pure_music/core/log/playback_log.dart';

void main() {
  tearDown(LogMemory.instance.clear);

  test('diagnostic clock keeps the last real playing sample', () {
    expect(
      nextDiagnosticAt(previous: null, sample: 5.5, length: 176, playing: true),
      5.5,
    );
    expect(
      nextDiagnosticAt(previous: 5.5, sample: 0, length: 1, playing: false),
      5.5,
    );
    expect(
      nextDiagnosticAt(previous: 5.5, sample: 0, length: 176, playing: true),
      5.5,
    );
    expect(
      nextDiagnosticAt(previous: 100, sample: 40, length: 176, playing: true),
      40,
    );
    expect(completedBeforeEnd(position: 5.5, length: 176), isTrue);
    expect(completedBeforeEnd(position: 170, length: 176), isFalse);
    expect(completedBeforeEnd(position: 0, length: 1), isFalse);
  });

  test('missing clock does not invent an early advance', () {
    logSongChanged(reason: 'completed', to: 'Night Drive', index: 13, origin: null);
    final record = LogMemory.instance.records.single;
    expect(record.event, 'song.changed');
    expect(record.fields['clock'], 'missing');
    LogMemory.instance.clear();

    logSongChanged(
      reason: 'completed',
      to: 'Night Drive',
      index: 13,
      origin: const SongOrigin(at: 5.5, length: 176, from: 'Old', fromIndex: 12, lengthSource: 'player'),
    );
    expect(
      LogMemory.instance.records.map((record) => record.event),
      ['song.changed', 'song.advanced_early'],
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/lyric/ttml.dart';
import 'package:pure_music/lyric/ttml_timeline.dart';

SyncLyricLine _line(int start, int end, {String agent = 'v1'}) {
  return SyncLyricLine(
    Duration(milliseconds: start),
    Duration(milliseconds: end - start),
    [
      SyncLyricWord(
        Duration(milliseconds: start),
        Duration(milliseconds: end - start),
        '字',
      ),
    ],
  )..agent = agent;
}

void main() {
  test('background overlap does not keep a finished main line in layout', () {
    final first = _line(0, 2000)
      ..bgText = '声'
      ..bgStart = const Duration(milliseconds: 2000)
      ..bgEnd = const Duration(milliseconds: 6000);
    final timeline = TtmlTimeline(Ttml([first, _line(3000, 5000)]));
    final update = timeline.snapshotAt(3000)!;
    expect(update.mainActiveIndices, [1]);
    expect(update.backgroundActiveIndices, [0]);
    expect(update.layoutIndices, [1]);
    expect(update.primaryIndex, 1);
  });

  test('parallel retention is independent of agent and short overlap', () {
    for (final agent in ['v1', 'v2']) {
      final timeline = TtmlTimeline(
        Ttml([_line(0, 3000), _line(2900, 4000, agent: agent)]),
      );
      final update = timeline.snapshotAt(2900)!;
      expect(update.mainActiveIndices, [0, 1]);
      expect(update.layoutIndices, [0, 1]);
      expect(timeline.snapshotAt(3000)!.layoutIndices, [0, 1]);
    }
  });

  test(
    'a new row collapses a finished main line even if its background is singing',
    () {
      final second = _line(500, 3500, agent: 'v2')
        ..bgText = '声'
        ..bgStart = const Duration(milliseconds: 3500)
        ..bgEnd = const Duration(milliseconds: 8000);
      final timeline = TtmlTimeline(
        Ttml([_line(0, 3000), second, _line(6500, 9000)]),
      );
      expect(timeline.snapshotAt(4000)!.layoutIndices, [0, 1]);
      final update = timeline.snapshotAt(6500)!;
      expect(update.layoutIndices, [2]);
      expect(update.mainActiveIndices, [2]);
      expect(update.backgroundActiveIndices, [1]);
      expect(update.primaryIndex, 2);
    },
  );
}

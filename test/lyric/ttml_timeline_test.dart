import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/lyric/ttml.dart';
import 'package:pure_music/lyric/ttml_timeline.dart';

SyncLyricLine line(int start, int end, {int? bgStart, int? bgEnd}) {
  final result = SyncLyricLine(
    Duration(milliseconds: start),
    Duration(milliseconds: end - start),
    [
      SyncLyricWord(
        Duration(milliseconds: start),
        Duration(milliseconds: end - start),
        '字',
        hasExplicitEnd: true,
      ),
    ],
  )..agent = 'v1';
  if (bgStart != null && bgEnd != null) {
    result.bgText = '声';
    result.bgStart = Duration(milliseconds: bgStart);
    result.bgEnd = Duration(milliseconds: bgEnd);
    result.bgWords = [
      SyncLyricWord(
        Duration(milliseconds: bgStart),
        Duration(milliseconds: bgEnd - bgStart),
        '声',
        hasExplicitEnd: true,
      ),
    ];
  }
  return result;
}

void main() {
  test(
    'parsed source timings retain same-agent main and background groups',
    () {
      final lyric = Ttml.fromTtmlText(
        File('test/fixtures/ttml/parallel_a.redacted.xml').readAsStringSync(),
      );
      expect(lyric, isNotNull);
      final parsed = lyric!;
      int row(int start) =>
          parsed.lines.indexWhere((line) => line.start.inMilliseconds == start);
      final first = row(305755);
      final second = row(310550);
      final third = row(317804);
      expect([first, second, third], everyElement(greaterThanOrEqualTo(0)));
      final timeline = TtmlTimeline(parsed);
      final overlap = timeline.snapshotAt(310550)!;
      expect(overlap.mainActiveIndices, [second]);
      expect(overlap.backgroundActiveIndices, [first]);
      expect(overlap.layoutIndices, [first, second]);
      expect(overlap.primaryIndex, first);
      expect(timeline.snapshotAt(318000)!.layoutIndices, [first, third]);
      final parent = parsed.lines[first] as SyncLyricLine;
      expect(
        (parent.words.last.start + parent.words.last.length).inMilliseconds,
        309582,
      );
      expect(parent.bgEnd!.inMilliseconds, 318410);
    },
  );

  test('parsed source handles delayed backgrounds and short duet overlaps', () {
    final lyric = Ttml.fromTtmlText(
      File('test/fixtures/ttml/parallel_b.redacted.xml').readAsStringSync(),
    );
    expect(lyric, isNotNull);
    final parsed = lyric!;
    int row(int start) =>
        parsed.lines.indexWhere((line) => line.start.inMilliseconds == start);
    final timeline = TtmlTimeline(parsed);
    final delayed = row(13719);
    final older = row(36810);
    final newer = row(40281);
    final tail = row(224520);
    final incoming = row(231030);
    expect([
      delayed,
      older,
      newer,
      tail,
      incoming,
    ], everyElement(greaterThanOrEqualTo(0)));
    expect(timeline.snapshotAt(14400)!.layoutIndices, [delayed]);
    expect(timeline.snapshotAt(14400)!.backgroundActiveIndices, isEmpty);
    expect(timeline.snapshotAt(15000)!.backgroundActiveIndices, [delayed]);
    expect(timeline.snapshotAt(40281)!.layoutIndices, [older, newer]);
    expect(timeline.snapshotAt(40281)!.mainActiveIndices, [older, newer]);
    expect(timeline.snapshotAt(231030)!.layoutIndices, [tail, incoming]);
    expect(timeline.snapshotAt(231030)!.primaryIndex, tail);
  });

  test('same-agent background overlap retains the first displayed row', () {
    final timeline = TtmlTimeline(
      Ttml([
        line(305755, 309582, bgStart: 309221, bgEnd: 318410),
        line(310550, 313957),
        line(317804, 321489, bgStart: 320192, bgEnd: 324655),
        line(321690, 325442),
        line(324662, 333909),
        line(335744, 340899),
      ]),
    );
    final firstOverlap = timeline.snapshotAt(310550)!;
    expect(firstOverlap.mainActiveIndices, [1]);
    expect(firstOverlap.backgroundActiveIndices, [0]);
    expect(firstOverlap.layoutIndices, [0, 1]);
    expect(firstOverlap.primaryIndex, 0);
    expect(timeline.snapshotAt(314000)!.layoutIndices, [0, 1]);
    expect(timeline.snapshotAt(318000)!.layoutIndices, [0, 2]);
    expect(timeline.snapshotAt(318410)!.primaryIndex, 0);
    expect(timeline.snapshotAt(321690)!.layoutIndices, [2, 3]);
    expect(timeline.snapshotAt(324662)!.layoutIndices, [3, 4]);
    expect(timeline.snapshotAt(340899)!.layoutIndices, isEmpty);
    expect(timeline.nextBoundaryAfter(340899), isNull);
  });

  test('background after the paragraph end keeps its parent available', () {
    final timeline = TtmlTimeline(
      Ttml([
        line(13719, 14301, bgStart: 14457, bgEnd: 15143),
        line(15253, 15933, bgStart: 16114, bgEnd: 16845),
        line(16839, 17539, bgStart: 17785, bgEnd: 18400),
      ]),
    );
    expect(timeline.snapshotAt(14400)!.mainActiveIndices, isEmpty);
    expect(timeline.snapshotAt(14400)!.backgroundActiveIndices, isEmpty);
    expect(timeline.snapshotAt(14400)!.layoutIndices, [0]);
    expect(timeline.nextBoundaryAfter(14301), 14457);
    expect(timeline.snapshotAt(15000)!.backgroundActiveIndices, [0]);
    expect(timeline.snapshotAt(15000)!.primaryIndex, 0);
    expect(timeline.snapshotAt(16839)!.layoutIndices, [1, 2]);
  });

  test('short overlap is not removed by a pre-switch threshold', () {
    final timeline = TtmlTimeline(
      Ttml([line(36810, 40410)..agent = 'v2', line(40281, 41864)]),
    );
    final update = timeline.snapshotAt(40281)!;
    expect(update.mainActiveIndices, [0, 1]);
    expect(update.layoutIndices, [0, 1]);
    expect(update.primaryIndex, 0);
    expect(timeline.snapshotAt(40410)!.mainActiveIndices, [1]);
    expect(timeline.snapshotAt(40410)!.layoutIndices, [0, 1]);
  });

  test('active row count is not capped and snapshots are seek-independent', () {
    final timeline = TtmlTimeline(
      Ttml([for (var i = 0; i < 12; i++) line(i * 100, 20000)]),
    );
    expect(
      timeline.snapshotAt(1200)!.layoutIndices,
      List.generate(12, (i) => i),
    );
    timeline.snapshotAt(20000);
    expect(
      timeline.snapshotAt(1200)!.layoutIndices,
      List.generate(12, (i) => i),
    );
    expect(timeline.snapshotAt(0)!.layoutIndices, [0]);
  });

  test('zero-duration words do not acquire the paragraph lifetime', () {
    final zero = line(1000, 1000)..length = const Duration(seconds: 8);
    final timeline = TtmlTimeline(Ttml([zero]));
    expect(timeline.snapshotAt(2000)!.mainActiveIndices, isEmpty);
    expect(timeline.snapshotAt(2000)!.layoutIndices, isEmpty);
  });
}

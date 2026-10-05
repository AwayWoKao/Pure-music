import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/page/now_playing_page/component/lyric_view_tile.dart';

void main() {
  test('interlude fades in over the entry window', () {
    expect(lyricTransitionEnterOpacity(0, 0.12), 0);
    expect(lyricTransitionEnterOpacity(0.06, 0.12), greaterThan(0));
    expect(lyricTransitionEnterOpacity(0.12, 0.12), closeTo(1, 0.001));
    expect(lyricTransitionEnterOpacity(0.5, 0.12), closeTo(1, 0.001));
  });

  test('enter opacity clamps outside its progress range', () {
    expect(lyricTransitionEnterOpacity(-1, 0.12), 0);
    expect(lyricTransitionEnterOpacity(2, 0.12), closeTo(1, 0.001));
  });

  test('dots extinguish in reverse lighting order near the end', () {
    // 窗口开始前三个点都全亮。
    expect(lyricTransitionDotExitOpacity(0.5, 0, 0.18, 1.0), 1);
    expect(lyricTransitionDotExitOpacity(0.5, 2, 0.18, 1.0), 1);
    // dot3 最先熄灭，dot1 最后熄灭。
    expect(lyricTransitionDotExitOpacity(0.9, 2, 0.18, 1.0), 0);
    expect(lyricTransitionDotExitOpacity(0.9, 1, 0.18, 1.0), greaterThan(0));
    expect(lyricTransitionDotExitOpacity(0.9, 0, 0.18, 1.0), 1);
    // 结束时全部熄灭。
    expect(lyricTransitionDotExitOpacity(1, 0, 0.18, 1.0), 0);
    expect(lyricTransitionDotExitOpacity(1, 1, 0.18, 1.0), 0);
    expect(lyricTransitionDotExitOpacity(1, 2, 0.18, 1.0), 0);
  });

  test('collapse factor holds, then reaches zero at exit end', () {
    expect(lyricTransitionCollapseFactor(0, 0.18, 0.86), 1);
    expect(lyricTransitionCollapseFactor(0.6, 0.18, 0.86), 1);
    expect(lyricTransitionCollapseFactor(0.7, 0.18, 0.86), lessThan(1));
    expect(lyricTransitionCollapseFactor(0.7, 0.18, 0.86), greaterThan(0));
    // 退场在 exitEnd（切行测量前）收完，之后保持为 0。
    expect(lyricTransitionCollapseFactor(0.86, 0.18, 0.86), 0);
    expect(lyricTransitionCollapseFactor(1, 0.18, 0.86), 0);
  });

  test('collapse factor clamps outside its progress range', () {
    expect(lyricTransitionCollapseFactor(-1, 0.18, 0.86), 1);
    expect(lyricTransitionCollapseFactor(2, 0.18, 0.86), 0);
  });

  test('only the current interlude reserves layout height', () {
    final line = SyncLyricLine(
      Duration.zero,
      const Duration(seconds: 5),
      const [],
    );
    expect(lyricLineIsTransitionTile(line), isTrue);
    expect(
      lyricTransitionLayoutHeight(line, isMain: true),
      transitionTileHeight,
    );
    expect(lyricTransitionLayoutHeight(line, isMain: false), 0);
  });

  test('short blanks are not reserved as transition tiles', () {
    final line = SyncLyricLine(
      Duration.zero,
      const Duration(seconds: 1),
      const [],
    );
    expect(lyricLineIsTransitionTile(line), isFalse);
    expect(lyricTransitionLayoutHeight(line, isMain: true), 0);
  });

  testWidgets('interlude height collapses after it ends', (tester) async {
    final line = SyncLyricLine(
      Duration.zero,
      const Duration(seconds: 8),
      const [],
    );
    Widget tile(double positionMs) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: LyricTransitionTile(
                syncLine: line,
                positionMs: positionMs,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(tile(0));
    await tester.pumpWidget(tile(4000));
    expect(
      tester.getSize(find.byType(LyricTransitionTile)).height,
      transitionTileHeight,
    );
    await tester.pumpWidget(tile(8000));
    expect(tester.getSize(find.byType(LyricTransitionTile)).height, 0);
  });
}

import 'package:flutter_test/flutter_test.dart';
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
    expect(lyricTransitionDotExitOpacity(0.5, 0, 0.18), 1);
    expect(lyricTransitionDotExitOpacity(0.5, 2, 0.18), 1);
    // dot3 最先熄灭，dot1 最后熄灭。
    expect(lyricTransitionDotExitOpacity(0.9, 2, 0.18), 0);
    expect(lyricTransitionDotExitOpacity(0.9, 1, 0.18), greaterThan(0));
    expect(lyricTransitionDotExitOpacity(0.9, 0, 0.18), 1);
    // 结束时全部熄灭。
    expect(lyricTransitionDotExitOpacity(1, 0, 0.18), 0);
    expect(lyricTransitionDotExitOpacity(1, 1, 0.18), 0);
    expect(lyricTransitionDotExitOpacity(1, 2, 0.18), 0);
  });

  test('collapse factor holds, then reaches zero at the end', () {
    expect(lyricTransitionCollapseFactor(0, 0.18), 1);
    expect(lyricTransitionCollapseFactor(0.8, 0.18), 1);
    expect(lyricTransitionCollapseFactor(0.9, 0.18), lessThan(1));
    expect(lyricTransitionCollapseFactor(0.9, 0.18), greaterThan(0));
    expect(lyricTransitionCollapseFactor(1, 0.18), 0);
  });

  test('collapse factor clamps outside its progress range', () {
    expect(lyricTransitionCollapseFactor(-1, 0.18), 1);
    expect(lyricTransitionCollapseFactor(2, 0.18), 0);
  });
}

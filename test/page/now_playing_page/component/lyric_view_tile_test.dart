import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/page/now_playing_page/component/lyric_view_tile.dart';

void main() {
  test('interlude fades in, stays visible, then fades out', () {
    expect(lyricTransitionOpacity(0), 0);
    expect(lyricTransitionOpacity(0.06), greaterThan(0));
    expect(lyricTransitionOpacity(0.5), closeTo(1, 0.001));
    expect(lyricTransitionOpacity(0.94), greaterThan(0));
    expect(lyricTransitionOpacity(1), 0);
  });

  test('interlude opacity clamps outside its progress range', () {
    expect(lyricTransitionOpacity(-1), 0);
    expect(lyricTransitionOpacity(2), 0);
  });
}

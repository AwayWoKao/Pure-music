import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/lyric/ttml.dart';

void main() {
  test('keeps explicit main-word timing separate from a background tail', () {
    final lyric = Ttml.fromTtmlText('''
<tt>
  <body>
    <div>
      <p begin="00:01.000" end="00:06.000">
        <span begin="00:01.000" end="00:02.500">主行</span>
        <span role="x-bg" begin="00:02.000" end="00:06.000">和声</span>
      </p>
    </div>
  </body>
</tt>
''');

    expect(lyric, isNotNull);
    final line = lyric!.lines.single as SyncLyricLine;
    expect(line.words.single.start, const Duration(seconds: 1));
    expect(line.words.single.length, const Duration(milliseconds: 1500));
    expect(line.bgStart, const Duration(seconds: 2));
    expect(line.bgEnd, const Duration(seconds: 6));
    expect(line.length, const Duration(seconds: 5));
    expect(line.words.single.hasExplicitEnd, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/lyric/ttml.dart';

void main() {
  test(
    'parses paragraphs directly under body and resolves relative voice times',
    () {
      final lyric = Ttml.fromTtmlText('''
<tt>
  <body>
    <p begin="00:10.000" end="00:14.000">
      <span begin="0s" end="500ms">主行</span>
      <span role="x-bg" begin="1s" end="2s">和声</span>
      <span role="x-translation" xml:lang="zh-CN">翻译</span>
    </p>
  </body>
      </tt>
''');

      expect(lyric, isNotNull);
      final line = lyric!.lines.whereType<SyncLyricLine>().firstWhere(
        (line) => line.words.isNotEmpty,
      );
      expect(line.words.single.start, const Duration(seconds: 10));
      expect(line.words.single.length, const Duration(milliseconds: 500));
      expect(line.translation, '翻译');
      expect(line.bgStart, const Duration(seconds: 11));
      expect(line.bgEnd, const Duration(seconds: 12));
    },
  );
}

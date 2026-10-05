import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/library/union_search_result.dart';

Audio _audio(String title, String path) => Audio(
  title,
  'Artist',
  'Album',
  null,
  1,
  60,
  320,
  44100,
  path,
  1,
  1,
  'test',
);

void main() {
  setUp(() {
    AudioLibrary.instance.dispose();
  });

  test('precomputed search matches title and pinyin initials', () {
    AudioLibrary.instance.audioCollection = [
      _audio('晴天', r'C:\Music\a.mp3'),
      _audio('Numb', r'C:\Music\b.mp3'),
    ];

    expect(UnionSearchResult.search('numb').audios.single.title, 'Numb');
    expect(UnionSearchResult.search('qt').audios.single.title, '晴天');
  });

  test('search finds one title among 10000 cached entries', () {
    AudioLibrary.instance.audioCollection = [
      for (var i = 0; i < 10000; i++)
        _audio('Track $i', 'C:\\Music\\$i.mp3'),
    ];
    final result = UnionSearchResult.search('track 9999');
    expect(result.audios.single.title, 'Track 9999');
  });
}

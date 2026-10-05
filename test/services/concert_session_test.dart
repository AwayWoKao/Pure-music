import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/services/concert_session.dart';

void main() {
  test('short set still splits into opening climax and outro', () {
    final sections = concertSectionsFor(count: 5, climaxPosition: 0.82);
    expect(sections.map((section) => section.name), ['开场', '压轴', '尾声']);
    expect(sections.first.start, 0);
    expect(sections.last.end, 5);
  });

  test('medium set keeps three acts including combined climax outro', () {
    final sections = concertSectionsFor(count: 12, climaxPosition: 0.82);
    expect(sections.map((section) => section.name), ['开场', '主轴', '压轴 · 尾声']);
    expect(sections.first.start, 0);
    expect(sections.last.end, 12);
  });

  test('long set uses six concert acts', () {
    final sections = concertSectionsFor(count: 24, climaxPosition: 0.82);
    expect(sections.map((section) => section.name), [
      '开场',
      '升温',
      '回落',
      '冲刺',
      '压轴',
      '尾声',
    ]);
    expect(sections.first.start, 0);
    expect(sections.last.end, 24);
  });

  test('two tracks do not create empty acts', () {
    expect(concertSectionsFor(count: 2, climaxPosition: 0.82), isEmpty);
    expect(concertActAt(const [], 0, length: 2), '演出');
  });

  test('queue layout prefixes each act with a header slot', () {
    final sections = concertSectionsFor(count: 8, climaxPosition: 0.82);
    final layout = concertQueueLayout(8, sections);
    expect(layout.first, -1);
    expect(layout.where((value) => value >= 0).length, 8);
  });

  test('playlist match requires the same order', () {
    expect(concertPlaylistMatches(['a', 'b'], ['a', 'b']), isTrue);
    expect(concertPlaylistMatches(['a', 'b'], ['b', 'a']), isFalse);
  });

  test('song offset includes act headers', () {
    final sections = [
      const ConcertSection(name: '开场', start: 0, end: 2),
      const ConcertSection(name: '压轴', start: 2, end: 4),
    ];
    expect(concertSongScrollOffset(0, sections), kConcertActHeaderExtent);
    expect(
      concertSongScrollOffset(2, sections),
      kConcertActHeaderExtent * 2 + kConcertSongExtent * 2,
    );
  });
}

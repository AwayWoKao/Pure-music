import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/utils.dart';

void main() {
  test('natural comparison preserves numeric and leading-zero ordering', () {
    final values = ['Track 10', 'Track 02', 'Track 2', 'Track 1'];

    sortNaturallyBy(values, (value) => value);

    expect(values, ['Track 1', 'Track 2', 'Track 02', 'Track 10']);
  });

  test('natural comparison handles integers larger than machine words', () {
    final values = [
      'Track 99999999999999999999999999999999999999',
      'Track 100000000000000000000000000000000000000',
      'Track 2',
    ];

    sortNaturallyBy(values, (value) => value);

    expect(values, [
      'Track 2',
      'Track 99999999999999999999999999999999999999',
      'Track 100000000000000000000000000000000000000',
    ]);
  });

  test('prepared natural sort reuses keys and supports descending order', () {
    final values = ['歌曲 10', '歌曲 2', '歌曲 2'];

    sortNaturallyBy(values, (value) => value, descending: true);

    expect(values, ['歌曲 10', '歌曲 2', '歌曲 2']);
  });

  test('latin case does not jump ahead of pinyin', () {
    final values = ['Banana', '爱', 'apple', 'Hello'];

    sortNaturallyBy(values, (value) => value);

    expect(values, ['爱', 'apple', 'Banana', 'Hello']);
  });

  test('decorative prefixes do not steal the title letter', () {
    final values = ['【官方】晴天', '《七里香》', '02. 稻香', '晴天'];

    sortNaturallyBy(values, (value) => value);

    expect(values.first, '02. 稻香');
    expect(values[1], '《七里香》');
    expect(values.sublist(2).toSet(), {'【官方】晴天', '晴天'});
    expect(alphabetSectionFor('【官方】晴天'), 'Q');
    expect(alphabetSectionFor('《七里香》'), 'Q');
    expect(alphabetSectionFor('02. 稻香'), 'D');
  });

  test('leading track numbers are ignored but years in titles are kept', () {
    final values = ['02. 晴天', '365天', '01 - 七里香'];

    sortNaturallyBy(values, (value) => value);

    expect(values, ['365天', '01 - 七里香', '02. 晴天']);
  });

  test('empty titles stay last in both directions', () {
    final ascending = ['晴天', '', '七里香'];
    sortNaturallyBy(ascending, (value) => value);
    expect(ascending.last, '');

    final descending = ['晴天', '', '七里香'];
    sortNaturallyBy(descending, (value) => value, descending: true);
    expect(descending.last, '');
  });

  test('fullwidth digits and punctuation follow halfwidth titles', () {
    final values = ['０２．晴天', '七里香'];

    sortNaturallyBy(values, (value) => value);

    expect(values, ['七里香', '０２．晴天']);
  });

  test('joined keys keep later fields as tie breakers', () {
    final values = [
      joinNaturalSortKeys(['同一专辑', '0001-0002', 'B']),
      joinNaturalSortKeys(['同一专辑', '0001-0001', 'A']),
    ];

    sortNaturallyBy(values, (value) => value);

    expect(values.first, joinNaturalSortKeys(['同一专辑', '0001-0001', 'A']));
  });

  test('integer ties keep a stable name order across repeated sorts', () {
    final items = [
      (count: 2, name: 'Bravo'),
      (count: 2, name: 'Alpha'),
      (count: 1, name: 'Zulu'),
      (count: 2, name: 'Charlie'),
    ];

    sortByIntegerThenNatural(
      items,
      valueOf: (item) => item.count,
      tieBreakOf: (item) => item.name,
      descending: true,
    );
    expect(items.map((item) => item.name).toList(), [
      'Alpha',
      'Bravo',
      'Charlie',
      'Zulu',
    ]);

    sortByIntegerThenNatural(
      items,
      valueOf: (item) => item.count,
      tieBreakOf: (item) => item.name,
      descending: true,
    );
    expect(items.map((item) => item.name).toList(), [
      'Alpha',
      'Bravo',
      'Charlie',
      'Zulu',
    ]);
  });
}

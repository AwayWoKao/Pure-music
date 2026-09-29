import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/native/rust/api/tag_reader.dart'
    as rust_tag_reader;
import 'package:pure_music/page/audio_detail_metadata_cache.dart';

void main() {
  test(
    'deduplicates concurrent reads and stores successful metadata',
    () async {
      final audio = _audio(1);
      final metadata = _metadata('genre', 'rock');
      final pending = Completer<rust_tag_reader.AudioExtraMetadata>();
      var calls = 0;
      final cache = AudioDetailMetadataCache(
        loader: (_) {
          calls++;
          return pending.future;
        },
      );

      final first = cache.get(audio);
      final second = cache.get(audio);

      expect(calls, 1);
      pending.complete(metadata);
      expect(await first, same(metadata));
      expect(await second, same(metadata));
      expect(cache.entryCount, 1);
    },
  );

  test('removes failed reads so the next request can retry', () async {
    final audio = _audio(2);
    var calls = 0;
    final cache = AudioDetailMetadataCache(
      loader: (_) {
        calls++;
        if (calls == 1) {
          return Future<rust_tag_reader.AudioExtraMetadata>.error(
            StateError('temporary failure'),
          );
        }
        return Future.value(_metadata('genre', 'jazz'));
      },
    );

    await expectLater(cache.get(audio), throwsA(isA<StateError>()));
    expect(cache.entryCount, 0);
    expect(await cache.get(audio), isNotNull);
    expect(calls, 2);
  });

  test('keeps completed metadata within the configured LRU limit', () async {
    var calls = 0;
    final cache = AudioDetailMetadataCache(
      maxEntries: 2,
      loader: (audio) {
        calls++;
        return Future.value(_metadata('title', audio.title));
      },
    );

    await cache.get(_audio(1));
    await cache.get(_audio(2));
    await cache.get(_audio(3));

    expect(cache.entryCount, 2);
    await cache.get(_audio(1));
    expect(calls, 4);
  });

  test(
    'evicting an in-flight read prevents it from repopulating the cache',
    () async {
      final audio = _audio(4);
      final firstPending = Completer<rust_tag_reader.AudioExtraMetadata>();
      final secondPending = Completer<rust_tag_reader.AudioExtraMetadata>();
      var calls = 0;
      final cache = AudioDetailMetadataCache(
        loader: (_) {
          calls++;
          return calls == 1 ? firstPending.future : secondPending.future;
        },
      );

      final first = cache.get(audio);
      cache.evict(audio);
      final second = cache.get(audio);

      expect(calls, 2);
      firstPending.complete(_metadata('title', 'old'));
      expect(await first, isNotNull);
      expect(cache.entryCount, 0);

      secondPending.complete(_metadata('title', 'new'));
      expect(await second, isNotNull);
      expect(cache.entryCount, 1);
    },
  );
}

Audio _audio(int index) => Audio(
  'Track $index',
  'Artist',
  'Album',
  null,
  1,
  180,
  null,
  null,
  'C:\\music\\track_$index.flac',
  1,
  1,
  null,
);

rust_tag_reader.AudioExtraMetadata _metadata(String key, String value) =>
    rust_tag_reader.AudioExtraMetadata(
      extension_: 'flac',
      fileSize: BigInt.from(1),
      items: [rust_tag_reader.AudioExtraItem(key: key, value: value)],
    );

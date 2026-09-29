import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/native/rust/api/tag_reader.dart'
    as rust_tag_reader;
import 'package:pure_music/page/audio_detail_metadata_cache.dart';

void main() {
  test('does not apply metadata after the owner is unmounted', () async {
    final pending = Completer<rust_tag_reader.AudioExtraMetadata>();
    var mounted = true;
    var applied = 0;

    final applying = applyAudioDetailMetadataIfMounted(
      future: pending.future,
      isMounted: () => mounted,
      apply: (_) => applied++,
    );

    mounted = false;
    pending.complete(_metadata());

    expect(await applying, isFalse);
    expect(applied, 0);
  });

  test('applies metadata while the owner is still mounted', () async {
    var applied = 0;

    final result = await applyAudioDetailMetadataIfMounted(
      future: Future.value(_metadata()),
      isMounted: () => true,
      apply: (_) => applied++,
    );

    expect(result, isTrue);
    expect(applied, 1);
  });
}

rust_tag_reader.AudioExtraMetadata _metadata() =>
    rust_tag_reader.AudioExtraMetadata(
      extension_: 'flac',
      fileSize: BigInt.zero,
      items: [],
    );

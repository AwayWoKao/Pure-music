import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/cache.dart';

void main() {
  final cache = CoverImageCache.instance;

  setUp(() {
    cache.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('recreated provider reuses a decoded cover after unmount', (
    tester,
  ) async {
    const path = r'C:\music\album\track.flac';
    final provider = cache.stableImageForTesting(
      path: path,
      width: 48,
      height: 48,
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Image(image: provider, width: 48, height: 48),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final restored = cache.getCached(path: path, width: 48, height: 48);

    expect(restored, isNotNull);
    expect(
      await restored!.obtainKey(ImageConfiguration.empty),
      await provider.obtainKey(ImageConfiguration.empty),
    );
  });

  test('stable key metadata does not grow with album count', () {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
      'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    cache.stableImageForTesting(
      path: 'track-seed.flac',
      width: 48,
      height: 48,
      bytes: bytes,
    );
    final configurationCount = cache.stableImageConfigurationCountForTesting;
    for (var index = 0; index < 2000; index++) {
      cache.stableImageForTesting(
        path: 'track-$index.flac',
        width: 48,
        height: 48,
        bytes: bytes,
      );
    }

    expect(cache.stableImageConfigurationCountForTesting, configurationCount);
  });

  testWidgets('decoded bytes cache hits the same path and mtime', (
    tester,
  ) async {
    const path = r'C:\music\album\track.flac';
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    cache.putDecodedBytes(
      path: path,
      width: 160,
      height: 160,
      bytes: bytes,
      modified: 123,
    );

    final hit = await cache.loadBytes(
      path: path,
      width: 160,
      height: 160,
      modified: 123,
    );

    expect(hit, same(bytes));
  });

  testWidgets('decoded bytes cache key includes mtime', (tester) async {
    const path = r'C:\music\album\track.flac';
    final first = Uint8List.fromList([1]);
    final second = Uint8List.fromList([2]);
    cache.putDecodedBytes(
      path: path,
      width: 160,
      height: 160,
      bytes: first,
      modified: 1,
    );
    cache.putDecodedBytes(
      path: path,
      width: 160,
      height: 160,
      bytes: second,
      modified: 2,
    );

    expect(
      await cache.loadBytes(path: path, width: 160, height: 160, modified: 1),
      same(first),
    );
    expect(
      await cache.loadBytes(path: path, width: 160, height: 160, modified: 2),
      same(second),
    );
  });

  testWidgets('decoded bytes cache keeps at most 20 covers', (tester) async {
    for (var i = 0; i < 21; i++) {
      cache.putDecodedBytes(
        path: 'track-$i.flac',
        width: 160,
        height: 160,
        bytes: Uint8List.fromList([i]),
        modified: 1,
      );
    }
    expect(cache.decodedBytesCountForTesting, 20);
  });
}

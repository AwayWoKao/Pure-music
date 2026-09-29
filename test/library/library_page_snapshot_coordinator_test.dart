import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/library/library_page_order_cache.dart';
import 'package:pure_music/library/library_page_snapshot_coordinator.dart';

void main() {
  test('coordinates cache writes without owning library generation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pure_music_page_snapshot_coordinator_test_',
    );
    try {
      final source = File(
        '${directory.path}${Platform.pathSeparator}index.json',
      );
      final cachePath = '${directory.path}${Platform.pathSeparator}orders.bin';
      await source.writeAsString('source');
      var context = 'context-a';
      final coordinator = LibraryPageSnapshotCoordinator(
        contextProvider: () => context,
      );
      final spec = await coordinator.resolve(
        sourcePath: source.path,
        cachePath: cachePath,
      );

      coordinator.scheduleWrite(
        spec: spec!,
        generation: 7,
        isGenerationCurrent: (generation) => generation == 7,
        buildOrders: (isCurrent) async {
          if (!isCurrent()) return null;
          return LibraryPageOrders(
            sourceSignature: spec.sourceSignature,
            context: spec.context,
            audios: PageOrderSnapshot(
              sortMethod: 0,
              sortOrderIndex: 0,
              indexes: Uint32List.fromList([0]),
            ),
            artists: PageOrderSnapshot(
              sortMethod: 0,
              sortOrderIndex: 0,
              indexes: Uint32List.fromList([0]),
            ),
            albums: PageOrderSnapshot(
              sortMethod: 0,
              sortOrderIndex: 0,
              indexes: Uint32List.fromList([0]),
            ),
          );
        },
      );
      await coordinator.waitForWrite();

      expect(
        await LibraryPageOrderCache.read(
          cachePath: cachePath,
          sourceSignature: spec.sourceSignature,
          context: spec.context,
          audioCount: 1,
          artistCount: 1,
          albumCount: 1,
        ),
        isNotNull,
      );

      context = 'context-b';
      coordinator.scheduleWrite(
        spec: spec,
        generation: 7,
        isGenerationCurrent: (generation) => generation == 7,
        buildOrders: (_) async {
          fail('stale context must not build a cache payload');
        },
      );
      await coordinator.waitForWrite();

      context = 'context-a';
      final secondSource = File(
        '${directory.path}${Platform.pathSeparator}second-index.json',
      );
      await secondSource.writeAsString('second source');
      final secondSpec = await coordinator.resolve(
        sourcePath: secondSource.path,
        cachePath: '${directory.path}${Platform.pathSeparator}second.bin',
      );
      coordinator.scheduleWrite(
        spec: spec,
        generation: 7,
        isGenerationCurrent: (generation) => generation == 7,
        buildOrders: (_) async {
          fail('stale cache spec must not build a cache payload');
        },
      );
      await coordinator.waitForWrite();
      expect(coordinator.activeSpec, same(secondSpec));

      coordinator.scheduleWrite(
        spec: spec,
        generation: 8,
        isGenerationCurrent: (generation) => generation == 7,
        buildOrders: (_) async {
          fail('stale generation must not build a cache payload');
        },
      );
      await coordinator.waitForWrite();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

import 'dart:async';

import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/library_page_order_cache.dart';

class LibraryPageOrderCacheSpec {
  const LibraryPageOrderCacheSpec({
    required this.sourcePath,
    required this.cachePath,
    required this.sourceSignature,
    required this.context,
  });

  final String sourcePath;
  final String cachePath;
  final LibraryPageSourceSignature sourceSignature;
  final String context;
}

typedef LibraryPageOrdersBuilder =
    Future<LibraryPageOrders?> Function(bool Function() isCurrent);

class LibraryPageSnapshotCoordinator {
  LibraryPageSnapshotCoordinator({required String Function() contextProvider})
    : _contextProvider = contextProvider;

  final String Function() _contextProvider;
  LibraryPageOrderCacheSpec? _activeSpec;
  Future<void>? _pendingWrite;
  int _writeRequest = 0;

  LibraryPageOrderCacheSpec? get activeSpec => _activeSpec;

  Future<LibraryPageOrderCacheSpec?> resolve({
    required String sourcePath,
    required String cachePath,
  }) async {
    final request = ++_writeRequest;
    final sourceSignature = await LibraryPageOrderCache.sourceSignature(
      sourcePath,
    );
    if (request != _writeRequest) return null;
    final spec = sourceSignature == null
        ? null
        : LibraryPageOrderCacheSpec(
            sourcePath: sourcePath,
            cachePath: cachePath,
            sourceSignature: sourceSignature,
            context: _contextProvider(),
          );
    _activeSpec = spec;
    return spec;
  }

  Future<LibraryPageOrders?> read({
    required LibraryPageOrderCacheSpec spec,
    required int audioCount,
    required int artistCount,
    required int albumCount,
  }) {
    return LibraryPageOrderCache.read(
      cachePath: spec.cachePath,
      sourceSignature: spec.sourceSignature,
      context: spec.context,
      audioCount: audioCount,
      artistCount: artistCount,
      albumCount: albumCount,
    );
  }

  void scheduleWrite({
    required LibraryPageOrderCacheSpec spec,
    required int generation,
    required bool Function(int generation) isGenerationCurrent,
    required LibraryPageOrdersBuilder buildOrders,
  }) {
    final request = ++_writeRequest;
    final previous = _pendingWrite;
    late final Future<void> future;
    future = () async {
      await Future<void>.delayed(Duration.zero);
      try {
        if (previous != null) await previous;
        bool isCurrent() =>
            request == _writeRequest &&
            isGenerationCurrent(generation) &&
            identical(_activeSpec, spec) &&
            spec.context == _contextProvider();
        if (!isCurrent()) return;

        final sourceSignature = await LibraryPageOrderCache.sourceSignature(
          spec.sourcePath,
        );
        if (!isCurrent() || sourceSignature != spec.sourceSignature) return;

        final orders = await buildOrders(isCurrent);
        if (orders == null || !isCurrent()) return;
        await LibraryPageOrderCache.write(
          cachePath: spec.cachePath,
          orders: orders,
        );
      } catch (error, trace) {
        log.library.warn('legacy', '页面顺序缓存写入失败', error: error, stackTrace: trace);
      } finally {
        if (identical(_pendingWrite, future)) _pendingWrite = null;
      }
    }();
    _pendingWrite = future;
  }

  Future<void> waitForWrite() async {
    while (true) {
      final pending = _pendingWrite;
      if (pending == null) return;
      await pending;
      if (identical(_pendingWrite, pending)) return;
    }
  }

  void reset() {
    _activeSpec = null;
    _writeRequest++;
  }
}

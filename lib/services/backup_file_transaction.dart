import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pure_music/core/settings.dart';

class BackupFileTransaction {
  BackupFileTransaction(Directory root)
    : _staging = Directory(
        p.join(
          root.path,
          '.backup-import-$pid-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );

  final Directory _staging;
  final _snapshots = <_BackupFileSnapshot>[];
  final _capturedPaths = <String>{};
  bool _closed = false;

  Future<void> writeBytes(File target, List<int> bytes) async {
    _ensureOpen();
    await _capture(target);
    await _writeBytesAtomically(target, bytes);
  }

  Future<void> writeText(File target, String content) async {
    _ensureOpen();
    await _capture(target);
    await writeTextFileAtomically(target.path, content);
  }

  Future<void> commit() async {
    if (_closed) return;
    _closed = true;
    await _deleteStaging();
  }

  Future<void> rollback() async {
    if (_closed) return;
    _closed = true;
    Object? firstError;
    StackTrace? firstTrace;
    try {
      for (final snapshot in _snapshots.reversed) {
        try {
          if (snapshot.backupPath == null) {
            if (await snapshot.target.exists()) {
              await snapshot.target.delete();
            }
            continue;
          }
          final backup = File(snapshot.backupPath!);
          final bytes = await backup.readAsBytes();
          await _writeBytesAtomically(snapshot.target, bytes);
        } catch (error, trace) {
          firstError ??= error;
          firstTrace ??= trace;
        }
      }
    } finally {
      await _deleteStaging();
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstTrace!);
    }
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Backup file transaction is already closed');
    }
  }

  Future<void> _capture(File target) async {
    final key = p.normalize(p.absolute(target.path)).toLowerCase();
    if (!_capturedPaths.add(key)) return;

    await _staging.create(recursive: true);
    if (!await target.exists()) {
      _snapshots.add(_BackupFileSnapshot(target: target));
      return;
    }

    final backup = File(
      p.join(
        _staging.path,
        '${_snapshots.length.toString().padLeft(4, '0')}.bak',
      ),
    );
    await target.copy(backup.path);
    _snapshots.add(
      _BackupFileSnapshot(target: target, backupPath: backup.path),
    );
  }

  Future<void> _writeBytesAtomically(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.backup.$pid.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
    } catch (_) {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _deleteStaging() async {
    try {
      if (await _staging.exists()) {
        await _staging.delete(recursive: true);
      }
    } catch (_) {}
  }
}

final class _BackupFileSnapshot {
  const _BackupFileSnapshot({required this.target, this.backupPath});

  final File target;
  final String? backupPath;
}

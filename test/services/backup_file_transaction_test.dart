import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/services/backup_file_transaction.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pure_music_backup_tx_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('rollback restores replaced files and removes new files', () async {
    final existing = File('${root.path}${Platform.pathSeparator}existing.json');
    await existing.writeAsString('old');
    final created = File('${root.path}${Platform.pathSeparator}created.json');
    final transaction = BackupFileTransaction(root);

    await transaction.writeText(existing, 'new');
    await transaction.writeText(created, 'created');
    await transaction.rollback();

    expect(await existing.readAsString(), 'old');
    expect(await created.exists(), isFalse);
    expect((await root.list().toList()).whereType<Directory>(), isEmpty);
  });

  test('commit keeps writes and removes the staging directory', () async {
    final target = File('${root.path}${Platform.pathSeparator}settings.json');
    final transaction = BackupFileTransaction(root);

    await transaction.writeText(target, '{"version":2}');
    await transaction.commit();

    expect(await target.readAsString(), '{"version":2}');
    expect((await root.list().toList()).whereType<Directory>(), isEmpty);
  });
}

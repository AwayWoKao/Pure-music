import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/services/backup_service.dart';
import 'package:pure_music/services/lastfm/lastfm_models.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pure_music_backup_service_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'credential import overwrites always but merge preserves authorized local data',
    () {
      const authorized = LastFmCredentials(
        apiKey: 'key',
        sharedSecret: 'secret',
        username: 'user',
        sessionKey: 'session',
      );
      const unauthorized = LastFmCredentials(
        apiKey: 'key',
        sharedSecret: 'secret',
      );

      expect(
        shouldImportLastFmCredentials(
          mode: BackupImportMode.overwrite,
          local: authorized,
        ),
        isTrue,
      );
      expect(
        shouldImportLastFmCredentials(
          mode: BackupImportMode.merge,
          local: authorized,
        ),
        isFalse,
      );
      expect(
        shouldImportLastFmCredentials(
          mode: BackupImportMode.merge,
          local: unauthorized,
        ),
        isTrue,
      );
    },
  );

  test('settings overwrite commits all selected files', () async {
    final source = await _writeArchive(
      root,
      entries: {
        'settings/settings.json': '{"Version":"new"}',
        'settings/app_preference.json': '{"startPage":2}',
        'settings/playback_pref.json': '{"lastAudioPath":"new.flac"}',
      },
    );

    final imported = await importBackup(
      sourcePath: source.path,
      mode: BackupImportMode.overwrite,
      dataRoot: root,
    );

    expect(imported, contains(BackupCategory.settings));
    expect(
      await File(
        '${root.path}${Platform.pathSeparator}settings/settings.json',
      ).readAsString(),
      '{"Version":"new"}',
    );
    expect(
      await File(
        '${root.path}${Platform.pathSeparator}settings/app_preference.json',
      ).readAsString(),
      '{"startPage":2}',
    );
    expect(
      await File(
        '${root.path}${Platform.pathSeparator}settings/playback_pref.json',
      ).readAsString(),
      '{"lastAudioPath":"new.flac"}',
    );
  });

  test(
    'failed settings merge restores every file changed before the failure',
    () async {
      final settingsDir = Directory(
        '${root.path}${Platform.pathSeparator}settings',
      );
      await settingsDir.create(recursive: true);
      final settings = File(
        '${settingsDir.path}${Platform.pathSeparator}settings.json',
      );
      final preferences = File(
        '${settingsDir.path}${Platform.pathSeparator}app_preference.json',
      );
      await settings.writeAsString('{"Version":"old","local":true}');
      await preferences.writeAsString('{"startPage":0}');

      final source = await _writeArchive(
        root,
        entries: {
          'settings/settings.json': '{"incoming":true}',
          'settings/app_preference.json': 'not-json',
        },
      );

      await expectLater(
        importBackup(
          sourcePath: source.path,
          mode: BackupImportMode.merge,
          dataRoot: root,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(await settings.readAsString(), '{"Version":"old","local":true}');
      expect(await preferences.readAsString(), '{"startPage":0}');
    },
  );

  test('restores external files and rewrites their settings path', () async {
    final source = await _writeArchive(
      root,
      entries: {
        'settings/settings.json': '{"FontPath":"external/font.ttf"}',
        'external/font.ttf': 'font-data',
      },
      externalFiles: {'FontPath': 'font.ttf'},
    );

    final imported = await importBackup(
      sourcePath: source.path,
      mode: BackupImportMode.overwrite,
      dataRoot: root,
    );

    expect(imported, contains(BackupCategory.settings));
    expect(
      await File(
        '${root.path}${Platform.pathSeparator}external${Platform.pathSeparator}font.ttf',
      ).readAsString(),
      'font-data',
    );
    final settings =
        jsonDecode(
              await File(
                '${root.path}${Platform.pathSeparator}settings${Platform.pathSeparator}settings.json',
              ).readAsString(),
            )
            as Map;
    expect(
      settings['FontPath'],
      endsWith('external${Platform.pathSeparator}font.ttf'),
    );
  });

  test(
    'external path rewrite failure rolls back the copied external file',
    () async {
      final source = await _writeArchive(
        root,
        entries: {
          'settings/settings.json': 'not-json',
          'external/font.ttf': 'font-data',
        },
        externalFiles: {'FontPath': 'font.ttf'},
      );

      await expectLater(
        importBackup(
          sourcePath: source.path,
          mode: BackupImportMode.overwrite,
          dataRoot: root,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        await File(
          '${root.path}${Platform.pathSeparator}settings${Platform.pathSeparator}settings.json',
        ).exists(),
        isFalse,
      );
      expect(
        await File(
          '${root.path}${Platform.pathSeparator}external${Platform.pathSeparator}font.ttf',
        ).exists(),
        isFalse,
      );
    },
  );
}

Future<File> _writeArchive(
  Directory root, {
  required Map<String, String> entries,
  Map<String, String>? externalFiles,
}) async {
  final archive = Archive();
  final manifest = utf8.encode(
    jsonEncode({
      'formatVersion': 2,
      'categories': ['settings'],
      'externalFiles': externalFiles ?? <String, String>{},
    }),
  );
  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  for (final entry in entries.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }

  final file = File('${root.path}${Platform.pathSeparator}backup.zip');
  await file.writeAsBytes(Uint8List.fromList(ZipEncoder().encode(archive)!));
  return file;
}

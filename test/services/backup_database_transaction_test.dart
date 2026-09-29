import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/services/backup_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'playlist and lyric source import rolls back as one database transaction',
    () {
      final database = sqlite3.openInMemory();
      addTearDown(database.dispose);
      database.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        cover_source TEXT
      );
      CREATE TABLE playlist_items (
        playlist_id INTEGER NOT NULL,
        path TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        added_at TEXT
      );
      CREATE TABLE lyric_sources (
        path TEXT PRIMARY KEY,
        source TEXT NOT NULL,
        id TEXT
      );
      CREATE TRIGGER fail_lyric_source_insert
      BEFORE INSERT ON lyric_sources
      BEGIN
        SELECT RAISE(ABORT, 'forced lyric source failure');
      END;
    ''');

      final archive = Archive()
        ..addFile(
          _jsonFile('playlists.json', [
            {
              'name': 'Imported',
              'coverSource': null,
              'items': [
                {'path': 'song.flac', 'sortOrder': 0},
              ],
            },
          ]),
        )
        ..addFile(
          _jsonFile('lyric_sources.json', [
            {'path': 'song.flac', 'source': 'qq', 'id': '1'},
          ]),
        );

      expect(
        () => importPlaylistsAndLyricSourcesForTesting(
          database,
          archive,
          BackupImportMode.overwrite,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        database.select('SELECT COUNT(*) AS c FROM playlists').single['c'],
        0,
      );
      expect(
        database.select('SELECT COUNT(*) AS c FROM playlist_items').single['c'],
        0,
      );
      expect(
        database.select('SELECT COUNT(*) AS c FROM lyric_sources').single['c'],
        0,
      );
    },
  );
}

ArchiveFile _jsonFile(String name, Object value) {
  final bytes = utf8.encode(jsonEncode(value));
  return ArchiveFile(name, bytes.length, bytes);
}

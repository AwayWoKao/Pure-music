import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/library/union_search_result.dart';

const _size = int.fromEnvironment(
  'PURE_MUSIC_SEARCH_SIZE',
  defaultValue: 50000,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  await WidgetsBinding.instance.endOfFrame;

  final library = AudioLibrary.instance;
  final artistCount = (_size * 0.4).round().clamp(1, _size);
  final albumCount = (_size * 0.67).round().clamp(1, _size);
  final artists = <String, Artist>{
    for (var index = 0; index < artistCount; index++)
      'Artist $index': Artist(name: 'Artist $index'),
  };
  final albums = <String, Album>{
    for (var index = 0; index < albumCount; index++)
      'Album $index': Album(name: 'Album $index'),
  };
  final audios = List<Audio>.generate(
    _size,
    (index) => Audio(
      index.isEven ? '歌曲 $index' : 'Track $index',
      index.isEven
          ? '艺术家 ${index % artistCount}'
          : 'Artist ${index % artistCount}',
      'Album ${index % albumCount}',
      null,
      (index % 24) + 1,
      180,
      320,
      44100,
      'C:/Benchmark/Track$index.flac',
      index + 10,
      index + 5,
      'Benchmark',
    ),
    growable: false,
  );
  library
    ..audioCollection = audios
    ..artistCollection = artists
    ..albumCollection = albums;

  final scenarios = <({String name, SearchScope scope, String query})>[
    (name: 'music_english', scope: SearchScope.music, query: 'Track 49999'),
    (name: 'music_chinese', scope: SearchScope.music, query: '歌曲 49998'),
    (name: 'artist_english', scope: SearchScope.artist, query: 'Artist 19999'),
    (name: 'album_english', scope: SearchScope.album, query: 'Album 33499'),
  ];
  final reports = <Map<String, Object?>>[];
  for (final scenario in scenarios) {
    UnionSearchResult.search(scenario.query, scope: scenario.scope);
    final clock = Stopwatch()..start();
    final rssBefore = ProcessInfo.currentRss;
    final result = UnionSearchResult.search(
      scenario.query,
      scope: scenario.scope,
    );
    clock.stop();
    reports.add({
      'scenario': scenario.name,
      'query': scenario.query,
      'scope': scenario.scope.name,
      'elapsedMs': clock.elapsedMicroseconds / 1000,
      'resultCount':
          result.audios.length + result.artists.length + result.album.length,
      'rssBeforeMb': _toMb(rssBefore),
      'rssAfterMb': _toMb(ProcessInfo.currentRss),
    });
  }

  debugPrint(
    'SEARCH_PERF_REPORT ${jsonEncode({'size': _size, 'artists': artistCount, 'albums': albumCount, 'reports': reports})}',
  );
  exit(0);
}

double _toMb(int bytes) =>
    double.parse((bytes / (1024 * 1024)).toStringAsFixed(2));

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/preference.dart';
import 'package:pure_music/play_service/playback_session_store.dart';

void main() {
  test('snapshots defensively copy playlist paths', () {
    final playlistPaths = <String>[r'C:\Music\song.mp3'];
    final original = PlaybackSessionSnapshot(
      lastAudioPath: playlistPaths.single,
      lastPlaylistPaths: playlistPaths,
      lastPlaylistIndex: 0,
      lastShuffleActive: false,
      lastOriginalPlaylistPaths: const [],
      lastPositionSeconds: 0,
    );
    playlistPaths.add(r'C:\Music\other.mp3');

    expect(original.lastPlaylistPaths, [r'C:\Music\song.mp3']);
    expect(
      () => original.lastPlaylistPaths.add(r'C:\Music\other.mp3'),
      throwsUnsupportedError,
    );
  });

  test(
    'reads and writes the persisted playback session as one snapshot',
    () async {
      final preference = PlaybackPreference.fromMap({
        'lastAudioPath': r'C:\Music\old.mp3',
        'lastPlaylistPaths': [r'C:\Music\old.mp3'],
        'lastPlaylistIndex': 0,
        'lastShuffleActive': false,
        'lastOriginalPlaylistPaths': [],
        'lastPositionSeconds': 12.5,
      });
      var saves = 0;
      final store = PlaybackSessionStore(
        preference: preference,
        save: () async {
          saves++;
          return true;
        },
      );

      final snapshot = store.snapshot.copyWith(
        lastAudioPath: r'C:\Music\new.mp3',
        lastPlaylistPaths: [r'C:\Music\new.mp3', r'C:\Music\other.mp3'],
        lastPlaylistIndex: 1,
        lastShuffleActive: true,
        lastOriginalPlaylistPaths: [r'C:\Music\new.mp3'],
        lastPositionSeconds: 42.0,
      );

      expect(await store.save(snapshot), isTrue);
      expect(saves, 1);
      expect(store.snapshot, snapshot);
    },
  );

  test('clears every persisted session field', () async {
    final preference = PlaybackPreference.fromMap({
      'lastAudioPath': r'C:\Music\old.mp3',
      'lastPlaylistPaths': [r'C:\Music\old.mp3'],
      'lastPlaylistIndex': 2,
      'lastShuffleActive': true,
      'lastOriginalPlaylistPaths': [r'C:\Music\old.mp3'],
      'lastPositionSeconds': 12.5,
    });
    final store = PlaybackSessionStore(
      preference: preference,
      save: () async => true,
    );

    expect(await store.clear(), isTrue);
    expect(store.snapshot, PlaybackSessionSnapshot.empty);
  });
}

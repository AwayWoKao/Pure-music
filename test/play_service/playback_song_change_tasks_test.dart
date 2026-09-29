import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/play_service/playback_song_change_tasks.dart';

void main() {
  testWidgets('fires post-song callbacks at their owned deadlines', (
    tester,
  ) async {
    final tasks = PlaybackSongChangeTasks();
    var metadata = 0;
    var prefetch = 0;
    var persist = 0;
    var cleanup = 0;
    final token = tasks.begin();

    tasks.schedule(
      token: token,
      onMetadata: () => metadata++,
      onPrefetch: () => prefetch++,
      onPersist: () => persist++,
      onCleanup: () => cleanup++,
    );

    await tester.pump(const Duration(milliseconds: 95));
    expect(metadata, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(metadata, 1);
    await tester.pump(const Duration(milliseconds: 124));
    expect(prefetch, 1);
    await tester.pump(const Duration(milliseconds: 430));
    expect(persist, 1);
    await tester.pump(const Duration(milliseconds: 1150));
    expect(cleanup, 1);
  });

  testWidgets('cancels timers and invalidates old tokens', (tester) async {
    final tasks = PlaybackSongChangeTasks();
    var callbacks = 0;
    final firstToken = tasks.begin();
    tasks.schedule(
      token: firstToken,
      onMetadata: () => callbacks++,
      onPrefetch: () => callbacks++,
      onPersist: () => callbacks++,
      onCleanup: () => callbacks++,
    );

    final secondToken = tasks.begin();
    tasks.cancel();
    await tester.pump(const Duration(seconds: 2));

    expect(tasks.isCurrent(firstToken), isFalse);
    expect(tasks.isCurrent(secondToken), isTrue);
    expect(callbacks, 0);
  });
}

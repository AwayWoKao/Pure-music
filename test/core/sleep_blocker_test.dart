import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/sleep_blocker.dart';

void main() {
  test('now-playing sleep block requires a visible main window', () {
    expect(
      sleepBlockerShouldPreventSleep(
        pageVisible: true,
        playerPlaying: true,
        mainWindowVisible: true,
        preventSleepOnNowPlaying: true,
      ),
      isTrue,
    );
    expect(
      sleepBlockerShouldPreventSleep(
        pageVisible: true,
        playerPlaying: true,
        mainWindowVisible: false,
        preventSleepOnNowPlaying: true,
      ),
      isFalse,
    );
  });
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/window_placement.dart';

void main() {
  const screen = (x: 0, y: 0, width: 1920, height: 1080);

  test('saved placement on the current virtual screen is kept', () {
    expect(
      windowPlacementIsOnscreen(
        position: const Offset(100, 80),
        size: const Size(1280, 756),
        devicePixelRatio: 1,
        screen: screen,
      ),
      isTrue,
    );
  });

  test('placement on a disconnected monitor is rejected', () {
    expect(
      windowPlacementIsOnscreen(
        position: const Offset(4000, 80),
        size: const Size(1280, 756),
        devicePixelRatio: 1,
        screen: screen,
      ),
      isFalse,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/settings.dart';
import 'package:pure_music/page/audio_detail_page.dart';

void main() {
  tearDown(() async {
    await AppSettings.readFromSettingsMapForTest({
      'Version': 'test',
      'AppBackgroundImagePath': null,
      'AppWindowTransparent': false,
    });
  });

  testWidgets('audio detail page provides an opaque page surface', (
    tester,
  ) async {
    await AppSettings.readFromSettingsMapForTest({
      'Version': 'test',
      'AppBackgroundImagePath': null,
      'AppWindowTransparent': false,
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: AudioDetailPageSurface(
          child: SizedBox(key: ValueKey('audio-detail-content')),
        ),
      ),
    );

    final surface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('audio-detail-page-surface')),
    );
    expect(
      surface.color,
      Theme.of(
        tester.element(find.byKey(const ValueKey('audio-detail-content'))),
      ).colorScheme.surfaceContainer,
    );
  });
}

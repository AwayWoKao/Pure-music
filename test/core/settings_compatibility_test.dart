import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/settings.dart';

void main() {
  test('keeps legacy theme setting compatibility', () {
    expect(normalizedThemeOption('ThemeOption.dark'), ThemeOption.dark);
    expect(normalizedThemeOption(1), ThemeOption.light);
    expect(normalizedThemeOption('unknown'), ThemeOption.system);
    expect(normalizedThemeColorMode('monochrome'), ThemeColorMode.independent);
    expect(normalizedThemeColorMode('seed'), ThemeColorMode.material3);
  });

  test('keeps enum name and fallback decoding', () {
    expect(
      normalizedSettingEnumValue(
        'WindowCloseBehavior.minimizeToTray',
        WindowCloseBehavior.values,
      ),
      WindowCloseBehavior.minimizeToTray,
    );
    expect(
      normalizedSettingEnumValue(
        'not-a-behavior',
        WindowCloseBehavior.values,
        fallback: WindowCloseBehavior.exit,
      ),
      WindowCloseBehavior.exit,
    );
  });

  test('keeps stored wavy bar modes decoding', () {
    expect(
      normalizedWavyBarEnabledModes('portrait').single,
      NowPlayingMode.portrait,
    );
    expect(normalizedWavyBarEnabledModes(['portrait', 'invalid']), {
      NowPlayingMode.portrait,
    });
    expect(normalizedWavyBarEnabledModes(null), isEmpty);
  });

  test('keeps legacy values at the settings read boundary', () async {
    final settings = AppSettings.instance;
    final previousThemeOption = settings.themeOption;
    final previousColorMode = settings.themeColorMode;
    final previousStackedEffect = settings.enableStackedScrollEffect;
    final previousCloseBehavior = settings.windowCloseBehavior;
    try {
      await AppSettings.readFromSettingsMapForTest({
        'Version': 'test',
        'ThemeOption': 'ThemeOption.dark',
        'ThemeColorMode': 'monochrome',
        'EnableStackedScrollEffect': 'off',
        'WindowCloseBehavior': 'not-a-behavior',
      });

      expect(settings.themeOption, ThemeOption.dark);
      expect(settings.themeColorMode, ThemeColorMode.independent);
      expect(settings.enableStackedScrollEffect, isFalse);
      expect(settings.windowCloseBehavior, WindowCloseBehavior.exit);
    } finally {
      settings
        ..themeOption = previousThemeOption
        ..themeColorMode = previousColorMode
        ..enableStackedScrollEffect = previousStackedEffect
        ..windowCloseBehavior = previousCloseBehavior;
    }
  });
}

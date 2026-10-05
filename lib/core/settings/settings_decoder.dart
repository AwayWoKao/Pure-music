import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/setting_action_state.dart';
import 'package:pure_music/core/settings/settings_types.dart';

Set<NowPlayingMode> defaultWavyBarEnabledModes() => {};

ThemeOption normalizedThemeOption(Object? value) {
  final index = normalizedEnumIndex(
    value,
    length: ThemeOption.values.length,
    defaultIndex: -1,
  );
  if (index >= 0) return ThemeOption.values[index];

  final name = normalizedSettingEnumName(value);
  for (final option in ThemeOption.values) {
    if (option.name == name) return option;
  }
  return ThemeOption.system;
}

ThemeColorMode normalizedThemeColorMode(Object? value) {
  final index = normalizedEnumIndex(
    value,
    length: ThemeColorMode.values.length,
    defaultIndex: -1,
  );
  if (index >= 0) return ThemeColorMode.values[index];

  return switch (normalizedSettingEnumName(value)) {
    'seed' || 'material3' => ThemeColorMode.material3,
    'monochrome' || 'independent' => ThemeColorMode.independent,
    _ => ThemeColorMode.material3,
  };
}

ThemeColorSource? normalizedThemeColorSource(Object? value) {
  if (value == null) return null;
  final index = normalizedEnumIndex(
    value,
    length: ThemeColorSource.values.length,
    defaultIndex: -1,
  );
  if (index >= 0) return ThemeColorSource.values[index];
  return switch (normalizedSettingEnumName(value)) {
    'cover' => ThemeColorSource.cover,
    'system' => ThemeColorSource.system,
    'custom' => ThemeColorSource.custom,
    _ => null,
  };
}

Set<NowPlayingMode> normalizedWavyBarEnabledModes(Object? value) {
  if (value is String) {
    final mode = NowPlayingMode.fromStoredValue(value);
    return mode == null ? defaultWavyBarEnabledModes() : {mode};
  }
  if (value is! List) return defaultWavyBarEnabledModes();
  if (value.isEmpty) return {};
  final modes = NowPlayingMode.fromList(value);
  return modes.isEmpty ? defaultWavyBarEnabledModes() : modes;
}

String? normalizedSettingEnumName(Object? value) {
  final normalized = normalizedStringSetting(value)?.toLowerCase();
  if (normalized == null) return null;
  final separator = normalized.lastIndexOf('.');
  return separator < 0 ? normalized : normalized.substring(separator + 1);
}

String? normalizedPathSetting(Object? value) {
  final normalized = normalizedStringSetting(value);
  if (normalized == null) return null;
  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.scheme.toLowerCase() == 'file') {
    final host = uri.host.toLowerCase();
    if ((host.isEmpty || host == 'localhost') && uri.path == '/') return null;
    if (host == 'localhost') {
      return uri.replace(host: '').toFilePath(windows: true);
    }
    return uri.toFilePath(windows: true);
  }
  return normalized;
}

T? normalizedSettingEnumValue<T extends Enum>(
  Object? value,
  List<T> values, {
  T? fallback,
}) {
  final index = normalizedEnumIndex(
    value,
    length: values.length,
    defaultIndex: -1,
  );
  if (index >= 0) return values[index];

  final name = normalizedSettingEnumName(value);
  if (name != null) {
    for (final option in values) {
      if (option.name.toLowerCase() == name) return option;
    }
  }
  return fallback;
}

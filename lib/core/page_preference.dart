import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/setting_action_state.dart';

class PagePreference {
  int sortMethod;
  SortOrder sortOrder;
  ContentView contentView;

  PagePreference(this.sortMethod, this.sortOrder, this.contentView);

  Map<String, dynamic> toMap() => {
    'sortMethod': sortMethod,
    'sortOrder': sortOrder.name,
    'contentView': contentView.name,
  };

  factory PagePreference.fromMap(Object? value) {
    final map = value is Map ? value : const <String, dynamic>{};
    return PagePreference(
      _normalizedNonNegativeInt(map['sortMethod']),
      _sortOrderFromStoredValue(map['sortOrder']) ?? SortOrder.ascending,
      _contentViewFromStoredValue(map['contentView']) ?? ContentView.list,
    );
  }
}

int _normalizedNonNegativeInt(Object? value) {
  if (value is int) return value < 0 ? 0 : value;
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt().clamp(0, 0x7fffffff);
  }
  if (value is String) {
    final integer = int.tryParse(value.trim());
    if (integer != null) return integer.clamp(0, 0x7fffffff);
  }
  return 0;
}

SortOrder? _sortOrderFromStoredValue(Object? value) {
  final index = normalizedEnumIndex(
    value,
    length: SortOrder.values.length,
    defaultIndex: -1,
  );
  if (index >= 0) return SortOrder.values[index];
  final name = normalizedStringSetting(value)?.toLowerCase();
  return name == null ? null : SortOrder.fromString(name);
}

ContentView? _contentViewFromStoredValue(Object? value) {
  final index = normalizedEnumIndex(
    value,
    length: ContentView.values.length,
    defaultIndex: -1,
  );
  if (index >= 0) return ContentView.values[index];
  final name = normalizedStringSetting(value)?.toLowerCase();
  return name == null ? null : ContentView.fromString(name);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/setting_action_state.dart';

void main() {
  test('minimized window dimensions restore the default size', () {
    expect(normalizedWindowSizeSetting('158.0,26.0'), defaultWindowSizeSetting);
  });

  test('valid window dimensions are preserved', () {
    expect(normalizedWindowSizeSetting('1280.0,756.0'), (
      width: 1280.0,
      height: 756.0,
    ));
  });

  test('encoded window size roundtrips through the decoder', () {
    expect(normalizedWindowSizeSetting(encodedWindowSizeSetting(1440, 900)), (
      width: 1440.0,
      height: 900.0,
    ));
  });

  test('a comma-only payload restores the default size', () {
    expect(normalizedWindowSizeSetting(','), defaultWindowSizeSetting);
  });

  test('window position keeps negatives for a left-side monitor', () {
    expect(normalizedWindowPositionSetting('-1920.0,80.0'), (
      x: -1920.0,
      y: 80.0,
    ));
  });

  test('invalid window position is ignored', () {
    expect(normalizedWindowPositionSetting(','), isNull);
    expect(normalizedWindowPositionSetting(null), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/lyric_render_config.dart';

LyricRenderConfig _config({bool enableBlur = true}) {
  return LyricRenderConfig(
    textAlign: LyricTextAlign.center,
    baseFontSize: 32,
    translationBaseFontSize: 20,
    showTranslation: true,
    showRoman: true,
    fontWeight: 600,
    enableBlur: enableBlur,
  );
}

void main() {
  test('blur uses four distance steps and caps far lines', () {
    final config = _config();
    expect(config.blurSigmaForDistance(0), 0.0);
    expect(config.blurSigmaForDistance(1), 1.0);
    expect(config.blurSigmaForDistance(2), 1.5);
    expect(config.blurSigmaForDistance(3), 2.0);
    expect(config.blurSigmaForDistance(4), 2.5);
    expect(config.blurSigmaForDistance(9), 2.5);
  });

  test('blur stays off when disabled', () {
    final config = _config(enableBlur: false);
    expect(config.blurSigmaForDistance(1), 0.0);
    expect(config.blurSigmaForDistance(4), 0.0);
  });
}

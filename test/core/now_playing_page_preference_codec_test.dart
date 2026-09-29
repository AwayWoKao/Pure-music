import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/preference.dart';

void main() {
  test(
    'codec preserves protected lyric and audio-reactive preference fields',
    () {
      final preference = NowPlayingPagePreferenceCodec.decode({
        'nowPlayingViewMode': 'withLyric',
        'backgroundMode': 'flowingCover',
        'dynamicFlowingLight': false,
        'audioReactiveFlow': true,
        'showLyricRoman': false,
      });

    expect(preference.nowPlayingViewMode, NowPlayingViewMode.withLyric);
    expect(preference.backgroundMode, NowPlayingBackgroundMode.flowingCover);
    expect(preference.dynamicFlowingLight, isTrue);
    expect(preference.audioReactiveFlow, isTrue);
      expect(preference.showLyricRoman, isFalse);
      expect(
        NowPlayingPagePreferenceCodec.encode(preference)['audioReactiveFlow'],
        isTrue,
      );
    },
  );
}

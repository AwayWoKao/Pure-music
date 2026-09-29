part of 'preference.dart';

class NowPlayingPagePreference {
  NowPlayingViewMode nowPlayingViewMode;
  LyricTextAlign lyricTextAlign;
  double lyricFontSize;
  double translationFontSize;
  bool showLyricTranslation;
  bool showLyricRoman;
  RubyPosition rubyPosition;
  int lyricFontWeight;
  bool enableLyricBlur;
  bool enableLyricGlow;
  LyricLiftStyle liftStyle;
  double liftPeak;
  int liftDurationMs;
  LyricStaggerStyle staggerStyle;
  NowPlayingBackgroundMode backgroundMode;
  bool dynamicFlowingLight;
  bool audioReactiveFlow;

  NowPlayingPagePreference(
    this.nowPlayingViewMode,
    this.lyricTextAlign,
    this.lyricFontSize,
    this.translationFontSize,
    this.showLyricTranslation,
    this.lyricFontWeight,
    this.enableLyricBlur, {
    this.showLyricRoman = true,
    this.rubyPosition = RubyPosition.below,
    this.enableLyricGlow = false,
    this.liftStyle = LyricLiftStyle.vertical,
    this.liftPeak = 2.0,
    this.liftDurationMs = lyricVerticalLiftDurationMs,
    this.staggerStyle = LyricStaggerStyle.smooth,
    this.backgroundMode = NowPlayingBackgroundMode.meshGradient,
    this.dynamicFlowingLight = true,
    this.audioReactiveFlow = false,
  });

  LyricRenderConfig get lyricRenderConfig => LyricRenderConfig(
    textAlign: lyricTextAlign,
    baseFontSize: lyricFontSize,
    translationBaseFontSize: translationFontSize,
    showTranslation: showLyricTranslation,
    showRoman: showLyricRoman,
    lineOrder: rubyPosition.toLineOrder(),
    fontWeight: lyricFontWeight,
    enableBlur: enableLyricBlur,
    enableGlow: enableLyricGlow,
    liftStyle: liftStyle,
    liftPeak: liftPeak,
    liftDurationMs: lyricVerticalLiftDurationMs,
    staggerStyle: staggerStyle,
  );

  Map<String, dynamic> toMap() => {
    'nowPlayingViewMode': nowPlayingViewMode.name,
    'lyricTextAlign': lyricTextAlign.name,
    'lyricFontSize': lyricFontSize,
    'translationFontSize': translationFontSize,
    'showLyricTranslation': showLyricTranslation,
    'showLyricRoman': showLyricRoman,
    'rubyPosition': rubyPosition.name,
    'lyricFontWeight': lyricFontWeight,
    'enableLyricBlur': enableLyricBlur,
    'enableLyricGlow': enableLyricGlow,
    'liftStyle': liftStyle.name,
    'liftPeak': liftPeak,
    'liftDurationMs': lyricVerticalLiftDurationMs,
    'staggerStyle': staggerStyle.name,
    'backgroundMode': backgroundMode.name,
    'dynamicFlowingLight': dynamicFlowingLight,
    'audioReactiveFlow': audioReactiveFlow,
  };

  factory NowPlayingPagePreference.fromMap(Object? value) {
    final map = value is Map ? value : const <String, dynamic>{};
    final backgroundMode =
        _nowPlayingBackgroundModeFromStoredValue(map['backgroundMode']) ??
        NowPlayingBackgroundMode.meshGradient;
    return NowPlayingPagePreference(
      _nowPlayingViewModeFromStoredValue(map['nowPlayingViewMode']) ??
          NowPlayingViewMode.withLyric,
      _lyricTextAlignFromStoredValue(map['lyricTextAlign']) ??
          LyricTextAlign.left,
      _normalizedBoundedDouble(
        map['lyricFontSize'],
        defaultValue: 22.0,
        min: 16.0,
        max: 48.0,
      ),
      _normalizedBoundedDouble(
        map['translationFontSize'],
        defaultValue: 18.0,
        min: 12.0,
        max: 44.0,
      ),
      _normalizedBool(map['showLyricTranslation'], defaultValue: true),
      _normalizedBoundedInt(
        map['lyricFontWeight'],
        defaultValue: 400,
        min: 100,
        max: 900,
      ),
      _normalizedBool(map['enableLyricBlur'], defaultValue: true),
      showLyricRoman: _normalizedBool(
        map['showLyricRoman'],
        defaultValue: true,
      ),
      rubyPosition:
          RubyPosition.fromString((map['rubyPosition'] as String?) ?? '') ??
          RubyPosition.below,
      enableLyricGlow: _normalizedBool(
        map['enableLyricGlow'],
        defaultValue: false,
      ),
      liftStyle:
          LyricLiftStyle.fromString((map['liftStyle'] as String?) ?? '') ??
          LyricLiftStyle.vertical,
      liftPeak: _normalizedBoundedDouble(
        map['liftPeak'],
        defaultValue: 2.0,
        min: 0.5,
        max: 6.0,
      ),
      liftDurationMs: lyricVerticalLiftDurationMs,
      staggerStyle:
          LyricStaggerStyle.fromString(
            (map['staggerStyle'] as String?) ?? '',
          ) ??
          LyricStaggerStyle.smooth,
      backgroundMode: backgroundMode,
      dynamicFlowingLight: true,
      audioReactiveFlow: _normalizedBool(
        map['audioReactiveFlow'],
        defaultValue: false,
      ),
    );
  }
}

class NowPlayingPagePreferenceCodec {
  const NowPlayingPagePreferenceCodec._();

  static NowPlayingPagePreference decode(Object? value) =>
      NowPlayingPagePreference.fromMap(value);

  static Map<String, dynamic> encode(NowPlayingPagePreference value) =>
      value.toMap();
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/lyric_render_config.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/page/now_playing_page/component/lyric_height_cache_key.dart';
import 'package:pure_music/page/now_playing_page/component/lyric_painter_params.dart';
import 'package:pure_music/page/now_playing_page/component/lyrics_line_painter.dart';
import 'package:pure_music/page/now_playing_page/component/lyrics_line_widget.dart';

const _config = LyricRenderConfig(
  textAlign: LyricTextAlign.center,
  baseFontSize: 32,
  translationBaseFontSize: 20,
  showTranslation: true,
  showRoman: true,
  fontWeight: 600,
  enableBlur: true,
);

const _lineWidth = 320.0;
const _beforeBackgroundMs = 10350.0;
const _backgroundActiveMs = 10500.0;

const _scheme = ColorScheme.dark();

SyncLyricLine _backgroundVocalLine() {
  final line = SyncLyricLine(
    const Duration(milliseconds: 10000),
    const Duration(milliseconds: 2000),
    [
      SyncLyricWord(
        const Duration(milliseconds: 10000),
        const Duration(milliseconds: 1900),
        '主唱句子',
      ),
    ],
    '主唱翻译',
    '主唱注音',
  );
  line.bgText = '背景和声句子';
  line.bgTranslation = '背景翻译';
  line.bgStart = const Duration(milliseconds: 10400);
  line.bgEnd = const Duration(milliseconds: 11500);
  return line;
}

double _measureHeight({
  required double currentTimeMs,
  required bool isMainLine,
  bool isHighlightActive = false,
  bool isBackgroundActive = false,
  double? exitVisibility,
}) {
  final line = _backgroundVocalLine();
  return LyricsLinePainter(
    params: LyricPainterParams(
      line: line,
      currentTimeMs: currentTimeMs,
      backgroundVocalVisibilityListenable: exitVisibility == null
          ? null
          : ValueNotifier<double>(exitVisibility),
      blurSigma: 0.0,
      config: _config,
      isMainLine: isMainLine,
      isHighlightActive: isHighlightActive,
      isBackgroundActive: isBackgroundActive,
      accelerateTailHighlight: false,
      useMaterialYouColor: false,
      opacity: 1.0,
      lineMedianWordDuration: Duration.zero,
    ),
    scheme: _scheme,
  ).measureHeight(_lineWidth, reserveBackgroundVocalHeight: true);
}

LyricHeightCacheKey _heightCacheKey(
  LyricLine line, {
  required bool reserveBackgroundVocalHeight,
}) {
  return LyricHeightCacheKey(
    line: line,
    lineWidth: _lineWidth,
    config: _config,
    isMainLine: true,
    useMaterialYouColor: false,
    reserveBackgroundVocalHeight: reserveBackgroundVocalHeight,
    fontFamily: null,
    agent: null,
  );
}

void main() {
  test('highlight end keeps the layout height unchanged', () {
    final active = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: true,
      isHighlightActive: true,
    );
    final ended = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: false,
      isHighlightActive: false,
      isBackgroundActive: true,
    );

    expect(ended, closeTo(active, 0.001));
    expect(active, greaterThan(0));
  });

  test('background vocal trigger grows the layout height', () {
    final beforeTrigger = _measureHeight(
      currentTimeMs: _beforeBackgroundMs,
      isMainLine: true,
      isBackgroundActive: false,
    );
    final afterTrigger = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: true,
      isHighlightActive: true,
      isBackgroundActive: true,
    );

    expect(afterTrigger, greaterThan(beforeTrigger));
  });

  test('background vocal window pushes and releases the layout height', () {
    // bgStart 10400、bgEnd 11500：进场把下文顶开，出场随离场淡出收回。
    final beforeStart = _measureHeight(
      currentTimeMs: 10350,
      isMainLine: true,
      isBackgroundActive: false,
    );
    final atStart = _measureHeight(
      currentTimeMs: 10400,
      isMainLine: true,
      isHighlightActive: true,
      isBackgroundActive: true,
    );
    final midEntry = _measureHeight(
      currentTimeMs: 10600,
      isMainLine: true,
      isHighlightActive: true,
      isBackgroundActive: true,
    );
    final atEnd = _measureHeight(
      currentTimeMs: 11500,
      isMainLine: true,
      isHighlightActive: true,
      isBackgroundActive: true,
    );
    final activeFull = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: true,
      isBackgroundActive: true,
    );
    final halfExit = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: true,
      isBackgroundActive: true,
      exitVisibility: 0.5,
    );
    final endedExit = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: true,
      isBackgroundActive: true,
      exitVisibility: 0.0,
    );

    expect(atStart, closeTo(beforeStart, 0.001));
    expect(midEntry, greaterThan(atStart));
    expect(atEnd, closeTo(beforeStart, 0.001));
    expect(activeFull, greaterThan(beforeStart));
    expect(halfExit, lessThan(activeFull));
    expect(endedExit, closeTo(beforeStart, 0.001));
  });

  test('scale and displacement keep one stable layout height state', () {
    final first = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: true,
      isHighlightActive: true,
      isBackgroundActive: false,
    );
    final second = _measureHeight(
      currentTimeMs: _backgroundActiveMs,
      isMainLine: false,
      isHighlightActive: false,
      isBackgroundActive: true,
    );

    expect(second, closeTo(first, 0.001));

    final line = _backgroundVocalLine();
    final reserved = _heightCacheKey(line, reserveBackgroundVocalHeight: true);
    final repeated = _heightCacheKey(line, reserveBackgroundVocalHeight: true);
    final notReserved = _heightCacheKey(
      line,
      reserveBackgroundVocalHeight: false,
    );
    expect(repeated, reserved);
    expect(repeated.hashCode, reserved.hashCode);
    expect(notReserved, isNot(reserved));
  });

  testWidgets('matrix transform keeps layout height and the top anchor', (
    tester,
  ) async {
    const lineWidth = _lineWidth;
    const layoutHeight = 100.0;
    for (final align in [
      LyricTextAlign.left,
      LyricTextAlign.center,
      LyricTextAlign.right,
    ]) {
      final anchorX = lineWidth * (lyricLineScaleAlignment(align).x + 1) / 2;
      final matrix = lyricLineTransformMatrix(
        scale: 1.3,
        offsetY: -7.5,
        anchorX: anchorX,
        anchorY: 0.0,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Transform(
              transform: matrix,
              child: const SizedBox(width: lineWidth, height: layoutHeight),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(SizedBox)).height, layoutHeight);

      final transform = tester.widget<Transform>(find.byType(Transform));
      final s = transform.transform.storage;
      final anchorMappedX = s[0] * anchorX + s[4] * 0 + s[12];
      final anchorMappedY = s[1] * anchorX + s[5] * 0 + s[13];
      expect(anchorMappedX, closeTo(anchorX, 0.0001));
      expect(anchorMappedY, closeTo(-7.5, 0.0001));
    }
  });

  test('lift holds after the line ends until the next line takes over', () {
    var latched = lyricLineFloatTarget(
      mainHighlight: false,
      isHighlightActive: false,
      wasLatched: false,
    );
    expect(latched, isFalse);

    latched = lyricLineFloatTarget(
      mainHighlight: true,
      isHighlightActive: true,
      wasLatched: latched,
    );
    expect(latched, isTrue);

    latched = lyricLineFloatTarget(
      mainHighlight: false,
      isHighlightActive: true,
      wasLatched: latched,
    );
    expect(latched, isTrue);

    latched = lyricLineFloatTarget(
      mainHighlight: false,
      isHighlightActive: false,
      wasLatched: latched,
    );
    expect(latched, isFalse);
  });

  test('lift does not start before the line sings within its group', () {
    expect(
      lyricLineFloatTarget(
        mainHighlight: false,
        isHighlightActive: true,
        wasLatched: false,
      ),
      isFalse,
    );
    expect(
      lyricLineFloatTarget(
        mainHighlight: true,
        isHighlightActive: false,
        wasLatched: false,
      ),
      isTrue,
    );
  });
}

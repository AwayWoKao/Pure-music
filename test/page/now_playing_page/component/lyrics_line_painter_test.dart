import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pure_music/core/lyric_render_config.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/page/now_playing_page/component/lyric_painter_params.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/page/now_playing_page/component/lyrics_line_painter.dart';

void main() {
  test('authored highlight time ignores layout deadlines and catch-up', () {
    for (final time in [309000.0, 309581.0, 309582.0, 310550.0]) {
      expect(
        lyricHighlightTimeMs(
          currentTimeMs: time,
          lineStartMs: 305755,
          lastWordEndMs: 309582,
          deadlineMs: 309300,
          usesAuthoredTiming: true,
        ),
        time,
      );
    }
  });

  test('background visibility follows its authored time window', () {
    for (final time in [14301.0, 14400.0]) {
      expect(
        lyricBackgroundHeightFactor(
          currentTimeMs: time,
          startMs: 14457,
          endMs: 15143,
          isMainLine: true,
        ),
        0.0,
      );
    }
    expect(
      lyricBackgroundHeightFactor(
        currentTimeMs: 14800,
        startMs: 14457,
        endMs: 15143,
        isMainLine: true,
      ),
      greaterThan(0.0),
    );
    expect(
      lyricBackgroundHeightFactor(
        currentTimeMs: 15253,
        startMs: 14457,
        endMs: 15143,
        isMainLine: true,
      ),
      greaterThan(0.0),
    );
    expect(
      lyricBackgroundHeightFactor(
        currentTimeMs: 15253,
        startMs: 14457,
        endMs: 15143,
        isMainLine: true,
      ),
      lessThan(1.0),
    );
    expect(
      lyricBackgroundHeightFactor(
        currentTimeMs: 15543,
        startMs: 14457,
        endMs: 15143,
        isMainLine: true,
      ),
      0.0,
    );
    expect(
      lyricBackgroundHeightFactor(
        currentTimeMs: 15253,
        startMs: 14457,
        endMs: 15143,
        isMainLine: false,
      ),
      0.0,
    );
  });

  test('each background exit finishes using its own elapsed time', () {
    expect(lyricBackgroundExitVisibility(0), 1.0);
    expect(lyricBackgroundExitVisibility(400), 0.0);
    expect(lyricBackgroundExitVisibility(250), greaterThan(0.0));
    expect(lyricBackgroundExitVisibility(500), 0.0);
    expect(lyricBackgroundExitElapsedMs(1.0), 0.0);
    expect(lyricBackgroundExitElapsedMs(0.0), 400.0);
    expect(
      lyricBackgroundExitVisibility(lyricBackgroundExitElapsedMs(0.4)),
      closeTo(0.4, 0.02),
    );
  });

  group('lyricHighlightTimeMs', () {
    test('keeps the final lyric line on its authored timing', () {
      expect(
        lyricHighlightTimeMs(
          currentTimeMs: 9800,
          lineStartMs: 8000,
          lastWordEndMs: 10000,
          deadlineMs: null,
        ),
        9800,
      );
    });

    test('keeps catch-up when another lyric line follows', () {
      final adjusted = lyricHighlightTimeMs(
        currentTimeMs: 9800,
        lineStartMs: 8000,
        lastWordEndMs: 10100,
        deadlineMs: 10000,
      );

      expect(adjusted, greaterThan(9800));
    });

    test(
      'accelerates the tail when its deadline is just after the final word',
      () {
        final adjusted = lyricHighlightTimeMs(
          currentTimeMs: 9900,
          lineStartMs: 8000,
          lastWordEndMs: 10000,
          deadlineMs: 10032,
        );

        expect(adjusted, greaterThan(9900));
      },
    );

    test('never moves highlight time backwards after a late frame', () {
      final adjusted = lyricHighlightTimeMs(
        currentTimeMs: 10150,
        lineStartMs: 8000,
        lastWordEndMs: 10000,
        deadlineMs: 10032,
      );

      expect(adjusted, 10150);
    });
  });

  group('lyricWordEffect', () {
    const typicalLine = Duration(milliseconds: 500);

    test('keeps ordinary short words unchanged', () {
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 749),
          lineMedianDuration: typicalLine,
          isLineEnding: false,
        ),
        LyricWordEffect.none,
      );
    });

    test('scales words at the absolute threshold', () {
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 950),
          lineMedianDuration: typicalLine,
          isLineEnding: false,
        ),
        LyricWordEffect.scale,
      );
    });

    test('scales shorter words that stand out from the line', () {
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 750),
          lineMedianDuration: const Duration(milliseconds: 400),
          isLineEnding: false,
        ),
        LyricWordEffect.scale,
      );
    });

    test('adds glow at the absolute threshold', () {
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 1600),
          lineMedianDuration: typicalLine,
          isLineEnding: false,
        ),
        LyricWordEffect.scaleAndGlow,
      );
    });

    test('adds glow to a clear relative long note', () {
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 1200),
          lineMedianDuration: const Duration(milliseconds: 500),
          isLineEnding: false,
        ),
        LyricWordEffect.scaleAndGlow,
      );
    });

    test('lets a moderately long line ending glow', () {
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 1200),
          lineMedianDuration: const Duration(milliseconds: 600),
          isLineEnding: true,
        ),
        LyricWordEffect.scaleAndGlow,
      );
    });

    test('keeps a line-timed sentence from glowing as one long note', () {
      expect(lyricSungUnitCount('每次上机 都幻想'), 7);
      expect(lyricSungUnitCount('再捕捉捕捉恋爱定格'), 9);
      expect(lyricSungUnitCount('Cream cheese点缀我吗'), 6);
      expect(lyricSungUnitCount("can't"), 1);
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 18920),
          lineMedianDuration: const Duration(milliseconds: 18920),
          isLineEnding: true,
          sungUnitCount: lyricSungUnitCount('再捕捉捕捉恋爱定格'),
        ),
        LyricWordEffect.none,
      );
    });

    test('still glows one sustained syllable', () {
      expect(lyricSungUnitCount('啊'), 1);
      expect(
        lyricWordEffect(
          duration: const Duration(milliseconds: 2400),
          lineMedianDuration: const Duration(milliseconds: 400),
          isLineEnding: false,
          sungUnitCount: 1,
        ),
        LyricWordEffect.scaleAndGlow,
      );
    });
  });

  group('lyricCharacterScale', () {
    const duration = Duration(milliseconds: 1600);

    test('rests at the original size at both ends', () {
      expect(
        lyricCharacterScale(
          effect: LyricWordEffect.scaleAndGlow,
          duration: duration,
          lineMedianDuration: const Duration(milliseconds: 500),
          progress: 0,
        ),
        1.0,
      );
      expect(
        lyricCharacterScale(
          effect: LyricWordEffect.scaleAndGlow,
          duration: duration,
          lineMedianDuration: const Duration(milliseconds: 500),
          progress: 1,
        ),
        1.0,
      );
    });

    test('keeps the peak restrained', () {
      final scale = lyricCharacterScale(
        effect: LyricWordEffect.scaleAndGlow,
        duration: duration,
        lineMedianDuration: const Duration(milliseconds: 500),
        progress: 0.5,
      );
      expect(scale, greaterThanOrEqualTo(1.15));
      expect(scale, lessThanOrEqualTo(1.26));
    });

    test('holds the peak through the second half then releases', () {
      double scaleAt(double progress) {
        return lyricCharacterScale(
          effect: LyricWordEffect.scale,
          duration: duration,
          lineMedianDuration: const Duration(milliseconds: 500),
          progress: progress,
        );
      }

      final peak = scaleAt(0.5);
      expect(scaleAt(0.25), lessThan(peak));
      expect(scaleAt(0.55), closeTo(peak, 0.0001));
      expect(scaleAt(0.75), lessThan(peak));
      expect(scaleAt(0.9), lessThan(scaleAt(0.75)));
      expect(scaleAt(0.9), greaterThan(1.0));
    });

    test('raises the peak for more prominent long notes', () {
      final ordinaryScale = lyricCharacterScale(
        effect: LyricWordEffect.scale,
        duration: const Duration(milliseconds: 950),
        lineMedianDuration: const Duration(milliseconds: 600),
        progress: 0.5,
      );
      final prominentScale = lyricCharacterScale(
        effect: LyricWordEffect.scale,
        duration: const Duration(milliseconds: 2200),
        lineMedianDuration: const Duration(milliseconds: 500),
        progress: 0.5,
      );
      expect(prominentScale, greaterThan(ordinaryScale));
    });
  });

  group('lyricWrappedWordReveal', () {
    test('matches whole-word progress when the word is not wrapped', () {
      expect(
        lyricWrappedWordReveal(
          wordProgress: 0.5,
          wordCharIndex: 0,
          segmentLength: 10,
          wordPlacedCount: 10,
        ),
        5,
      );
    });

    test('fills the first visual line before the wrapped remainder', () {
      expect(
        lyricWrappedWordReveal(
          wordProgress: 0.5,
          wordCharIndex: 0,
          segmentLength: 8,
          wordPlacedCount: 10,
        ),
        5,
      );
      expect(
        lyricWrappedWordReveal(
          wordProgress: 0.5,
          wordCharIndex: 8,
          segmentLength: 2,
          wordPlacedCount: 10,
        ),
        0,
      );
    });

    test('starts the second visual line only after the first is full', () {
      expect(
        lyricWrappedWordReveal(
          wordProgress: 0.9,
          wordCharIndex: 0,
          segmentLength: 8,
          wordPlacedCount: 10,
        ),
        8,
      );
      expect(
        lyricWrappedWordReveal(
          wordProgress: 0.9,
          wordCharIndex: 8,
          segmentLength: 2,
          wordPlacedCount: 10,
        ),
        1,
      );
    });
  });

  group('lyricScaledContentWidth', () {
    test('keeps the layout width when scale is 1', () {
      expect(
        lyricScaledContentWidth(
          layoutWidth: 400,
          scale: 1,
          paddingHorizontal: 24,
        ),
        376,
      );
    });

    test('shrinks wrap width when the current line is scaled up', () {
      expect(
        lyricScaledContentWidth(
          layoutWidth: 400,
          scale: 1.25,
          paddingHorizontal: 24,
        ),
        closeTo(400 / 1.25 - 24, 0.0001),
      );
    });

    test('widens wrap width when inactive lines are scaled down', () {
      expect(
        lyricScaledContentWidth(
          layoutWidth: 400,
          scale: 0.9,
          paddingHorizontal: 24,
        ),
        closeTo(400 / 0.9 - 24, 0.0001),
      );
    });
  });

  group('lyricUnifiedWrapScale', () {
    test('uses the larger scale so played and unplayed wrap the same', () {
      expect(lyricUnifiedWrapScale(activeScale: 1.0, inactiveScale: 0.9), 1.0);
      expect(
        lyricScaledContentWidth(
          layoutWidth: 400,
          scale: lyricUnifiedWrapScale(activeScale: 1.0, inactiveScale: 0.9),
          paddingHorizontal: 24,
        ),
        376,
      );
    });
  });

  group('lyricLayoutFontSize', () {
    test('uses the larger size so current and other lines wrap the same', () {
      expect(lyricLayoutFontSize(mainFontSize: 32, subFontSize: 28), 32);
      expect(lyricLayoutFontSize(mainFontSize: 28, subFontSize: 32), 32);
    });

    test('also keeps translation and romanization layout size stable', () {
      final translationSize = lyricLayoutFontSize(
        mainFontSize: 24.96,
        subFontSize: 22.4,
      );
      final romanSize = lyricLayoutFontSize(
        mainFontSize: 24.96 * 0.85,
        subFontSize: 22.4 * 0.85,
      );

      expect(translationSize, 24.96);
      expect(romanSize, closeTo(24.96 * 0.85, 0.0001));
    });
  });

  group('lyricLineScaleAlignment', () {
    test('scales a wrapped line from the vertical center', () {
      expect(
        lyricLineScaleAlignment(LyricTextAlign.left),
        Alignment.centerLeft,
      );
      expect(lyricLineScaleAlignment(LyricTextAlign.center), Alignment.center);
      expect(
        lyricLineScaleAlignment(LyricTextAlign.right),
        Alignment.centerRight,
      );
    });
  });

  group('lyricExitLift', () {
    test('falls with the line float instead of snapping off', () {
      expect(lyricExitLift(-2, 1), -2);
      expect(lyricExitLift(-2, 0.5), -1);
      expect(lyricExitLift(-2, 0), 0);
    });
  });

  group('lyricUsesSoftLift', () {
    test('matches CJK and kana only', () {
      expect(lyricUsesSoftLift('你'), isTrue);
      expect(lyricUsesSoftLift('あ'), isTrue);
      expect(lyricUsesSoftLift('Hello'), isFalse);
      expect(lyricUsesSoftLift('한글'), isFalse);
    });
  });

  group('lyricSoftLiftSpring', () {
    test('matches the mass 1 stiffness 14 damping 7 spring', () {
      final sim = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 14, damping: 7),
        0,
        1,
        0,
      );
      for (final t in [0.0, 0.05, 0.2, 0.5, 1.0, 2.0]) {
        expect(lyricSoftLiftSpring(t), closeTo(sim.x(t), 0.002));
      }
    });
  });

  group('lyricVerticalCharLiftPx', () {
    test('does not lift before the syllable rise starts', () {
      expect(
        lyricVerticalCharLiftPx(
          nowMs: 1000,
          wordStartMs: 1000,
          wordDurationSec: 1,
          syllableIndex: 0,
          syllableCount: 1,
          softLift: false,
          liftPeak: 2,
        ),
        0,
      );
    });

    test('holds near peak after the word ends', () {
      double liftAt(double nowMs) => lyricVerticalCharLiftPx(
        nowMs: nowMs,
        wordStartMs: 0,
        wordDurationSec: 0.4,
        syllableIndex: 0,
        syllableCount: 1,
        softLift: false,
        liftPeak: 2,
      );
      final atEnd = liftAt(400);
      final later = liftAt(2400);
      expect(atEnd, lessThan(0));
      expect(later, closeTo(-2, 0.05));
      expect(later.abs(), greaterThan(atEnd.abs() - 0.05));
    });

    test('CJK syllables start later than latin ones', () {
      double lift({required bool softLift}) => lyricVerticalCharLiftPx(
        nowMs: 300,
        wordStartMs: 0,
        wordDurationSec: 1,
        syllableIndex: 0,
        syllableCount: 2,
        softLift: softLift,
        liftPeak: 2,
      );
      expect(lift(softLift: true), 0);
      expect(lift(softLift: false), lessThan(0));
    });
  });

  test('line-end catch-up still pulls highlight time forward', () {
    const raw = 800.0;
    final highlight = lyricHighlightTimeMs(
      currentTimeMs: raw,
      lineStartMs: 0,
      lastWordEndMs: 1000,
      deadlineMs: 1000,
    );
    expect(highlight, greaterThan(raw));
  });

  group('lyricCosineLiftPx', () {
    test('does not treat a wrap as the line end', () {
      const fontSize = 20.0;
      const peak = 2.0;
      final midWrap = lyricCosineLiftPx(
        charCenter: 90,
        cursorX: 100,
        lineEndX: 240,
        fontSize: fontSize,
        liftPeak: peak,
      );
      final trueEnd = lyricCosineLiftPx(
        charCenter: 90,
        cursorX: 100,
        lineEndX: 110,
        fontSize: fontSize,
        liftPeak: peak,
      );
      expect(midWrap, isNot(0));
      expect(trueEnd.abs(), greaterThan(midWrap.abs()));
    });

    test('follows the highlight cursor instead of lifting the whole line', () {
      const fontSize = 20.0;
      const peak = 2.0;
      const cursor = 40.0;
      const end = 120.0;
      final behind = lyricCosineLiftPx(
        charCenter: 10,
        cursorX: cursor,
        lineEndX: end,
        fontSize: fontSize,
        liftPeak: peak,
      );
      final ahead = lyricCosineLiftPx(
        charCenter: 110,
        cursorX: cursor,
        lineEndX: end,
        fontSize: fontSize,
        liftPeak: peak,
      );
      expect(behind, lessThan(0));
      expect(ahead, 0);
    });
  });

  test('cosine paint raises sung glyphs and leaves later ones down', () {
    final line =
        SyncLyricLine(Duration.zero, const Duration(milliseconds: 800), [
          SyncLyricWord(Duration.zero, const Duration(milliseconds: 400), '甲乙'),
          SyncLyricWord(
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 400),
            '丙丁',
          ),
        ]);
    final painter = LyricsLinePainter(
      params: LyricPainterParams(
        line: line,
        currentTimeMs: 200,
        blurSigma: 0,
        config: const LyricRenderConfig(
          textAlign: LyricTextAlign.left,
          baseFontSize: 32,
          translationBaseFontSize: 20,
          showTranslation: false,
          showRoman: false,
          fontWeight: 600,
          enableBlur: false,
          liftStyle: LyricLiftStyle.cosine,
          liftPeak: 2,
        ),
        isMainLine: true,
        isHighlightActive: true,
        isMainVocalActive: true,
        accelerateTailHighlight: false,
        useMaterialYouColor: false,
        opacity: 1,
        lineMedianWordDuration: Duration.zero,
      ),
      scheme: const ColorScheme.dark(),
    );
    painter.paint(Canvas(PictureRecorder()), const Size(400, 140));
    expect(debugLyricCharYLifts, isNotEmpty);
    expect(debugLyricCharYLifts.first, lessThan(0));
    expect(debugLyricCharYLifts.last, 0);
  });

  test('translation paint Y stays put while original glyphs lift', () {
    final line =
        SyncLyricLine(Duration.zero, const Duration(milliseconds: 800), [
          SyncLyricWord(
            Duration.zero,
            const Duration(milliseconds: 400),
            'Hello',
          ),
          SyncLyricWord(
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 400),
            'world',
          ),
        ], '翻译');
    const config = LyricRenderConfig(
      textAlign: LyricTextAlign.left,
      baseFontSize: 32,
      translationBaseFontSize: 20,
      showTranslation: true,
      showRoman: false,
      fontWeight: 600,
      enableBlur: false,
      liftStyle: LyricLiftStyle.vertical,
      liftPeak: 2,
    );
    LyricsLinePainter painterAt(double timeMs) {
      return LyricsLinePainter(
        params: LyricPainterParams(
          line: line,
          currentTimeMs: timeMs,
          blurSigma: 0,
          config: config,
          isMainLine: true,
          isHighlightActive: true,
          isMainVocalActive: true,
          accelerateTailHighlight: false,
          useMaterialYouColor: false,
          opacity: 1,
          lineMedianWordDuration: Duration.zero,
        ),
        scheme: const ColorScheme.dark(),
      );
    }

    painterAt(20).paint(Canvas(PictureRecorder()), const Size(400, 180));
    final earlyY = debugLyricTranslationY;
    expect(earlyY, isNotNull);
    painterAt(600).paint(Canvas(PictureRecorder()), const Size(400, 180));
    expect(debugLyricCharYLifts.any((y) => y < 0), isTrue);
    expect(debugLyricTranslationY, earlyY);
  });

  test('vertical lift keeps sub-pixel fractions', () {
    final line =
        SyncLyricLine(Duration.zero, const Duration(milliseconds: 800), [
          SyncLyricWord(
            Duration.zero,
            const Duration(milliseconds: 400),
            'Hello',
          ),
          SyncLyricWord(
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 400),
            'world',
          ),
        ]);
    LyricsLinePainter(
      params: LyricPainterParams(
        line: line,
        currentTimeMs: 200,
        blurSigma: 0,
        config: const LyricRenderConfig(
          textAlign: LyricTextAlign.left,
          baseFontSize: 32,
          translationBaseFontSize: 20,
          showTranslation: false,
          showRoman: false,
          fontWeight: 600,
          enableBlur: false,
          liftStyle: LyricLiftStyle.vertical,
          liftPeak: 2,
        ),
        isMainLine: true,
        isHighlightActive: true,
        isMainVocalActive: true,
        accelerateTailHighlight: false,
        useMaterialYouColor: false,
        opacity: 1,
        lineMedianWordDuration: Duration.zero,
      ),
      scheme: const ColorScheme.dark(),
    ).paint(Canvas(PictureRecorder()), const Size(400, 140));
    expect(debugLyricCharYLifts, isNotEmpty);
    expect(debugLyricCharYLifts.any((y) => y != y.roundToDouble()), isTrue);
  });

  test('wrapped cosine visual lines lift only sung glyphs', () {
    final line =
        SyncLyricLine(Duration.zero, const Duration(milliseconds: 800), [
          SyncLyricWord(Duration.zero, const Duration(milliseconds: 400), '甲'),
          SyncLyricWord(
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 400),
            '乙丙丁戊己庚',
          ),
        ]);
    LyricsLinePainter(
      params: LyricPainterParams(
        line: line,
        currentTimeMs: 200,
        blurSigma: 0,
        config: const LyricRenderConfig(
          textAlign: LyricTextAlign.left,
          baseFontSize: 32,
          translationBaseFontSize: 20,
          showTranslation: false,
          showRoman: false,
          fontWeight: 600,
          enableBlur: false,
          liftStyle: LyricLiftStyle.cosine,
          liftPeak: 2,
        ),
        isMainLine: true,
        isHighlightActive: true,
        isMainVocalActive: true,
        accelerateTailHighlight: false,
        useMaterialYouColor: false,
        opacity: 1,
        lineMedianWordDuration: Duration.zero,
      ),
      scheme: const ColorScheme.dark(),
    ).paint(Canvas(PictureRecorder()), const Size(80, 220));
    expect(debugLyricCharYLifts.length, greaterThan(1));
    expect(debugLyricCharYLifts.first, lessThan(0));
    expect(debugLyricCharYLifts[1], 0);
    expect(debugLyricCharYLifts.last, 0);
  });

  test('wrapped vertical visual lines lift only sung glyphs', () {
    final line =
        SyncLyricLine(Duration.zero, const Duration(milliseconds: 800), [
          SyncLyricWord(Duration.zero, const Duration(milliseconds: 400), '甲'),
          SyncLyricWord(
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 400),
            '乙丙丁戊己庚',
          ),
        ]);
    LyricsLinePainter(
      params: LyricPainterParams(
        line: line,
        currentTimeMs: 380,
        blurSigma: 0,
        config: const LyricRenderConfig(
          textAlign: LyricTextAlign.left,
          baseFontSize: 32,
          translationBaseFontSize: 20,
          showTranslation: false,
          showRoman: false,
          fontWeight: 600,
          enableBlur: false,
          liftStyle: LyricLiftStyle.vertical,
          liftPeak: 2,
        ),
        isMainLine: true,
        isHighlightActive: true,
        isMainVocalActive: true,
        accelerateTailHighlight: false,
        useMaterialYouColor: false,
        opacity: 1,
        lineMedianWordDuration: Duration.zero,
      ),
      scheme: const ColorScheme.dark(),
    ).paint(Canvas(PictureRecorder()), const Size(80, 220));
    expect(debugLyricCharYLifts.length, greaterThan(1));
    expect(debugLyricCharYLifts.first, lessThan(0));
    expect(debugLyricCharYLifts[1], 0);
    expect(debugLyricCharYLifts.last, 0);
  });

  test('wrapped English visual lines lift only sung glyphs', () {
    final line =
        SyncLyricLine(Duration.zero, const Duration(milliseconds: 2000), [
          SyncLyricWord(
            Duration.zero,
            const Duration(milliseconds: 1600),
            'sick of sick of sick of sick of ',
          ),
          SyncLyricWord(
            const Duration(milliseconds: 1600),
            const Duration(milliseconds: 400),
            'chasing',
          ),
        ]);
    LyricsLinePainter(
      params: LyricPainterParams(
        line: line,
        currentTimeMs: 800,
        blurSigma: 0,
        config: const LyricRenderConfig(
          textAlign: LyricTextAlign.left,
          baseFontSize: 32,
          translationBaseFontSize: 20,
          showTranslation: false,
          showRoman: false,
          fontWeight: 600,
          enableBlur: false,
          liftStyle: LyricLiftStyle.vertical,
          liftPeak: 2,
        ),
        isMainLine: true,
        isHighlightActive: true,
        isMainVocalActive: true,
        accelerateTailHighlight: false,
        useMaterialYouColor: false,
        opacity: 1,
        lineMedianWordDuration: Duration.zero,
      ),
      scheme: const ColorScheme.dark(),
    ).paint(Canvas(PictureRecorder()), const Size(220, 220));
    expect(debugLyricCharYLifts.length, greaterThan(8));
    expect(debugLyricCharYLifts.first, lessThan(0));
    expect(debugLyricCharYLifts.last, 0);
  });

  test(
    'inactive paint eases lifts down instead of dropping every glyph together',
    () {
      final line = SyncLyricLine(
        Duration.zero,
        const Duration(milliseconds: 800),
        [
          SyncLyricWord(Duration.zero, const Duration(milliseconds: 400), '甲乙'),
          SyncLyricWord(
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 400),
            '丙丁',
          ),
        ],
      );
      const config = LyricRenderConfig(
        textAlign: LyricTextAlign.left,
        baseFontSize: 32,
        translationBaseFontSize: 20,
        showTranslation: false,
        showRoman: false,
        fontWeight: 600,
        enableBlur: false,
        liftPeak: 2,
      );
      final cache = LyricCharLiftCache();
      LyricsLinePainter(
        params: LyricPainterParams(
          line: line,
          currentTimeMs: 700,
          blurSigma: 0,
          config: config,
          isMainLine: true,
          isHighlightActive: true,
          isMainVocalActive: true,
          accelerateTailHighlight: false,
          useMaterialYouColor: false,
          opacity: 1,
          lineMedianWordDuration: Duration.zero,
        ),
        scheme: const ColorScheme.dark(),
        liftCache: cache,
      ).paint(Canvas(PictureRecorder()), const Size(400, 140));
      expect(cache.values.where((y) => y < 0), isNotEmpty);

      LyricsLinePainter(
        params: LyricPainterParams(
          line: line,
          currentTimeMs: 900,
          blurSigma: 0,
          config: config,
          isMainLine: false,
          isHighlightActive: false,
          isMainVocalActive: false,
          accelerateTailHighlight: false,
          useMaterialYouColor: false,
          opacity: 1,
          lineMedianWordDuration: Duration.zero,
          liftDecayListenable: ValueNotifier<double>(0.7),
        ),
        scheme: const ColorScheme.dark(),
        liftCache: cache,
      ).paint(Canvas(PictureRecorder()), const Size(400, 140));
      expect(debugLyricCharYLifts, isNotEmpty);
      final before = cache.values.fold<double>(
        0,
        (m, y) => y.abs() > m ? y.abs() : m,
      );
      final after = debugLyricCharYLifts.fold<double>(
        0,
        (m, y) => y.abs() > m ? y.abs() : m,
      );
      expect(before, greaterThan(0));
      expect(after, lessThan(before));
    },
  );

  test('catch-up paint still raises earlier glyphs first', () {
    final line =
        SyncLyricLine(Duration.zero, const Duration(milliseconds: 800), [
          SyncLyricWord(Duration.zero, const Duration(milliseconds: 400), '甲乙'),
          SyncLyricWord(
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 400),
            '丙丁',
          ),
        ]);
    LyricsLinePainter(
      params: LyricPainterParams(
        line: line,
        currentTimeMs: 600,
        blurSigma: 0,
        config: const LyricRenderConfig(
          textAlign: LyricTextAlign.left,
          baseFontSize: 32,
          translationBaseFontSize: 20,
          showTranslation: false,
          showRoman: false,
          fontWeight: 600,
          enableBlur: false,
          liftPeak: 2,
        ),
        isMainLine: true,
        isHighlightActive: true,
        isMainVocalActive: true,
        accelerateTailHighlight: false,
        useMaterialYouColor: false,
        opacity: 1,
        highlightDeadlineMs: 800,
        lineMedianWordDuration: Duration.zero,
      ),
      scheme: const ColorScheme.dark(),
    ).paint(Canvas(PictureRecorder()), const Size(400, 140));
    expect(debugLyricCharYLifts.length, greaterThanOrEqualTo(4));
    expect(debugLyricCharYLifts.first, lessThan(0));
    expect(
      debugLyricCharYLifts.first.abs(),
      greaterThan(debugLyricCharYLifts.last.abs()),
    );
  });

  group('layoutTimedWordChars', () {
    LyricWordLayoutCursor cursor({
      double x = 0,
      double y = 0,
      bool firstOnLine = true,
    }) => LyricWordLayoutCursor(x: x, y: y, firstOnLine: firstOnLine);

    List<(int, double, double)> place({
      required List<String> chars,
      required List<double> widths,
      required LyricWordLayoutCursor cursor,
      double contentLeft = 0,
      double contentRight = 100,
      double lineHeight = 20,
    }) {
      final placed = <(int, double, double)>[];
      layoutTimedWordChars(
        chars: chars,
        widths: widths,
        contentLeft: contentLeft,
        contentRight: contentRight,
        lineHeight: lineHeight,
        cursor: cursor,
        onPlace: (i, x, y) => placed.add((i, x, y)),
      );
      return placed;
    }

    test('keeps a short timed word on one line', () {
      final c = cursor();
      final placed = place(chars: ['h', 'i'], widths: [10, 10], cursor: c);
      expect(placed, [(0, 0.0, 0.0), (1, 10.0, 0.0)]);
      expect(c.visualLineCount, 1);
      expect(c.x, 20);
    });

    test('does not split a timed word that still fits on the current line', () {
      final c = cursor(x: 40, firstOnLine: false);
      final placed = place(chars: ['o', 'h'], widths: [10, 10], cursor: c);
      expect(placed.map((e) => e.$3).toSet(), {0.0});
      expect(c.visualLineCount, 1);
      expect(c.x, 60);
    });

    test('wraps an oversized timed word at spaces', () {
      final c = cursor();
      final placed = place(
        chars: ['W', 'h', 'a', ' ', 'o', 'h', ' ', 'o', 'h'],
        widths: List<double>.filled(9, 10),
        cursor: c,
        contentRight: 35,
      );
      expect(placed.where((e) => e.$3 == 0.0).map((e) => e.$1).toList(), [
        0,
        1,
        2,
      ]);
      expect(placed.where((e) => e.$3 == 20.0).map((e) => e.$1).toList(), [
        4,
        5,
        6,
      ]);
      expect(placed.where((e) => e.$3 == 40.0).map((e) => e.$1).toList(), [
        7,
        8,
      ]);
      expect(c.visualLineCount, 3);
    });

    test('does not wrap a spaced timed word that already fits', () {
      final c = cursor();
      final placed = place(
        chars: ['h', 'i', ' ', 'o', 'h'],
        widths: List<double>.filled(5, 10),
        cursor: c,
        contentRight: 100,
      );
      expect(placed.map((e) => e.$3).toSet(), {0.0});
      expect(c.visualLineCount, 1);
    });

    test('wraps a spaceless overflow at characters', () {
      final c = cursor();
      place(
        chars: ['A', 'B', 'C', 'D', 'E', 'F'],
        widths: List<double>.filled(6, 10),
        cursor: c,
        contentRight: 35,
      );
      expect(c.visualLineCount, 2);
      expect(c.y, 20);
    });
  });

  group('word effect envelope follows char wave with a warp cap', () {
    test('char wave keeps later glyphs behind the first', () {
      expect(
        lyricCharWaveProgress(wordProgress: 0.2, charIndex: 0, charCount: 4),
        greaterThan(
          lyricCharWaveProgress(wordProgress: 0.2, charIndex: 3, charCount: 4),
        ),
      );
    });

    test('capped progress stays on the warped curve until the lead limit', () {
      expect(
        lyricCappedEffectProgress(warpedProgress: 0.4, realProgress: 0.4),
        0.4,
      );
      expect(
        lyricCappedEffectProgress(warpedProgress: 0.5, realProgress: 0.45),
        0.5,
      );
      expect(
        lyricCappedEffectProgress(warpedProgress: 0.99, realProgress: 0.84),
        closeTo(0.84 + lyricEffectWarpLead, 0.0001),
      );
    });

    test('tail warp cannot skip the whole release in one step', () {
      const start = 8000.0;
      const end = 10000.0;
      const times = [9800.0, 9850.0, 9900.0, 9950.0, 10000.0];
      var last = 0.0;
      for (final now in times) {
        final highlight = lyricHighlightTimeMs(
          currentTimeMs: now,
          lineStartMs: start,
          lastWordEndMs: end,
          deadlineMs: 10032,
        );
        final warped = lyricCharWaveProgress(
          wordProgress: lyricWordProgress(
            nowMs: highlight,
            wordStartMs: start,
            wordEndMs: end,
          ),
          charIndex: 0,
          charCount: 1,
        );
        final real = lyricCharWaveProgress(
          wordProgress: lyricWordProgress(
            nowMs: now,
            wordStartMs: start,
            wordEndMs: end,
          ),
          charIndex: 0,
          charCount: 1,
        );
        final effect = lyricCappedEffectProgress(
          warpedProgress: warped,
          realProgress: real,
        );
        if (now > times.first) {
          expect(effect - last, lessThan(0.12));
        }
        expect(effect, greaterThanOrEqualTo(last));
        last = effect;
      }
    });

    test('exit mix eases scale and glow to rest', () {
      expect(lyricExitScale(1.2, 1), closeTo(1.2, 0.0001));
      expect(lyricExitScale(1.2, 0.5), closeTo(1.1, 0.0001));
      expect(lyricExitScale(1.2, 0), 1.0);
      expect(lyricExitGlowAlpha(0.4, 1), closeTo(0.4, 0.0001));
      expect(lyricExitGlowAlpha(0.4, 0.5), closeTo(0.2, 0.0001));
      expect(lyricExitGlowAlpha(0.4, 0), 0);
    });
  });
}

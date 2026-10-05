import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/native/bass/bass_player.dart';
import 'package:pure_music/page/now_playing_page/component/audio_reactive_flow.dart';
import 'package:pure_music/page/now_playing_page/component/flowing_light_background.dart';
import 'package:pure_music/page/now_playing_page/component/now_playing_background_inputs.dart';

Future<Uint8List> _createCoverPng() async {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=',
  );
}

Future<Uint8List> _createColorCoverPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();
  paint.color = const Color(0xFFE53935);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 32, 32), paint);
  paint.color = const Color(0xFF1E88E5);
  canvas.drawRect(const Rect.fromLTWH(32, 0, 32, 32), paint);
  paint.color = const Color(0xFF43A047);
  canvas.drawRect(const Rect.fromLTWH(0, 32, 32, 32), paint);
  paint.color = const Color(0xFFFDD835);
  canvas.drawRect(const Rect.fromLTWH(32, 32, 32, 32), paint);
  final image = await recorder.endRecording().toImage(64, 64);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  test('upper bass joins the low-frequency beat energy', () {
    final upperBassHit = AudioReactiveFlowResponse.fromBands(const [
      0.12,
      0.70,
      0.10,
      0.05,
    ]);
    final subBassHit = AudioReactiveFlowResponse.fromBands(const [
      0.68,
      0.20,
      0.10,
      0.05,
    ]);

    expect(upperBassHit.low, closeTo(0.595, 0.001));
    expect(subBassHit.low, closeTo(0.68, 0.001));
  });

  test('visual normalization strengthens quiet spectrum response', () {
    final normalizer = AudioReactiveFlowNormalizer();
    const input = AudioReactiveFlowResponse(0.16, 0.10, 0.04);
    late AudioReactiveFlowResponse output;

    for (var i = 0; i < 30; i++) {
      output = normalizer.update(input);
    }

    expect(output.low, greaterThan(input.low * 1.5));
    expect(output.mid / output.low, closeTo(input.mid / input.low, 0.001));
  });

  test('visual normalization settles loud spectrum near its target peak', () {
    final normalizer = AudioReactiveFlowNormalizer();
    late AudioReactiveFlowResponse output;

    for (var i = 0; i < 30; i++) {
      output = normalizer.update(
        const AudioReactiveFlowResponse(0.9, 0.5, 0.2),
      );
    }

    expect(output.low, closeTo(0.85, 0.001));
    expect(output.mid / output.low, closeTo(0.5 / 0.9, 0.001));
  });

  test('visual normalization caps gain for near-silent spectrum', () {
    final normalizer = AudioReactiveFlowNormalizer();

    final output = normalizer.update(
      const AudioReactiveFlowResponse(0.0011, 0.0005, 0.0002),
    );

    expect(output.low, closeTo(0.033, 0.001));
  });

  test(
    'visual normalization keeps silence silent and reset clears its peak',
    () {
      final normalizer = AudioReactiveFlowNormalizer();
      normalizer.update(const AudioReactiveFlowResponse(0.4, 0.2, 0.1));
      normalizer.reset();

      final silence = normalizer.update(AudioReactiveFlowResponse.zero);
      final afterReset = normalizer.update(
        const AudioReactiveFlowResponse(0.1, 0.05, 0.02),
      );

      expect(silence.isNearlySilent, isTrue);
      expect(afterReset.low, greaterThan(0.2));
    },
  );

  test('audio curve holds the endpoints and the midpoint', () {
    expect(audioReactiveFlowCurve(0), 0);
    expect(audioReactiveFlowCurve(1), 1);
    expect(audioReactiveFlowCurve(0.5), closeTo(0.5, 0.001));
  });

  test('spectrum scale is driven by low more than mid', () {
    expect(audioReactiveFlowSpectrumScale(0, 0), 1);
    expect(
      audioReactiveFlowSpectrumScale(1, 0),
      greaterThan(audioReactiveFlowSpectrumScale(0, 1)),
    );
    expect(audioReactiveFlowSpectrumScale(1, 1), closeTo(1.38, 0.001));
  });

  test('contrast and saturation stay as small color-field pushes', () {
    expect(audioReactiveFlowContrast(0), 1);
    expect(audioReactiveFlowContrast(1), closeTo(1.08, 0.001));
    expect(audioReactiveFlowSaturationBoost(0), 0);
    expect(audioReactiveFlowSaturationBoost(1), closeTo(0.08, 0.001));
  });

  test('motion speed accents onsets without doubling the clock', () {
    expect(
      audioReactiveFlowMotionSpeedTarget(energy: 0.20, onset: 0.90),
      greaterThan(
        audioReactiveFlowMotionSpeedTarget(energy: 0.90, onset: 0.05),
      ),
    );
    expect(
      audioReactiveFlowMotionSpeedTarget(energy: 0, onset: 0),
      closeTo(1.0, 0.001),
    );
    expect(
      audioReactiveFlowMotionSpeedTarget(energy: 1, onset: 1),
      closeTo(1.70, 0.001),
    );
  });

  test('smallest artwork layer is cropped beyond the viewport', () {
    const output = Size(320, 180);
    const artwork = Size.square(512);

    final scale = flowingLightArtworkCropScale(output, artwork);
    final renderedSide = artwork.width * scale;

    expect(renderedSide, greaterThanOrEqualTo(output.width * 1.3));
    expect(renderedSide, greaterThan(output.height * 2));
  });

  test('envelope FIR holds back a spectrum spike instead of copying it', () {
    final envelope = AudioReactiveFlowEnvelope();
    final first = envelope.update(const AudioReactiveFlowResponse(1, 0.6, 0.3));

    expect(first.low, lessThan(0.45));
    expect(first.mid, lessThan(first.low));
    expect(first.high, lessThan(first.mid));
  });

  test('artwork layers carry the cover color over the neutral fallback', () {
    expect(flowingLightArtworkOpacityCeiling(), greaterThan(0.92));
  });

  test('cover base color averages the 5x5 grid', () {
    const width = 10;
    const height = 10;
    final pixels = ByteData(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      pixels.setUint8(i * 4, 200);
      pixels.setUint8(i * 4 + 1, 10);
      pixels.setUint8(i * 4 + 2, 20);
      pixels.setUint8(i * 4 + 3, 255);
    }

    expect(
      flowingLightCoverBaseColor(pixels, width, height).toARGB32(),
      const Color(0xFFC80A14).toARGB32(),
    );
  });

  testWidgets('disabled audio-reactive flow does not subscribe to spectrum', (
    tester,
  ) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);

    await tester.pumpWidget(
      MaterialApp(
        home: FlowingLightBackground(
          inputs: NowPlayingBackgroundInputs(
            spectrumStream: spectrum.stream,
            enableAnimation: true,
            isVisible: true,
            playerState: PlayerState.playing,
            audioReactiveFlow: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(spectrum.hasListener, isFalse);
  });

  testWidgets('static flow does not subscribe to spectrum while playing', (
    tester,
  ) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);
    final cover = await _createCoverPng();

    await tester.pumpWidget(
      MaterialApp(
        home: FlowingLightBackground(
          inputs: NowPlayingBackgroundInputs(
            albumCoverBytes: cover,
            spectrumStream: spectrum.stream,
            enableAnimation: false,
            isVisible: true,
            playerState: PlayerState.playing,
            audioReactiveFlow: true,
          ),
        ),
      ),
    );
    await _pumpAsyncWork(tester);

    expect(spectrum.hasListener, isFalse);
  });

  testWidgets('audio-reactive spectrum updates without throwing', (
    tester,
  ) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);
    final cover = await _createCoverPng();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: FlowingLightBackground(
            inputs: NowPlayingBackgroundInputs(
              albumCoverBytes: cover,
              spectrumStream: spectrum.stream,
              enableAnimation: true,
              isVisible: true,
              playerState: PlayerState.playing,
              audioReactiveFlow: true,
            ),
          ),
        ),
      );
      await _pumpAsyncWork(tester);
      expect(spectrum.hasListener, isTrue);

      spectrum.add(Float32List.fromList([0.1, 0.1, 0.05, 0.02]));
      await tester.pump(const Duration(milliseconds: 42));
      spectrum.add(Float32List.fromList([0.9, 0.75, 0.12, 0.04]));
      await tester.pump(const Duration(milliseconds: 42));

      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('flowing artwork renders a non-empty layered color field', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    final cover = (await tester.runAsync(_createColorCoverPng))!;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 320,
              height: 180,
              child: FlowingLightBackground(
                inputs: NowPlayingBackgroundInputs(
                  albumCoverBytes: cover,
                  enableAnimation: false,
                  isVisible: true,
                  playerState: PlayerState.paused,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpAsyncWork(tester);

    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = (await tester.runAsync(boundary.toImage))!;
    final data = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    image.dispose();
    final pixels = data!.buffer.asUint8List();
    final colorBuckets = <int>{};
    var maxChannelSpread = 0;
    for (var offset = 0; offset < pixels.length; offset += 4) {
      final red = pixels[offset];
      final green = pixels[offset + 1];
      final blue = pixels[offset + 2];
      final maximum = max(red, max(green, blue));
      final minimum = min(red, min(green, blue));
      maxChannelSpread = max(maxChannelSpread, maximum - minimum);
      colorBuckets.add((red ~/ 16 << 8) | (green ~/ 16 << 4) | blue ~/ 16);
    }

    expect(maxChannelSpread, greaterThan(24));
    expect(colorBuckets.length, greaterThan(24));
  });

  testWidgets('paused audio-reactive flow releases its spectrum subscription', (
    tester,
  ) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);

    await tester.pumpWidget(
      MaterialApp(
        home: FlowingLightBackground(
          inputs: NowPlayingBackgroundInputs(
            spectrumStream: spectrum.stream,
            enableAnimation: true,
            isVisible: true,
            playerState: PlayerState.paused,
            audioReactiveFlow: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(spectrum.hasListener, isFalse);
  });

  testWidgets('pause then play keeps artwork visible and resubscribes', (
    tester,
  ) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);
    final cover = await _createCoverPng();

    Widget buildSubject(PlayerState state) {
      return MaterialApp(
        home: FlowingLightBackground(
          inputs: NowPlayingBackgroundInputs(
            albumCoverBytes: cover,
            spectrumStream: spectrum.stream,
            enableAnimation: true,
            isVisible: true,
            playerState: state,
            audioReactiveFlow: true,
          ),
        ),
      );
    }

    final flowingOpacity = find.descendant(
      of: find.byType(FlowingLightBackground),
      matching: find.byType(AnimatedOpacity),
    );

    try {
      await tester.pumpWidget(buildSubject(PlayerState.playing));
      await _pumpAsyncWork(tester);
      expect(spectrum.hasListener, isTrue);
      expect(tester.widget<AnimatedOpacity>(flowingOpacity).opacity, 1);

      await tester.pumpWidget(buildSubject(PlayerState.paused));
      await tester.pump();
      expect(spectrum.hasListener, isFalse);
      expect(tester.widget<AnimatedOpacity>(flowingOpacity).opacity, 1);

      await tester.pumpWidget(buildSubject(PlayerState.playing));
      await tester.pump();
      expect(spectrum.hasListener, isTrue);
      expect(tester.widget<AnimatedOpacity>(flowingOpacity).opacity, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('ticker mode controls the spectrum subscription', (tester) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);
    final cover = await _createCoverPng();

    Widget buildSubject({required bool tickerModeEnabled}) {
      return MaterialApp(
        home: TickerMode(
          enabled: tickerModeEnabled,
          child: FlowingLightBackground(
            inputs: NowPlayingBackgroundInputs(
              albumCoverBytes: cover,
              spectrumStream: spectrum.stream,
              enableAnimation: true,
              isVisible: true,
              playerState: PlayerState.playing,
              audioReactiveFlow: true,
            ),
          ),
        ),
      );
    }

    try {
      await tester.pumpWidget(buildSubject(tickerModeEnabled: false));
      await _pumpAsyncWork(tester);
      expect(spectrum.hasListener, isFalse);

      await tester.pumpWidget(buildSubject(tickerModeEnabled: true));
      await tester.pump();
      expect(spectrum.hasListener, isTrue);

      await tester.pumpWidget(buildSubject(tickerModeEnabled: false));
      await tester.pump();
      expect(spectrum.hasListener, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'invalid current cover falls back instead of keeping old artwork',
    (tester) async {
      final cover = await _createCoverPng();

      Widget buildSubject(Uint8List bytes) {
        return MaterialApp(
          home: FlowingLightBackground(
            inputs: NowPlayingBackgroundInputs(
              albumCoverBytes: bytes,
              enableAnimation: false,
              isVisible: true,
              playerState: PlayerState.paused,
            ),
          ),
        );
      }

      final flowingPaint = find.descendant(
        of: find.byType(FlowingLightBackground),
        matching: find.byType(CustomPaint),
      );
      final flowingOpacity = find.descendant(
        of: find.byType(FlowingLightBackground),
        matching: find.byType(AnimatedOpacity),
      );

      try {
        await tester.pumpWidget(buildSubject(cover));
        await _pumpAsyncWork(tester);
        expect(flowingPaint, findsOneWidget);
        expect(tester.widget<AnimatedOpacity>(flowingOpacity).opacity, 1);

        await tester.pumpWidget(buildSubject(Uint8List.fromList([1, 2, 3])));
        await _pumpAsyncWork(tester);
        await tester.pump(const Duration(milliseconds: 600));
        expect(flowingPaint, findsOneWidget);
        expect(tester.widget<AnimatedOpacity>(flowingOpacity).opacity, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}

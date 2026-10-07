import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/component/transition_snapshot.dart';

void main() {
  testWidgets('freezing stops descendant tickers and resumes afterwards', (
    tester,
  ) async {
    final probeKey = GlobalKey<_TickerProbeState>();

    Future<void> pump({required bool freezing}) {
      return tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TransitionSnapshot(
              freezing: freezing,
              child: TickerProbe(key: probeKey),
            ),
          ),
        ),
      );
    }

    await pump(freezing: false);
    await tester.pump();
    final liveTicks = probeKey.currentState!.ticks;
    await tester.pump(const Duration(milliseconds: 40));
    expect(probeKey.currentState!.ticks, greaterThan(liveTicks));

    await pump(freezing: true);
    await tester.pump();
    final frozenTicks = probeKey.currentState!.ticks;
    await tester.pump(const Duration(milliseconds: 40));
    expect(probeKey.currentState!.ticks, frozenTicks);

    await pump(freezing: false);
    await tester.pump();
    final resumedTicks = probeKey.currentState!.ticks;
    await tester.pump(const Duration(milliseconds: 40));
    expect(probeKey.currentState!.ticks, greaterThan(resumedTicks));
  });

  testWidgets(
    'covered routes stay frozen after the incoming animation settles',
    (tester) async {
      final probeKey = GlobalKey<_TickerProbeState>();
      final secondary = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 80),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RouteTransitionSnapshot(
              secondaryAnimation: secondary,
              child: TickerProbe(key: probeKey),
            ),
          ),
        ),
      );

      await tester.pump();
      final liveTicks = probeKey.currentState!.ticks;
      await tester.pump(const Duration(milliseconds: 40));
      expect(probeKey.currentState!.ticks, greaterThan(liveTicks));

      secondary.value = 1;
      await tester.pump();
      final coveredTicks = probeKey.currentState!.ticks;
      await tester.pump(const Duration(milliseconds: 40));
      expect(probeKey.currentState!.ticks, coveredTicks);

      secondary.dispose();
    },
  );
}

class TickerProbe extends StatefulWidget {
  const TickerProbe({super.key});

  @override
  State<TickerProbe> createState() => _TickerProbeState();
}

class _TickerProbeState extends State<TickerProbe>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int ticks = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => ticks++)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

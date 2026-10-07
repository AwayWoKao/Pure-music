import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_music/core/paths.dart' as app_paths;
import 'package:pure_music/page/now_playing_page/now_playing_overlay.dart';
import 'package:pure_music/page/now_playing_page/now_playing_visibility.dart';

void main() {
  testWidgets('hiding then showing keeps the now playing session alive', (
    tester,
  ) async {
    final probeKey = GlobalKey<_KeepAliveProbeState>();

    Widget buildHost({required bool visible}) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: NowPlayingSessionHost(
            visible: visible,
            page: KeepAliveProbe(key: probeKey),
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildHost(visible: true));
    expect(probeKey.currentState, isNotNull);
    expect(NowPlayingVisibility.shownOf(probeKey.currentContext!), isTrue);
    expect(probeKey.currentState!.initCount, 1);
    expect(probeKey.currentState!.disposeCount, 0);

    await tester.pumpWidget(buildHost(visible: false));
    await tester.pump();
    expect(probeKey.currentState, isNotNull);
    expect(NowPlayingVisibility.shownOf(probeKey.currentContext!), isFalse);
    expect(probeKey.currentState!.initCount, 1);
    expect(probeKey.currentState!.disposeCount, 0);

    await tester.pumpWidget(buildHost(visible: true));
    await tester.pump();
    expect(probeKey.currentState, isNotNull);
    expect(NowPlayingVisibility.shownOf(probeKey.currentContext!), isTrue);
    expect(probeKey.currentState!.initCount, 1);
    expect(probeKey.currentState!.disposeCount, 0);
  });

  testWidgets('showing now playing freezes the page underneath', (
    tester,
  ) async {
    final probeKey = GlobalKey<_TickerProbeState>();

    Widget buildHost({required bool visible}) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: NowPlayingSessionHost(
            visible: visible,
            page: const SizedBox.expand(),
            child: TickerProbe(key: probeKey),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildHost(visible: false));
    await tester.pump();
    final liveTicks = probeKey.currentState!.ticks;
    await tester.pump(const Duration(milliseconds: 40));
    expect(probeKey.currentState!.ticks, greaterThan(liveTicks));

    await tester.pumpWidget(buildHost(visible: true));
    await tester.pump();
    final frozenTicks = probeKey.currentState!.ticks;
    await tester.pump(const Duration(milliseconds: 40));
    expect(probeKey.currentState!.ticks, frozenTicks);

    await tester.pumpWidget(buildHost(visible: false));
    await tester.pump();
    final resumedTicks = probeKey.currentState!.ticks;
    await tester.pump(const Duration(milliseconds: 40));
    expect(probeKey.currentState!.ticks, greaterThan(resumedTicks));
  });

  testWidgets('router host does not crash before the initial route is ready', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: app_paths.AUDIOS_PAGE,
      routes: [
        GoRoute(
          path: app_paths.AUDIOS_PAGE,
          builder: (context, state) => const SizedBox.expand(),
        ),
        GoRoute(
          path: app_paths.NOW_PLAYING_PAGE,
          builder: (context, state) => const SizedBox.expand(),
        ),
      ],
    );
    addTearDown(router.dispose);
    expect(router.routerDelegate.currentConfiguration.isEmpty, isTrue);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: NowPlayingRouterHost(
            router: router,
            page: const SizedBox.expand(),
            child: const ColoredBox(
              color: Color(0xFF00FF00),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ColoredBox), findsOneWidget);
  });
}

class KeepAliveProbe extends StatefulWidget {
  const KeepAliveProbe({super.key});

  @override
  State<KeepAliveProbe> createState() => _KeepAliveProbeState();
}

class _KeepAliveProbeState extends State<KeepAliveProbe> {
  int initCount = 0;
  int disposeCount = 0;

  @override
  void initState() {
    super.initState();
    initCount++;
  }

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
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

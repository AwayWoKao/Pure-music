import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/component/motion.dart';

void main() {
  testWidgets('spring rail exposes the live and target rail widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 100,
          child: SpringRailScaffold(
            progress: 0.4,
            targetProgress: 1,
            collapsedWidth: 80,
            expandedWidth: 240,
            rail: SizedBox(),
            body: SizedBox(),
          ),
        ),
      ),
    );

    final scope = tester.widget<SidebarMotionScope>(
      find.byType(SidebarMotionScope),
    );
    expect(scope.railWidth, closeTo(144, 0.01));
    expect(scope.targetRailWidth, closeTo(240, 0.01));
    expect(scope.isAnimating, isTrue);
  });

  testWidgets(
    'sidebar frozen viewport keeps content geometry during the live rail motion',
    (tester) async {
      final key = GlobalKey<_SidebarMotionHarnessState>();
      final contentKey = GlobalKey();
      final bodyKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: _SidebarMotionHarness(
            key: key,
            bodyKey: bodyKey,
            contentKey: contentKey,
          ),
        ),
      );

      expect(tester.getSize(find.byKey(bodyKey)).width, 320);
      expect(tester.getSize(find.byKey(contentKey)).width, 320);

      key.currentState!.setMotion(
        railWidth: 160,
        targetRailWidth: 240,
        bodyWidth: 240,
      );
      await tester.pump();

      expect(tester.getSize(find.byKey(bodyKey)).width, 240);
      expect(tester.getSize(find.byKey(contentKey)).width, 320);

      key.currentState!.setMotion(
        railWidth: 240,
        targetRailWidth: 240,
        bodyWidth: 160,
      );
      await tester.pump();

      expect(tester.getSize(find.byKey(contentKey)).width, 160);

      key.currentState!.setMotion(
        railWidth: 160,
        targetRailWidth: 80,
        bodyWidth: 240,
      );
      await tester.pump();

      expect(tester.getSize(find.byKey(contentKey)).width, 240);

      key.currentState!.setMotion(
        railWidth: 80,
        targetRailWidth: 80,
        bodyWidth: 320,
      );
      await tester.pump();

      expect(tester.getSize(find.byKey(contentKey)).width, 320);

      key.currentState!.setMotion(
        railWidth: 240,
        targetRailWidth: 240,
        bodyWidth: 160,
      );
      await tester.pump();

      expect(tester.getSize(find.byKey(contentKey)).width, 160);
    },
  );

  testWidgets('sidebar frozen viewport keeps child state across motion', (
    tester,
  ) async {
    final key = GlobalKey<_SidebarStateHarnessState>();

    await tester.pumpWidget(MaterialApp(home: _SidebarStateHarness(key: key)));

    final field = find.byKey(const ValueKey('field'));
    await tester.enterText(field, '保留状态');
    final state = tester.state(field);

    key.currentState!.setMotion(railWidth: 160, targetRailWidth: 240);
    await tester.pump();

    expect(tester.state(field), same(state));
    expect(find.text('保留状态'), findsOneWidget);

    key.currentState!.setMotion(railWidth: 240, targetRailWidth: 240);
    await tester.pump();

    expect(tester.state(field), same(state));
  });

  testWidgets('sidebar frozen viewport avoids child layout churn in flight', (
    tester,
  ) async {
    final key = GlobalKey<_LayoutCountHarnessState>();

    await tester.pumpWidget(MaterialApp(home: _LayoutCountHarness(key: key)));

    final stableLayouts = key.currentState!.childLayouts;
    key.currentState!.setMotion(
      railWidth: 100,
      targetRailWidth: 240,
      bodyWidth: 300,
    );
    await tester.pump();
    final inFlightLayouts = key.currentState!.childLayouts;

    for (var i = 2; i <= 3; i++) {
      key.currentState!.setMotion(
        railWidth: 80 + i * 20,
        targetRailWidth: 240,
        bodyWidth: 320 - i * 20,
      );
      await tester.pump();
    }

    expect(inFlightLayouts, stableLayouts);

    for (var i = 4; i <= 8; i++) {
      key.currentState!.setMotion(
        railWidth: 80 + i * 20,
        targetRailWidth: 240,
        bodyWidth: 320 - i * 20,
      );
      await tester.pump();
    }

    expect(
      key.currentState!.childLayouts,
      lessThanOrEqualTo(stableLayouts + 1),
    );

    key.currentState!.setMotion(
      railWidth: 240,
      targetRailWidth: 240,
      bodyWidth: 160,
    );
    await tester.pump();

    expect(key.currentState!.childLayouts, greaterThan(stableLayouts));
  });

  testWidgets('sidebar frozen viewport commits child updates after motion', (
    tester,
  ) async {
    final key = GlobalKey<_ChildUpdateHarnessState>();

    await tester.pumpWidget(MaterialApp(home: _ChildUpdateHarness(key: key)));
    expect(find.text('old'), findsOneWidget);

    key.currentState!.update(
      label: 'new',
      railWidth: 160,
      targetRailWidth: 240,
    );
    await tester.pump();

    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsNothing);

    key.currentState!.update(
      label: 'new',
      railWidth: 240,
      targetRailWidth: 240,
    );
    await tester.pump();

    expect(find.text('new'), findsOneWidget);
  });
}

class _SidebarMotionHarness extends StatefulWidget {
  const _SidebarMotionHarness({
    super.key,
    required this.bodyKey,
    required this.contentKey,
  });

  final GlobalKey bodyKey;
  final GlobalKey contentKey;

  @override
  State<_SidebarMotionHarness> createState() => _SidebarMotionHarnessState();
}

class _SidebarMotionHarnessState extends State<_SidebarMotionHarness> {
  double railWidth = 80;
  double targetRailWidth = 80;
  double bodyWidth = 320;

  void setMotion({
    required double railWidth,
    required double targetRailWidth,
    required double bodyWidth,
  }) {
    setState(() {
      this.railWidth = railWidth;
      this.targetRailWidth = targetRailWidth;
      this.bodyWidth = bodyWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SidebarMotionScope(
      railWidth: railWidth,
      targetRailWidth: targetRailWidth,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: widget.bodyKey,
          width: bodyWidth,
          height: 100,
          child: SidebarFrozenViewport(
            child: SizedBox.expand(key: widget.contentKey),
          ),
        ),
      ),
    );
  }
}

class _SidebarStateHarness extends StatefulWidget {
  const _SidebarStateHarness({super.key});

  @override
  State<_SidebarStateHarness> createState() => _SidebarStateHarnessState();
}

class _SidebarStateHarnessState extends State<_SidebarStateHarness> {
  double railWidth = 80;
  double targetRailWidth = 80;

  void setMotion({required double railWidth, required double targetRailWidth}) {
    setState(() {
      this.railWidth = railWidth;
      this.targetRailWidth = targetRailWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SidebarMotionScope(
      railWidth: railWidth,
      targetRailWidth: targetRailWidth,
      child: const SizedBox(
        width: 320,
        height: 100,
        child: SidebarFrozenViewport(
          child: Material(child: TextField(key: ValueKey('field'))),
        ),
      ),
    );
  }
}

class _LayoutCountHarness extends StatefulWidget {
  const _LayoutCountHarness({super.key});

  @override
  State<_LayoutCountHarness> createState() => _LayoutCountHarnessState();
}

class _LayoutCountHarnessState extends State<_LayoutCountHarness> {
  double railWidth = 80;
  double targetRailWidth = 80;
  double bodyWidth = 320;
  int childLayouts = 0;
  late final Widget child = LayoutBuilder(
    builder: (context, constraints) {
      childLayouts++;
      return const SizedBox.expand();
    },
  );

  void setMotion({
    required double railWidth,
    required double targetRailWidth,
    required double bodyWidth,
  }) {
    setState(() {
      this.railWidth = railWidth;
      this.targetRailWidth = targetRailWidth;
      this.bodyWidth = bodyWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SidebarMotionScope(
      railWidth: railWidth,
      targetRailWidth: targetRailWidth,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: bodyWidth,
          height: 100,
          child: SidebarFrozenViewport(child: child),
        ),
      ),
    );
  }
}

class _ChildUpdateHarness extends StatefulWidget {
  const _ChildUpdateHarness({super.key});

  @override
  State<_ChildUpdateHarness> createState() => _ChildUpdateHarnessState();
}

class _ChildUpdateHarnessState extends State<_ChildUpdateHarness> {
  String label = 'old';
  double railWidth = 80;
  double targetRailWidth = 80;

  void update({
    required String label,
    required double railWidth,
    required double targetRailWidth,
  }) {
    setState(() {
      this.label = label;
      this.railWidth = railWidth;
      this.targetRailWidth = targetRailWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SidebarMotionScope(
      railWidth: railWidth,
      targetRailWidth: targetRailWidth,
      child: SizedBox(
        width: 320,
        height: 100,
        child: SidebarFrozenViewport(
          child: Text(label, key: const ValueKey('content')),
        ),
      ),
    );
  }
}

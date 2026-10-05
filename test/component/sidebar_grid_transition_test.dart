import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/component/adaptive_action_layout.dart';
import 'package:pure_music/component/motion.dart';
import 'package:pure_music/component/sidebar_grid_transition.dart';

const _delegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 180,
  mainAxisExtent: 60,
  mainAxisSpacing: 8,
  crossAxisSpacing: 20,
);

void main() {
  test('reflow interpolates the same item between rows without clipping', () {
    for (final reverse in [false, true]) {
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final layout = SidebarGridGeometry(
          width: 540,
          delegate: _delegate,
          weights: {4: 1 - t, 3: t},
          itemCount: 100,
          reverse: reverse,
        );
        for (var i = 0; i < 100; i++) {
          final item = layout.getGeometryForChildIndex(i);
          expect(item.crossAxisOffset, greaterThanOrEqualTo(-0.001));
          expect(
            item.crossAxisOffset + item.crossAxisExtent,
            lessThanOrEqualTo(540.001),
          );
        }
        expect(
          layout.getGeometryForChildIndex(3).scrollOffset,
          closeTo(68 * t, 0.001),
        );
      }
    }
  });

  test('visible index bounds include every intersecting moving item', () {
    final layout = SidebarGridGeometry(
      width: 540,
      delegate: _delegate,
      weights: const {4: 0.4, 3: 0.6},
      itemCount: 200,
    );
    for (var offset = 0.0; offset < 3000; offset += 97) {
      final first = layout.getMinChildIndexForScrollOffset(offset);
      final last = layout.getMaxChildIndexForScrollOffset(offset + 250);
      for (var i = 0; i < 200; i++) {
        final item = layout.getGeometryForChildIndex(i);
        if (item.scrollOffset < offset + 250 &&
            item.scrollOffset + item.mainAxisExtent > offset) {
          expect(i, inInclusiveRange(first, last));
        }
      }
    }
    expect(layout.computeMaxScrollOffset(0), 0);
  });

  testWidgets('rail movement does not bounce tiles to another row', (
    tester,
  ) async {
    final key = GlobalKey<_GridHarnessState>();
    await tester.pumpWidget(MaterialApp(home: _GridHarness(key: key)));
    final item = find.byKey(const ValueKey('tile-3'));
    final top = tester.getTopLeft(item).dy;
    key.currentState!.setRail(160, 240);
    await tester.pump();
    expect(tester.getTopLeft(item).dy, closeTo(top, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail actions stay left while search stays right', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 700,
              child: AdaptiveActionLayout(
                compact: false,
                actions: [
                  SizedBox(key: ValueKey('action'), width: 120, height: 40),
                ],
                trailing: SizedBox(key: ValueKey('search'), height: 40),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('action'))).dx, 0);
    expect(tester.getTopRight(find.byKey(const ValueKey('search'))).dx, 700);
  });
}

class _GridHarness extends StatefulWidget {
  const _GridHarness({super.key});

  @override
  State<_GridHarness> createState() => _GridHarnessState();
}

class _GridHarnessState extends State<_GridHarness> {
  final controller = ScrollController();
  double rail = 80;
  double target = 80;

  void setRail(double value, double destination) => setState(() {
    rail = value;
    target = destination;
  });

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SidebarMotionScope(
    railWidth: rail,
    targetRailWidth: target,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 780 - rail,
        height: 300,
        child: SidebarFrozenViewport(
          child: SidebarGridTransition(
          controller: controller,
          gridDelegate: _delegate,
          itemCount: 200,
          itemBuilder: (context, index) =>
              SizedBox(key: ValueKey('tile-$index'), child: Text('$index')),
        ),
        ),
      ),
    ),
  );
}

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
}

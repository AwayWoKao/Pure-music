import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/component/adaptive_action_layout.dart';
import 'package:pure_music/page/page_scaffold.dart';

void main() {
  testWidgets(
    'adaptive action layout changes shape without recreating the trailing field',
    (tester) async {
      final key = GlobalKey<_AdaptiveActionHarnessState>();

      await tester.pumpWidget(
        MaterialApp(home: _AdaptiveActionHarness(key: key)),
      );

      final field = find.byKey(const ValueKey('field'));
      await tester.enterText(field, '未提交');
      final state = tester.state(field);

      key.currentState!.setCompact(false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.state(field), same(state));
      expect(find.text('未提交'), findsOneWidget);
      expect(
        tester.getTopLeft(field).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('action'))).dy),
      );
    },
  );

  testWidgets('page scaffold header follows its local width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 420,
            height: 300,
            child: PageScaffold(
              title: '标题',
              actions: [
                SizedBox(key: ValueKey('page-action'), width: 200, height: 40),
              ],
              body: SizedBox(),
            ),
          ),
        ),
      ),
    );

    final title = find.text('标题');
    final action = find.byKey(const ValueKey('page-action'));
    expect(
      tester.getTopLeft(action).dy,
      greaterThan(tester.getBottomRight(title).dy),
    );
  });

  testWidgets('page scaffold can place actions below the subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 900,
          height: 300,
          child: PageScaffold(
            title: '音乐',
            subtitle: '2754 首乐曲',
            actionPlacement: PageActionPlacement.belowSubtitle,
            actions: [
              SizedBox(key: ValueKey('below-action'), width: 120, height: 40),
            ],
            body: SizedBox(),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('below-action'))).dy,
      greaterThan(tester.getBottomRight(find.text('2754 首乐曲')).dy),
    );
  });

  testWidgets('default page scaffold keeps wide actions beside the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 900,
          height: 300,
          child: PageScaffold(
            title: '专辑',
            subtitle: '12 张专辑',
            actions: [
              SizedBox(key: ValueKey('wide-action'), width: 120, height: 40),
            ],
            body: SizedBox(),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('wide-action'))).dx,
      greaterThan(tester.getTopRight(find.text('专辑')).dx),
    );
  });

  testWidgets('page scaffold animates wide and compact header changes', (
    tester,
  ) async {
    final key = GlobalKey<_HeaderWidthHarnessState>();
    await tester.pumpWidget(MaterialApp(home: _HeaderWidthHarness(key: key)));

    key.currentState!.setWidth(500);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
  });
}

class _HeaderWidthHarness extends StatefulWidget {
  const _HeaderWidthHarness({super.key});

  @override
  State<_HeaderWidthHarness> createState() => _HeaderWidthHarnessState();
}

class _HeaderWidthHarnessState extends State<_HeaderWidthHarness> {
  double width = 900;

  void setWidth(double value) => setState(() => width = value);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: 300,
        child: const PageScaffold(
          title: '标题',
          subtitle: '副标题',
          actions: [
            SizedBox(key: ValueKey('animated-action'), width: 120, height: 40),
          ],
          body: SizedBox(),
        ),
      ),
    );
  }
}

class _AdaptiveActionHarness extends StatefulWidget {
  const _AdaptiveActionHarness({super.key});

  @override
  State<_AdaptiveActionHarness> createState() => _AdaptiveActionHarnessState();
}

class _AdaptiveActionHarnessState extends State<_AdaptiveActionHarness> {
  bool compact = true;

  void setCompact(bool value) => setState(() => compact = value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Material(
        child: AdaptiveActionLayout(
          compact: compact,
          actions: const [
            SizedBox(key: ValueKey('action'), width: 200, height: 40),
          ],
          trailing: const TextField(key: ValueKey('field')),
        ),
      ),
    );
  }
}

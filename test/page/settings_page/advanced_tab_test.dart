import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/page/settings_page/tabs/advanced_tab.dart';

void main() {
  testWidgets('advanced tab keeps its group entries', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 800, height: 800, child: AdvancedTabContent()),
        ),
      ),
    );

    expect(find.text('系统行为'), findsOneWidget);
    expect(find.text('媒体与字体'), findsOneWidget);
    expect(find.text('媒体解析'), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    expect(find.text('备份'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/page/settings_page/tabs/about_tab.dart';

void main() {
  testWidgets('about tab keeps update and link sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 800,
            child: AboutTabContent(contributorsSection: SizedBox.shrink()),
          ),
        ),
      ),
    );

    expect(find.text('更新'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('更新渠道'), findsOneWidget);
    expect(find.text('启动时自动检查更新'), findsOneWidget);
    expect(find.text('相关链接'), findsOneWidget);
    expect(find.text('官方网站'), findsOneWidget);
    expect(find.text('项目主页'), findsOneWidget);
    expect(find.text('交流群组'), findsOneWidget);
    expect(find.text('报告问题'), findsOneWidget);
    expect(find.text('创建问题'), findsOneWidget);
  });
}

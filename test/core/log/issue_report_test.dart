import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/issue_report.dart';

void main() {
  test('bug template file and frequency options stay aligned', () {
    final yaml = File(
      '.github/ISSUE_TEMPLATE/$issueBugTemplateFile',
    ).readAsStringSync();
    expect(yaml, contains('id: logs'));
    expect(yaml, contains('id: frequency'));
    for (final option in issueFrequencyOptions) {
      expect(yaml, contains('- $option'));
    }
  });

  test('title gets a bug prefix unless it already has one', () {
    expect(bugIssueTitle(' 切歌 '), '[BUG] 切歌');
    expect(bugIssueTitle('[BUG] 切歌'), '[BUG] 切歌');
    expect(bugIssueTitle('[bug] already'), '[bug] already');
  });

  test('section headings map onto GitHub form fields', () {
    const description = '''
### 问题描述
放到一半自己切歌

### 复现步骤
1. 播放任意歌曲
2. 等待

### 期望结果
播完再切

### 实际结果
中途切走

### 发生频率
偶尔复现

### 其他补充（可选）
无缝切歌开着
''';
    final fields = parseIssueFormFields(
      title: '放到一半切歌',
      description: description,
      version: '2.3.0',
      windowsVersion: 'Windows 11 24H2 (26100)',
    );
    expect(fields.title, '[BUG] 放到一半切歌');
    expect(fields.version, '2.3.0');
    expect(fields.windowsVersion, 'Windows 11 24H2 (26100)');
    expect(fields.description, '放到一半自己切歌');
    expect(fields.steps, '1. 播放任意歌曲\n2. 等待');
    expect(fields.expectedBehavior, '播完再切');
    expect(fields.actualBehavior, '中途切走');
    expect(fields.frequency, '偶尔复现');
    expect(fields.additionalContext, '无缝切歌开着');
  });

  test(
    'empty template sections are omitted and free text becomes description',
    () {
      const template = '''
### 问题描述

### 复现步骤
1. 
2. 

### 期望结果

### 实际结果

### 发生频率

### 其他补充（可选）
''';
      final empty = parseIssueFormFields(
        title: 'x',
        description: template,
        version: '1.0.0',
        windowsVersion: 'Windows 11',
      );
      expect(empty.description, isNull);
      expect(empty.steps, isNull);
      expect(empty.expectedBehavior, isNull);
      expect(empty.actualBehavior, isNull);
      expect(empty.frequency, isNull);
      expect(empty.additionalContext, isNull);

      final freeform = parseIssueFormFields(
        title: 'x',
        description: '就是会跳歌',
        version: '1.0.0',
        windowsVersion: 'Windows 11',
      );
      expect(freeform.description, '就是会跳歌');
    },
  );

  test('unmatched frequency stays out of the dropdown', () {
    final fields = parseIssueFormFields(
      title: 'x',
      description: '### 发生频率\n完全随机',
      version: '1.0.0',
      windowsVersion: 'Windows 11',
    );
    expect(fields.frequency, isNull);
    expect(fields.additionalContext, '发生频率：完全随机');
  });

  test('issue url uses the bug form and prefills known fields', () {
    final uri = buildBugIssueUri(
      owner: 'qingyueyin',
      repo: 'Pure-music',
      fields: parseIssueFormFields(
        title: '放到一半切歌',
        description: '### 问题描述\n中途切歌\n\n### 发生频率\n偶尔复现',
        version: '2.3.0',
        windowsVersion: 'Windows 11',
      ),
    );
    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/qingyueyin/Pure-music/issues/new');
    expect(uri.queryParameters['template'], issueBugTemplateFile);
    expect(uri.queryParameters['title'], '[BUG] 放到一半切歌');
    expect(uri.queryParameters['version'], '2.3.0');
    expect(uri.queryParameters['windows_version'], 'Windows 11');
    expect(uri.queryParameters['description'], '中途切歌');
    expect(uri.queryParameters['frequency'], '偶尔复现');
    expect(uri.queryParameters['logs'], issueLogsPasteHint);
    expect(uri.queryParameters.containsKey('body'), isFalse);
    expect(uri.toString().length, lessThanOrEqualTo(issueUrlMaxChars));
  });

  test('long fields are dropped before the url exceeds the cap', () {
    final uri = buildBugIssueUri(
      owner: 'qingyueyin',
      repo: 'Pure-music',
      maxChars: 280,
      fields: const IssueFormFields(
        title: '[BUG] 切歌',
        version: '2.3.0',
        windowsVersion: 'Windows 11 24H2 (26100.4652)',
        description: '这是一段很长的问题描述，用来把链接撑过上限。',
        steps: '1. 打开软件\n2. 播放',
        logsHint: issueLogsPasteHint,
      ),
    );
    expect(uri.queryParameters['template'], issueBugTemplateFile);
    expect(uri.queryParameters['title'], '[BUG] 切歌');
    expect(uri.queryParameters.containsKey('logs'), isFalse);
    expect(uri.toString().length, lessThanOrEqualTo(280));
  });
}

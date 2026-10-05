const issueBugTemplateFile = '01-bug_report.yml';
const issueUrlMaxChars = 6000;

const issueLogGuide =
    'APPLICATION_LOG 是折叠时间线，不是原始日志文件。先看 problems，再看 timeline。'
    'song.changed 的 reason/at/length 是切歌原因和切歌前进度。debug 默认不出现。';

const issueLogsPasteHint =
    '请粘贴剪贴板里的完整日志快照。快照由应用生成，含 APP / ENV / PREF / SETTINGS / NOW_PLAYING / APPLICATION_LOG。'
    'APPLICATION_LOG 是折叠时间线：先看 problems，再看 timeline。debug 默认不出现。';

const issueFrequencyOptions = [
  '每次都能复现',
  '大多数时候能复现',
  '偶尔复现',
  '只出现过一次',
  '出现后暂时没有再次复现',
];

const _sectionKeys = {
  '问题描述': 'description',
  '描述': 'description',
  '复现步骤': 'steps',
  '步骤': 'steps',
  '期望结果': 'expected_behavior',
  '预期结果': 'expected_behavior',
  '预期行为': 'expected_behavior',
  '实际结果': 'actual_behavior',
  '实际行为': 'actual_behavior',
  '发生频率': 'frequency',
  '复现频率': 'frequency',
  '其他补充': 'additional_context',
  '其他补充（可选）': 'additional_context',
  '其他信息': 'additional_context',
};

final _heading = RegExp(r'^#{1,3}\s+(.+?)\s*$', multiLine: true);
final _placeholderStep = RegExp(r'^\d+\.\s*$');

class IssueFormFields {
  const IssueFormFields({
    required this.title,
    required this.version,
    required this.windowsVersion,
    this.description,
    this.steps,
    this.expectedBehavior,
    this.actualBehavior,
    this.frequency,
    this.additionalContext,
    this.logsHint = issueLogsPasteHint,
  });

  final String title;
  final String version;
  final String windowsVersion;
  final String? description;
  final String? steps;
  final String? expectedBehavior;
  final String? actualBehavior;
  final String? frequency;
  final String? additionalContext;
  final String logsHint;
}

String bugIssueTitle(String raw) {
  final title = raw.trim();
  if (title.toUpperCase().startsWith('[BUG]')) return title;
  return title.isEmpty ? '[BUG] ' : '[BUG] $title';
}

IssueFormFields parseIssueFormFields({
  required String title,
  required String description,
  required String version,
  required String windowsVersion,
}) {
  final sections = _parseSections(description);
  return IssueFormFields(
    title: bugIssueTitle(title),
    version: version.trim(),
    windowsVersion: windowsVersion.trim(),
    description: sections['description'],
    steps: sections['steps'],
    expectedBehavior: sections['expected_behavior'],
    actualBehavior: sections['actual_behavior'],
    frequency: sections['frequency'],
    additionalContext: sections['additional_context'],
  );
}

Uri buildBugIssueUri({
  required String owner,
  required String repo,
  required IssueFormFields fields,
  int maxChars = issueUrlMaxChars,
}) {
  final params = <String, String>{
    'template': issueBugTemplateFile,
    'title': fields.title,
  };
  void put(String key, String? value, {int? maxFieldChars}) {
    var text = value?.trim() ?? '';
    if (text.isEmpty) return;
    if (maxFieldChars != null && text.length > maxFieldChars) {
      text = '${text.substring(0, maxFieldChars - 1)}…';
    }
    params[key] = text;
  }

  put('version', fields.version);
  put('windows_version', fields.windowsVersion);
  put('frequency', fields.frequency);
  put('description', fields.description, maxFieldChars: 1200);
  put('steps', fields.steps, maxFieldChars: 1200);
  put('expected_behavior', fields.expectedBehavior, maxFieldChars: 800);
  put('actual_behavior', fields.actualBehavior, maxFieldChars: 800);
  put('additional_context', fields.additionalContext, maxFieldChars: 800);
  put('logs', fields.logsHint, maxFieldChars: 500);

  Uri make() => Uri.https('github.com', '/$owner/$repo/issues/new', params);
  var uri = make();
  if (uri.toString().length <= maxChars) return uri;

  const dropOrder = [
    'additional_context',
    'description',
    'steps',
    'expected_behavior',
    'actual_behavior',
    'logs',
    'frequency',
    'windows_version',
    'version',
  ];
  for (final key in dropOrder) {
    if (!params.containsKey(key)) continue;
    params.remove(key);
    uri = make();
    if (uri.toString().length <= maxChars) return uri;
  }
  if (fields.title.length > 80) {
    params['title'] = '${fields.title.substring(0, 77)}...';
    uri = make();
  }
  return uri;
}

Map<String, String> _parseSections(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final matches = _heading.allMatches(normalized).toList();
  if (matches.isEmpty) {
    final body = _normalizeSection(normalized);
    return body == null ? {} : {'description': body};
  }

  final result = <String, String>{};
  void append(String key, String value) {
    final previous = result[key];
    result[key] = previous == null ? value : '$previous\n\n$value';
  }

  final intro = _normalizeSection(normalized.substring(0, matches.first.start));
  if (intro != null) append('description', intro);

  for (var i = 0; i < matches.length; i++) {
    final heading = matches[i].group(1)!.trim();
    final start = matches[i].end;
    final end = i + 1 < matches.length
        ? matches[i + 1].start
        : normalized.length;
    final body = _normalizeSection(normalized.substring(start, end));
    if (body == null) continue;
    final key = _sectionKeys[heading];
    if (key == null) {
      append('description', body);
      continue;
    }
    if (key == 'frequency') {
      final matched = _matchFrequency(body);
      if (matched != null) {
        result['frequency'] = matched;
      } else {
        append('additional_context', '发生频率：$body');
      }
      continue;
    }
    append(key, body);
  }
  return result;
}

String? _normalizeSection(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final meaningful = text.split('\n').any((line) {
    final trimmed = line.trim();
    return trimmed.isNotEmpty && !_placeholderStep.hasMatch(trimmed);
  });
  return meaningful ? text : null;
}

String? _matchFrequency(String body) {
  final first = body.split('\n').first.trim();
  for (final option in issueFrequencyOptions) {
    if (first == option) return option;
  }
  return null;
}

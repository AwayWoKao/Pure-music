// 问题报告里的崩溃段：相同异常只留最近一次，截断从行边界开始。

const _maxUniqueCrashes = 8;

final _unhandledHeader = RegExp(
  r'^\d{4}-\d{2}-\d{2}T[^|]*\|UNHANDLED\|',
);

String renderIssueCrashLog(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  String? path;
  final events = <_CrashEvent>[];
  String? header;
  final body = StringBuffer();

  void flush() {
    if (header == null) return;
    events.add(
      _CrashEvent(header: header!, body: body.toString().trimRight()),
    );
    header = null;
    body.clear();
  }

  for (final line in lines) {
    if (line.startsWith('CRASH_LOG_PATH=')) {
      path = line;
      continue;
    }
    if (line.startsWith('LOG|') || line.startsWith('TRUNCATED|')) {
      continue;
    }
    if (_unhandledHeader.hasMatch(line)) {
      flush();
      header = line;
      continue;
    }
    if (header == null) continue;
    if (body.isNotEmpty) body.writeln();
    body.write(line);
  }
  flush();

  if (events.isEmpty) {
    return normalized.trimRight();
  }

  final groups = <String, _CrashGroup>{};
  for (final event in events) {
    final existing = groups[event.fingerprint];
    if (existing == null) {
      groups[event.fingerprint] = _CrashGroup(event);
    } else {
      existing.add(event);
    }
  }
  final ordered = groups.values.toList()
    ..sort((a, b) => a.lastTime.compareTo(b.lastTime));
  final omittedUnique = ordered.length > _maxUniqueCrashes
      ? ordered.length - _maxUniqueCrashes
      : 0;
  final shown = omittedUnique > 0
      ? ordered.sublist(ordered.length - _maxUniqueCrashes)
      : ordered;

  final buffer = StringBuffer();
  if (path != null) buffer.writeln(path);
  if (omittedUnique > 0) {
    buffer.writeln(
      'total=${events.length} unique=${ordered.length} shown=${shown.length}',
    );
  } else {
    buffer.writeln('total=${events.length} unique=${ordered.length}');
  }
  for (var i = 0; i < shown.length; i++) {
    if (i > 0) buffer.writeln();
    final group = shown[i];
    if (group.count > 1) {
      buffer.writeln(
        '-- ×${group.count} ${group.firstTime} until ${group.lastTime} --',
      );
    }
    buffer.writeln(group.last.header);
    if (group.last.body.isNotEmpty) buffer.writeln(group.last.body);
  }
  return buffer.toString();
}

String truncateIssueTail(String content, int maxChars) {
  if (content.length <= maxChars) return content;
  var start = content.length - maxChars;
  if (start < 0) start = 0;
  if (start > 0 && start < content.length) {
    final next = content.indexOf('\n', start);
    if (next >= 0 && next + 1 < content.length) {
      start = next + 1;
    } else {
      final previous = content.lastIndexOf('\n', start - 1);
      if (previous >= 0) start = previous + 1;
    }
  }
  return 'TRUNCATED|omittedChars=$start\n${content.substring(start)}';
}

class _CrashEvent {
  _CrashEvent({required this.header, required this.body});

  final String header;
  final String body;

  String get time {
    final bar = header.indexOf('|');
    return bar <= 0 ? header : header.substring(0, bar);
  }

  String get fingerprint => body.isEmpty ? header : body;
}

class _CrashGroup {
  _CrashGroup(this.last)
    : firstTime = last.time,
      lastTime = last.time,
      count = 1;

  _CrashEvent last;
  final String firstTime;
  String lastTime;
  int count;

  void add(_CrashEvent event) {
    last = event;
    lastTime = event.time;
    count++;
  }
}

import 'diagnostic_redaction.dart';
import 'log_format.dart';
import 'log_record.dart';

const _detailWindowBefore = Duration(seconds: 5);
const _detailWindowAfter = Duration(seconds: 1);
const _detailLimit = 5;
// 摘要里每种问题留一条。error/fatal 全留；warn 太多时只留最近 32 种。
const _problemWarnCap = 32;

String renderIssueLog(List<LogRecord> records) {
  final ordered = [...records]..sort((a, b) => a.time.compareTo(b.time));
  final issueRecords = ordered.where(_isIncluded).toList(growable: false);
  final titles = issueRecords.where(_isTitle).toList(growable: false);
  final counts = <LogLevel, int>{};
  final moduleWarnings = <LogModule, int>{};
  for (final record in issueRecords) {
    counts[record.level] = (counts[record.level] ?? 0) + 1;
    if (record.level.index >= LogLevel.warn.index) {
      moduleWarnings[record.module] = (moduleWarnings[record.module] ?? 0) + 1;
    }
  }

  final buffer = StringBuffer()
    ..writeln(_summary(counts))
    ..writeln(_moduleSummary(moduleWarnings));
  final problems = _selectProblems(_groupByTitle(
    titles.where((record) => record.level.index >= LogLevel.warn.index),
  ));
  if (problems.groups.isEmpty) {
    buffer.writeln('problems=-');
  } else {
    buffer.writeln('-- problems --');
    if (problems.omitted > 0) {
      buffer.writeln('omitted=${problems.omitted}');
    }
    for (final group in problems.groups) {
      buffer.writeln(_formatFoldedTitle(group));
    }
  }
  buffer.writeln('-- timeline --');

  final groups = _fold(titles);
  for (final group in groups) {
    buffer.writeln(_formatFoldedTitle(group));
  }

  final expandable = titles
      .where((record) => record.level.index >= LogLevel.warn.index)
      .toList();
  final shown = expandable.skip(
    expandable.length > _detailLimit ? expandable.length - _detailLimit : 0,
  );
  for (final record in shown) {
      final details = issueRecords.where((candidate) {
      if (candidate.module != record.module) return false;
      if (candidate.level.index > LogLevel.debug.index) return false;
      final delta = candidate.time.difference(record.time);
      return delta >= -_detailWindowBefore && delta <= _detailWindowAfter;
    });
    if (details.isEmpty) continue;
    buffer.writeln(
      '-- detail ${record.module.wire} ${formatLogTime(record.time)} --',
    );
    for (final detail in details) {
      buffer.writeln(redactDiagnosticData(formatRecord(detail)));
    }
  }
  return buffer.toString();
}

bool _isTitle(LogRecord record) {
  if (record.level.index < LogLevel.info.index) return false;
  if (record.module == LogModule.desktopLyric &&
      (record.message.contains('sendLyricLineMessage') ||
          record.message.contains('first word:'))) {
    return false;
  }
  return true;
}

bool _isIncluded(LogRecord record) {
  if (record.module != LogModule.desktopLyric) return true;
  return !record.message.contains('sendLyricLineMessage') &&
      !record.message.contains('first word:');
}

String _summary(Map<LogLevel, int> counts) {
  String count(LogLevel level) => '${level.name}=${counts[level] ?? 0}';
  return LogLevel.values.map(count).join(' ');
}

String _moduleSummary(Map<LogModule, int> counts) {
  if (counts.isEmpty) return 'modules=-';
  return counts.entries
      .map((entry) => '${entry.key.wire}=${entry.value}')
      .join(' ');
}

String _formatFoldedTitle(List<LogRecord> group) {
  final first = group.first;
  final head = redactDiagnosticData(formatRecord(first).split('\n').first);
  if (group.length == 1) return head;
  final until = formatLogTime(group.last.time);
  return head.replaceFirst(
    formatLogTime(first.time),
    '${formatLogTime(first.time)} ×${group.length} until $until',
  );
}

List<List<LogRecord>> _fold(List<LogRecord> titles) {
  final groups = <List<LogRecord>>[];
  for (final record in titles) {
    if (groups.isNotEmpty && _sameTitle(groups.last.last, record)) {
      groups.last.add(record);
      continue;
    }
    groups.add([record]);
  }
  return groups;
}

List<List<LogRecord>> _groupByTitle(Iterable<LogRecord> records) {
  final groups = <List<LogRecord>>[];
  for (final record in records) {
    var matched = false;
    for (final group in groups) {
      if (_sameTitle(group.first, record)) {
        group.add(record);
        matched = true;
        break;
      }
    }
    if (!matched) groups.add([record]);
  }
  return groups;
}

({List<List<LogRecord>> groups, int omitted}) _selectProblems(
  List<List<LogRecord>> groups,
) {
  final errors = <List<LogRecord>>[];
  final warns = <List<LogRecord>>[];
  for (final group in groups) {
    if (group.first.level.index >= LogLevel.error.index) {
      errors.add(group);
    } else {
      warns.add(group);
    }
  }
  int byLastTime(List<LogRecord> a, List<LogRecord> b) =>
      b.last.time.compareTo(a.last.time);
  errors.sort(byLastTime);
  warns.sort(byLastTime);
  if (warns.length <= _problemWarnCap) {
    return (groups: [...errors, ...warns], omitted: 0);
  }
  return (
    groups: [...errors, ...warns.take(_problemWarnCap)],
    omitted: warns.length - _problemWarnCap,
  );
}

bool _sameTitle(LogRecord a, LogRecord b) {
  return a.level == b.level &&
      a.module == b.module &&
      a.event == b.event &&
      a.message == b.message &&
      a.error?.toString() == b.error?.toString() &&
      _sameFields(a.fields, b.fields);
}

bool _sameFields(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

import 'log_record.dart';

export 'log_record.dart' show LogModuleWire, parseLevel, parseLogModule;

String formatLogTime(DateTime time) {
  final local = time.isUtc ? time.toLocal() : time;
  String two(int value) => value.toString().padLeft(2, '0');
  final millis = local.millisecond.toString().padLeft(3, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${two(local.month)}-${two(local.day)}T'
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.$millis';
}

String formatRecord(LogRecord record) {
  final buffer = StringBuffer(formatLogTime(record.time))
    ..write(' ${record.level.name.toUpperCase()} ')
    ..write('${record.module.wire} ${record.event} | ');
  final fields = <String, Object?>{};
  record.fields.forEach((key, value) {
    if (value != null) fields[key] = value;
  });
  if (record.error != null) fields['error'] = record.error.toString();
  buffer.write(fields.isEmpty ? '-' : _formatFields(fields));
  buffer.write(' | ${record.message}');
  final stack = record.stackTrace;
  if (stack != null) {
    for (final line in stack.toString().split('\n')) {
      if (line.isEmpty) continue;
      buffer.write('\n  $line');
    }
  }
  return buffer.toString();
}

List<LogRecord> parseLog(String text) {
  final records = <LogRecord>[];
  for (final line in text.split('\n')) {
    final trimmedRight = line.replaceAll(RegExp(r'\r$'), '');
    if (trimmedRight.startsWith('  ')) {
      if (records.isEmpty) continue;
      final previous = records.removeLast();
      final addition = trimmedRight.substring(2);
      final merged = previous.stackTrace == null
          ? addition
          : '${previous.stackTrace}\n$addition';
      records.add(
        LogRecord(
          time: previous.time,
          level: previous.level,
          module: previous.module,
          event: previous.event,
          message: previous.message,
          fields: previous.fields,
          error: previous.error,
          stackTrace: StackTrace.fromString(merged),
        ),
      );
      continue;
    }
    final record = _parseMainLine(trimmedRight);
    if (record != null) records.add(record);
  }
  return records;
}

LogRecord? _parseMainLine(String line) {
  final firstSeparator = _findSeparatorOutsideQuotes(line, 0);
  if (firstSeparator == null) return null;
  final secondSeparator = _findSeparatorOutsideQuotes(
    line,
    firstSeparator + 3,
  );
  if (secondSeparator == null) return null;
  final head = line.substring(0, firstSeparator).split(' ');
  if (head.length != 4) return null;
  final time = _parseTime(head[0]);
  if (time == null) return null;
  return LogRecord(
    time: time,
    level: parseLevel(head[1]),
    module: parseLogModule(head[2]),
    event: head[3],
    message: line.substring(secondSeparator + 3),
    fields: _parseFields(
      line.substring(firstSeparator + 3, secondSeparator),
    ),
  );
}

int? _findSeparatorOutsideQuotes(String line, int start) {
  var quoted = false;
  var escaped = false;
  for (var index = start; index <= line.length - 3; index++) {
    final char = line[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quoted && char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      quoted = !quoted;
      continue;
    }
    if (!quoted && line.startsWith(' | ', index)) return index;
  }
  return null;
}

DateTime? _parseTime(String text) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z)?$',
  ).firstMatch(text);
  if (match == null) return null;
  final fraction = match.group(7);
  var micros = 0;
  if (fraction != null) {
    micros = int.parse(fraction.padRight(6, '0'));
  }
  final utc = match.group(8) == 'Z';
  final time = utc
      ? DateTime.utc(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
          0,
          micros,
        ).toLocal()
      : DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
          0,
          micros,
        );
  return time;
}

String _formatFields(Map<String, Object?> fields) {
  return fields.entries.map((entry) {
    final value = entry.value;
    if (value is String) return '${entry.key}=${_quote(value)}';
    return '${entry.key}=$value';
  }).join(' ');
}

String _quote(String value) {
  final needsQuotes =
      value.contains(RegExp(r'[\s|\"\\]'));
  if (!needsQuotes) return value;
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

Map<String, Object?> _parseFields(String segment) {
  if (segment == '-') return {};
  final fields = <String, Object?>{};
  final tokens = _scanTokens(segment);
  for (final token in tokens) {
    final separator = token.indexOf('=');
    if (separator <= 0) continue;
    final key = token.substring(0, separator);
    fields[key] = _parseValue(token.substring(separator + 1));
  }
  return fields;
}

List<String> _scanTokens(String segment) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  var escaped = false;
  for (final code in segment.codeUnits) {
    final char = String.fromCharCode(code);
    if (escaped) {
      buffer.write(char);
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      quoted = !quoted;
      continue;
    }
    if (char == ' ' && !quoted) {
      if (buffer.isNotEmpty) tokens.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  if (buffer.isNotEmpty) tokens.add(buffer.toString());
  return tokens;
}

Object? _parseValue(String raw) {
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  final integer = int.tryParse(raw);
  if (integer != null) return integer;
  final number = double.tryParse(raw);
  if (number != null) return number;
  return raw;
}

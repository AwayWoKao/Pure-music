import 'log_record.dart';

const _allowedTargets = {
  'smtc',
  'tag',
  'library',
  'font',
  'theme',
  'color',
  'util',
};

LogRecord? parseRustLogLine(String line, {DateTime? now}) {
  final parts = line.split('|');
  if (parts.length < 3) return null;
  final target = parts[1];
  if (!_allowedTargets.contains(target)) return null;
  return LogRecord(
    time: now ?? DateTime.now(),
    level: parseLevel(parts[0]),
    module: _moduleForTarget(target),
    event: 'legacy',
    message: parts.sublist(2).join('|'),
  );
}

LogModule _moduleForTarget(String target) {
  return switch (target) {
    'smtc' => LogModule.smtc,
    'tag' => LogModule.lyric,
    'library' => LogModule.library,
    _ => LogModule.rust,
  };
}

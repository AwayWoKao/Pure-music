import 'log_record.dart';

const logRetention = Duration(days: 14);

LogLevel fileThreshold(Map<String, String> environment) {
  final raw = environment['PURE_MUSIC_LOG'];
  if (raw == null) return LogLevel.info;
  for (final level in LogLevel.values) {
    if (level.name == raw) return level;
  }
  return LogLevel.info;
}

bool keepInMemory(LogLevel level) => level.index >= LogLevel.debug.index;

bool writeToFile(LogLevel level, LogLevel threshold) =>
    level.index >= threshold.index;

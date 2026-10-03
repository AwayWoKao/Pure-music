enum LogLevel { trace, debug, info, warn, error, fatal }

LogLevel parseLevel(String wire) {
  for (final level in LogLevel.values) {
    if (level.name.toUpperCase() == wire) return level;
  }
  return LogLevel.info;
}

enum LogModule {
  app,
  playback,
  bass,
  lyric,
  onlineLyric,
  smtc,
  memory,
  library,
  desktopLyric,
  settings,
  update,
  window,
  hotkey,
  lastfm,
  rust,
}

extension LogModuleWire on LogModule {
  String get wire => switch (this) {
    LogModule.onlineLyric => 'online_lyric',
    LogModule.desktopLyric => 'desktop_lyric',
    _ => name,
  };
}

LogModule parseLogModule(String wire) {
  for (final module in LogModule.values) {
    if (module.wire == wire) return module;
  }
  return LogModule.app;
}

class LogRecord {
  LogRecord({
    required this.time,
    required this.level,
    required this.module,
    required this.event,
    required this.message,
    Map<String, Object?> fields = const {},
    this.error,
    this.stackTrace,
  }) : fields = Map<String, Object?>.of(fields);

  final DateTime time;
  final LogLevel level;
  final LogModule module;
  final String event;
  final String message;
  final Map<String, Object?> fields;
  final Object? error;
  final StackTrace? stackTrace;
}

import 'package:flutter/foundation.dart';

import '../application_log.dart';
import 'log_format.dart';
import 'log_policy.dart';
import 'log_record.dart';

const _memoryCapacity = 2000;

class LogMemory {
  LogMemory._();

  static final instance = LogMemory._();

  final _records = <LogRecord>[];

  List<LogRecord> get records => List.unmodifiable(_records);

  void add(LogRecord record) {
    _records.add(record);
    while (_records.length > _memoryCapacity) {
      _records.removeAt(0);
    }
  }

  void clear() => _records.clear();
}

class LogChannel {
  LogChannel(this.module);

  final LogModule module;

  void trace(
    String event,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.trace, event, message, fields, error, stackTrace);

  void debug(
    String event,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.debug, event, message, fields, error, stackTrace);

  void info(
    String event,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.info, event, message, fields, error, stackTrace);

  void warn(
    String event,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.warn, event, message, fields, error, stackTrace);

  void error(
    String event,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.error, event, message, fields, error, stackTrace);

  void fatal(
    String event,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.fatal, event, message, fields, error, stackTrace);

  void _write(
    LogLevel level,
    String event,
    String message,
    Map<String, Object?> fields,
    Object? error,
    StackTrace? stackTrace,
  ) {
    log.write(
      LogRecord(
        time: DateTime.now(),
        level: level,
        module: module,
        event: event,
        message: message,
        fields: fields,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

class AppLog {
  final app = LogChannel(LogModule.app);
  final playback = LogChannel(LogModule.playback);
  final bass = LogChannel(LogModule.bass);
  final lyric = LogChannel(LogModule.lyric);
  final onlineLyric = LogChannel(LogModule.onlineLyric);
  final smtc = LogChannel(LogModule.smtc);
  final memory = LogChannel(LogModule.memory);
  final library = LogChannel(LogModule.library);
  final desktopLyric = LogChannel(LogModule.desktopLyric);
  final settings = LogChannel(LogModule.settings);
  final update = LogChannel(LogModule.update);
  final window = LogChannel(LogModule.window);
  final hotkey = LogChannel(LogModule.hotkey);
  final lastfm = LogChannel(LogModule.lastfm);
  final rust = LogChannel(LogModule.rust);

  void write(LogRecord record) {
    if (keepInMemory(record.level)) LogMemory.instance.add(record);
    applicationLogOutput.writeRecord(record);
    if (kDebugMode && record.level.index >= LogLevel.warn.index) {
      debugPrint(formatRecord(record));
    }
  }
}

final log = AppLog();

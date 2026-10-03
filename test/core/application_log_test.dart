import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/application_log.dart';
import 'package:pure_music/core/log/log_record.dart';

void main() {
  test('warning flushes stay ordered with concurrent log output', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pure_music_log_test_',
    );
    final output = ApplicationLogOutput(directoryPaths: [directory.path]);
    try {
      await output.init();
      for (var index = 0; index < 100; index++) {
        output.writeRecord(
          LogRecord(
            time: DateTime(2026, 10, 2, 14, 0, index),
            level: index.isEven ? LogLevel.info : LogLevel.warn,
            module: LogModule.app,
            event: 'legacy',
            message: 'entry=$index',
          ),
        );
      }
      output.writeRecord(
        LogRecord(
          time: DateTime(2026, 10, 2, 14, 2),
          level: LogLevel.debug,
          module: LogModule.app,
          event: 'legacy',
          message: 'debug stays out',
        ),
      );

      await output.flush();
      final content = await File(output.currentLogPath!).readAsString();
      for (var index = 0; index < 100; index++) {
        expect(content, contains('entry=$index'));
      }
      expect(content, contains('INFO app legacy | - | entry=0'));
      expect(content, isNot(contains('debug stays out')));
    } finally {
      await output.destroy();
      await directory.delete(recursive: true);
    }
  });

  test('expired logs are deleted by local calendar day', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pure_music_retention_test_',
    );
    final output = ApplicationLogOutput(directoryPaths: [directory.path]);
    try {
      File(directory.path + r'\pure_music_2000-01-01.log').writeAsStringSync(
        'old',
      );
      File(directory.path + r'\pure_music_2026-10-02.log').writeAsStringSync(
        'today',
      );
      File(directory.path + r'\crash.log').writeAsStringSync('crash');

      output.deleteExpiredLogs(now: DateTime(2026, 10, 2, 23, 30));

      expect(
        File(directory.path + r'\pure_music_2000-01-01.log').existsSync(),
        isFalse,
      );
      expect(
        File(directory.path + r'\pure_music_2026-10-02.log').existsSync(),
        isTrue,
      );
      expect(File(directory.path + r'\crash.log').existsSync(), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

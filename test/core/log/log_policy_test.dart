import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/log_policy.dart';
import 'package:pure_music/core/log/log_record.dart';

void main() {
  test('file threshold falls back to info for empty or illegal values', () {
    expect(fileThreshold(const {}), LogLevel.info);
    expect(fileThreshold(const {'PURE_MUSIC_LOG': 'debug'}), LogLevel.debug);
    expect(fileThreshold(const {'PURE_MUSIC_LOG': 'nope'}), LogLevel.info);
  });

  test('memory keeps debug and drops trace', () {
    expect(keepInMemory(LogLevel.debug), isTrue);
    expect(keepInMemory(LogLevel.trace), isFalse);
  });

  test('debug stays off disk under the default info threshold', () {
    expect(writeToFile(LogLevel.debug, LogLevel.info), isFalse);
    expect(writeToFile(LogLevel.info, LogLevel.info), isTrue);
  });
}

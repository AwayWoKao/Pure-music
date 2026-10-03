import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/app_log.dart';
import 'package:pure_music/core/log/log_record.dart';

void main() {
  tearDown(LogMemory.instance.clear);

  test('debug stays in memory and the ring drops the oldest', () {
    log.onlineLyric.debug('legacy', '[KG] searching');
    expect(LogMemory.instance.records.single.module, LogModule.onlineLyric);
    for (var i = 0; i < 2001; i++) {
      log.app.debug('loop', 'n=$i');
    }
    expect(LogMemory.instance.records, hasLength(2000));
    expect(LogMemory.instance.records.first.message, 'n=1');
  });
}

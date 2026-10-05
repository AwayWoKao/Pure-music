import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/log/diagnostic_redaction.dart';

void main() {
  test('redacts windows paths with slash or backslash', () {
    expect(
      redactDiagnosticData(r'open C:\Users\a\song.flac'),
      'open [local path]',
    );
    expect(
      redactDiagnosticData('open C:/Users/a/song.flac'),
      'open [local path]',
    );
  });

  test('redacts last.fm style secrets', () {
    expect(
      redactDiagnosticData('apiKey=abc sharedSecret=xyz sessionKey=sk'),
      'apiKey=[redacted] sharedSecret=[redacted] sessionKey=[redacted]',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/lyric/ttml.dart';
import 'package:pure_music/play_service/lyric_service.dart';

SyncLyricLine _line(
  int startMs,
  int endMs, {
  String agent = 'v1',
  int? backgroundStartMs,
  int? backgroundEndMs,
}) {
  final line = SyncLyricLine(
    Duration(milliseconds: startMs),
    Duration(milliseconds: endMs - startMs),
    [
      SyncLyricWord(
        Duration(milliseconds: startMs),
        Duration(milliseconds: endMs - startMs),
        'line',
        hasExplicitEnd: true,
      ),
    ],
  )..agent = agent;
  if (backgroundStartMs != null && backgroundEndMs != null) {
    line.bgText = 'bg';
    line.bgStart = Duration(milliseconds: backgroundStartMs);
    line.bgEnd = Duration(milliseconds: backgroundEndMs);
    line.bgWords = [
      SyncLyricWord(
        Duration(milliseconds: backgroundStartMs),
        Duration(milliseconds: backgroundEndMs - backgroundStartMs),
        'bg',
        hasExplicitEnd: true,
      ),
    ];
  }
  return line;
}

void main() {
  final lyric = Ttml(
    [
      _line(1000, 2500, backgroundStartMs: 2000, backgroundEndMs: 6000),
      _line(3000, 4500),
      _line(
        3500,
        5000,
        agent: 'v2',
        backgroundStartMs: 4000,
        backgroundEndMs: 6500,
      ),
      _line(5500, 7000),
    ],
    LyricFormat.local,
    null,
    true,
  );

  test('main and background activity are independent at every boundary', () {
    expect(
      lyricVoiceActivityAt(lyric, 2500),
      const LyricVoiceActivity(
        mainActiveIndices: [],
        backgroundActiveIndices: [0],
      ),
    );
    expect(
      lyricVoiceActivityAt(lyric, 3500),
      const LyricVoiceActivity(
        mainActiveIndices: [1, 2],
        backgroundActiveIndices: [0],
      ),
    );
    expect(
      lyricVoiceActivityAt(lyric, 4000),
      const LyricVoiceActivity(
        mainActiveIndices: [1, 2],
        backgroundActiveIndices: [0, 2],
      ),
    );
    expect(
      lyricVoiceActivityAt(lyric, 5000),
      const LyricVoiceActivity(
        mainActiveIndices: [],
        backgroundActiveIndices: [0, 2],
      ),
    );
    expect(
      lyricVoiceActivityAt(lyric, 6500),
      const LyricVoiceActivity(
        mainActiveIndices: [3],
        backgroundActiveIndices: [],
      ),
    );
  });
}

import 'dart:math' show min, max;

import 'package:pure_music/lyric/lyric.dart';

/// 演唱时间与整行的布局保留时间分开计算，不修改原始词时间。
class TtmlTimeline {
  TtmlTimeline(this.lyric) {
    _rows = [for (final line in lyric.lines) _VoiceTiming.fromLine(line)];
    final boundaries = <int>{};
    for (final row in _rows) {
      for (final window in [row.main, row.background, row.display]) {
        if (window == null || window.end <= window.start) continue;
        boundaries
          ..add(window.start)
          ..add(window.end);
        _lastEnd = max(_lastEnd, window.end);
      }
    }
    _boundaries = boundaries.toList()..sort();
  }

  final Lyric lyric;
  late final List<_VoiceTiming> _rows;
  late final List<int> _boundaries;
  int _lastEnd = 0;

  List<int> get groupStartTimes => List.unmodifiable([
    for (var i = 0; i < _rows.length; i++)
      _rows[i].display?.start ?? lyric.lines[i].start.inMilliseconds,
  ]);

  int? nextBoundaryAfter(int positionMs) {
    var low = 0;
    var high = _boundaries.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_boundaries[mid] <= positionMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low < _boundaries.length ? _boundaries[low] : null;
  }

  LyricLineUpdate? snapshotAt(int positionMs, {int? generation}) {
    if (_rows.isEmpty) return null;
    final main = <int>[];
    final background = <int>[];
    int? latestStart;
    var fallback = 0;
    int? transition;
    var hasPlayingGroup = false;
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row.main?.contains(positionMs) == true) main.add(i);
      if (row.background?.contains(positionMs) == true) background.add(i);
      final window = row.display;
      if (window == null || window.end <= window.start) continue;
      if (row.isTransition) {
        if (window.contains(positionMs)) transition = i;
        continue;
      }
      if (window.contains(positionMs)) hasPlayingGroup = true;
      if (window.start <= positionMs &&
          (latestStart == null || window.start >= latestStart)) {
        latestStart = window.start;
        fallback = i;
      }
    }

    final layout = <int>[];
    if (latestStart != null &&
        positionMs < _lastEnd &&
        (transition == null || hasPlayingGroup)) {
      for (var i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final window = row.display;
        if (!row.isTransition &&
            window != null &&
            window.end > window.start &&
            window.start <= latestStart &&
            window.end > latestStart) {
          layout.add(i);
        }
      }
    }
    // 没有新行进入时保留整组锚点；下一行进入时才移走已经结束的组。
    final primary = layout.isNotEmpty
        ? layout.first
        : !hasPlayingGroup && transition != null
        ? transition
        : fallback;
    return LyricLineUpdate(
      primaryIndex: primary,
      mainActiveIndices: List.unmodifiable(main),
      backgroundActiveIndices: List.unmodifiable(background),
      layoutIndices: List.unmodifiable(layout),
      positionMs: positionMs,
      sourceLyric: lyric,
      generation: generation,
      usesAuthoredTiming: true,
    );
  }
}

class _TimeWindow {
  const _TimeWindow(this.start, this.end);

  final int start;
  final int end;

  bool contains(int position) => position >= start && position < end;
}

class _VoiceTiming {
  const _VoiceTiming(
    this.main,
    this.background,
    this.display,
    this.isTransition,
  );

  factory _VoiceTiming.fromLine(LyricLine line) {
    if (line is! SyncLyricLine) {
      return const _VoiceTiming(null, null, null, false);
    }
    final main = _wordsWindow(line.words);
    final hasBackground =
        line.bgWords.isNotEmpty ||
        line.bgText?.isNotEmpty == true ||
        line.bg != null;
    _TimeWindow? background;
    if (hasBackground) {
      final words = _wordsWindow(line.bgWords);
      final start =
          line.bgStart?.inMilliseconds ??
          line.bg?.start.inMilliseconds ??
          words?.start ??
          line.start.inMilliseconds;
      final end =
          line.bgEnd?.inMilliseconds ??
          line.bg?.end.inMilliseconds ??
          words?.end ??
          (line.start + line.length).inMilliseconds;
      background = _TimeWindow(
        words == null ? start : min(start, words.start),
        words == null ? end : max(end, words.end),
      );
    }
    final isTransition =
        line.words.isEmpty &&
        !hasBackground &&
        line.length > const Duration(seconds: 3);
    if (isTransition) {
      return _VoiceTiming(
        null,
        null,
        _TimeWindow(
          line.start.inMilliseconds,
          (line.start + line.length).inMilliseconds,
        ),
        true,
      );
    }
    // 布局只跟主行：bg 是主行附件，下一句主行接手时本行连 bg 一起收。
    // 没有主词的 bg 行仍用 bg 窗口占位，避免整行消失。
    final display = main ?? background;
    return _VoiceTiming(main, background, display, false);
  }

  final _TimeWindow? main;
  final _TimeWindow? background;
  final _TimeWindow? display;
  final bool isTransition;

  static _TimeWindow? _wordsWindow(List<SyncLyricWord> words) {
    int? start;
    int? end;
    for (final word in words) {
      if (word.content.trim().isEmpty || word.length <= Duration.zero) continue;
      final wordStart = word.start.inMilliseconds;
      final wordEnd = (word.start + word.length).inMilliseconds;
      start = start == null ? wordStart : min(start, wordStart);
      end = end == null ? wordEnd : max(end, wordEnd);
    }
    return start == null || end == null ? null : _TimeWindow(start, end);
  }
}

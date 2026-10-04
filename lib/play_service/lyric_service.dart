import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' show max, min;

import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/lyric/lrc.dart';
import 'package:pure_music/lyric/lrc_serializer.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/lyric/lyric_tag_word_format.dart';
import 'package:pure_music/lyric/ttml.dart' show Ttml;
import 'package:pure_music/lyric/ttml_timeline.dart';
import 'package:pure_music/lyric/lyric_source.dart';
import 'package:pure_music/lyric/lyric_stripper.dart';
import 'package:pure_music/lyric/lyric_loader.dart';
import 'package:pure_music/core/matcher.dart';
import 'package:pure_music/core/settings.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/native/bass/bass_player.dart';
import 'package:pure_music/play_service/play_service.dart';
import 'package:pure_music/play_service/lyric_write_prompt_history.dart';
import 'package:pure_music/native/rust/api/tag_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

const int _kLyricCacheCapacity = 32;
const int lyricWordPreSwitchMs = 320;
const int lyricHighlightCatchUpDurationMs = 260;
const int lyricHighlightFinishLeadMs = 32;
const int lyricLineAdvanceTimerMaxMs = 1000;

/// 判断一次位置变化是否应按跳转处理；定时器回调可关闭正向跳转判定。
bool lyricLineAdvanceIsSeekJump({
  required double previousPositionSec,
  required double nextPositionSec,
  required double rate,
  bool allowForwardJump = true,
}) {
  final delta = nextPositionSec - previousPositionSec;
  if (delta < -0.05) return true;
  if (!allowForwardJump) return false;
  final speed = rate > 1.0 ? rate : 1.0;
  final maxForwardSec = (lyricLineAdvanceTimerMaxMs / 1000.0) * speed + 0.35;
  return delta > maxForwardSec;
}

/// 顺序播放每次只推进一行，避免定时器迟到时一次跳过多行把切换动画吞掉。
int lyricSequentialAdvanceCursor({
  required int nextLyricLine,
  required int posMs,
  required List<int> lineSwitchStartMs,
}) {
  if (nextLyricLine < lineSwitchStartMs.length &&
      posMs >= lineSwitchStartMs[nextLyricLine]) {
    return nextLyricLine + 1;
  }
  return nextLyricLine;
}

int? lyricNextAdvanceBoundaryMs({
  required int posMs,
  required int nextLyricLine,
  required List<int> lineSwitchStartMs,
  List<int> lineRenderStartMs = const [],
  List<int> lineMainEndMs = const [],
  List<int> lineEndMs = const [],
  List<int> backgroundStartMs = const [],
  List<int> backgroundEndMs = const [],
}) {
  if (nextLyricLine >= 0 &&
      nextLyricLine < lineSwitchStartMs.length &&
      posMs >= lineSwitchStartMs[nextLyricLine]) {
    return posMs;
  }
  final nextStart = _lyricLowerBoundGreater(lineSwitchStartMs, posMs);
  int? candidate = nextStart == -1 ? null : lineSwitchStartMs[nextStart];
  for (final startMs in lineRenderStartMs) {
    final entryMs = startMs - lyricWordPreSwitchMs;
    if (entryMs > posMs && (candidate == null || entryMs < candidate)) {
      candidate = entryMs;
    }
    if (startMs > posMs && (candidate == null || startMs < candidate)) {
      candidate = startMs;
    }
  }
  final activityEndMs = lineMainEndMs.isNotEmpty ? lineMainEndMs : lineEndMs;
  for (final endMs in activityEndMs) {
    if (endMs > posMs && (candidate == null || endMs < candidate)) {
      candidate = endMs;
    }
  }
  for (final startMs in backgroundStartMs) {
    if (startMs > posMs && (candidate == null || startMs < candidate)) {
      candidate = startMs;
    }
  }
  for (final endMs in backgroundEndMs) {
    if (endMs > posMs && (candidate == null || endMs < candidate)) {
      candidate = endMs;
    }
  }
  return candidate;
}

int lyricSwitchCursorAt({
  required int timeMs,
  required List<int> switchStartMs,
  required List<int> lineEndMs,
  required int hintLineIndex,
}) {
  final n = switchStartMs.length;
  if (n == 0) return -1;
  if (hintLineIndex >= 0 &&
      hintLineIndex < n &&
      hintLineIndex < lineEndMs.length) {
    final nextIndex = hintLineIndex + 1;
    if (nextIndex < n && nextIndex < lineEndMs.length) {
      final nextStart = switchStartMs[nextIndex];
      final nextEnd = lineEndMs[nextIndex];
      if (timeMs >= nextStart && timeMs < nextEnd) {
        return nextIndex + 1;
      }
      if (timeMs >= nextStart) {
        return _lyricLowerBoundGreater(switchStartMs, timeMs);
      }
    }
    if (timeMs >= switchStartMs[hintLineIndex] &&
        timeMs < lineEndMs[hintLineIndex]) {
      return hintLineIndex + 1;
    }
  }
  return _lyricLowerBoundGreater(switchStartMs, timeMs);
}

int _lyricLowerBoundGreater(List<int> arr, int x) {
  if (arr.isEmpty) return -1;
  var lo = 0;
  var hi = arr.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (arr[mid] > x) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return lo >= arr.length ? -1 : lo;
}

bool _hasDesktopLyricContent(LyricLine line) {
  final content = switch (line) {
    SyncLyricLine() => line.content,
    UnsyncLyricLine() => line.content,
    _ => null,
  };
  return content != null && content.trim().isNotEmpty;
}

bool isDesktopLyricTransitionLine(LyricLine line) {
  if (line is SyncLyricLine) {
    return line.words.isEmpty && line.length > const Duration(seconds: 3);
  }
  if (line is LrcLine) {
    return line.isBlank &&
        line.length > const Duration(seconds: 3) &&
        line.start == Duration.zero;
  }
  return false;
}

int _lyricLineRenderStartMs(LyricLine line) {
  if (line is SyncLyricLine && line.words.isNotEmpty) {
    return line.words.first.start.inMilliseconds;
  }
  return line.start.inMilliseconds;
}

int _lyricLineRenderEndMs(Lyric lyric, LyricLine line) {
  var end = (line.start + line.length).inMilliseconds;
  if (line is SyncLyricLine && line.words.isNotEmpty) {
    final lastWord = line.words.last;
    final wordEnd = (lastWord.start + lastWord.length).inMilliseconds;
    if (lyric is! Ttml) return wordEnd;
    end = max(end, wordEnd);
  }
  if (lyric is Ttml && line is SyncLyricLine) {
    final bgEnd = line.bgEnd ?? line.bg?.end;
    if (bgEnd != null) end = max(end, bgEnd.inMilliseconds);
    for (final word in line.bgWords) {
      end = max(end, (word.start + word.length).inMilliseconds);
    }
  }
  return end;
}

@visibleForTesting
class LyricVoiceActivity {
  const LyricVoiceActivity({
    required this.mainActiveIndices,
    required this.backgroundActiveIndices,
  });

  final List<int> mainActiveIndices;
  final List<int> backgroundActiveIndices;

  @override
  bool operator ==(Object other) {
    return other is LyricVoiceActivity &&
        listEquals(other.mainActiveIndices, mainActiveIndices) &&
        listEquals(other.backgroundActiveIndices, backgroundActiveIndices);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(mainActiveIndices),
    Object.hashAll(backgroundActiveIndices),
  );
}

@visibleForTesting
LyricVoiceActivity lyricVoiceActivityAt(Lyric lyric, int positionMs) {
  final update = lyric is Ttml
      ? TtmlTimeline(lyric).snapshotAt(positionMs)
      : null;
  return LyricVoiceActivity(
    mainActiveIndices: update?.mainActiveIndices ?? const [],
    backgroundActiveIndices: update?.backgroundActiveIndices ?? const [],
  );
}

SyncLyricLine? desktopLyricPreludeLineAt(Lyric lyric, int positionMs) {
  if (lyric.lines.isEmpty) return null;
  final firstIndex = lyric.lines.indexWhere(_hasDesktopLyricContent);
  if (firstIndex <= 0) return null;
  for (var index = 0; index < firstIndex; index++) {
    final line = lyric.lines[index];
    if (!isDesktopLyricTransitionLine(line) || line.start != Duration.zero) {
      continue;
    }
    final endMs = _lyricLineRenderEndMs(lyric, line);
    if (positionMs < endMs) {
      return SyncLyricLine(
        Duration.zero,
        Duration(milliseconds: endMs),
        const [],
      );
    }
  }
  return null;
}

int lyricLineSwitchStartMs({
  required int previousSwitchStartMs,
  required int previousLineEndMs,
  required int nextLineStartMs,
  required bool preserveSingleWordTiming,
}) {
  var switchStart = max(
    previousSwitchStartMs,
    nextLineStartMs - lyricWordPreSwitchMs,
  );
  if (preserveSingleWordTiming) {
    switchStart = max(switchStart, min(previousLineEndMs, nextLineStartMs));
  }
  return switchStart;
}

int? lyricHighlightDeadlineMsForLine(Lyric lyric, int lineIndex) {
  if (lyric is Ttml) return null;
  final lines = lyric.lines;
  if (lineIndex < 0 || lineIndex >= lines.length) return null;
  final currentLine = lines[lineIndex];
  if (currentLine is SyncLyricLine && currentLine.words.length == 1) {
    return null;
  }
  for (var i = lineIndex + 1; i < lines.length; i++) {
    final next = lines[i];
    if (next is SyncLyricLine &&
        next.words.isEmpty &&
        next.length <= const Duration(seconds: 3)) {
      continue;
    }
    if (next is LrcLine &&
        next.isBlank &&
        (next.length <= const Duration(seconds: 3) ||
            next.start > Duration.zero)) {
      continue;
    }
    final start = _lyricLineRenderStartMs(next);
    return next is SyncLyricLine && next.words.isNotEmpty
        ? start - lyricWordPreSwitchMs
        : start;
  }
  return null;
}

typedef _CachedLocalLyric = ({Lyric lyric, bool isExternal});

class _LyricCache {
  final LinkedHashMap<String, _CachedLocalLyric> _cache = LinkedHashMap();

  _CachedLocalLyric? get(String path) {
    final lyric = _cache[path];
    if (lyric != null) {
      _cache.remove(path);
      _cache[path] = lyric;
    }
    return lyric;
  }

  bool containsKey(String path) => _cache.containsKey(path);

  void put(String path, _CachedLocalLyric lyric) {
    if (_cache.containsKey(path)) {
      _cache.remove(path);
    } else if (_cache.length >= _kLyricCacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[path] = lyric;
  }

  void remove(String path) {
    _cache.remove(path);
  }

  void clear() {
    _cache.clear();
  }
}

final _LyricCache _lyricCache = _LyricCache();

/// 只通知 lyric 变更
class LyricService extends ChangeNotifier {
  final PlayService playService;

  Timer? _lineAdvanceTimer;
  double _lastPos = 0.0;
  Lyric? _currLyric;
  TtmlTimeline? _ttmlTimeline;
  int _ttmlGeneration = 0;
  List<int> _lineRenderStartMs = const [];
  List<int> _lineSwitchStartMs = const [];
  List<int> _lineEndMs = const [];
  int _lastEmittedLineIndex = -1;
  int _lastDesktopLyricLineIndex = -1;
  bool _desktopGapShown = false;
  bool _desktopPreludeShown = false;
  int _lyricRequestToken = 0;
  int _prefetchGeneration = 0;
  final Map<String, Future<_CachedLocalLyric?>> _lyricPrefetches = {};
  String? _activeLyricPath;

  final LyricWritePromptHistory _lyricWritePromptHistory =
      LyricWritePromptHistory();
  Timer? _promptTimer;
  int _promptGeneration = 0;
  LyricService(this.playService) {
    playService.playbackService.playerStateNotifier.addListener(
      _syncLineAdvanceTimer,
    );
    _syncLineAdvanceTimer();
  }

  void _syncLineAdvanceTimer() {
    final isPlaying =
        playService.playbackService.playerState == PlayerState.playing;
    final lyric = _currLyric;
    _lineAdvanceTimer?.cancel();
    _lineAdvanceTimer = null;
    if (!isPlaying || lyric == null || lyric.lines.isEmpty) {
      return;
    }
    findCurrLyricLineAt(playService.playbackService.position);
  }

  void _scheduleNextLineAdvance() {
    if (playService.playbackService.playerState != PlayerState.playing) return;
    final lyric = _currLyric;
    if (lyric == null || lyric.lines.isEmpty) return;
    final posMs = (playService.playbackService.position * 1000).round();
    final nextBoundaryMs = _nextLyricBoundaryAfter(posMs);
    if (nextBoundaryMs == null) return;
    final speed = playService.playbackService.rate.value;
    if (speed <= 0) return;
    final delayMs = ((nextBoundaryMs - posMs) / speed)
        .clamp(16, lyricLineAdvanceTimerMaxMs)
        .toInt();
    _lineAdvanceTimer?.cancel();
    _lineAdvanceTimer = Timer(Duration(milliseconds: delayMs), () {
      _lineAdvanceTimer = null;
      _advanceLyricLineAt(playService.playbackService.position);
      _scheduleNextLineAdvance();
    });
  }

  void _restartLineAdvanceTimer() {
    if (playService.playbackService.playerState != PlayerState.playing) return;
    _lineAdvanceTimer?.cancel();
    _lineAdvanceTimer = null;
    _scheduleNextLineAdvance();
  }

  int? _nextLyricBoundaryAfter(int posMs) {
    final timeline = _ttmlTimeline;
    if (timeline != null) return timeline.nextBoundaryAfter(posMs);
    return lyricNextAdvanceBoundaryMs(
      posMs: posMs,
      nextLyricLine: _nextLyricLine,
      lineSwitchStartMs: _lineSwitchStartMs,
    );
  }

  bool _emitLineUpdate({
    required int primaryIndex,
    required List<int> mainActiveIndices,
    required List<int> backgroundActiveIndices,
    required List<int> layoutIndices,
    required int positionMs,
    bool force = false,
    Lyric? sourceLyric,
    int? generation,
    bool usesAuthoredTiming = false,
  }) {
    final changed =
        primaryIndex != _lastEmittedLineIndex ||
        !listEquals(_lastEmittedActiveIndices, mainActiveIndices) ||
        !listEquals(
          _lastEmittedBackgroundActiveIndices,
          backgroundActiveIndices,
        ) ||
        !listEquals(_lastEmittedLayoutIndices, layoutIndices);
    if (!force && !changed) return false;

    _lastEmittedLineIndex = primaryIndex;
    _lastEmittedLineIndexForHint = primaryIndex;
    _lastEmittedActiveIndices = mainActiveIndices;
    _lastEmittedBackgroundActiveIndices = backgroundActiveIndices;
    _lastEmittedLayoutIndices = layoutIndices;
    _lyricLineStreamController.add(
      LyricLineUpdate(
        primaryIndex: primaryIndex,
        activeIndices: mainActiveIndices,
        mainActiveIndices: mainActiveIndices,
        backgroundActiveIndices: backgroundActiveIndices,
        layoutIndices: layoutIndices,
        positionMs: positionMs,
        sourceLyric: sourceLyric,
        generation: generation,
        usesAuthoredTiming: usesAuthoredTiming,
      ),
    );
    return true;
  }

  TtmlTimeline _timelineFor(Lyric lyric) {
    final timeline = _ttmlTimeline;
    return timeline != null && identical(timeline.lyric, lyric)
        ? timeline
        : TtmlTimeline(lyric);
  }

  void _emitTtmlAt(Ttml lyric, int positionMs, {bool force = false}) {
    final generation = _ttmlGeneration;
    final update = _timelineFor(
      lyric,
    ).snapshotAt(positionMs, generation: generation);
    if (update == null) return;
    _emitLineUpdate(
      primaryIndex: update.primaryIndex,
      mainActiveIndices: update.mainActiveIndices,
      backgroundActiveIndices: update.backgroundActiveIndices,
      layoutIndices: update.layoutIndices,
      positionMs: positionMs,
      sourceLyric: lyric,
      generation: generation,
      usesAuthoredTiming: true,
      force: force,
    );
    final primary = update.primaryIndex;
    if (primary != _lastDesktopLyricLineIndex) {
      _lastDesktopLyricLineIndex = primary;
      _desktopGapShown = false;
      if (_hasDesktopLyricContent(lyric.lines[primary])) {
        final nextLine = primary + 1 < lyric.lines.length
            ? lyric.lines[primary + 1]
            : null;
        playService.desktopLyricService.canSendMessage.then((canSend) {
          if (!canSend ||
              !identical(_currLyric, lyric) ||
              generation != _ttmlGeneration ||
              primary != _lastDesktopLyricLineIndex) {
            return;
          }
          playService.desktopLyricService.sendLyricLineMessage(
            lyric.lines[primary],
            nextLine: nextLine,
            isWordByWord: lyric.isWordByWord,
            lineIndex: primary,
          );
        });
      }
    }
    _sendDesktopPreludeIfNeeded(positionMs);
    _sendDesktopGapIfNeeded(primary, positionMs);
  }

  void _advanceLyricLineAt(double pos) {
    final previous = _lastPos;
    _lastPos = pos;
    if (lyricLineAdvanceIsSeekJump(
      previousPositionSec: previous,
      nextPositionSec: pos,
      rate: playService.playbackService.rate.value,
      // 定时器正向迟到仍是正常播放，交给顺序游标逐行补发更新。
      allowForwardJump: false,
    )) {
      findCurrLyricLineAt(pos);
      return;
    }
    final posMs = (pos * 1000).round();
    final lyric = _currLyric;
    if (lyric == null) return;
    if (lyric is Ttml) {
      _emitTtmlAt(lyric, posMs);
      return;
    }
    _nextLyricLine = lyricSequentialAdvanceCursor(
      nextLyricLine: _nextLyricLine,
      posMs: posMs,
      lineSwitchStartMs: _lineSwitchStartMs,
    );

    _emitCurrentLineState(
      lyric: lyric,
      currLineIndex: _nextLyricLine - 1,
      positionMs: posMs,
      force: false,
    );
  }

  void _sendDesktopGapIfNeeded(int currLineIndex, int posMs) {
    final lyric = _currLyric;
    if (lyric == null) return;
    if (currLineIndex < 0 || currLineIndex >= lyric.lines.length) return;
    final transitionLine = lyric.lines[currLineIndex];
    if (!isDesktopLyricTransitionLine(transitionLine)) {
      _desktopGapShown = false;
      return;
    }
    final transitionStart = _lyricLineRenderStartMs(transitionLine);
    final transitionEnd = _lyricLineRenderEndMs(lyric, transitionLine);
    if (transitionEnd <= transitionStart ||
        posMs < transitionStart ||
        posMs >= transitionEnd) {
      _desktopGapShown = false;
      return;
    }
    if (_desktopGapShown) return;
    _desktopGapShown = true;
    var nextIndex = currLineIndex + 1;
    while (nextIndex < lyric.lines.length &&
        !_hasDesktopLyricContent(lyric.lines[nextIndex])) {
      nextIndex += 1;
    }
    final nextLine = nextIndex < lyric.lines.length
        ? lyric.lines[nextIndex]
        : null;
    playService.desktopLyricService.canSendMessage.then((canSend) {
      if (!canSend) return;
      playService.desktopLyricService.sendLyricLineMessage(
        transitionLine,
        nextLine: nextLine,
        isWordByWord: lyric.isWordByWord,
        syntheticLineId: playService.desktopLyricService
            .syntheticLineIdForStart(transitionStart),
      );
    });
  }

  /// 第一行歌词开始前给桌面歌词发送完整前奏，保持中途启动时的进度一致。
  void _sendDesktopPreludeIfNeeded(int posMs) {
    final lyric = _currLyric;
    if (lyric == null || lyric.lines.isEmpty) return;
    final firstIndex = lyric.lines.indexWhere(_hasDesktopLyricContent);
    if (firstIndex < 0) return;
    final firstLine = lyric.lines[firstIndex];
    final preludeLine = desktopLyricPreludeLineAt(lyric, posMs);
    if (preludeLine == null) {
      _desktopPreludeShown = false;
      return;
    }
    if (_desktopPreludeShown) return;
    _desktopPreludeShown = true;
    playService.desktopLyricService.canSendMessage.then((canSend) {
      if (!canSend) return;
      playService.desktopLyricService.sendLyricLineMessage(
        preludeLine,
        nextLine: firstLine,
        isWordByWord: lyric.isWordByWord,
        syntheticLineId: playService.desktopLyricService
            .syntheticLineIdForStart(preludeLine.start.inMilliseconds),
      );
    });
  }

  Audio? _getNowPlaying() => playService.playbackService.nowPlaying;

  Future<void> writeCurrentLyricToTag({
    LyricTagWordFormat? wordFormat,
    String? expectedPath,
  }) async {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) throw StateError('当前没有正在播放的歌曲');
    final audioPath = nowPlaying.path;
    if (expectedPath != null && expectedPath != audioPath) {
      throw StateError('当前歌曲已切换');
    }

    final lyric = _currLyric ?? await currLyricFuture;
    if (lyric == null) throw StateError('当前歌曲没有可写入的歌词');

    final lrcText = serializeLyricToLrc(
      lyric,
      wordFormat: wordFormat ?? AppSettings.instance.lyricTagWordFormat,
      includeTranslation: AppSettings.instance.lyricTagIncludeTranslation,
      includeRomanization: AppSettings.instance.lyricTagIncludeRomanization,
    );
    if (lrcText.trim().isEmpty) {
      throw StateError('当前歌词内容为空');
    }
    if (_getNowPlaying()?.path != audioPath) {
      throw StateError('当前歌曲已切换');
    }

    await writeLyricToPath(path: audioPath, lyric: lrcText);
  }

  Future<String?> saveCurrentLyricAsLrc({
    LyricTagWordFormat? wordFormat,
  }) async {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return null;

    final lyric = _currLyric ?? await currLyricFuture;
    if (lyric == null) return null;

    final lrcText = serializeLyricToLrc(
      lyric,
      wordFormat: wordFormat ?? AppSettings.instance.lyricTagWordFormat,
    );
    if (lrcText.trim().isEmpty) return null;

    final dir = p.dirname(nowPlaying.path);
    final base = p.basenameWithoutExtension(nowPlaying.path);
    final outPath = p.join(dir, '$base.lrc');
    final outFile = File(outPath);

    if (outFile.existsSync()) {
      final bakPath = p.join(dir, '$base.lrc.bak');
      try {
        await outFile.copy(bakPath);
      } catch (_) {}
    }

    await writeTextFileAtomically(outPath, lrcText);

    return outPath;
  }

  /// 供 widget 使用
  Future<Lyric?> currLyricFuture = Future.value(null);
  LyricSourceType _activeLyricSourceType = LyricSourceType.local;
  // 非在线来源细分：true=外置文件，false=内嵌标签，null=尚未确定
  bool? _activeLocalIsExternal;

  /// 当前正在使用的歌词来源（加载期间为预设值，完成后为实际命中源）
  LyricSourceType get activeLyricSourceType => _activeLyricSourceType;

  /// 非在线来源时，true=外置文件，false=内嵌标签，null=尚未确定
  bool? get activeLocalIsExternal => _activeLocalIsExternal;

  /// 当前歌词是否已加载
  bool get hasLyric => _currLyric != null;

  /// 下一行歌词
  int _nextLyricLine = 0;
  int _lastEmittedLineIndexForHint = -1;
  List<int> _lastEmittedActiveIndices = const [];
  List<int> _lastEmittedBackgroundActiveIndices = const [];
  List<int> _lastEmittedLayoutIndices = const [];

  late final StreamController<LyricLineUpdate> _lyricLineStreamController =
      StreamController.broadcast(
        onListen: () {
          forceEmitCurrentLine();
        },
      );

  Stream<LyricLineUpdate> get lyricLineStream =>
      _lyricLineStreamController.stream;

  LyricLineUpdate? lineUpdateAt(double positionSeconds) {
    final lyric = _currLyric;
    if (lyric == null) return null;
    return lineUpdateForLyric(
      lyric,
      positionSeconds,
      hint: _lastEmittedLineIndexForHint,
    );
  }

  LyricLineUpdate? lineUpdateForLyric(
    Lyric lyric,
    double positionSeconds, {
    int hint = -1,
  }) {
    if (lyric.lines.isEmpty) return null;
    final posMs = (positionSeconds * 1000).round();
    if (lyric is Ttml) {
      return _timelineFor(lyric).snapshotAt(
        posMs,
        generation: identical(lyric, _currLyric) ? _ttmlGeneration : null,
      );
    }
    final useCurrentTables = identical(lyric, _currLyric);
    final renderStartMs = useCurrentTables
        ? _lineRenderStartMs
        : _buildLineStarts(lyric);
    final lineEndMs = useCurrentTables ? _lineEndMs : _buildLineEnds(lyric);
    final switchStartMs = useCurrentTables
        ? _lineSwitchStartMs
        : _buildLineSwitchStarts(lyric, renderStartMs, lineEndMs);
    final next = _findLrcPosInTables(
      time: posMs,
      lines: lyric.lines,
      lineRenderStartMs: switchStartMs,
      lineEndMs: lineEndMs,
      hint: hint,
    );
    final currLineIndex = (next == -1 ? lyric.lines.length : next) - 1;
    return LyricLineUpdate(
      primaryIndex: currLineIndex.clamp(0, lyric.lines.length - 1),
      activeIndices: const [],
      positionMs: posMs,
    );
  }

  LyricLineUpdate? currentLineUpdate() {
    return lineUpdateAt(playService.playbackService.position);
  }

  List<int> switchStartMsForLyric(Lyric lyric) {
    if (identical(lyric, _currLyric)) {
      return List<int>.unmodifiable(_lineSwitchStartMs);
    }
    final renderStartMs = _buildLineStarts(lyric);
    return List<int>.unmodifiable(
      _buildLineSwitchStarts(lyric, renderStartMs, _buildLineEnds(lyric)),
    );
  }

  void _emitCurrentLineState({
    required Lyric lyric,
    required int currLineIndex,
    required int positionMs,
    required bool force,
  }) {
    final activity = _lineActivityForSwitchPosition(currLineIndex, positionMs);
    final mainActiveIndices = activity.mainActiveIndices;
    final backgroundActiveIndices = activity.backgroundActiveIndices;
    final layoutIndices = activity.layoutIndices;

    if (currLineIndex < 0) {
      _emitLineUpdate(
        primaryIndex: 0,
        mainActiveIndices: mainActiveIndices,
        backgroundActiveIndices: backgroundActiveIndices,
        layoutIndices: layoutIndices,
        positionMs: positionMs,
        force: force,
      );
      _sendDesktopPreludeIfNeeded(positionMs);
      return;
    }

    if (currLineIndex >= lyric.lines.length) {
      _emitLineUpdate(
        primaryIndex: lyric.lines.length - 1,
        mainActiveIndices: mainActiveIndices,
        backgroundActiveIndices: backgroundActiveIndices,
        layoutIndices: layoutIndices,
        positionMs: positionMs,
        force: force,
      );
      return;
    }

    var primaryIndex = currLineIndex;
    if (layoutIndices.isNotEmpty) {
      final minActive = layoutIndices.first;
      if (minActive != currLineIndex) {
        primaryIndex = minActive;
      }
    }
    _emitLineUpdate(
      primaryIndex: primaryIndex,
      mainActiveIndices: mainActiveIndices,
      backgroundActiveIndices: backgroundActiveIndices,
      layoutIndices: layoutIndices,
      positionMs: positionMs,
      force: force,
    );

    if (primaryIndex != _lastDesktopLyricLineIndex) {
      _lastDesktopLyricLineIndex = primaryIndex;
      _desktopGapShown = false;
      if (_hasDesktopLyricContent(lyric.lines[primaryIndex])) {
        final nextLine = primaryIndex + 1 < lyric.lines.length
            ? lyric.lines[primaryIndex + 1]
            : null;
        playService.desktopLyricService.canSendMessage.then((canSend) {
          if (!canSend) return;
          playService.desktopLyricService.sendLyricLineMessage(
            lyric.lines[primaryIndex],
            nextLine: nextLine,
            isWordByWord: lyric.isWordByWord,
            highlightDeadlineMs: lyricHighlightDeadlineMsForLine(
              lyric,
              primaryIndex,
            ),
            lineIndex: primaryIndex,
          );
        });
      }
    }
    _sendDesktopGapIfNeeded(currLineIndex, positionMs);
  }

  /// 强制发射当前行（绕过 _lastEmittedLineIndex 检查），
  /// 用于新创建的歌词 view 初始化时获取当前行
  void forceEmitCurrentLine() {
    final lyric = _currLyric;
    if (lyric == null) {
      final token = _lyricRequestToken;
      final path = _activeLyricPath;
      final future = currLyricFuture;
      future.then((value) {
        if (path == null || !_isCurrentLyricRequest(token, path, future)) {
          return;
        }
        if (value == null) return;
        _setCurrLyric(value);
        forceEmitCurrentLine();
      });
      return;
    }
    final posMs = (playService.playbackService.position * 1000).round();
    if (lyric is Ttml) {
      _emitTtmlAt(lyric, posMs, force: true);
      _restartLineAdvanceTimer();
      return;
    }
    final next = _findLrcPos(
      time: posMs,
      lines: lyric.lines,
      hint: _lastEmittedLineIndexForHint,
    );
    _nextLyricLine = next == -1 ? lyric.lines.length : next;
    _emitCurrentLineState(
      lyric: lyric,
      currLineIndex: _nextLyricLine - 1,
      positionMs: posMs,
      force: true,
    );
    _restartLineAdvanceTimer();
  }

  void findCurrLyricLineAt(double positionSeconds) {
    final lyric = _currLyric;
    if (lyric == null) {
      final token = _lyricRequestToken;
      final path = _activeLyricPath;
      final future = currLyricFuture;
      future.then((value) {
        if (path == null || !_isCurrentLyricRequest(token, path, future)) {
          return;
        }
        if (value == null) return;
        _setCurrLyric(value);
        findCurrLyricLineAt(positionSeconds);
      });
      return;
    }

    _lastPos = positionSeconds;
    final posMs = (positionSeconds * 1000).round();
    if (lyric is Ttml) {
      _ttmlGeneration++;
      _emitTtmlAt(lyric, posMs, force: true);
      _restartLineAdvanceTimer();
      return;
    }
    final hint = _lastEmittedLineIndexForHint;
    final next = _findLrcPos(time: posMs, lines: lyric.lines, hint: hint);
    _nextLyricLine = next == -1 ? lyric.lines.length : next;
    _emitCurrentLineState(
      lyric: lyric,
      currLineIndex: _nextLyricLine - 1,
      positionMs: posMs,
      force: false,
    );
    _restartLineAdvanceTimer();
  }

  /// hint 优先 + 二分搜索查找歌词位置
  /// 正常播放时 hint 命中率 >95%，时间复杂度接近 O(1)
  int _findLrcPos({
    required int time,
    required List<LyricLine> lines,
    required int hint,
  }) {
    return _findLrcPosInTables(
      time: time,
      lines: lines,
      lineRenderStartMs: _lineSwitchStartMs,
      lineEndMs: _lineEndMs,
      hint: hint,
    );
  }

  int _findLrcPosInTables({
    required int time,
    required List<LyricLine> lines,
    required List<int> lineRenderStartMs,
    required List<int> lineEndMs,
    required int hint,
  }) {
    if (lines.isEmpty) return -1;
    return lyricSwitchCursorAt(
      timeMs: time,
      switchStartMs: lineRenderStartMs,
      lineEndMs: lineEndMs,
      hintLineIndex: hint,
    );
  }

  ({
    List<int> mainActiveIndices,
    List<int> backgroundActiveIndices,
    List<int> layoutIndices,
  })
  _lineActivityForSwitchPosition(int lineIndex, int posMs) {
    final lyric = _currLyric;
    final update = lyric is Ttml ? _timelineFor(lyric).snapshotAt(posMs) : null;
    return (
      mainActiveIndices: update?.mainActiveIndices ?? const [],
      backgroundActiveIndices: update?.backgroundActiveIndices ?? const [],
      layoutIndices: update?.layoutIndices ?? const [],
    );
  }

  List<int> _buildLineStarts(Lyric lyric) {
    return lyric.lines.map(_lyricLineRenderStartMs).toList();
  }

  List<int> _buildLineEnds(Lyric lyric) {
    return lyric.lines
        .map((line) => _lyricLineRenderEndMs(lyric, line))
        .toList();
  }

  List<int> _buildLineSwitchStarts(
    Lyric lyric,
    List<int> renderStartMs,
    List<int> lineEndMs,
  ) {
    if (lyric is Ttml) return _timelineFor(lyric).groupStartTimes;
    final switchStarts = List<int>.of(renderStartMs);
    for (var i = 1; i < lyric.lines.length; i++) {
      final line = lyric.lines[i];
      if (line is SyncLyricLine && line.words.isNotEmpty) {
        final previous = lyric.lines[i - 1];
        switchStarts[i] = lyricLineSwitchStartMs(
          previousSwitchStartMs: switchStarts[i - 1],
          previousLineEndMs: lineEndMs[i - 1],
          nextLineStartMs: renderStartMs[i],
          preserveSingleWordTiming:
              previous is SyncLyricLine && previous.words.length == 1,
        );
      }
    }
    return switchStarts;
  }

  void _setCurrLyric(Lyric lyric) {
    // 先还原歌词中被 * 屏蔽的脏话词，避免星号/连字符干扰元数据检测
    applyProfanityUncensor(lyric);
    if (lyric is Ttml && _activeLyricSourceType == LyricSourceType.amll) {
      blankAmllTtmlCreatorLines(lyric.lines);
    } else if (!AppSettings.instance.keepLyricMetadata) {
      final nowPlaying = _getNowPlaying();
      final artists = nowPlaying == null
          ? const <String>[]
          : <String>{...nowPlaying.splitedArtists, nowPlaying.artist}
                .where((artist) => artist.trim().isNotEmpty)
                .toList(growable: false);
      blankMetadataLines(
        lyric.lines,
        StripOptions(matchTitle: nowPlaying?.title, matchArtists: artists),
      );
    }

    _currLyric = lyric;
    _ttmlGeneration++;
    _ttmlTimeline = lyric is Ttml ? TtmlTimeline(lyric) : null;
    _lineRenderStartMs = _buildLineStarts(lyric);
    _lineEndMs = _buildLineEnds(lyric);
    _lineSwitchStartMs = _buildLineSwitchStarts(
      lyric,
      _lineRenderStartMs,
      _lineEndMs,
    );
    playService.desktopLyricService.sendFullLyricMessage(lyric);
    _lastEmittedLineIndex = -1;
    _lastEmittedLineIndexForHint = -1;
    _lastEmittedActiveIndices = const [];
    _lastEmittedBackgroundActiveIndices = const [];
    _lastEmittedLayoutIndices = const [];
    _syncLineAdvanceTimer();
  }

  int _beginLyricRequest(String path) {
    currLyricFuture.ignore();
    _activeLyricPath = path;
    _lyricRequestToken += 1;
    _currLyric = null;
    _ttmlTimeline = null;
    _ttmlGeneration++;
    playService.desktopLyricService.sendFullLyricMessage(Lyric.empty);
    _syncLineAdvanceTimer();
    _lineRenderStartMs = const [];
    _lineSwitchStartMs = const [];
    _lineEndMs = const [];
    _lastEmittedLineIndex = -1;
    _lastDesktopLyricLineIndex = -1;
    _desktopGapShown = false;
    _desktopPreludeShown = false;
    _nextLyricLine = 0;
    _lastEmittedActiveIndices = const [];
    _lastEmittedBackgroundActiveIndices = const [];
    _lastEmittedLayoutIndices = const [];
    return _lyricRequestToken;
  }

  bool _isCurrentLyricRequest(int token, String path, Future<Lyric?> future) {
    return token == _lyricRequestToken &&
        identical(currLyricFuture, future) &&
        _activeLyricPath == path &&
        playService.playbackService.nowPlaying?.path == path;
  }

  String _localLyricCacheKey(String audioPath) {
    final selectedPath = lyricSources[audioPath]?.localLyricPath;
    return selectedPath == null ? audioPath : '$audioPath\n$selectedPath';
  }

  Future<Lyric?> _loadLocalLyric(
    String audioPath, {
    bool notifyFailure = false,
  }) async {
    final cacheKey = _localLyricCacheKey(audioPath);
    final selectedPath = lyricSources[audioPath]?.localLyricPath;
    if (selectedPath != null) {
      _activeLocalIsExternal = true;
      if (!await File(selectedPath).exists()) {
        _lyricCache.remove(cacheKey);
        _lyricPrefetches.remove(cacheKey);
        if (notifyFailure) {
          showTextOnSnackBar('指定的歌词文件不存在', variant: ToastVariant.error);
        }
        return null;
      }
    }
    final cached = _lyricCache.get(cacheKey);
    if (cached != null) {
      _activeLocalIsExternal = cached.isExternal;
      return cached.lyric;
    }
    final loaded =
        await (_lyricPrefetches[cacheKey] ??
            _readLocalLyric(audioPath, notifyFailure: notifyFailure));
    if (loaded != null) _activeLocalIsExternal = loaded.isExternal;
    return loaded?.lyric;
  }

  Future<_CachedLocalLyric?> _readLocalLyric(
    String audioPath, {
    required bool notifyFailure,
  }) async {
    final selectedPath = lyricSources[audioPath]?.localLyricPath;
    if (selectedPath == null) {
      final result = await loadLyricFromAudio(audioPath);
      if (result == null) return null;
      return (lyric: result.lyric, isExternal: result.isExternal);
    }
    if (!await File(selectedPath).exists()) {
      if (notifyFailure) {
        showTextOnSnackBar('指定的歌词文件不存在', variant: ToastVariant.error);
      }
      return null;
    }

    final lyric = await loadLyricFromFile(selectedPath);
    if (lyric == null) {
      if (notifyFailure) {
        showTextOnSnackBar('指定的歌词文件读取或解析失败', variant: ToastVariant.error);
      }
      return null;
    }
    return (lyric: lyric, isExternal: true);
  }

  void _putLocalLyricCache(String cacheKey, Lyric lyric) {
    final isExternal = _activeLocalIsExternal;
    if (isExternal == null) return;
    _lyricCache.put(cacheKey, (lyric: lyric, isExternal: isExternal));
  }

  static LyricSourceType _lyricSourceTypeFromResultSource(ResultSource source) {
    return switch (source) {
      ResultSource.qq => LyricSourceType.qq,
      ResultSource.kugou => LyricSourceType.kugou,
      ResultSource.ne => LyricSourceType.ne,
      ResultSource.amll => LyricSourceType.amll,
    };
  }

  Future<({Lyric lyric, ResultSource source, SongSearchResult? result})?>
  _loadOnlineLyricWithFallback(Audio audio, ResultSource preferredSource) =>
      getLyricWithSourceFallback(audio, preferredSource);

  /// 启动带源切换的在线搜索：命中非首选源时固化该单曲来源，
  /// 避免下次播放重复等待首选源超时。返回歌词加载 future。
  Future<Lyric?> _startOnlineLyricWithFallback({
    required Audio audio,
    required ResultSource preferredSource,
    required int requestToken,
    required String audioPath,
  }) {
    final fallbackFuture = _loadOnlineLyricWithFallback(audio, preferredSource);
    final lyricFuture = fallbackFuture.then((result) => result?.lyric);
    final future = lyricFuture;
    fallbackFuture.then((result) {
      if (result == null ||
          !_isCurrentLyricRequest(requestToken, audioPath, future)) {
        return;
      }
      _activeLyricSourceType = _lyricSourceTypeFromResultSource(result.source);
      final hitResult = result.result;
      if (hitResult == null || result.source == preferredSource) return;
      persistLyricSource(audioPath, hitResult.toLyricSource()).catchError((
        error,
        trace,
      ) {
        log.lyric.warn(
          'legacy',
          '[lyric] persist fallback source failed: $error',
          stackTrace: trace,
        );
      });
    });
    return lyricFuture;
  }

  /// 根据默认歌词来源获取歌词：
  /// 1. 如果没有指定来源，按照现在的方式寻找歌词（本地优先或在线优先）
  /// 2. 如果指定来源，按照指定的来源获取
  void _reportLyricUpdate({required String mode, required String source}) {
    log.lyric.info(
      'lyric.update',
      '刷新歌词',
      fields: {'mode': mode, 'source': source},
    );
  }

  void updateLyric() {
    _cancelLyricWritePrompt();
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;
    final audioPath = nowPlaying.path;
    final requestToken = _beginLyricRequest(audioPath);
    _activeLyricSourceType = LyricSourceType.local;
    _activeLocalIsExternal = null;
    final lyricSource = lyricSources[audioPath];
    final isFromWeb =
        lyricSource != null && lyricSource.source != LyricSourceType.local;
    final usesLocalLyric =
        lyricSource?.source == LyricSourceType.local ||
        (lyricSource == null && AppSettings.instance.localLyricFirst);
    final localCacheKey = usesLocalLyric
        ? _localLyricCacheKey(audioPath)
        : null;
    currLyricFuture = _lyricFutureForUpdate(
      nowPlaying,
      audioPath,
      requestToken,
      lyricSource,
    );
    currLyricFuture.then((value) {
      _applyLoadedLyric(
        value,
        requestToken: requestToken,
        audioPath: audioPath,
        future: currLyricFuture,
        usesLocalLyric: usesLocalLyric,
        localCacheKey: localCacheKey,
        isFromWeb: isFromWeb,
      );
    });
    notifyListeners();
  }

  Future<Lyric?> _lyricFutureForUpdate(
    Audio nowPlaying,
    String audioPath,
    int requestToken,
    LyricSource? lyricSource,
  ) {
    if (lyricSource == null) {
      if (AppSettings.instance.localLyricFirst) {
        _reportLyricUpdate(mode: 'local', source: 'local');
        return _loadLocalLyric(audioPath, notifyFailure: true);
      }
      final preferredSource = AppSettings.instance.preferredOnlineSource;
      final rs = switch (preferredSource) {
        LyricSourceType.qq => ResultSource.qq,
        LyricSourceType.kugou => ResultSource.kugou,
        LyricSourceType.ne => ResultSource.ne,
        LyricSourceType.amll => ResultSource.amll,
        LyricSourceType.local => ResultSource.qq,
      };
      _activeLyricSourceType = _lyricSourceTypeFromResultSource(rs);
      _reportLyricUpdate(mode: 'online', source: rs.name);
      return _startOnlineLyricWithFallback(
        audio: nowPlaying,
        preferredSource: rs,
        requestToken: requestToken,
        audioPath: audioPath,
      );
    }
    _activeLyricSourceType = lyricSource.source;
    _reportLyricUpdate(mode: 'saved', source: lyricSource.source.name);
    if (lyricSource.source == LyricSourceType.local) {
      return _loadLocalLyric(audioPath, notifyFailure: true);
    }
    return getOnlineLyric(
      qqSongId: lyricSource.qqSongId,
      kugouSongHash: lyricSource.kugouSongHash,
      neSongId: lyricSource.neSongId,
      amllTtmlFile: lyricSource.amllTtmlFile,
      title: nowPlaying.title,
      album: nowPlaying.album,
      artist: nowPlaying.artist,
      durationSec: nowPlaying.duration,
    );
  }

  void _applyLoadedLyric(
    Lyric? value, {
    required int requestToken,
    required String audioPath,
    required Future<Lyric?> future,
    required bool usesLocalLyric,
    required String? localCacheKey,
    required bool isFromWeb,
  }) {
    if (!_isCurrentLyricRequest(requestToken, audioPath, future)) return;
    log.lyric.debug(
      'legacy',
      '[lyric_service] then: value=${value?.lines.length ?? "null"}',
    );
    if (value != null) {
      _nextLyricLine = 0;
      _setCurrLyric(value);
      if (usesLocalLyric) {
        _putLocalLyricCache(localCacheKey!, value);
      }
      if (isFromWeb || value.source == LyricFormat.web) {
        _scheduleLyricWritePrompt(audioPath);
        unawaited(_autoSaveExternalLyric(audioPath));
      }
    } else {
      _currLyric = null;
    }
    findCurrLyricLineAt(playService.playbackService.position);
    _notifyLyricChangeListeners();
  }

  void _cancelLyricWritePrompt() {
    _promptGeneration += 1;
    _promptTimer?.cancel();
    _promptTimer = null;
  }

  /// 网络歌词加载成功后，延迟弹出写入标签提示或自动写入
  void _scheduleLyricWritePrompt(String audioPath) {
    _cancelLyricWritePrompt();
    if (!enableOnlineLyricWriting) return;
    if (!_lyricWritePromptHistory.shouldPrompt(audioPath)) return;
    final settings = AppSettings.instance;
    final useAutoWrite = settings.autoWriteLyricToTag;
    final delay = Duration(
      seconds: useAutoWrite
          ? settings.autoWriteLyricToTagDelay
          : settings.promptWriteLyricToTagDelay,
    );
    final generation = _promptGeneration;
    _promptTimer = Timer(
      delay,
      () => _runLyricWritePrompt(audioPath, generation, useAutoWrite),
    );
  }

  void _runLyricWritePrompt(
    String audioPath,
    int generation,
    bool useAutoWrite,
  ) {
    if (generation != _promptGeneration) return;
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null || nowPlaying.path != audioPath) return;
    getLyricFromPath(path: audioPath).then((existing) {
      if (generation != _promptGeneration ||
          _getNowPlaying()?.path != audioPath) {
        return;
      }
      if (existing != null && existing.trim().isNotEmpty) {
        _lyricWritePromptHistory.markEmbeddedLyricFound(audioPath);
        return;
      }
      if (useAutoWrite) {
        _handleAutoWrite(audioPath);
        return;
      }
      final shown = showLyricWritePrompt(
        title: nowPlaying.title,
        onWrite: () => _handlePromptWrite(audioPath),
        onDismiss: () => _handlePromptDismiss(audioPath),
      );
      if (shown) {
        _lyricWritePromptHistory.markPromptShown(audioPath);
      }
    });
  }

  void _handlePromptWrite(String audioPath) {
    _lyricWritePromptHistory.markPromptShown(audioPath);
    writeCurrentLyricToTag(expectedPath: audioPath)
        .then((_) {
          showTextOnSnackBar('歌词已写入标签', variant: ToastVariant.success);
        })
        .catchError((e, trace) {
          _lyricWritePromptHistory.markWriteFailed(audioPath);
          log.lyric.error('legacy', '写入歌词标签失败', error: e, stackTrace: trace);
          showTextOnSnackBar('写入标签失败，请查看日志', variant: ToastVariant.error);
        });
  }

  /// 用户选择忽略 → 仅本次提示不再显示，不影响设置
  void _handlePromptDismiss(String audioPath) {
    _lyricWritePromptHistory.markPromptShown(audioPath);
    _cancelLyricWritePrompt();
    showTextOnSnackBar('本次提示已跳过');
  }

  /// 自动写入：静默写入，不弹窗
  void _handleAutoWrite(String audioPath) {
    _lyricWritePromptHistory.markPromptShown(audioPath);

    writeCurrentLyricToTag(expectedPath: audioPath)
        .then((_) {
          // 静默成功，不打扰用户
        })
        .catchError((e) {
          _lyricWritePromptHistory.markWriteFailed(audioPath);
          log.lyric.error('legacy', '自动写入歌词标签失败: $e');
        });
  }

  /// 网络歌词加载成功后，静默保存同名外置 .lrc 文件，已存在则先备份为 .bak
  Future<void> _autoSaveExternalLyric(String audioPath) async {
    if (!enableOnlineLyricWriting) return;
    if (!AppSettings.instance.autoSaveExternalLyric) return;
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null || nowPlaying.path != audioPath) return;
    try {
      await saveCurrentLyricAsLrc();
    } catch (e) {
      log.lyric.error('legacy', '自动保存外置歌词失败: $e');
    }
  }

  /// 重置写入标签提示状态（刷新已提示列表）
  void resetLyricWritePrompts() {
    _cancelLyricWritePrompt();
    _lyricWritePromptHistory.clear();
  }

  /// 预加载歌词（不影响当前播放）
  /// 下一首切换时直接使用缓存
  void prefetchLyric(Audio audio) {
    final path = audio.path;
    final lyricSource = lyricSources[path];
    final usesLocalLyric =
        lyricSource?.source == LyricSourceType.local ||
        (lyricSource == null && AppSettings.instance.localLyricFirst);
    if (!usesLocalLyric) return;
    final cacheKey = _localLyricCacheKey(path);
    // 如果已缓存，跳过
    if (_lyricCache.containsKey(cacheKey) ||
        _lyricPrefetches.containsKey(cacheKey)) {
      return;
    }
    final generation = _prefetchGeneration;

    // 触发加载但不等待结果
    late final Future<_CachedLocalLyric?> future;
    future = (() async {
      try {
        final value = await _readLocalLyric(path, notifyFailure: false);
        if (value != null && generation == _prefetchGeneration) {
          _lyricCache.put(cacheKey, value);
        }
        return value;
      } finally {
        if (identical(_lyricPrefetches[cacheKey], future)) {
          _lyricPrefetches.remove(cacheKey);
        }
      }
    })();
    _lyricPrefetches[cacheKey] = future;
    future.ignore();
  }

  void useLocalLyric() {
    _cancelLyricWritePrompt();

    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;
    final audioPath = nowPlaying.path;
    final requestToken = _beginLyricRequest(audioPath);
    _activeLyricSourceType = LyricSourceType.local;
    _activeLocalIsExternal = null;

    final cacheKey = _localLyricCacheKey(audioPath);
    currLyricFuture = _loadLocalLyric(audioPath, notifyFailure: true);
    _reportLyricUpdate(mode: 'local', source: 'local');
    final future = currLyricFuture;
    future.then((value) {
      if (!_isCurrentLyricRequest(requestToken, audioPath, future)) return;
      if (value != null) {
        _setCurrLyric(value);
        _putLocalLyricCache(cacheKey, value);
      } else {
        _currLyric = null;
      }
      findCurrLyricLineAt(playService.playbackService.position);
      _notifyLyricChangeListeners();
    });

    notifyListeners();
  }

  /// 写入标签后刷新当前歌词：清除本地缓存并重新从标签加载
  void reloadLyricFromTag() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;
    final cacheKey = _localLyricCacheKey(nowPlaying.path);
    _lyricCache.remove(cacheKey);
    _lyricPrefetches.remove(cacheKey);
    useLocalLyric();
  }

  void useOnlineLyric() {
    _cancelLyricWritePrompt();
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;
    final audioPath = nowPlaying.path;
    final requestToken = _beginLyricRequest(audioPath);
    currLyricFuture = _onlineLyricFuture(nowPlaying, audioPath, requestToken);
    final future = currLyricFuture;
    future.then((value) {
      if (!_isCurrentLyricRequest(requestToken, audioPath, future)) return;
      if (value != null) {
        _setCurrLyric(value);
        _scheduleLyricWritePrompt(audioPath);
      } else {
        _currLyric = null;
      }
      findCurrLyricLineAt(playService.playbackService.position);
      _notifyLyricChangeListeners();
    });
    notifyListeners();
  }

  Future<Lyric?> _onlineLyricFuture(
    Audio nowPlaying,
    String audioPath,
    int requestToken,
  ) {
    final savedSource = lyricSources[audioPath];
    if (savedSource != null && savedSource.source != LyricSourceType.local) {
      _activeLyricSourceType = savedSource.source;
      log.lyric.info(
        'lyric.update',
        '切换到已保存的在线歌词',
        fields: {'mode': 'saved', 'source': savedSource.source.name},
      );
      return getOnlineLyric(
        qqSongId: savedSource.qqSongId,
        kugouSongHash: savedSource.kugouSongHash,
        neSongId: savedSource.neSongId,
        amllTtmlFile: savedSource.amllTtmlFile,
        title: nowPlaying.title,
        album: nowPlaying.album,
        artist: nowPlaying.artist,
        durationSec: nowPlaying.duration,
      );
    }
    final rs = switch (AppSettings.instance.preferredOnlineSource) {
      LyricSourceType.qq => ResultSource.qq,
      LyricSourceType.kugou => ResultSource.kugou,
      LyricSourceType.ne => ResultSource.ne,
      LyricSourceType.amll => ResultSource.amll,
      LyricSourceType.local => ResultSource.qq,
    };
    _activeLyricSourceType = _lyricSourceTypeFromResultSource(rs);
    log.lyric.info(
      'lyric.update',
      '按首选来源搜索在线歌词',
      fields: {'mode': 'online', 'source': rs.name},
    );
    return _startOnlineLyricWithFallback(
      audio: nowPlaying,
      preferredSource: rs,
      requestToken: requestToken,
      audioPath: audioPath,
    );
  }

  void useSpecificLyric(Lyric lyric) {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;
    final audioPath = nowPlaying.path;
    final requestToken = _beginLyricRequest(audioPath);
    _activeLyricSourceType = LyricSourceType.local;
    _activeLocalIsExternal = true; // useSpecificLyric 由用户手动选择外置文件触发

    currLyricFuture = Future.value(lyric);
    final future = currLyricFuture;
    future.then((value) {
      if (!_isCurrentLyricRequest(requestToken, audioPath, future)) return;
      if (value != null) {
        _setCurrLyric(value);
      } else {
        _currLyric = null;
      }
      findCurrLyricLineAt(playService.playbackService.position);
      _notifyLyricChangeListeners();
    });

    notifyListeners();
  }

  void _notifyLyricChangeListeners() {
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelLyricWritePrompt();
    _lyricLineStreamController.close();
    playService.playbackService.playerStateNotifier.removeListener(
      _syncLineAdvanceTimer,
    );
    _lineAdvanceTimer?.cancel();
    _lyricPrefetches.clear();
    _lyricCache.clear();
    super.dispose();
  }

  void clearCache() {
    _prefetchGeneration++;
    _lyricPrefetches.clear();
    _lyricCache.clear();
  }

  void reloadAfterMetadataSettingChange() {
    clearCache();
    clearOnlineLyricCache();
    updateLyric();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/lyric/lyric.dart';
import 'package:pure_music/native/bass/bass_player.dart';
import 'package:pure_music/page/now_playing_page/component/vertical_lyric_view.dart';
import 'package:pure_music/play_service/lyric_service.dart';

void main() {
  test(
    'authored snapshots can keep an earlier anchor without losing updates',
    () {
      const update = LyricLineUpdate(
        primaryIndex: 0,
        mainActiveIndices: [2],
        backgroundActiveIndices: [0],
        layoutIndices: [0, 2],
        positionMs: 318000,
        generation: 4,
        usesAuthoredTiming: true,
      );
      expect(
        lyricLineUpdateQueueAfterEnqueue(
          queued: const [],
          update: update,
          currentIndex: 2,
          isPlaying: true,
          currentPositionMs: 317900,
          currentGeneration: 4,
        ),
        [update],
      );
      expect(
        shouldApplyPlaybackLyricResync(
          currentIndex: 2,
          resyncIndex: 0,
          isPlaying: true,
          usesAuthoredTiming: true,
        ),
        isTrue,
      );
    },
  );

  test(
    'authored snapshots replace backlog and reject old seek generations',
    () {
      const previous = LyricLineUpdate(
        primaryIndex: 0,
        mainActiveIndices: [0],
        positionMs: 1000,
        generation: 2,
        usesAuthoredTiming: true,
      );
      const latest = LyricLineUpdate(
        primaryIndex: 3,
        mainActiveIndices: [3, 4],
        positionMs: 9000,
        generation: 2,
        usesAuthoredTiming: true,
      );
      final queue = lyricLineUpdateQueueAfterEnqueue(
        queued: const [previous],
        update: latest,
        currentIndex: 0,
        isPlaying: true,
        currentPositionMs: 1000,
        currentGeneration: 2,
      );
      expect(queue, [latest]);
      expect(
        lyricLineUpdateQueueAfterEnqueue(
          queued: queue,
          update: previous,
          currentIndex: 3,
          isPlaying: true,
          currentPositionMs: 9000,
          currentGeneration: 3,
        ),
        queue,
      );
      const seek = LyricLineUpdate(
        primaryIndex: 0,
        mainActiveIndices: [0],
        positionMs: 1000,
        generation: 3,
        usesAuthoredTiming: true,
      );
      expect(
        lyricLineUpdateQueueAfterEnqueue(
          queued: queue,
          update: seek,
          currentIndex: 3,
          isPlaying: true,
          currentPositionMs: 9000,
          currentGeneration: 2,
        ),
        [seek],
      );
    },
  );

  group('initial lyric scroll completion', () {
    bool finished({
      bool hasContentDimensions = true,
      double viewportDimension = 600,
      double targetHeight = 64,
      double requestedOffset = 420,
      double appliedOffset = 420,
    }) => shouldFinishInitialLyricScroll(
      hasContentDimensions: hasContentDimensions,
      viewportDimension: viewportDimension,
      targetHeight: targetHeight,
      requestedOffset: requestedOffset,
      appliedOffset: appliedOffset,
    );

    test('waits for the interlude to expand before ending restoration', () {
      expect(finished(targetHeight: 0), isFalse);
      expect(finished(targetHeight: 40), isTrue);
    });

    test('waits for scroll content and viewport layout', () {
      expect(finished(hasContentDimensions: false), isFalse);
      expect(finished(viewportDimension: 0), isFalse);
      expect(finished(viewportDimension: 1), isFalse);
      expect(finished(viewportDimension: double.infinity), isFalse);
      expect(finished(), isTrue);
    });

    test('does not finish at a temporarily clamped or estimated offset', () {
      expect(finished(appliedOffset: 0), isFalse);
      expect(finished(appliedOffset: 400), isFalse);
      expect(finished(appliedOffset: 419.75), isTrue);
      expect(finished(appliedOffset: 420.25), isTrue);
      expect(finished(appliedOffset: 418), isFalse);
    });

    test('rejects non-finite geometry', () {
      for (final value in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(finished(targetHeight: value), isFalse);
        expect(finished(requestedOffset: value), isFalse);
        expect(finished(appliedOffset: value), isFalse);
      }
    });
  });

  test('paused position sync does not force lyric scroll', () {
    expect(shouldForceLyricScrollForPositionSync(PlayerState.paused), isFalse);
  });

  test('playing position sync does not steal a user lyric browse', () {
    expect(shouldForceLyricScrollForPositionSync(PlayerState.playing), isFalse);
  });

  test(
    'user browsing still blocks follow even before the first line settles',
    () {
      expect(
        shouldIgnoreLyricFollowWhileUserScrolling(isUserDragging: true),
        isTrue,
      );
      expect(
        shouldIgnoreLyricFollowWhileUserScrolling(isUserDragging: false),
        isFalse,
      );
    },
  );

  test('viewport height jitter does not force lyric scroll', () {
    expect(shouldForceLyricScrollForViewportChange(), isFalse);
  });

  test('entering the page still force-scrolls after viewport settles', () {
    expect(
      shouldForceLyricScrollForViewportChange(needsInitialScroll: true),
      isTrue,
    );
  });

  test('position sync still force-scrolls until the first line is found', () {
    expect(
      shouldForceLyricScrollForPositionSync(
        PlayerState.playing,
        needsInitialScroll: true,
      ),
      isTrue,
    );
    expect(
      shouldForceLyricScrollForPositionSync(
        PlayerState.paused,
        needsInitialScroll: true,
      ),
      isTrue,
    );
  });

  test('playing resync does not skip the first current-line scroll', () {
    expect(
      shouldEnqueuePlayingLyricResync(
        forceScroll: false,
        needsInitialScroll: true,
        isPlaying: true,
      ),
      isFalse,
    );
    expect(
      shouldEnqueuePlayingLyricResync(
        forceScroll: false,
        needsInitialScroll: false,
        isPlaying: true,
      ),
      isTrue,
    );
    expect(
      shouldEnqueuePlayingLyricResync(
        forceScroll: true,
        needsInitialScroll: false,
        isPlaying: true,
      ),
      isFalse,
    );
  });

  test('offset cache measures wrapped lines at the tile content width', () {
    expect(lyricLineLayoutWidth(400), 376);
    expect(lyricLineLayoutWidth(20), 1);
  });

  test(
    'stagger compensation is the scroll delta, not zeroed for a real jump',
    () {
      expect(lyricStaggerJumpDeltaY(from: 80, to: 200), 120);
      expect(lyricStaggerJumpDeltaY(from: 80, to: 80.2), 0);
    },
  );

  test('stagger jump uses cached line advance, not a larger live reveal', () {
    const offsets = [0.0, 80.0, 200.0];
    const heights = [80.0, 120.0, 60.0];
    const current = 140.0;
    final target = lyricStaggerScrollTarget(
      currentOffset: current,
      fromIndex: 0,
      toIndex: 1,
      offsets: offsets,
      heights: heights,
      alignment: 0.35,
    );
    final follow = lyricFollowScrollOffset(
      currentOffset: current,
      fromIndex: 0,
      toIndex: 1,
      offsets: offsets,
      heights: heights,
      alignment: 0.35,
    );
    expect(target, follow);
    expect(lyricStaggerJumpDeltaY(from: current, to: target), follow - current);
    expect(target - current, lessThan(200));
  });

  test('programmatic lyric scroll snaps to physical pixels', () {
    expect(lyricSnapScrollOffset(10.4, 1.25), 10.4);
    expect(lyricSnapScrollOffset(10.2, 1.0), 10.0);
    expect(lyricSnapScrollOffset(10.6, 1.0), 11.0);
  });

  test('restored initial offset uses the same padding as the list', () {
    const viewport = 800.0;
    const alignment = 0.35;
    const lineTop = 100.0;
    const lineHeight = 80.0;
    final restored = lyricScrollOffsetToAlignLine(
      topPadding: lyricListTopPadding(
        viewportHeight: viewport,
        centerVertically: true,
        enableEdgeSpacer: true,
        alignment: alignment,
      ),
      lineTop: lineTop,
      lineHeight: lineHeight,
      viewportHeight: viewport,
      alignment: alignment,
    );
    const oldWrong =
        viewport / 2 + lineTop + lineHeight / 2 - viewport * alignment;
    expect(
      restored,
      closeTo(
        1200 + lineTop + lineHeight * alignment - viewport * alignment,
        0.0001,
      ),
    );
    expect(restored - oldWrong, greaterThan(700));
  });

  test('edge spacer padding is included in the follow target', () {
    expect(
      lyricListTopPadding(
        viewportHeight: 800,
        centerVertically: true,
        enableEdgeSpacer: true,
        alignment: 0.35,
      ),
      1200,
    );
    expect(
      lyricScrollOffsetToAlignLine(
        topPadding: lyricListTopPadding(
          viewportHeight: 800,
          centerVertically: true,
          enableEdgeSpacer: true,
          alignment: 0.35,
        ),
        lineTop: 100,
        lineHeight: 80,
        viewportHeight: 800,
        alignment: 0.35,
      ),
      closeTo(1200 + 100 + 80 * 0.35 - 800 * 0.35, 0.0001),
    );
    expect(
      lyricScrollOffsetToAlignLine(
        topPadding: 400,
        lineTop: 100,
        lineHeight: 80,
        viewportHeight: 800,
        alignment: 0.35,
      ),
      isNot(closeTo(1200 + 100 + 80 * 0.35 - 800 * 0.35, 1)),
    );
  });

  test('cached lyric scroll aligns the same point as the viewport', () {
    expect(
      lyricScrollOffsetToAlignLine(
        topPadding: 400,
        lineTop: 100,
        lineHeight: 80,
        viewportHeight: 800,
        alignment: 0.12,
      ),
      closeTo(400 + 100 + 80 * 0.12 - 800 * 0.12, 0.0001),
    );
    expect(
      lyricScrollOffsetToAlignLine(
        topPadding: 400,
        lineTop: 100,
        lineHeight: 80,
        viewportHeight: 800,
        alignment: 0.12,
      ),
      isNot(closeTo(400 + 100 + 40 - 800 * 0.12, 0.0001)),
    );
  });

  test('follow does not jump a whole screen backward', () {
    expect(
      lyricScrollOffsetWithoutRetreat(
        from: 1400,
        candidate: 400,
        advancing: true,
      ),
      1400,
    );
  });

  test('forward follow does not snap below the current offset', () {
    expect(
      lyricScrollOffsetWithoutRetreat(
        from: 200.4,
        candidate: 200.0,
        advancing: true,
      ),
      200.4,
    );
    expect(
      lyricScrollOffsetWithoutRetreat(
        from: 200.4,
        candidate: 248.0,
        advancing: true,
      ),
      248.0,
    );
    expect(
      lyricScrollOffsetWithoutRetreat(
        from: 200.4,
        candidate: 201.0,
        advancing: false,
      ),
      200.4,
    );
  });

  test('follow scroll adds cached line height and never goes backward', () {
    const offsets = [0.0, 80.0, 200.0];
    const heights = [80.0, 120.0, 60.0];
    expect(
      lyricFollowScrollOffset(
        currentOffset: 140,
        fromIndex: 0,
        toIndex: 1,
        offsets: offsets,
        heights: heights,
        alignment: 0.35,
      ),
      closeTo(140 + (80 + 120 * 0.35) - (0 + 80 * 0.35), 0.0001),
    );
    expect(
      lyricFollowScrollOffset(
        currentOffset: 140,
        fromIndex: 1,
        toIndex: 0,
        offsets: offsets,
        heights: heights,
        alignment: 0.35,
      ),
      lessThan(140),
    );
    expect(
      lyricClampScrollForLineAdvance(
        from: 140,
        to: lyricFollowScrollOffset(
          currentOffset: 140,
          fromIndex: 0,
          toIndex: 1,
          offsets: offsets,
          heights: heights,
          alignment: 0.35,
        ),
        fromIndex: 0,
        toIndex: 1,
      ),
      greaterThan(140),
    );
  });

  test('advancing a line does not scroll backward', () {
    expect(
      lyricClampScrollForLineAdvance(
        from: 200,
        to: 120,
        fromIndex: 3,
        toIndex: 4,
      ),
      200,
    );
    expect(
      lyricClampScrollForLineAdvance(
        from: 200,
        to: 260,
        fromIndex: 3,
        toIndex: 4,
      ),
      260,
    );
  });

  test('force jump does not cut a scroll already moving to the same line', () {
    expect(
      shouldSnapLyricScroll(
        distancePx: 80,
        forceJump: true,
        animatingToSameTarget: true,
      ),
      isFalse,
    );
    expect(
      shouldSnapLyricScroll(
        distancePx: 80,
        forceJump: true,
        animatingToSameTarget: false,
      ),
      isTrue,
    );
    expect(
      shouldSnapLyricScroll(
        distancePx: 0.2,
        forceJump: false,
        animatingToSameTarget: false,
      ),
      isTrue,
    );
    expect(
      shouldSnapLyricScroll(
        distancePx: 1.5,
        forceJump: false,
        animatingToSameTarget: false,
      ),
      isTrue,
    );
  });

  test(
    'tiny remaining distance does not kill a scroll to a different line',
    () {
      expect(
        shouldSnapLyricScroll(
          distancePx: 0.2,
          forceJump: false,
          animatingToSameTarget: false,
          isAnimating: true,
        ),
        isFalse,
      );
    },
  );

  test('activity-only updates do not follow-scroll the current line', () {
    expect(
      shouldFollowLyricLineScroll(
        forceScroll: false,
        needsInitialScroll: false,
        mainLineChanged: false,
      ),
      isFalse,
    );
    expect(
      shouldFollowLyricLineScroll(
        forceScroll: false,
        needsInitialScroll: false,
        mainLineChanged: true,
      ),
      isTrue,
    );
  });

  test('an in-flight scroll to the same line is not restarted', () {
    expect(
      shouldRestartLyricScroll(animatingToSameTarget: true, forceJump: false),
      isFalse,
    );
    expect(
      shouldRestartLyricScroll(animatingToSameTarget: true, forceJump: true),
      isFalse,
    );
    expect(
      shouldRestartLyricScroll(animatingToSameTarget: false, forceJump: false),
      isTrue,
    );
    expect(
      shouldRestartLyricScroll(
        animatingToSameTarget: false,
        forceJump: false,
        isAnimating: true,
        distancePx: 0.2,
      ),
      isFalse,
    );
  });

  test('playing resync does not pull the current line backward', () {
    expect(
      shouldApplyPlaybackLyricResync(
        currentIndex: 8,
        resyncIndex: 7,
        isPlaying: true,
      ),
      isFalse,
    );
    expect(
      shouldApplyPlaybackLyricResync(
        currentIndex: 8,
        resyncIndex: 9,
        isPlaying: true,
      ),
      isTrue,
    );
    expect(
      shouldApplyPlaybackLyricResync(
        currentIndex: 8,
        resyncIndex: 7,
        isPlaying: false,
      ),
      isTrue,
    );
  });

  test('playing resync does not skip an intermediate line', () {
    expect(
      shouldApplyPlaybackLyricResync(
        currentIndex: 8,
        resyncIndex: 10,
        isPlaying: true,
      ),
      isFalse,
    );
    expect(
      shouldApplyPlaybackLyricResync(
        currentIndex: 8,
        resyncIndex: 10,
        isPlaying: false,
      ),
      isTrue,
    );
  });

  test('queued line updates wait for the applied frame to commit', () {
    expect(
      shouldScheduleQueuedLyricLineUpdate(
        awaitingAppliedUpdateFrame: true,
        alreadyScheduledForGeneration: false,
      ),
      isFalse,
    );
    expect(
      shouldScheduleQueuedLyricLineUpdate(
        awaitingAppliedUpdateFrame: false,
        alreadyScheduledForGeneration: true,
      ),
      isFalse,
    );
    expect(
      shouldScheduleQueuedLyricLineUpdate(
        awaitingAppliedUpdateFrame: false,
        alreadyScheduledForGeneration: false,
      ),
      isTrue,
    );
  });

  test(
    'same-frame lyric updates keep intermediate lines and merge one line',
    () {
      const first = LyricLineUpdate(
        primaryIndex: 1,
        activeIndices: [1],
        positionMs: 1000,
      );
      const second = LyricLineUpdate(
        primaryIndex: 2,
        activeIndices: [2],
        positionMs: 1016,
      );
      var queued = lyricLineUpdateQueueAfterEnqueue(
        queued: const <LyricLineUpdate>[],
        update: first,
        currentIndex: 0,
        isPlaying: true,
      );
      queued = lyricLineUpdateQueueAfterEnqueue(
        queued: queued,
        update: second,
        currentIndex: 0,
        isPlaying: true,
      );

      expect(queued.map((update) => update.primaryIndex), [1, 2]);

      const merged = LyricLineUpdate(
        primaryIndex: 2,
        activeIndices: [2, 3],
        positionMs: 1020,
      );
      queued = lyricLineUpdateQueueAfterEnqueue(
        queued: queued,
        update: merged,
        currentIndex: 0,
        isPlaying: true,
      );
      expect(queued, hasLength(2));
      expect(queued.last.activeIndices, [2, 3]);

      const stale = LyricLineUpdate(
        primaryIndex: 1,
        activeIndices: [1],
        positionMs: 1021,
      );
      queued = lyricLineUpdateQueueAfterEnqueue(
        queued: queued,
        update: stale,
        currentIndex: 0,
        isPlaying: true,
      );
      expect(queued.map((update) => update.primaryIndex), [1, 2]);
    },
  );

  test('force resync only drops the queue on a real jump', () {
    expect(
      shouldDiscardQueuedLyricUpdatesForResync(
        forceScroll: true,
        currentIndex: 5,
        resyncIndex: 5,
      ),
      isFalse,
    );
    expect(
      shouldDiscardQueuedLyricUpdatesForResync(
        forceScroll: true,
        currentIndex: 5,
        resyncIndex: 6,
      ),
      isFalse,
    );
    expect(
      shouldDiscardQueuedLyricUpdatesForResync(
        forceScroll: true,
        currentIndex: 5,
        resyncIndex: 8,
      ),
      isTrue,
    );
    expect(
      shouldDiscardQueuedLyricUpdatesForResync(
        forceScroll: false,
        currentIndex: 5,
        resyncIndex: 8,
      ),
      isFalse,
    );
  });

  test('next pre-switch does not take over a single-word line early', () {
    expect(
      lyricLineSwitchStartMs(
        previousSwitchStartMs: 212506,
        previousLineEndMs: 212978,
        nextLineStartMs: 212978,
        preserveSingleWordTiming: true,
      ),
      212978,
    );
    expect(
      lyricLineSwitchStartMs(
        previousSwitchStartMs: 212506,
        previousLineEndMs: 212978,
        nextLineStartMs: 212978,
        preserveSingleWordTiming: false,
      ),
      212658,
    );
  });

  test('TTML primary line follows the frozen parallel group', () {
    expect(
      lyricDisplayPrimaryIndex(
        fallbackPrimaryIndex: 82,
        lineCount: 88,
        groupedLines: {82, 84, 85},
      ),
      82,
    );
    expect(
      lyricDisplayPrimaryIndex(
        fallbackPrimaryIndex: 85,
        lineCount: 88,
        groupedLines: {82, 84, 85},
      ),
      82,
    );
    expect(
      lyricDisplayPrimaryIndex(
        fallbackPrimaryIndex: 86,
        lineCount: 88,
        groupedLines: {},
      ),
      86,
    );
  });

  test('parallel group members use main-line visual distance', () {
    expect(
      lyricLineVisualDistance(
        index: 85,
        mainLine: 82,
        parallelGroupLines: {82, 84, 85},
      ),
      0,
    );
    expect(
      lyricLineVisualDistance(
        index: 86,
        mainLine: 82,
        parallelGroupLines: {82, 84, 85},
      ),
      4,
    );
  });

  test('offset computation still force-scrolls the first current line', () {
    expect(
      shouldForceLyricScrollAfterOffsetsComputed(
        needsInitialScroll: true,
        isUserDragging: false,
      ),
      isTrue,
    );
    expect(
      shouldForceLyricScrollAfterOffsetsComputed(
        needsInitialScroll: true,
        isUserDragging: true,
      ),
      isFalse,
    );
    expect(
      shouldForceLyricScrollAfterOffsetsComputed(
        needsInitialScroll: false,
        isUserDragging: false,
      ),
      isFalse,
    );
  });
}

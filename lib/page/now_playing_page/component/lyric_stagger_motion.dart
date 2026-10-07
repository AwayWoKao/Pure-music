import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

const lyricSmoothTransitionDuration = Duration(milliseconds: 700);
const lyricSmoothTransitionCurve = Cubic(0.25, 0.0, 0.2, 1.0);

/// 切行缩放/浮起/模糊共用弹簧。
const lyricLineSwitchSpring = SpringDescription(
  mass: 1,
  stiffness: 100,
  damping: 18,
);

/// 行位移用略过阻尼：zeta 1.1 不回弹，k=100 比 200 慢一档，切行距离改成真实行距后不会甩出去。
const lyricLinePositionSpring = SpringDescription(
  mass: 1,
  stiffness: 100,
  damping: 22,
);

double lyricSmoothTransitionInterpolator(double t, double start, double end) {
  final progress = lyricSmoothTransitionCurve.transform(t);
  return start + (end - start) * progress;
}

int lyricStaggerDelayMs({
  required int itemIndex,
  required int visibleStartIndex,
}) {
  final distance = (itemIndex - visibleStartIndex).abs();
  var step = 50.0;
  var total = 0.0;
  for (var i = 0; i < distance; i++) {
    total += step;
    step /= 1.05;
  }
  return total.toInt();
}

Duration lyricSpringItemDelay({
  required int itemIndex,
  required int visibleStartIndex,
}) {
  return Duration(
    milliseconds: lyricStaggerDelayMs(
      itemIndex: itemIndex,
      visibleStartIndex: visibleStartIndex,
    ),
  );
}

/// 从补偿位移回到 0 时不允许越过终点，避免整列下沉。
double lyricStaggerClampedOffset(double value, double origin) {
  if (origin >= 0) {
    return value < 0 ? 0.0 : value;
  }
  return value > 0 ? 0.0 : value;
}

bool canStartLyricStagger({
  required bool enabled,
  required int previousIndex,
  required int nextIndex,
  required bool isUserDragging,
  required bool skipNextAfterDrag,
}) {
  if (!enabled || isUserDragging || skipNextAfterDrag) return false;
  if (previousIndex < 0 || nextIndex < 0 || previousIndex == nextIndex) {
    return false;
  }
  return (nextIndex - previousIndex).abs() <= 10;
}

enum LyricUserScrollPhase { ignored, started, updated, ended }

class LyricUserScrollTracker {
  bool _isActive = false;

  bool get isActive => _isActive;

  LyricUserScrollPhase start() {
    if (_isActive) return LyricUserScrollPhase.updated;
    _isActive = true;
    return LyricUserScrollPhase.started;
  }

  LyricUserScrollPhase update() {
    if (!_isActive) return LyricUserScrollPhase.ignored;
    return LyricUserScrollPhase.updated;
  }

  LyricUserScrollPhase end() {
    if (!_isActive) return LyricUserScrollPhase.ignored;
    _isActive = false;
    return LyricUserScrollPhase.ended;
  }
}

/// 滚轮没有 dragDetails，不能走 update()，否则永远进不了用户翻看 hold。
LyricUserScrollPhase lyricPhaseForUserScrollNotification({
  required LyricUserScrollTracker tracker,
  required bool idle,
}) => idle ? tracker.end() : tracker.start();

class LyricStaggerTransition extends StatefulWidget {
  const LyricStaggerTransition({
    super.key,
    required this.enabled,
    required this.generation,
    required this.shiftY,
    required this.delay,
    required this.child,
  });

  final bool enabled;
  final int generation;
  final double shiftY;
  final Duration delay;
  final Widget child;

  @override
  State<LyricStaggerTransition> createState() => _LyricStaggerTransitionState();
}

class _LyricStaggerTransitionState extends State<LyricStaggerTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;
  double _originY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _scheduleTransition();
  }

  @override
  void didUpdateWidget(covariant LyricStaggerTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _scheduleTransition();
      return;
    }
    if (widget.generation != oldWidget.generation) {
      // 新补偿只要过跳过阈值就接上剩余弹簧，避免 0.2~0.5 的切行把回弹掐掉。
      _scheduleTransition(composeCurrent: widget.shiftY.abs() >= 0.2);
    }
  }

  void _scheduleTransition({bool composeCurrent = false}) {
    if (!widget.enabled || widget.generation <= 0) {
      _delayTimer?.cancel();
      _controller.stop();
      _controller.value = 0;
      return;
    }
    // 如果动画正在进行中且 shiftY 很小，继续当前动画而不是中断
    if (!composeCurrent &&
        widget.shiftY.abs() < 0.2 &&
        _controller.isAnimating) {
      return;
    }
    // 小位移时直接跳到目标，不启动弹簧
    if (!composeCurrent && widget.shiftY.abs() < 0.2) {
      _delayTimer?.cancel();
      _controller.stop();
      _controller.value = 0;
      return;
    }

    final velocity = composeCurrent ? _controller.velocity : 0.0;
    final start = composeCurrent
        ? _controller.value + widget.shiftY
        : widget.shiftY;
    final springRunning =
        composeCurrent && _delayTimer == null && _controller.isAnimating;
    _delayTimer?.cancel();
    _controller.stop();
    _controller.value = start;
    final generation = widget.generation;
    _originY = start;
    if (springRunning || widget.delay <= Duration.zero) {
      _startSpring(generation, velocity: velocity);
      return;
    }
    _delayTimer = Timer(widget.delay, () => _startSpring(generation));
  }

  void _startSpring(int generation, {double velocity = 0}) {
    if (!mounted || !widget.enabled || generation != widget.generation) return;
    final future = _controller.animateWith(
      SpringSimulation(
        lyricLinePositionSpring,
        _controller.value,
        0,
        velocity,
        tolerance: const Tolerance(distance: 0.05, velocity: 0.1),
      ),
    );
    future.whenComplete(() {
      if (!mounted || generation != widget.generation) return;
      if (!_controller.isAnimating && _controller.value.abs() < 0.05) {
        _controller.value = 0;
      }
    });
  }

  double _visualOffsetY() {
    final raw = lyricStaggerClampedOffset(_controller.value, _originY);
    if (!_controller.isAnimating && raw.abs() < 0.05) return 0.0;
    return raw;
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) =>
        Transform.translate(offset: Offset(0, _visualOffsetY()), child: child),
    child: widget.child,
  );
}

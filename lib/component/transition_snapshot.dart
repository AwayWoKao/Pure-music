import 'package:flutter/widgets.dart';

/// 过渡期间停掉子树动画，避免被盖住的页面还在每帧干活。
/// 不用贴图：Windows 上整页截图会在第一帧截到空画面，看起来像灰屏。
class TransitionSnapshot extends StatelessWidget {
  const TransitionSnapshot({
    super.key,
    required this.freezing,
    required this.child,
  });

  final bool freezing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: !freezing, child: child);
  }
}

/// 只冻住被盖住的旧页；新页推入时保持可绘制，避免启动第一帧灰屏。
class RouteTransitionSnapshot extends StatefulWidget {
  const RouteTransitionSnapshot({
    super.key,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<RouteTransitionSnapshot> createState() =>
      _RouteTransitionSnapshotState();
}

class _RouteTransitionSnapshotState extends State<RouteTransitionSnapshot> {
  late bool _freezing = _shouldFreeze();

  bool _shouldFreeze() {
    return widget.secondaryAnimation.status.isAnimating ||
        widget.secondaryAnimation.value > 0.001;
  }

  @override
  void initState() {
    super.initState();
    widget.secondaryAnimation.addStatusListener(_handleStatus);
    widget.secondaryAnimation.addListener(_handleValue);
  }

  @override
  void didUpdateWidget(covariant RouteTransitionSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      oldWidget.secondaryAnimation.removeStatusListener(_handleStatus);
      oldWidget.secondaryAnimation.removeListener(_handleValue);
      widget.secondaryAnimation.addStatusListener(_handleStatus);
      widget.secondaryAnimation.addListener(_handleValue);
    }
    _sync();
  }

  void _handleStatus(AnimationStatus _) => _sync();

  void _handleValue() => _sync();

  void _sync() {
    final next = _shouldFreeze();
    if (next == _freezing) return;
    setState(() => _freezing = next);
  }

  @override
  void dispose() {
    widget.secondaryAnimation.removeStatusListener(_handleStatus);
    widget.secondaryAnimation.removeListener(_handleValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TransitionSnapshot(freezing: _freezing, child: widget.child);
  }
}

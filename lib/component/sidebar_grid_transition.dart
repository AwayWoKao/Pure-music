import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:pure_music/component/motion.dart';

/// 侧栏移动时保留列数，让卡片适配真实宽度，停止后再平滑重排。
class SidebarGridTransition extends StatelessWidget {
  const SidebarGridTransition({
    super.key,
    required this.controller,
    required this.gridDelegate,
    required this.itemCount,
    required this.itemBuilder,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.revision,
  });

  final ScrollController controller;
  final SliverGridDelegate gridDelegate;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollPhysics? physics;
  final EdgeInsets padding;
  final Object? revision;

  @override
  Widget build(BuildContext context) {
    final delegate = gridDelegate;
    if (delegate is! SliverGridDelegateWithMaxCrossAxisExtent) {
      return GridView.builder(
        controller: controller,
        gridDelegate: delegate,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        physics: physics,
        padding: padding,
      );
    }
    final moving = SidebarMotionScope.maybeOf(context)?.isAnimating ?? false;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => _ReflowGrid(
        width: math.max(0, constraints.maxWidth - padding.horizontal),
        moving: moving,
        reduceMotion: reduceMotion,
        delegate: delegate,
        configuration: this,
      ),
    );
  }
}

class _ReflowGrid extends StatefulWidget {
  const _ReflowGrid({
    required this.width,
    required this.moving,
    required this.reduceMotion,
    required this.delegate,
    required this.configuration,
  });

  final double width;
  final bool moving;
  final bool reduceMotion;
  final SliverGridDelegateWithMaxCrossAxisExtent delegate;
  final SidebarGridTransition configuration;

  int get columns => math.max(
    1,
    (width / (delegate.maxCrossAxisExtent + delegate.crossAxisSpacing)).ceil(),
  );

  @override
  State<_ReflowGrid> createState() => _ReflowGridState();
}

class _ReflowGridState extends State<_ReflowGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Map<int, double> _from;
  late int _target;
  SidebarGridGeometry? _lastLayout;
  int? _anchorIndex;
  double _anchorInset = 0;

  @override
  void initState() {
    super.initState();
    _target = widget.columns;
    _from = {_target: 1};
    _controller = AnimationController(
      vsync: this,
      duration: MotionDuration.base,
      value: 1,
    )..addListener(_tick);
  }

  Map<int, double> get _weights {
    final t = MotionCurve.standard.transform(_controller.value);
    if (t == 1) return {_target: 1};
    return {
      for (final entry in _from.entries) entry.key: entry.value * (1 - t),
      _target: (_from[_target] ?? 0) * (1 - t) + t,
    };
  }

  @override
  void didUpdateWidget(covariant _ReflowGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contentChanged =
        oldWidget.configuration.revision != widget.configuration.revision ||
        oldWidget.configuration.itemCount != widget.configuration.itemCount;
    if (widget.reduceMotion || contentChanged) {
      _target = widget.columns;
      _from = {_target: 1};
      _lastLayout = null;
      _anchorIndex = null;
      _controller.stop();
      _controller.value = 1;
    } else if (widget.moving) {
      _controller.stop();
    } else if (_target != widget.columns ||
        (!_controller.isAnimating && _controller.value < 1)) {
      _captureAnchor();
      _from = _weights;
      _target = widget.columns;
      _controller.forward(from: 0);
    }
  }

  SidebarGridGeometry _geometry({bool reverse = false}) => SidebarGridGeometry(
    width: widget.width,
    delegate: widget.delegate,
    weights: _weights,
    itemCount: widget.configuration.itemCount,
    reverse: reverse,
  );

  void _captureAnchor() {
    _anchorIndex = null;
    final layout = _lastLayout;
    final config = widget.configuration;
    if (layout == null ||
        config.itemCount == 0 ||
        config.controller.positions.length != 1) {
      return;
    }
    final position = config.controller.position;
    if (!position.hasContentDimensions) return;
    final offset = math.max(0.0, position.pixels - config.padding.top);
    _anchorIndex = layout.getMinChildIndexForScrollOffset(offset);
    _anchorInset =
        position.pixels -
        config.padding.top -
        layout.getGeometryForChildIndex(_anchorIndex!).scrollOffset;
  }


  void _jumpToAnchor(
    SidebarGridGeometry next,
    SidebarGridTransition config,
    ScrollPosition position,
  ) {
    final maxOffset = math.max(
      0.0,
      next.computeMaxScrollOffset(config.itemCount) +
          config.padding.vertical -
          position.viewportDimension,
    );
    final anchor = _anchorIndex;
    final raw = anchor == null
        ? position.pixels
        : next.getGeometryForChildIndex(anchor).scrollOffset +
              config.padding.top +
              _anchorInset;
    final target = raw.clamp(0.0, maxOffset);
    if ((target - position.pixels).abs() > 0.01) {
      position.jumpTo(target);
    }
  }

  void _tick() {
    if (!mounted) return;
    final previous = _lastLayout;
    final next = _geometry();
    final config = widget.configuration;
    if (previous != null &&
        config.itemCount > 0 &&
        config.controller.positions.length == 1) {
      final position = config.controller.position;
      if (position.isScrollingNotifier.value) {
        _anchorIndex = null;
      } else if (position.hasContentDimensions &&
          SchedulerBinding.instance.schedulerPhase !=
              SchedulerPhase.persistentCallbacks) {
        if (_anchorIndex == null) _captureAnchor();
        _jumpToAnchor(next, config, position);
      }
    }
    _lastLayout = next;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuration;
    final layout = _geometry(
      reverse: Directionality.of(context) == TextDirection.rtl,
    );
    _lastLayout = layout;
    return GridView.builder(
      controller: config.controller,
      physics: config.physics,
      padding: config.padding,
      gridDelegate: _ReflowDelegate(layout),
      itemCount: config.itemCount,
      itemBuilder: config.itemBuilder,
    );
  }
}

class _ReflowDelegate extends SliverGridDelegate {
  const _ReflowDelegate(this.layout);
  final SidebarGridGeometry layout;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) => layout;

  @override
  bool shouldRelayout(_ReflowDelegate oldDelegate) =>
      oldDelegate.layout != layout;
}

/// 同一项目在不同列数布局间插值，保留懒加载和单一命中区域。
class SidebarGridGeometry extends SliverGridLayout {
  SidebarGridGeometry({
    required double width,
    required SliverGridDelegateWithMaxCrossAxisExtent delegate,
    required Map<int, double> weights,
    required this.itemCount,
    bool reverse = false,
  }) : _layouts = [
         for (final entry in weights.entries)
           if (entry.value > 0)
             (
               weight: entry.value,
               layout: _regularLayout(width, delegate, entry.key, reverse),
             ),
       ];

  final int itemCount;
  final List<({double weight, SliverGridRegularTileLayout layout})> _layouts;

  static SliverGridRegularTileLayout _regularLayout(
    double width,
    SliverGridDelegateWithMaxCrossAxisExtent delegate,
    int columns,
    bool reverse,
  ) {
    final tileWidth =
        math.max(0.0, width - (columns - 1) * delegate.crossAxisSpacing) /
        columns;
    final tileHeight =
        delegate.mainAxisExtent ?? tileWidth / delegate.childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: tileHeight + delegate.mainAxisSpacing,
      crossAxisStride: tileWidth + delegate.crossAxisSpacing,
      childMainAxisExtent: tileHeight,
      childCrossAxisExtent: tileWidth,
      reverseCrossAxis: reverse,
    );
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    var x = 0.0;
    var y = 0.0;
    var width = 0.0;
    var height = 0.0;
    for (final entry in _layouts) {
      final geometry = entry.layout.getGeometryForChildIndex(index);
      x += geometry.crossAxisOffset * entry.weight;
      y += geometry.scrollOffset * entry.weight;
      width += geometry.crossAxisExtent * entry.weight;
      height += geometry.mainAxisExtent * entry.weight;
    }
    return SliverGridGeometry(
      scrollOffset: y,
      crossAxisOffset: x,
      mainAxisExtent: height,
      crossAxisExtent: width,
    );
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    var low = 0;
    var high = itemCount;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      final geometry = getGeometryForChildIndex(middle);
      if (geometry.scrollOffset + geometry.mainAxisExtent <= scrollOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return math.min(low, math.max(0, itemCount - 1));
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    var low = 0;
    var high = itemCount;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (getGeometryForChildIndex(middle).scrollOffset < scrollOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return math.max(0, low - 1);
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount == 0) return 0;
    final last = getGeometryForChildIndex(childCount - 1);
    return last.scrollOffset + last.mainAxisExtent;
  }
}

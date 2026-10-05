import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 网格本体。切页时不要给 GridView 加 key，否则整表拆掉会弹跳。
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
    return GridView.builder(
      controller: controller,
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      physics: physics,
      padding: padding,
    );
  }
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

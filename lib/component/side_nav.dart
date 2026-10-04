// ignore_for_file: camel_case_types

import 'dart:ui';
import 'dart:math' as math;

import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/core/mouse_back_exit.dart';
import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/settings.dart';
import 'package:pure_music/component/frosted_chrome.dart';
import 'package:pure_music/component/motion.dart';
import 'package:pure_music/component/responsive_builder.dart';
import 'package:pure_music/core/paths.dart' as app_paths;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class DestinationDesc {
  final IconData icon;
  final String label;
  final String desPath;
  DestinationDesc(this.icon, this.label, this.desPath);
}

final destinations = <DestinationDesc>[
  DestinationDesc(Symbols.library_music, '音乐', app_paths.AUDIOS_PAGE),
  DestinationDesc(Symbols.artist, '艺术家', app_paths.ARTISTS_PAGE),
  DestinationDesc(Symbols.album, '专辑', app_paths.ALBUMS_PAGE),
  DestinationDesc(Symbols.folder, '文件夹', app_paths.FOLDERS_PAGE),
  DestinationDesc(Symbols.list, '歌单', app_paths.PLAYLISTS_PAGE),
  DestinationDesc(Symbols.stadium, '演出模式', app_paths.CONCERT_PAGE),
  DestinationDesc(Symbols.bar_chart, '统计', app_paths.STATS_PAGE),
  DestinationDesc(Symbols.settings, '设置', app_paths.SETTINGS_PAGE),
];

class SideNav extends StatefulWidget {
  const SideNav({
    super.key,
    this.navigationShell,
    this.onExpandedChanged,
    this.expansion,
  });

  final StatefulNavigationShell? navigationShell;
  final ValueChanged<bool>? onExpandedChanged;

  /// When set, width is owned by the parent and this value only drives labels.
  final double? expansion;
  static const double collapsedWidth = 80.0;
  static const double expandedWidth = 240.0;

  static double widthFor(double expansion) =>
      lerpDouble(collapsedWidth, expandedWidth, expansion.clamp(0.0, 1.0))!;

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  final sidebarExpanded = ValueNotifier(AppPreference.instance.sidebarExpanded);
  static const double _collapsedWidth = SideNav.collapsedWidth;
  static const double _expandedWidth = SideNav.expandedWidth;
  static const double _itemHeight = 54.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final navShell = widget.navigationShell;
    final selectedIndex =
        navShell?.currentIndex ??
        destinations.indexWhere(
          (d) => GoRouterState.of(context).uri.toString().startsWith(d.desPath),
        );
    final isDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    return ResponsiveBuilder(
      builder: (context, screenType) => LayoutBuilder(
        builder: (context, constraints) => _navForConstraints(
          context,
          scheme: scheme,
          navShell: navShell,
          selectedIndex: selectedIndex,
          isDrawer: isDrawer,
          constraints: constraints,
        ),
      ),
    );
  }


  Widget _navForConstraints(
    BuildContext context, {
    required ColorScheme scheme,
    required StatefulNavigationShell? navShell,
    required int selectedIndex,
    required bool isDrawer,
    required BoxConstraints constraints,
  }) {
    final expandedWidth = isDrawer
        ? constraints.maxWidth
        : math.min(_expandedWidth, constraints.maxWidth);
    return ValueListenableBuilder(
      valueListenable: sidebarExpanded,
      builder: (context, expanded, _) => _SmoothLargeSideNav(
        isDrawer: isDrawer,
        expanded: isDrawer || expanded,
        expansion: widget.expansion,
        expandedWidth: expandedWidth,
        colorScheme: scheme,
        selectedIndex: selectedIndex,
        onToggle: isDrawer ? () => _closeDrawer(context) : _toggleSidebar,
        onSelect: (value) => _onDestinationSelected(context, navShell, value),
        onReturnHome: (value) => _onDestinationDoubleTap(
          context,
          navShell,
          selectedIndex,
          value,
        ),
      ),
    );
  }

  void _closeDrawer(BuildContext context) {
    final scaffold = Scaffold.of(context);
    if (scaffold.hasDrawer) scaffold.closeDrawer();
  }

  void _toggleSidebar() {
    final newVal = !sidebarExpanded.value;
    sidebarExpanded.value = newVal;
    widget.onExpandedChanged?.call(newVal);
    AppPreference.instance.sidebarExpanded = newVal;
    AppPreference.instance.save();
  }

  void _onDestinationSelected(
    BuildContext context,
    StatefulNavigationShell? navShell,
    int value,
  ) {
    if (navShell?.currentIndex == value) return;
    if (value < app_paths.START_PAGES.length &&
        AppPreference.instance.startPage != value) {
      AppPreference.instance.startPage = value;
      AppPreference.instance.save();
    }
    if (navShell != null) {
      navShell.goBranch(value);
    } else {
      context.go(destinations[value].desPath);
    }
    _closeDrawer(context);
  }

  void _onDestinationDoubleTap(
    BuildContext context,
    StatefulNavigationShell? navShell,
    int selectedIndex,
    int value,
  ) {
    if (selectedIndex != value) return;
    if (MouseBackExit.consumeRoute(destinations[value].desPath)) return;
    if (navShell != null) {
      navShell.goBranch(value, initialLocation: true);
    } else {
      context.go(destinations[value].desPath);
    }
    _closeDrawer(context);
  }
}

class _SmoothLargeSideNav extends StatelessWidget {
  const _SmoothLargeSideNav({
    required this.isDrawer,
    required this.expanded,
    this.expansion,
    required this.expandedWidth,
    required this.colorScheme,
    required this.selectedIndex,
    required this.onToggle,
    required this.onSelect,
    required this.onReturnHome,
  });

  final bool isDrawer;
  final bool expanded;
  final double? expansion;
  final double expandedWidth;
  final ColorScheme colorScheme;
  final int? selectedIndex;
  final VoidCallback onToggle;
  final void Function(int) onSelect;
  final void Function(int) onReturnHome;

  static const double _collapsedWidth = _SideNavState._collapsedWidth;
  static const double _itemHeight = _SideNavState._itemHeight;

  @override
  Widget build(BuildContext context) {
    final expansion = this.expansion;
    if (expansion != null) {
      return RepaintBoundary(child: _buildPanel(context, expansion));
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        duration: reduceMotion ? Duration.zero : MotionDuration.sidebar,
        curve: MotionCurve.sidebar,
        tween: Tween<double>(end: expanded ? 1.0 : 0.0),
        builder: (context, t, _) => _buildPanel(context, t),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, double t) {
    final fillParent = expansion != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleWidth = fillParent
            ? constraints.maxWidth
            : SideNav.widthFor(t).clamp(_collapsedWidth, expandedWidth);
        final itemWidth = math.max(0.0, visibleWidth - 16.0);
        return SizedBox(
          width: fillParent ? double.infinity : visibleWidth,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _panelChrome(context, itemWidth, t),
          ),
        );
      },
    );
  }

  Widget _panelChrome(BuildContext context, double itemWidth, double t) {
    return ListenableBuilder(
      listenable: AppSettings.backgroundNotifier,
      builder: (context, _) => FrostedChrome(
        enabled: AppSettings.instance.enableSidebarFrostedGlass,
        borderRadius: AppRadius.mdCircular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _toggleItem(itemWidth, t),
            const SizedBox(height: 8),
            Expanded(child: _destinationList(context, itemWidth, t)),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(double itemWidth, double t) {
    final expandedVisual = t >= 0.5;
    return _NavItem(
      height: _itemHeight,
      width: itemWidth,
      icon: isDrawer
          ? Symbols.close
          : expandedVisual
          ? Symbols.menu_open
          : Symbols.menu,
      label: isDrawer
          ? '关闭'
          : expandedVisual
          ? '收起'
          : '展开',
      expandedT: t,
      selected: false,
      onTap: onToggle,
    );
  }

  Widget _destinationList(BuildContext context, double itemWidth, double t) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        SizedBox(
          height: _itemHeight * destinations.length,
          child: Stack(
            children: [
              if (selectedIndex != null && selectedIndex! >= 0)
                _selectionHighlight(itemWidth),
              Column(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _destinationItem(context, itemWidth, t, i),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _destinationItem(
    BuildContext context,
    double itemWidth,
    double t,
    int i,
  ) {
    final selected = selectedIndex == i;
    return _NavItem(
      height: _itemHeight,
      width: itemWidth,
      icon: destinations[i].icon,
      label: destinations[i].label,
      expandedT: t,
      selected: selected,
      onTap: () {
        onSelect(i);
        final scaffold = Scaffold.of(context);
        if (scaffold.hasDrawer) scaffold.closeDrawer();
      },
      onDoubleTap: selected ? () => onReturnHome(i) : null,
    );
  }

  Widget _selectionHighlight(double itemWidth) {
    return SpringProgress(
      target: selectedIndex!.toDouble(),
      spring: MotionSpring.entrance,
      builder: (context, index, child) => Transform.translate(
        offset: Offset(0, index * _itemHeight),
        child: child,
      ),
      child: SizedBox(
        width: itemWidth,
        height: _itemHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.85),
            borderRadius: AppRadius.smCircular,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.height,
    required this.width,
    required this.icon,
    required this.label,
    required this.expandedT,
    required this.selected,
    required this.onTap,
    this.onDoubleTap,
  });

  final double height;
  final double width;
  final IconData icon;
  final String label;
  final double expandedT;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final textOpacity = expandedT.clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.smCircular,
          child: InkWell(
            borderRadius: AppRadius.smCircular,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ClipRect(child: _row(fg, textOpacity)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(Color fg, double textOpacity) {
    const iconSize = 24.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 20.0),
        SizedBox(
          width: iconSize,
          child: Icon(icon, size: iconSize, color: fg.withValues(alpha: 0.90)),
        ),
        Opacity(
          opacity: textOpacity,
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: fg,
                fontSize: 14.5,
                fontWeight: selected
                    ? AppType.weightSemibold
                    : AppType.weightMedium,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

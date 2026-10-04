import 'package:pure_music/component/motion.dart';
import 'package:pure_music/component/adaptive_action_layout.dart';
import 'package:pure_music/core/design_tokens.dart';
import 'package:flutter/material.dart';

enum PageActionPlacement { besideTitle, belowSubtitle }

/// title, actions, body
///
/// 提供基本的响应式布局：
///
/// 小屏幕时，标题在上、操作按钮在下，互不挤压；
/// 中大屏幕时，标题和操作按钮在同一行排列。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
    required this.body,
    this.actionPlacement = PageActionPlacement.besideTitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final PageActionPlacement actionPlacement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SidebarMotionScope.maybeOf(context) != null
                ? _header(
                    context,
                    scheme,
                    BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        _header(context, scheme, constraints),
                  ),
          ),
          Container(
            height: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surfaceContainer.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }


  Widget _header(
    BuildContext context,
    ColorScheme scheme,
    BoxConstraints constraints,
  ) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sidebarMoving =
        SidebarMotionScope.maybeOf(context)?.isAnimating ?? false;
    if (actions.isEmpty) return _titleWidget(scheme);
    if (actionPlacement == PageActionPlacement.belowSubtitle) {
      return _buildBelowSubtitleLayout(scheme);
    }
    final compact =
        SidebarMotionScope.layoutWidthOf(context, constraints.maxWidth) <= 640;
    return _AnimatedHeaderLayout(
      layoutKey: compact,
      duration: (reduceMotion || sidebarMoving)
          ? Duration.zero
          : MotionDuration.base,
      child: compact ? _buildCompactLayout(scheme) : _buildWideLayout(scheme),
    );
  }

  Widget _buildBelowSubtitleLayout(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _titleWidget(scheme),
        const SizedBox(height: 12),
        AdaptiveActionLayout(compact: true, actions: actions),
      ],
    );
  }

  Widget _buildCompactLayout(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _titleWidget(scheme),
        const SizedBox(height: 16),
        _buildActionWrap(alignment: WrapAlignment.start),
      ],
    );
  }

  Widget _buildWideLayout(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _titleWidget(scheme)),
        const SizedBox(width: 16),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildActionWrap(alignment: WrapAlignment.end),
          ),
        ),
      ],
    );
  }

  Widget _buildActionWrap({required WrapAlignment alignment}) {
    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }

  Widget _titleWidget(ColorScheme scheme) {
    if (subtitle == null) {
      return Text(
        title,
        style: TextStyle(
          fontSize: AppType.display,
          fontWeight: AppType.weightSemibold,
          color: scheme.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppType.display,
            fontWeight: AppType.weightSemibold,
            color: scheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6.0),
        Text(
          subtitle!,
          style: TextStyle(
            fontSize: AppType.body,
            color: scheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _AnimatedHeaderLayout extends StatelessWidget {
  const _AnimatedHeaderLayout({
    required this.layoutKey,
    required this.duration,
    required this.child,
  });

  final bool layoutKey;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      alignment: Alignment.topLeft,
      duration: duration,
      curve: MotionCurve.standard,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: MotionCurve.standard,
        switchOutCurve: MotionCurve.standard,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topLeft,
          children: [
            ...previousChildren,
            ...[?currentChild],
          ],
        ),
        transitionBuilder: (child, animation) {
          final offset =
              Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: MotionCurve.standard),
              );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: KeyedSubtree(key: ValueKey(layoutKey), child: child),
      ),
    );
  }
}

import 'package:pure_music/component/motion.dart';
import 'package:flutter/material.dart';

class AdaptiveActionLayout extends StatelessWidget {
  const AdaptiveActionLayout({
    super.key,
    required this.compact,
    required this.actions,
    this.trailing,
  });

  final bool compact;
  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final child = trailing == null
        ? _buildActions()
        : Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: compact
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: compact ? 0 : 1,
                fit: compact ? FlexFit.loose : FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildActions(),
                ),
              ),
              SizedBox(width: compact ? 0 : 12, height: compact ? 8 : 0),
              Flexible(
                flex: 0,
                fit: FlexFit.loose,
                child: SizedBox(
                  width: compact ? double.infinity : 220,
                  child: trailing,
                ),
              ),
            ],
          );

    return AnimatedSize(
      alignment: Alignment.topLeft,
      duration: reduceMotion ? Duration.zero : MotionDuration.base,
      curve: MotionCurve.standard,
      child: child,
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
  }
}

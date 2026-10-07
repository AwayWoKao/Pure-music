import 'package:flutter/widgets.dart';

class NowPlayingVisibility extends InheritedWidget {
  const NowPlayingVisibility({
    super.key,
    required this.shown,
    required super.child,
  });

  final bool shown;

  static bool shownOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<NowPlayingVisibility>()
            ?.shown ??
        true;
  }

  @override
  bool updateShouldNotify(NowPlayingVisibility oldWidget) {
    return shown != oldWidget.shown;
  }
}

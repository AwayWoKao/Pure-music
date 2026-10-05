import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:ui';

typedef WindowVirtualScreen = ({int x, int y, int width, int height});

const _smXVirtualScreen = 76;
const _smYVirtualScreen = 77;
const _smCxVirtualScreen = 78;
const _smCyVirtualScreen = 79;
const _minVisiblePhysicalPx = 48.0;

typedef _GetSystemMetricsNative = Int32 Function(Int32 index);
typedef _GetSystemMetricsDart = int Function(int index);

_GetSystemMetricsDart? _getSystemMetrics;

void _ensureSystemMetrics() {
  if (_getSystemMetrics != null || !Platform.isWindows) return;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    _getSystemMetrics = user32
        .lookupFunction<_GetSystemMetricsNative, _GetSystemMetricsDart>(
          'GetSystemMetrics',
        );
  } catch (_) {
    _getSystemMetrics = null;
  }
}

WindowVirtualScreen? windowsVirtualScreen() {
  _ensureSystemMetrics();
  final fn = _getSystemMetrics;
  if (fn == null) return null;
  final width = fn(_smCxVirtualScreen);
  final height = fn(_smCyVirtualScreen);
  if (width <= 0 || height <= 0) return null;
  return (
    x: fn(_smXVirtualScreen),
    y: fn(_smYVirtualScreen),
    width: width,
    height: height,
  );
}

bool windowPlacementIsOnscreen({
  required Offset position,
  required Size size,
  required double devicePixelRatio,
  required WindowVirtualScreen screen,
}) {
  if (devicePixelRatio <= 0 || size.width <= 0 || size.height <= 0) {
    return false;
  }
  final left = position.dx * devicePixelRatio;
  final top = position.dy * devicePixelRatio;
  final right = left + size.width * devicePixelRatio;
  final bottom = top + size.height * devicePixelRatio;
  final overlapX = _overlap(
    left,
    right,
    screen.x.toDouble(),
    (screen.x + screen.width).toDouble(),
  );
  final overlapY = _overlap(
    top,
    bottom,
    screen.y.toDouble(),
    (screen.y + screen.height).toDouble(),
  );
  return overlapX >= _minVisiblePhysicalPx && overlapY >= _minVisiblePhysicalPx;
}

double _overlap(double a0, double a1, double b0, double b1) {
  final start = a0 > b0 ? a0 : b0;
  final end = a1 < b1 ? a1 : b1;
  final delta = end - start;
  return delta > 0 ? delta : 0;
}

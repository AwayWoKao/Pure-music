import 'package:flutter/material.dart';

/// 从封面调色板里挑主题种子色：主色够鲜就用主色，否则用更有色彩的那颗。
Color selectThemeSeedColor(List<Color> palette) {
  if (palette.isEmpty) return const Color(0xff27272a);
  final dominant = palette.first;
  final dominantHsv = HSVColor.fromColor(dominant);
  final dominantHsl = HSLColor.fromColor(dominant);
  if (dominantHsv.saturation * dominantHsv.value >= 0.06 &&
      dominantHsl.saturation >= 0.18) {
    return dominant;
  }

  Color? selected;
  var bestScore = double.negativeInfinity;
  for (var index = 1; index < palette.length; index++) {
    final color = palette[index];
    final hsv = HSVColor.fromColor(color);
    final hsl = HSLColor.fromColor(color);
    final chroma = hsv.saturation * hsv.value;
    if (chroma < 0.06 || hsl.saturation < 0.18) continue;

    final toneFit = 1.0 - (hsl.lightness - 0.5).abs() * 2.0;
    final score =
        chroma * 0.65 +
        hsl.saturation * 0.2 +
        toneFit * 0.1 +
        0.05 / (index + 1);
    if (score > bestScore) {
      bestScore = score;
      selected = color;
    }
  }
  return selected ?? palette.first;
}

class ColorExtractionService {
  static final ColorExtractionService _instance =
      ColorExtractionService._internal();
  factory ColorExtractionService() => _instance;
  ColorExtractionService._internal();

  static const int _maxPathCacheSize = 200;

  /// 按音频路径+修改时间缓存主色，避免封面更新后仍用旧色。
  final Map<String, Color> _pathColorCache = {};
  final Map<String, List<Color>> _pathPaletteCache = {};
  final List<String> _pathAccessOrder = [];

  String _cacheKey(String path, int? modified) {
    if (modified == null) return path;
    return '$path|$modified';
  }

  void cachePaletteForPath(String path, List<Color> palette, {int? modified}) {
    if (palette.isEmpty) return;
    final key = _cacheKey(path, modified);
    _pathPaletteCache[key] = List.unmodifiable(palette);
    _pathColorCache[key] = palette.first;
    _trimPathCache(key);
  }

  void _trimPathCache(String key) {
    _touchPathCacheEntry(key);
    while (_pathAccessOrder.length > _maxPathCacheSize &&
        _pathAccessOrder.isNotEmpty) {
      final oldest = _pathAccessOrder.removeAt(0);
      _pathColorCache.remove(oldest);
      _pathPaletteCache.remove(oldest);
    }
  }

  Color? getCachedColorForPath(String path, {int? modified}) {
    final key = _cacheKey(path, modified);
    final color =
        _pathColorCache[key] ??
        (modified == null ? null : _pathColorCache[path]);
    if (color != null) _touchPathCacheEntry(key);
    return color;
  }

  List<Color>? getCachedPaletteForPath(String path, {int? modified}) {
    final key = _cacheKey(path, modified);
    final palette =
        _pathPaletteCache[key] ??
        (modified == null ? null : _pathPaletteCache[path]);
    if (palette != null) {
      _touchPathCacheEntry(key);
      return List<Color>.from(palette);
    }
    return null;
  }

  void _touchPathCacheEntry(String path) {
    _pathAccessOrder.remove(path);
    _pathAccessOrder.add(path);
  }

  void clear() {
    _pathColorCache.clear();
    _pathPaletteCache.clear();
    _pathAccessOrder.clear();
  }
}

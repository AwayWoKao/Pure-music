import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/theme.dart';

void main() {
  test('player theme foreground uses seed color when enabled', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE53935),
      brightness: Brightness.dark,
    );
    expect(
      playerThemeForeground(scheme, enabled: true),
      scheme.primary,
    );
  });

  test('player theme foreground uses black or white when disabled', () {
    final dark = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE53935),
      brightness: Brightness.dark,
    );
    final light = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE53935),
      brightness: Brightness.light,
    );
    expect(playerThemeForeground(dark, enabled: false), Colors.white);
    expect(playerThemeForeground(light, enabled: false), Colors.black);
    expect(playerThemeForeground(dark, enabled: false), isNot(dark.onSurface));
    expect(playerThemeForeground(light, enabled: false), isNot(light.onSurface));
  });
}

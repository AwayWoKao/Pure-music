import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/color_extraction.dart';

void main() {
  test('keeps a colorful dominant color as the theme seed', () {
    expect(
      selectThemeSeedColor(const [Color(0xFFE53935), Color(0xFF90CAF9)]),
      const Color(0xFFE53935),
    );
  });

  test('skips a gray dominant color for a more colorful seed', () {
    expect(
      selectThemeSeedColor(const [Color(0xFF808080), Color(0xFFE53935)]),
      const Color(0xFFE53935),
    );
  });

  test('falls back to the first color when the palette is all gray', () {
    expect(
      selectThemeSeedColor(const [Color(0xFF777777), Color(0xFF9E9E9E)]),
      const Color(0xFF777777),
    );
  });

  test('falls back to a neutral seed when the palette is empty', () {
    expect(selectThemeSeedColor(const []), const Color(0xff27272a));
  });
}

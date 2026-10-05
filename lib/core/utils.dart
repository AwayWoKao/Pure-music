// ignore_for_file: unnecessary_this

import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:pure_music/core/design_tokens.dart';

export 'log/diagnostic_redaction.dart';
export 'log/app_log.dart' show log, LogMemory;
import 'package:pinyin/pinyin.dart';

extension StringHMMSS on Duration {
  /// Returns a string with hours, minutes, seconds,
  /// in the following format: H:MM:SS
  String toStringHMMSS() {
    return toString().split('.').first;
  }

  String toStringMSS() {
    final totalSeconds = inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

const int _pinyinCacheMaxSize = 2000;
final LinkedHashMap<String, String> _pinyinCache = LinkedHashMap();
final LinkedHashMap<String, String> _pinyinInitialsCache = LinkedHashMap();

extension PinyinCompare on String {
  /// convert str to pinyin, cache it when it hasn't been converted;
  String _getPinyin() {
    final cachedPinyin = _pinyinCache.remove(this);
    if (cachedPinyin != null) {
      _pinyinCache[this] = cachedPinyin;
      return cachedPinyin;
    }

    final pinyinBuilder = StringBuffer();
    for (final rune in runes) {
      final c = String.fromCharCode(rune);
      if (ChineseHelper.isChinese(c)) {
        final pinyin = PinyinHelper.convertToPinyinArray(
          c,
          PinyinFormat.WITHOUT_TONE,
        ).firstOrNull;

        pinyinBuilder.write(pinyin ?? c);
      } else {
        pinyinBuilder.write(c);
      }
    }

    final pinyin = pinyinBuilder.toString();

    _pinyinCache[this] = pinyin;
    while (_pinyinCache.length > _pinyinCacheMaxSize) {
      _pinyinCache.remove(_pinyinCache.keys.first);
    }

    return pinyin;
  }

  /// Compares this string to [other] with pinyin first, else use the ordering of the code units.
  ///
  /// Returns a negative value if `this` is ordered before `other`,
  /// a positive value if `this` is ordered after `other`,
  /// or zero if `this` and `other` are equivalent.
  int localeCompareTo(String other) {
    final thisContainsChinese = ChineseHelper.containsChinese(this);
    final otherContainsChinese = ChineseHelper.containsChinese(other);

    final thisCmpStr = thisContainsChinese ? this._getPinyin() : this;
    final otherCmpStr = otherContainsChinese ? other._getPinyin() : other;

    return thisCmpStr.compareTo(otherCmpStr);
  }

  int naturalCompareTo(String other) {
    final aTokens = _tokenizeForNaturalCompare(this);
    final bTokens = _tokenizeForNaturalCompare(other);
    return _compareNaturalTokens(aTokens, bTokens);
  }

  String getPinyinInitials() {
    final cached = _pinyinInitialsCache.remove(this);
    if (cached != null) {
      _pinyinInitialsCache[this] = cached;
      return cached;
    }

    final buffer = StringBuffer();
    for (final rune in runes) {
      final c = String.fromCharCode(rune);
      if (ChineseHelper.isChinese(c)) {
        final pinyin = PinyinHelper.convertToPinyinArray(
          c,
          PinyinFormat.WITHOUT_TONE,
        ).firstOrNull;
        if (pinyin != null && pinyin.isNotEmpty) {
          buffer.write(pinyin[0]);
        }
      } else if (c.codeUnitAt(0) >= 0x41 && c.codeUnitAt(0) <= 0x5A ||
          c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7A ||
          c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) {
        buffer.write(c);
      }
    }

    final result = buffer.toString();
    _pinyinInitialsCache[this] = result;
    while (_pinyinInitialsCache.length > _pinyinCacheMaxSize) {
      _pinyinInitialsCache.remove(_pinyinInitialsCache.keys.first);
    }
    return result;
  }
}

String alphabetSectionFor(String value) {
  final normalized = _localeComparisonKey(value.trimLeft());
  if (normalized.isEmpty) return '#';
  final first = normalized.codeUnitAt(0);
  if (first >= 0x30 && first <= 0x39) return '0';
  final upper = first >= 0x61 && first <= 0x7a ? first - 0x20 : first;
  if (upper >= 0x41 && upper <= 0x5a) {
    return String.fromCharCode(upper);
  }
  return '#';
}

void sortNaturallyBy<T>(
  List<T> list,
  String Function(T item) valueOf, {
  bool descending = false,
  bool reuseEqualKeys = false,
}) {
  final tokenCache = reuseEqualKeys ? <String, List<_NaturalToken>>{} : null;
  final prepared = List<(T, List<_NaturalToken>)>.generate(list.length, (
    index,
  ) {
    final item = list[index];
    final value = valueOf(item);
    var tokens = tokenCache?[value];
    if (tokens == null) {
      tokens = _tokenizeForNaturalCompare(value);
      tokenCache?[value] = tokens;
    }
    return (item, tokens);
  }, growable: false);
  prepared.sort((a, b) {
    if (descending) {
      return _compareNaturalTokens(b.$2, a.$2);
    }
    return _compareNaturalTokens(a.$2, b.$2);
  });
  for (var i = 0; i < prepared.length; i++) {
    list[i] = prepared[i].$1;
  }
}

class _NaturalToken {
  final bool isNumber;
  final String text;
  final int significantNumberStart;
  late final String comparisonText = _localeComparisonKey(text.toLowerCase());

  _NaturalToken._(this.isNumber, this.text, this.significantNumberStart);
  factory _NaturalToken.text(String text) => _NaturalToken._(false, text, 0);
  factory _NaturalToken.number(String text) {
    var start = 0;
    while (start < text.length - 1 && text.codeUnitAt(start) == 0x30) {
      start++;
    }
    return _NaturalToken._(true, text, start);
  }
}

String _localeComparisonKey(String value) =>
    ChineseHelper.containsChinese(value) ? value._getPinyin() : value;

int _compareNaturalTokens(
  List<_NaturalToken> aTokens,
  List<_NaturalToken> bTokens,
) {
  final len = aTokens.length < bTokens.length ? aTokens.length : bTokens.length;
  for (var i = 0; i < len; i++) {
    final a = aTokens[i];
    final b = bTokens[i];
    if (a.isNumber && b.isNumber) {
      final numberComparison = _compareNaturalNumbers(a, b);
      if (numberComparison != 0) return numberComparison;
      final lengthComparison = a.text.length.compareTo(b.text.length);
      if (lengthComparison != 0) return lengthComparison;
      continue;
    }
    final textComparison = a.comparisonText.compareTo(b.comparisonText);
    if (textComparison != 0) return textComparison;
  }
  return aTokens.length.compareTo(bTokens.length);
}

int _compareNaturalNumbers(_NaturalToken a, _NaturalToken b) {
  final aLength = a.text.length - a.significantNumberStart;
  final bLength = b.text.length - b.significantNumberStart;
  final lengthComparison = aLength.compareTo(bLength);
  if (lengthComparison != 0) return lengthComparison;
  for (var offset = 0; offset < aLength; offset++) {
    final comparison = a.text
        .codeUnitAt(a.significantNumberStart + offset)
        .compareTo(b.text.codeUnitAt(b.significantNumberStart + offset));
    if (comparison != 0) return comparison;
  }
  return 0;
}

List<_NaturalToken> _tokenizeForNaturalCompare(String input) {
  if (input.isEmpty) return const [];
  final tokens = <_NaturalToken>[];
  var tokenStart = 0;
  var inNumber = false;
  for (var i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    final isDigit = c >= 0x30 && c <= 0x39;
    if (i == 0) {
      inNumber = isDigit;
      continue;
    }
    if (isDigit == inNumber) {
      continue;
    }
    final text = input.substring(tokenStart, i);
    tokens.add(
      inNumber ? _NaturalToken.number(text) : _NaturalToken.text(text),
    );
    tokenStart = i;
    inNumber = isDigit;
  }
  final text = input.substring(tokenStart);
  tokens.add(
    inNumber == true ? _NaturalToken.number(text) : _NaturalToken.text(text),
  );
  return tokens;
}

final GlobalKey<NavigatorState> routerKey = GlobalKey();

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastVariant { info, success, error }

void showTextOnSnackBar(
  String text, {
  IconData? icon,
  ToastVariant variant = ToastVariant.info,
}) {
  final context =
      scaffoldMessengerKey.currentContext ?? routerKey.currentContext;
  final overlay = routerKey.currentState?.overlay;
  if (context == null || overlay == null) return;

  _toastEntry?.remove();
  _toastTimer?.cancel();

  final IconData effectiveIcon;
  switch (variant) {
    case ToastVariant.success:
      effectiveIcon = icon ?? Icons.check_circle_outline;
    case ToastVariant.error:
      effectiveIcon = icon ?? Icons.error_outline;
    case ToastVariant.info:
      effectiveIcon = icon ?? Icons.info_outline;
  }

  final visible = ValueNotifier(false);
  final entry = OverlayEntry(
    builder: (context) => _SnackToastBubble(
      text: text,
      icon: effectiveIcon,
      visible: visible,
    ),
  );

  _toastEntry = entry;
  overlay.insert(entry);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!identical(_toastEntry, entry)) return;
    visible.value = true;
  });

  _toastTimer = Timer(const Duration(seconds: 2), () {
    visible.value = false;
    Timer(const Duration(milliseconds: 160), () {
      entry.remove();
      if (identical(_toastEntry, entry)) {
        _toastEntry = null;
        _toastTimer = null;
      }
    });
  });
}

OverlayEntry? _toastEntry;
Timer? _toastTimer;

OverlayEntry? _lyricWriteEntry;
Timer? _lyricWriteTimer;
VoidCallback? _lyricWriteOnTimeout;

OverlayEntry? _hotkeyToastEntry;
Timer? _hotkeyToastTimer;

void showHotkeyToast({required String text, IconData? icon}) {
  final context =
      scaffoldMessengerKey.currentContext ?? routerKey.currentContext;
  final overlay = routerKey.currentState?.overlay;
  if (context == null || overlay == null) return;

  _hotkeyToastTimer?.cancel();
  final previousEntry = _hotkeyToastEntry;
  _hotkeyToastEntry = null;
  if (previousEntry?.mounted ?? false) {
    previousEntry!.remove();
  }

  final visible = ValueNotifier(false);
  final entry = OverlayEntry(
    builder: (context) =>
        _HotkeyToastBubble(text: text, icon: icon, visible: visible),
  );

  _hotkeyToastEntry = entry;
  overlay.insert(entry);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!identical(_hotkeyToastEntry, entry)) return;
    visible.value = true;
  });

  _hotkeyToastTimer = Timer(const Duration(milliseconds: 1100), () {
    if (!identical(_hotkeyToastEntry, entry)) return;
    visible.value = false;
    Timer(const Duration(milliseconds: 160), () {
      if (!identical(_hotkeyToastEntry, entry)) return;
      if (entry.mounted) entry.remove();
      _hotkeyToastEntry = null;
      _hotkeyToastTimer = null;
    });
  });
}

/// 显示网络歌词写入标签的提示（Overlay bubble）
bool showLyricWritePrompt({
  required String title,
  required VoidCallback onWrite,
  required VoidCallback onDismiss,
  VoidCallback? onTimeout,
  String message = '写入标签？',
  String confirmLabel = '写入',
}) {
  final context =
      scaffoldMessengerKey.currentContext ?? routerKey.currentContext;
  final overlay = routerKey.currentState?.overlay;
  if (context == null || overlay == null) return false;

  hideLyricWritePrompt();
  _lyricWriteOnTimeout = onTimeout;

  final visible = ValueNotifier(false);
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (context) => _LyricWritePromptBubble(
      visible: visible,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onWrite: () {
        hideLyricWritePrompt();
        onWrite();
      },
      onSkip: () {
        hideLyricWritePrompt();
        onDismiss();
      },
    ),
  );

  _lyricWriteEntry = entry;
  overlay.insert(entry);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!identical(_lyricWriteEntry, entry)) return;
    visible.value = true;
  });

  _lyricWriteTimer = Timer(const Duration(seconds: 8), () {
    visible.value = false;
    final timeout = _lyricWriteOnTimeout;
    _lyricWriteOnTimeout = null;
    timeout?.call();
    Timer(const Duration(milliseconds: 160), () {
      entry?.remove();
      if (identical(_lyricWriteEntry, entry)) {
        _lyricWriteEntry = null;
        _lyricWriteTimer = null;
      }
    });
  });
  return true;
}

void hideLyricWritePrompt() {
  _lyricWriteTimer?.cancel();
  _lyricWriteTimer = null;
  _lyricWriteOnTimeout = null;
  _lyricWriteEntry?.remove();
  _lyricWriteEntry = null;
}



class _LyricWritePromptBubble extends StatelessWidget {
  const _LyricWritePromptBubble({
    required this.visible,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onWrite,
    required this.onSkip,
  });

  final ValueNotifier<bool> visible;
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onWrite;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Positioned.fill(
      child: SafeArea(
        minimum: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: Spacing.bottomNav),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder(
              valueListenable: visible,
              builder: (context, v, child) => AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                curve: Curves.fastOutSlowIn,
                opacity: v ? 1.0 : 0.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.fastOutSlowIn,
                  scale: v ? 1.0 : 0.96,
                  child: child,
                ),
              ),
              child: _card(scheme, textTheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme scheme, TextTheme textTheme) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withAlpha(40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 16,
              color: scheme.onInverseSurface,
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              message,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onInverseSurface,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onInverseSurface,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            GestureDetector(
              onTap: onWrite,
              child: Text(
                confirmLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onInverseSurface,
                  fontWeight: AppType.weightBold,
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            GestureDetector(
              onTap: onSkip,
              child: Text(
                '\u8df3\u8fc7',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


Widget _toastAppear(bool visible, Widget? child) {
  return AnimatedOpacity(
    duration: const Duration(milliseconds: 140),
    curve: Curves.fastOutSlowIn,
    opacity: visible ? 1.0 : 0.0,
    child: AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.fastOutSlowIn,
      scale: visible ? 1.0 : 0.96,
      child: child,
    ),
  );
}

class _SnackToastBubble extends StatelessWidget {
  const _SnackToastBubble({
    required this.text,
    required this.icon,
    required this.visible,
  });

  final String text;
  final IconData icon;
  final ValueNotifier<bool> visible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final txtColor = scheme.onInverseSurface;
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          minimum: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: Spacing.bottomNav),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder(
                valueListenable: visible,
                builder: (context, v, child) => _toastAppear(v, child),
                child: _card(scheme, textTheme, txtColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme scheme, TextTheme textTheme, Color txtColor) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: txtColor),
            const SizedBox(width: Spacing.sm),
            Text(
              text,
              style: textTheme.labelLarge?.copyWith(color: txtColor),
            ),
          ],
        ),
      ),
    );
  }
}


class _HotkeyToastBubble extends StatelessWidget {
  const _HotkeyToastBubble({
    required this.text,
    required this.visible,
    this.icon,
  });

  final String text;
  final IconData? icon;
  final ValueNotifier<bool> visible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          minimum: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: Spacing.bottomNav),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder(
                valueListenable: visible,
                builder: (context, v, child) => _toastAppear(v, child),
                child: _toastBody(scheme, textTheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toastBody(ColorScheme scheme, TextTheme textTheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: scheme.onInverseSurface),
              const SizedBox(width: Spacing.sm),
            ],
            Text(
              text,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onInverseSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

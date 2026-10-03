import 'dart:io';

const modules = <String, String>{
  'lib/play_service/playback_service.dart': 'playback',
  'lib/play_service/smart_transition_coordinator.dart': 'playback',
  'lib/play_service/sleep_timer.dart': 'playback',
  'lib/native/bass/bass_player.dart': 'bass',
  'lib/play_service/equalizer_service.dart': 'bass',
  'lib/lyric/lyric_loader.dart': 'lyric',
  'lib/lyric/lyric_source.dart': 'lyric',
  'lib/play_service/lyric_service.dart': 'lyric',
  'lib/services/online_lyric/sources/kg_source.dart': 'onlineLyric',
  'lib/services/online_lyric/sources/ne_source.dart': 'onlineLyric',
  'lib/services/online_lyric/sources/qq_source.dart': 'onlineLyric',
  'lib/core/matcher.dart': 'onlineLyric',
  'lib/play_service/smtc_bridge.dart': 'smtc',
  'lib/core/memory_monitor.dart': 'memory',
  'lib/library/audio_library.dart': 'library',
  'lib/library/playlist.dart': 'library',
  'lib/library/library_page_snapshot_coordinator.dart': 'library',
  'lib/page/albums_page.dart': 'library',
  'lib/page/artists_page.dart': 'library',
  'lib/page/folders_page.dart': 'library',
  'lib/page/concert_page.dart': 'library',
  'lib/page/playlists_page.dart': 'library',
  'lib/page/uni_page.dart': 'library',
  'lib/page/updating_page.dart': 'library',
  'lib/page/audio_detail_page.dart': 'library',
  'lib/play_service/desktop_lyric_service.dart': 'desktopLyric',
  'lib/core/settings.dart': 'settings',
  'lib/core/preference_app.dart': 'settings',
  'lib/page/settings_page/backup_settings.dart': 'settings',
  'lib/page/settings_page/settings_tabs.dart': 'settings',
  'lib/page/settings_page/tabs/about_tab.dart': 'settings',
  'lib/services/backup_service.dart': 'settings',
  'lib/core/update_checker.dart': 'update',
  'lib/core/update_installer.dart': 'update',
  'lib/core/window_lifecycle.dart': 'window',
  'lib/core/hotkeys.dart': 'hotkey',
  'lib/services/lastfm/lastfm_service.dart': 'lastfm',
};

const levels = {'t': 'trace', 'd': 'debug', 'i': 'info', 'w': 'warn', 'e': 'error', 'f': 'fatal'};

void main() {
  final roots = [Directory('lib'), Directory('test'), Directory('integration_test')];
  var changed = 0;
  for (final root in roots) {
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceAll('\\', '/');
      if (relative.contains('frb_generated')) continue;
      if (relative.endsWith('lib/native/rust/api/kg.dart') ||
          relative.endsWith('lib/native/rust/api/qq.dart') ||
          relative.endsWith('lib/core/log/app_log.dart')) {
        continue;
      }
      final module = _moduleFor(relative);
      final original = entity.readAsStringSync();
      final migrated = _migrate(original, module);
      if (migrated == original) continue;
      entity.writeAsStringSync(migrated);
      changed++;
      stdout.writeln('$relative -> $module');
    }
  }
  stdout.writeln('changed $changed files');
}

String _moduleFor(String relative) {
  for (final entry in modules.entries) {
    if (relative.endsWith(entry.key)) return entry.value;
  }
  return 'app';
}

String _migrate(String source, String module) {
  final buffer = StringBuffer();
  var index = 0;
  final pattern = RegExp(r'logger\.([tdiwef])\(');
  for (final match in pattern.allMatches(source)) {
    final end = _callEnd(source, match.end - 1);
    if (end == null) continue;
    buffer
      ..write(source.substring(index, match.start))
      ..write(_rewrite(source.substring(match.start, end), module));
    index = end;
  }
  buffer.write(source.substring(index));
  final merged = buffer.toString();
  if (merged == source) return source;
  return _ensureImport(merged);
}

int? _callEnd(String source, int openParen) {
  var depth = 0;
  var quote = '';
  var escaped = false;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == quote) quote = '';
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return null;
}

String _rewrite(String call, String module) {
  final match = RegExp(r'^logger\.([tdiwef])\(').firstMatch(call)!;
  final level = levels[match.group(1)]!;
  final body = call.substring(match.end, call.length - 1);
  final split = _splitArgs(body);
  final message = split.message.trim();
  final named = split.named.trim();
  final suffix = named.isEmpty ? '' : ', $named';
  return "log.$module.$level('legacy', $message$suffix)";
}

({String message, String named}) _splitArgs(String body) {
  var depth = 0;
  var quote = '';
  var escaped = false;
  for (var i = 0; i < body.length; i++) {
    final char = body[i];
    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == quote) quote = '';
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') depth--;
    if (char == ',' && depth == 0) {
      final rest = body.substring(i + 1);
      if (RegExp(r'^\s*(error|stackTrace)\s*:').hasMatch(rest)) {
        return (message: body.substring(0, i), named: rest);
      }
    }
  }
  return (message: body, named: '');
}

String _ensureImport(String source) {
  if (source.contains("core/utils.dart") || source.contains("core/log/app_log.dart")) {
    return source;
  }
  final import = RegExp(r"^import '[^']+';\r?\n", multiLine: true);
  final matches = import.allMatches(source).toList();
  if (matches.isEmpty) {
    return "import 'package:pure_music/core/log/app_log.dart';\n$source";
  }
  final at = matches.last.end;
  return "${source.substring(0, at)}import 'package:pure_music/core/log/app_log.dart';\n${source.substring(at)}";
}

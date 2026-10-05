import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:pure_music/core/application_log.dart';
import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/setting_action_state.dart';
import 'package:pure_music/core/settings.dart';
import 'package:pure_music/core/cache.dart';
import 'package:path/path.dart' as path;
import 'package:pure_music/entry.dart';
import 'package:pure_music/core/hotkeys.dart';
import 'package:pure_music/core/immersive.dart';
import 'package:pure_music/core/memory_monitor.dart';
import 'package:pure_music/core/now_playing_perf_auto.dart';
import 'package:pure_music/core/sidebar_perf_auto.dart';
import 'package:pure_music/native/rust/api/logger.dart';
import 'package:pure_music/native/rust/frb_generated.dart';
import 'package:pure_music/core/app_fonts.dart';
import 'package:pure_music/core/theme.dart';
import 'package:pure_music/core/log/rust_log_line.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/core/window_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';

Future<void> initWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  final minimumSize = Size(
    minimumWindowSizeSetting.width,
    minimumWindowSizeSetting.height,
  );
  Size targetSize = AppSettings.instance.windowSize;
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final display = view.display;
  final displayW = display.size.width / display.devicePixelRatio;
  final displayH = display.size.height / display.devicePixelRatio;
  final maxW = (displayW - 16.0)
      .clamp(minimumSize.width, double.infinity)
      .toDouble();
  final maxH = (displayH - 16.0)
      .clamp(minimumSize.height, double.infinity)
      .toDouble();
  targetSize = Size(
    targetSize.width.clamp(minimumSize.width, maxW),
    targetSize.height.clamp(minimumSize.height, maxH),
  );

  WindowOptions windowOptions = WindowOptions(
    minimumSize: minimumSize,
    size: targetSize,
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (WindowLifecycleService.instance.isExiting) return;
    await windowManager.show();
    if (WindowLifecycleService.instance.isExiting) return;
    if (AppSettings.instance.isWindowMaximized) {
      await windowManager.maximize();
      if (WindowLifecycleService.instance.isExiting) return;
    }
    await windowManager.focus();
  });
}

Future<void> loadPrefFont() async {
  final settings = AppSettings.instance;
  Future<void> load(String? family, String? path) async {
    if (family == null || path == null) return;
    try {
      await loadAppFontFile(family: family, path: path);
    } catch (err, trace) {
      log.app.error('legacy', err.toString(), stackTrace: trace);
    }
  }

  await load(settings.fontFamily, settings.fontPath);
  await load(settings.lyricFontFamily, settings.lyricFontPath);
  ThemeProvider.instance.applyLoadedFonts();
}

void _installGlobalErrorLogging() {
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    applicationLogOutput.recordUnhandledSync(
      source: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
    log.app.error(
      'legacy',
      '[flutter] unhandled framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    previousFlutterError?.call(details);
  };
  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    applicationLogOutput.recordUnhandledSync(
      source: 'platform',
      error: error,
      stackTrace: stackTrace,
    );
    log.app.fatal(
      'legacy',
      '[platform] unhandled asynchronous error',
      error: error,
      stackTrace: stackTrace,
    );
    return previousPlatformError?.call(error, stackTrace) ?? false;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await applicationLogOutput.init();
  _installGlobalErrorLogging();
  try {
    await _runApplication();
  } catch (error, stackTrace) {
    applicationLogOutput.recordUnhandledSync(
      source: 'startup',
      error: error,
      stackTrace: stackTrace,
    );
    log.app.fatal(
      'legacy',
      '[startup] unhandled error',
      error: error,
      stackTrace: stackTrace,
    );
    await applicationLogOutput.flush();
    rethrow;
  }
}

Future<void> _runApplication() async {
  PaintingBinding.instance.imageCache.maximumSize = 96;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 32 << 20;
  final singleInstance = FlutterSingleInstance();
  if (!await singleInstance.isFirstInstance()) {
    await singleInstance.focus();
    exit(0);
  }
  try {
    await RustLib.init();
  } catch (e, s) {
    log.app.error('legacy', 'RustLib.init failed: $e\n$s');
    rethrow;
  }
  _listenRustLogger();
  await HotkeysHelper.unregisterAll();
  final welcome = await _loadSettingsAndCaches();
  if (!await _initWindowShell()) return;
  MemoryMonitorService.instance.start();
  runApp(Entry(welcome: welcome));
  NowPlayingPerfAuto.schedule();
  SidebarPerfAuto.schedule();
}

void _listenRustLogger() {
  _rustLoggerSub = initRustLogger().listen((line) {
    final parsed = parseRustLogLine(line);
    if (parsed == null) {
      log.rust.info('legacy', line);
      return;
    }
    log.write(parsed);
  });
}

Future<bool> _loadSettingsAndCaches() async {
  final supportPath = (await getAppDataDir()).path;
  CoverImageCache.instance.configure(indexPath: supportPath);
  final settingsDir = await getSettingsDir();
  if (File(path.join(settingsDir.path, 'settings.json')).existsSync()) {
    await AppSettings.readFromJson();
    await loadPrefFont();
  }
  if (File(path.join(settingsDir.path, 'app_preference.json')).existsSync()) {
    await AppPreference.read();
  }
  await HotkeysHelper.registerHotKeys();
  await AlbumColorCache.instance.init();
  return !File(path.join(supportPath, 'index.json')).existsSync();
}

Future<bool> _initWindowShell() async {
  await initWindow();
  await WindowLifecycleService.instance.init(
    disposeRuntimeResources: disposeRuntimeResources,
  );
  if (WindowLifecycleService.instance.isExiting) return false;
  FlutterSingleInstance.onFocus = (_) =>
      WindowLifecycleService.instance.showWindow();
  await ImmersiveModeController.instance.init();
  if (WindowLifecycleService.instance.isExiting) return false;
  if (AppSettings.instance.appWindowTransparent) {
    await windowManager.setBackgroundColor(Colors.transparent);
  }
  return true;
}

StreamSubscription<String>? _rustLoggerSub;

Future<void> disposeRuntimeResources() async {
  MemoryMonitorService.instance.stop();
  final rustLoggerSub = _rustLoggerSub;
  _rustLoggerSub = null;
  if (rustLoggerSub != null) {
    unawaited(rustLoggerSub.cancel().catchError((_) {}));
  }
  await applicationLogOutput.flush();
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error hooks: in release builds an uncaught error otherwise shows
  // nothing but a black window. Log it instead of going silent.
  FlutterError.onError = (details) {
    logger.error('Flutter framework error',
        error: details.exception, stackTrace: details.stack);
    if (!kReleaseMode) {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('Uncaught platform error', error: error, stackTrace: stack);
    return true;
  };

  await logger.initialize();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
  ));

  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    try {
      await windowManager.ensureInitialized();
      final isMacOS = Platform.isMacOS;
      final options = WindowOptions(
        size: Size(1180, 760),
        minimumSize: Size(760, 560),
        center: true,
        // Opaque backing: a transparent frameless window renders BLACK if the
        // Metal surface ever stalls (e.g. during a heavy model load), hiding
        // the app behind an unreadable void. A solid color always shows the
        // themed background / last frame instead. Matches the default dark
        // theme ("midnight espresso") until the theme provider syncs it.
        backgroundColor: const Color(0xFF241A11),
        // macOS: the native title-bar strip is configured natively as a
        // separate, theme-colored region above the content (see
        // MainFlutterWindow.swift) — passing a titleBarStyle here would
        // override it (hidden re-adds fullSizeContentView). Windows/Linux
        // draw their own bar in Flutter, so their native bar is hidden.
        titleBarStyle: isMacOS ? null : TitleBarStyle.hidden,
        title: 'Moonlight Study',
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e, stackTrace) {
      logger.error('Window initialization failed', error: e, stackTrace: stackTrace);
    }
  }

  runApp(const ProviderScope(child: StudyCompanionApp()));
}

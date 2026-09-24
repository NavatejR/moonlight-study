import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Desktop-platform helpers for the native, theme-colored title bar.
///
/// macOS: the traffic-light strip is a real, separate native title bar above
/// the window content (see `macos/Runner/MainFlutterWindow.swift`); its
/// background follows the app theme via [setWindowBackgroundColor].
abstract final class DesktopWindow {
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  static bool get isWindowsOrLinux => isDesktop && !isMacOS;

  /// Height of the Flutter-drawn title bar on platforms without a native
  /// themed strip (Windows/Linux). macOS uses the native strip instead.
  static double get titleBarHeight => isMacOS ? 0 : 40;

  /// Horizontal room reserved on the left of the Flutter-drawn bar for
  /// window controls. Only relevant on Windows/Linux.
  static double get trafficLightInset => 0;

  /// Whether the current platform needs Flutter-drawn window controls
  /// (macOS shows native traffic lights, so we don't draw our own).
  static bool get usesNativeWindowControls => isMacOS;

  static const _channel = MethodChannel('com.moonlightstudy/window');

  /// Keeps the native macOS title-bar strip in sync with the app theme.
  /// Fire-and-forget: failures are swallowed (the strip just keeps its last
  /// color); never let them crash the widget tree.
  static void setWindowBackgroundColor(Color color) {
    if (!isMacOS) return;
    unawaited(_channel.invokeMethod<void>('setWindowBackground', {
      'r': (color.r * 255.0).round() & 0xff,
      'g': (color.g * 255.0).round() & 0xff,
      'b': (color.b * 255.0).round() & 0xff,
      'a': (color.a * 255.0).round() & 0xff,
    }).catchError((_) {}));
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Desktop-platform helpers for the frameless themed title bar.
abstract final class DesktopWindow {
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Height of the app's custom title bar (separate row on top of the UI).
  static double get titleBarHeight => isMacOS ? 44 : 40;

  /// Horizontal room reserved on the left of the title bar for the native
  /// macOS traffic-light buttons.
  static double get trafficLightInset => isMacOS ? 82 : 0;

  /// Whether the current platform uses native window controls (macOS shows
  /// traffic lights, so we don't draw our own).
  static bool get usesNativeWindowControls => isMacOS;
}
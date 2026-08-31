import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode override. Defaults to dark (midnight espresso).
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, bool>(ThemeModeNotifier.new);

/// Holds whether dark (midnight espresso) mode is active.
class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;

  void set(bool value) => state = value;
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_companion/core/settings/settings_storage.dart';
import 'package:study_companion/study/pomodoro.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

void main() {
  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [settingsProvider.overrideWith(_FakeSettings.new)],
    );
  }

  test('defaults to a 25 minute focus phase', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(pomodoroProvider);
    expect(state.phase, PomodoroPhase.focus);
    expect(state.isFocus, true);
    expect(state.phaseLabel, 'Focus');
    expect(state.label, '25:00');
    expect(state.running, false);
  });

  test('skip moves focus -> break -> focus', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pomodoroProvider.notifier);

    notifier.skip();
    var state = container.read(pomodoroProvider);
    expect(state.phase, PomodoroPhase.rest);
    expect(state.label, '05:00');

    notifier.skip();
    state = container.read(pomodoroProvider);
    expect(state.phase, PomodoroPhase.focus);
    expect(state.label, '25:00');
  });

  test('skip keeps a running timer running', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pomodoroProvider.notifier);

    notifier.start();
    expect(container.read(pomodoroProvider).running, true);

    notifier.skip();
    final afterFocus = container.read(pomodoroProvider);
    expect(afterFocus.phase, PomodoroPhase.rest);
    expect(afterFocus.running, true);

    notifier.pause();
    notifier.skip();
    final afterPausedBreak = container.read(pomodoroProvider);
    expect(afterPausedBreak.phase, PomodoroPhase.focus);
    expect(afterPausedBreak.running, false);
  });

  test('reset returns to a fresh focus phase', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pomodoroProvider.notifier);

    notifier.skip();
    notifier.start();
    notifier.reset();
    final state = container.read(pomodoroProvider);
    expect(state.phase, PomodoroPhase.focus);
    expect(state.label, '25:00');
    expect(state.running, false);
  });
}
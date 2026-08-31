import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_storage.dart';

/// The active timer section: deep-focus work or a short break.
enum PomodoroPhase { focus, rest }

/// A real pomodoro countdown driving the dashboard hero card and lofi.
///
/// Focus runs for [AppSettings.pomodoroMinutes] (default 25), then the timer
/// automatically switches to a 5-minute break, then back to focus (loop).
class PomodoroState {
  const PomodoroState({
    this.phase = PomodoroPhase.focus,
    this.secondsLeft = 25 * 60,
    this.totalSeconds = 25 * 60,
    this.running = false,
  });

  final PomodoroPhase phase;
  final int secondsLeft;
  final int totalSeconds;
  final bool running;

  bool get isFocus => phase == PomodoroPhase.focus;
  String get phaseLabel => isFocus ? 'Focus' : 'Break';
  double get fraction => secondsLeft / totalSeconds;

  /// A session the user has started — still shown after pausing (secondsLeft
  /// only equals totalSeconds before the session has ever run).
  bool get isActive => running || secondsLeft < totalSeconds;

  String get label {
    final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PomodoroState copyWith({
    int? secondsLeft,
    bool? running,
  }) =>
      PomodoroState(
        phase: phase,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        totalSeconds: totalSeconds,
        running: running ?? this.running,
      );
}

final pomodoroProvider =
    NotifierProvider<PomodoroNotifier, PomodoroState>(PomodoroNotifier.new);

class PomodoroNotifier extends Notifier<PomodoroState> {
  static const int breakMinutes = 5;

  Timer? _timer;

  int get _focusSeconds {
    final minutes = ref.read(settingsProvider).value?.pomodoroMinutes ?? 25;
    return minutes * 60;
  }

  @override
  PomodoroState build() {
    ref.onDispose(() => _timer?.cancel());
    final focus = _focusSeconds;
    return PomodoroState(secondsLeft: focus, totalSeconds: focus);
  }

  void start() {
    if (state.running) return;
    _restartTimer();
    state = state.copyWith(running: true);
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(running: false);
  }

  void toggle() => state.running ? pause() : start();

  void reset() {
    _timer?.cancel();
    _timer = null;
    final focus = _focusSeconds;
    state = PomodoroState(secondsLeft: focus, totalSeconds: focus);
  }

  /// Skips the current phase immediately: focus → break, break → focus.
  ///
  /// Keeps the timer in its current running state (a paused skip stays
  /// paused, a running session keeps counting).
  void skip() {
    final wasRunning = state.running;
    _timer?.cancel();
    _timer = null;
    if (state.phase == PomodoroPhase.focus) {
      final total = breakMinutes * 60;
      state = PomodoroState(
        phase: PomodoroPhase.rest,
        secondsLeft: total,
        totalSeconds: total,
        running: wasRunning,
      );
    } else {
      final total = _focusSeconds;
      state = PomodoroState(
        phase: PomodoroPhase.focus,
        secondsLeft: total,
        totalSeconds: total,
        running: wasRunning,
      );
    }
    if (wasRunning) _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.secondsLeft <= 1) {
      // Phase finished → advance to the other phase and keep looping.
      _timer?.cancel();
      _timer = null;
      _advance();
      return;
    }
    state = state.copyWith(secondsLeft: state.secondsLeft - 1);
  }

  void _advance() {
    if (state.phase == PomodoroPhase.focus) {
      final total = breakMinutes * 60;
      state = PomodoroState(
        phase: PomodoroPhase.rest,
        secondsLeft: total,
        totalSeconds: total,
        running: true,
      );
    } else {
      final total = _focusSeconds;
      state = PomodoroState(
        phase: PomodoroPhase.focus,
        secondsLeft: total,
        totalSeconds: total,
        running: true,
      );
    }
    _restartTimer();
  }
}
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A lightweight state holder for the lofi ambience player.
///
/// The player itself is wired in Phase 1 to bundled royalty-free loops
/// under `assets/audio/`. This provider exposes the current playing state
/// and the selected atmosphere so the UI can react.
class AmbiState {
  const AmbiState({
    this.isPlaying = false,
    this.atmosphere = 'Lofi Focus',
    this.volume = 0.65,
  });

  final bool isPlaying;
  final String atmosphere;
  final double volume;

  AmbiState copyWith({
    bool? isPlaying,
    String? atmosphere,
    double? volume,
  }) =>
      AmbiState(
        isPlaying: isPlaying ?? this.isPlaying,
        atmosphere: atmosphere ?? this.atmosphere,
        volume: volume ?? this.volume,
      );
}

final ambienceProvider =
    NotifierProvider<AmbienceNotifier, AmbiState>(AmbienceNotifier.new);

class AmbienceNotifier extends Notifier<AmbiState> {
  static const _atmospheres = <String>[
    'Lofi Focus',
    'Rainy Café',
    'Vinyl Stacks',
  ];

  @override
  AmbiState build() => const AmbiState();

  void toggle() => state = state.copyWith(isPlaying: !state.isPlaying);

  void stop() => state = state.copyWith(isPlaying: false);

  void setVolume(double v) => state = state.copyWith(volume: v.clamp(0.0, 1.0));

  void rotate() {
    final next = (_atmospheres.indexOf(state.atmosphere) + 1) %
        _atmospheres.length;
    state = state.copyWith(atmosphere: _atmospheres[next]);
  }
}

/// Helper that drives a simple animated "now playing" vinyl indicator.
class PlayerGlyphModel extends ChangeNotifier {
  double turns = 0;
  Timer? _timer;
  bool _playing = false;

  bool get playing => _playing;

  void setPlaying(bool playing) {
    if (_playing == playing) return;
    _playing = playing;
    if (playing) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
        turns += 0.02;
        notifyListeners();
      });
    } else {
      _timer?.cancel();
      _timer = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
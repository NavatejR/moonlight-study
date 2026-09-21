import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../logging/app_logger.dart';
import '../settings/settings_storage.dart';

/// What is currently playing in the app-wide music player.
class NowPlaying {
  const NowPlaying({
    this.queue = const [],
    this.index = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
  });

  final List<String> queue; // track paths
  final int index;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;

  String? get currentPath => index >= 0 && index < queue.length ? queue[index] : null;
  bool get hasTrack => currentPath != null;
}

/// App-wide music player built on just_audio. Queue is a list of local file
/// paths; the player drives a single [AudioPlayer].
class MusicPlayer {
  MusicPlayer({required this.ref}) {
    _player = AudioPlayer();
    _subscriptions
      ..add(_player.positionStream.listen((pos) => _emitPlaying()))
      ..add(_player.durationStream.listen((d) => _emitPlaying()))
      ..add(_player.playerStateStream.listen((state) {
        _playing = state.playing;
        _emitPlaying();
      }))
      ..add(_player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _next();
      }));
  }

  final Ref ref;
  late final AudioPlayer _player;
  final List<StreamSubscription> _subscriptions = [];

  List<String> _queue = const [];
  int _index = -1;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _volume = 0.65;

  StreamController<NowPlaying>? _controller;

  Stream<NowPlaying> watch() {
    _controller ??= StreamController.broadcast();
    return _controller!.stream;
  }

  /// Loads [paths] as the queue and starts playing the first track.
  Future<void> playQueue(List<String> paths, {int startAt = 0}) async {
    if (paths.isEmpty) return;
    _queue = paths;
    _index = startAt.clamp(0, paths.length - 1);
    await _loadCurrent();
    await _player.play();
  }

  /// Appends/replaces the queue's items after the current with [paths].
  Future<void> enqueue(List<String> paths) async {
    _queue = [..._queue, ...paths];
    _emitPlaying();
  }

  Future<void> play() async {
    if (_queue.isEmpty) return;
    if (_player.playing) return;
    await _player.play();
    _emitPlaying();
  }

  Future<void> pause() => _player.pause();

  Future<void> toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await play();
    }
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  double get volume => _volume;

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_index + 1 < _queue.length) {
      _index += 1;
      await _loadCurrent();
      await _player.play();
    } else {
      await _player.pause();
      _playing = false;
      _emitPlaying();
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_position > const Duration(seconds: 3)) {
      return _player.seek(Duration.zero);
    }
    if (_index > 0) {
      _index -= 1;
      await _loadCurrent();
      await _player.play();
    }
  }

  Future<void> _loadCurrent() async {
    final path = _queue[_index];
    try {
      _duration = await _player.setFilePath(path);
    } catch (e, stackTrace) {
      logger.warning('Failed to load audio track: $path', error: e, stackTrace: stackTrace);
      _duration = null;
    }
    _position = Duration.zero;
    _emitPlaying();
  }

  void _emitPlaying() {
    _position = _player.position;
    _duration = _duration ?? _player.duration;
    _controller?.add(NowPlaying(
      queue: _queue,
      index: _index,
      isPlaying: _player.playing,
      position: _position,
      duration: _duration,
    ));
  }

  Future<void> _next() => next();

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    await _controller?.close();
  }
}

final musicPlayerProvider = Provider<MusicPlayer>((ref) {
  final player = MusicPlayer(ref: ref);
  ref.onDispose(player.dispose);
  // Apply persisted default volume.
  ref.listen(settingsProvider, (_, next) {
    if (next.hasValue) {
      player.setVolume(next.value!.volume);
    }
  }, fireImmediately: true);
  return player;
});

/// Current player state for the UI.
final nowPlayingProvider = StreamProvider<NowPlaying>((ref) {
  final player = ref.watch(musicPlayerProvider);
  return player.watch();
});
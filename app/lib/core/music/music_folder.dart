import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _channel = MethodChannel('moonlight/music_folder');

/// Bridge to the native macOS security-scoped folder picker.
class MusicFolderBridge {
  const MusicFolderBridge();

  /// Opens the folder picker; returns the chosen path ('' if cancelled).
  Future<String> pickFolder() async {
    try {
      final path = await _channel.invokeMethod<String>('pickFolder');
      return path ?? '';
    } on PlatformException {
      return '';
    }
  }

  /// Resolves the persisted bookmark on startup; '' if none set.
  Future<String> resolveFolder() async {
    try {
      final path = await _channel.invokeMethod<String>('resolveFolder');
      return path ?? '';
    } on PlatformException {
      return '';
    }
  }
}

/// The resolved music folder path (persisted across launches).
final musicFolderProvider =
    FutureProvider<String>((ref) => const MusicFolderBridge().resolveFolder());

final musicFolderBridgeProvider =
    Provider<MusicFolderBridge>((ref) => const MusicFolderBridge());
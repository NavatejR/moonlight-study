import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import '../settings/settings_storage.dart';

/// A music track discovered on disk.
class MusicTrack {
  const MusicTrack({
    required this.path,
    required this.title,
    this.artist,
    this.duration,
  });

  final String path;
  final String title;
  final String? artist;
  final Duration? duration;

  MusicTrack copyWith({Duration? duration}) => MusicTrack(
        path: path,
        title: title,
        artist: artist,
        duration: duration ?? this.duration,
      );
}

const trackExtensions = {'mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus'};

/// Scans the configured music folder for playable tracks.
class MusicLibraryService {
  MusicLibraryService();

  Future<List<MusicTrack>> scanFolder(String folderPath) async {
    final root = Directory(folderPath);
    if (!await root.exists()) return const [];
    final files = <FileSystemEntity>[];
    final stack = <Directory>[root];
    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Directory) {
            stack.add(entity);
          } else if (_isTrack(entity)) {
            files.add(entity);
          }
        }
      } on FileSystemException {
        // Skip unreadable subfolders.
      }
    }

    final tracks = <MusicTrack>[];
    for (final file in files) {
      final base = p.basenameWithoutExtension(file.path);
      final title = _fancyTitle(base);
      final duration = await _probe(file.path);
      tracks.add(MusicTrack(path: file.path, title: title, duration: duration));
    }
    tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return tracks;
  }

  bool _isTrack(FileSystemEntity entity) {
    if (entity is! File) return false;
    final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
    return trackExtensions.contains(ext);
  }

  Future<Duration?> _probe(String path) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(path);
      return duration;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }

  String _fancyTitle(String base) {
    final cleaned = base.replaceFirst(RegExp(r'^\s*\d+\s*[-_.]\s*'), '');
    return cleaned.trim();
  }
}

/// Combination of a playlist and its tracks.
class PlaylistView {
  const PlaylistView({required this.playlist, required this.tracks});

  final Playlist playlist;
  final List<PlaylistTrack> tracks;
}

final musicLibraryProvider = Provider<MusicLibraryService>((ref) {
  return MusicLibraryService();
});

final playlistsProvider = StreamProvider<List<Playlist>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final rows = await (db.select(db.playlists)
        ..orderBy([(t) => OrderingTerm.asc(t.title)]))
      .get();
  yield rows;
});

/// Tracks for all playlists, plus the "All tracks" folder scan combined.
final libraryTracksProvider = FutureProvider<List<MusicTrack>>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final folder = settings.musicFolder;
  if (folder.isEmpty) return const [];
  return ref.read(musicLibraryProvider).scanFolder(folder);
});

final playlistTracksProvider = FutureProvider.family<List<PlaylistTrack>, int>(
  (ref, playlistId) async {
    final db = ref.watch(appDatabaseProvider);
    final rows = await (db.select(db.playlistTracks)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .get();
    return rows;
  },
);
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' hide Column;

import '../../core/db/app_database.dart';
import '../../core/music/music_folder.dart';
import '../../core/music/music_library.dart';
import '../../core/music/player_controller.dart';
import '../../core/settings/settings_storage.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/vinyldisc.dart';
import '../../shared/widgets/coffee_card.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: _PlaylistColumn(
              playlists: playlists.value ?? const [],
              hasFolder: settings.value?.musicFolder.isNotEmpty ?? false,
              musicFolder: settings.value?.musicFolder ?? '',
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _TracksView()),
        ],
      ),
    );
  }
}

class _PlaylistColumn extends ConsumerWidget {
  const _PlaylistColumn({
    required this.playlists,
    required this.hasFolder,
    required this.musicFolder,
  });

  final List<Playlist> playlists;
  final bool hasFolder;
  final String musicFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPlaylistProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Text('Music', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                onPressed: () => _createPlaylist(context, ref),
                icon: const Icon(Icons.add_rounded, color: CoffeeColors.caramel),
                tooltip: 'New playlist',
              ),
            ],
          ),
        ),
        if (!hasFolder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: CoffeeCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No music folder yet',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick a folder of tracks in Settings → Player.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: () => _pickFolder(context, ref),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Choose folder'),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              musicFolder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _PlaylistTile(
          label: 'All tracks',
          icon: Icons.queue_music_rounded,
          selected: selected == -1,
          onTap: () => ref.read(selectedPlaylistProvider.notifier).select(-1),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final playlist in playlists)
                _PlaylistTile(
                  label: playlist.title,
                  icon: Icons.playlist_play_rounded,
                  selected: selected == playlist.id,
                  onTap: () => ref
                      .read(selectedPlaylistProvider.notifier)
                      .select(playlist.id),
                  onDelete: () => _deletePlaylist(context, ref, playlist.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(musicFolderBridgeProvider).pickFolder();
    if (path.isNotEmpty) {
      await ref.read(settingsProvider.notifier).setMusicFolder(path);
      ref.invalidate(libraryTracksProvider);
    }
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final db = ref.read(appDatabaseProvider);
    await db.into(db.playlists).insert(PlaylistsCompanion.insert(title: name));
  }

  Future<void> _deletePlaylist(
      BuildContext context, WidgetRef ref, int id) async {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.playlistTracks)..where((t) => t.playlistId.equals(id))).go();
    await (db.delete(db.playlists)..where((t) => t.id.equals(id))).go();
    ref.read(selectedPlaylistProvider.notifier).select(-1);
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        size: 20,
        color: selected ? CoffeeColors.caramel : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? CoffeeColors.caramel : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selected: selected,
      onTap: onTap,
      trailing: onDelete == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              onPressed: onDelete,
            ),
    );
  }
}

class _TracksView extends ConsumerWidget {
  const _TracksView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPlaylistProvider);
    final allTracks = ref.watch(libraryTracksProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected == -1 ? 'All tracks' : 'Playlist',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (selected != -1)
                _AddToPlaylistButton(playlistId: selected),
            ],
          ),
        ),
        Expanded(
          child: selected == -1
              ? _TrackList(
                  tracks: allTracks.value ?? const [],
                  loading: allTracks.isLoading,
                )
              : _PlaylistTrackList(playlistId: selected),
        ),
        const _MiniPlayerBar(),
      ],
    );
  }
}

class _AddToPlaylistButton extends ConsumerWidget {
  const _AddToPlaylistButton({required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTracks = ref.watch(libraryTracksProvider);
    final current = ref.watch(playlistTracksProvider(playlistId));

    return IconButton.filledTonal(
      onPressed: () async {
        final tracks = allTracks.value ?? const [];
        final existing = current.value ?? const [];
        final existingPaths = existing.map((t) => t.path).toSet();
        final newTracks = tracks.where((t) => !existingPaths.contains(t.path)).toList();
        if (newTracks.isEmpty) return;

        final db = ref.read(appDatabaseProvider);
        final baseOrder = existing.length;
        for (var i = 0; i < newTracks.length; i++) {
          await db.into(db.playlistTracks).insert(
                PlaylistTracksCompanion.insert(
                  playlistId: playlistId,
                  path: newTracks[i].path,
                  title: newTracks[i].title,
                  durationMs: Value(newTracks[i].duration?.inMilliseconds),
                  order: Value(baseOrder + i),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      },
      tooltip: 'Add all songs to playlist',
      icon: const Icon(Icons.playlist_add_rounded, size: 20),
    );
  }
}

class _PlaylistTrackList extends ConsumerWidget {
  const _PlaylistTrackList({required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(playlistTracksProvider(playlistId));
    final tracks = rows.value ?? const [];

    if (rows.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tracks.isEmpty) {
      return const _EmptyTracks();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        return _TrackRow(
          title: track.title,
          subtitle: p.basename(p.dirname(track.path)),
          onTap: () async {
            final player = ref.read(musicPlayerProvider);
            await player.playQueue([
              for (final t in tracks) t.path,
            ], startAt: i);
          },
          onRemove: () async {
            final db = ref.read(appDatabaseProvider);
            await (db.delete(db.playlistTracks)
                  ..where((t) =>
                      t.playlistId.equals(playlistId) &
                      t.path.equals(track.path)))
                .go();
            ref.invalidate(playlistTracksProvider(playlistId));
          },
        );
      },
    );
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({required this.tracks, required this.loading});

  final List<MusicTrack> tracks;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tracks.isEmpty) {
      return const _EmptyTracks();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        return _TrackRow(
          title: track.title,
          subtitle: p.dirname(track.path),
          onTap: () async {
            final player = ref.read(musicPlayerProvider);
            await player.playQueue(
              [for (final t in tracks) t.path],
              startAt: i,
            );
          },
        );
      },
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onRemove,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.music_note_rounded, color: CoffeeColors.caramel),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
      onTap: onTap,
      trailing: onRemove == null
          ? null
          : IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
              onPressed: onRemove,
            ),
    );
  }
}

class _EmptyTracks extends StatelessWidget {
  const _EmptyTracks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_off_rounded, size: 40, color: CoffeeColors.cacao),
          const SizedBox(height: 10),
          const Text('No tracks yet'),
          const SizedBox(height: 4),
          Text(
            'Pick a music folder in Settings → Player\nthen come back here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final np = ref.watch(nowPlayingProvider).value;
    final track = p.basenameWithoutExtension(
        np?.currentPath ?? '');
    final duration = np?.duration ?? Duration.zero;
    final position = np?.position ?? Duration.zero;
    final fraction = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        color: CoffeeColors.espresso,
        border: Border.all(color: CoffeeColors.espresso),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (np?.hasTrack ?? false) ...[
            Slider(
              value: fraction,
              activeColor: CoffeeColors.caramel,
              onChanged: (v) => ref
                  .read(musicPlayerProvider)
                  .seek(duration * v),
            ),
            Row(
              children: [
                VinylDisc(size: 56, spinning: np?.isPlaying ?? false),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.isEmpty ? 'Nothing playing' : track,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CoffeeColors.foam,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(musicPlayerProvider).previous(),
                  icon: const Icon(Icons.skip_previous_rounded, color: CoffeeColors.foam),
                ),
                IconButton.filled(
                  onPressed: () => ref.read(musicPlayerProvider).toggle(),
                  style: IconButton.styleFrom(
                    backgroundColor: CoffeeColors.caramel,
                  ),
                  icon: Icon(
                    np?.isPlaying == true
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: CoffeeColors.espresso,
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(musicPlayerProvider).next(),
                  icon: const Icon(Icons.skip_next_rounded, color: CoffeeColors.foam),
                ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Pick a track to start studying with music.',
                style: TextStyle(color: Colors.white38, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

final selectedPlaylistProvider =
    NotifierProvider<_SelectedPlaylistNotifier, int>(_SelectedPlaylistNotifier.new);

class _SelectedPlaylistNotifier extends Notifier<int> {
  @override
  int build() => -1;

  void select(int id) => state = id;
}
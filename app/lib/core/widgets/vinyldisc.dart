import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../music/music_library.dart';
import '../music/player_controller.dart';
import '../settings/settings_storage.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';

/// A rotating vinyl record used as the "now playing" ambience widget.
class VinylDisc extends StatefulWidget {
  const VinylDisc({
    super.key,
    this.size = 88,
    this.spinning = false,
  });

  final double size;
  final bool spinning;

  @override
  State<VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<VinylDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(VinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _VinylPainter(),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Disc body
    final body = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF2A211B), CoffeeColors.vinyl],
        stops: [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, body);

    // Grooves
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(center, radius * (0.35 + i * 0.06), groove);
    }

    // Label
    canvas.drawCircle(
      center,
      radius * 0.32,
      Paint()..color = CoffeeColors.vinylLabel,
    );
    canvas.drawCircle(
      center,
      radius * 0.1,
      Paint()..color = CoffeeColors.warmDark,
    );
    // Label sheen
    canvas.drawCircle(
      center + Offset(-radius * 0.08, -radius * 0.08),
      radius * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: center + Offset(-radius * 0.08, -radius * 0.08),
          radius: radius * 0.22,
        )),
    );
  }

  @override
  bool shouldRepaint(_VinylPainter oldDelegate) => false;
}

/// Small reusable vinyl "now playing" tile for the shell footer.
class NowPlayingTile extends ConsumerWidget {
  const NowPlayingTile({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final np = ref.watch(nowPlayingProvider).value;
    final hasTrack = np?.hasTrack ?? false;
    final isPlaying = np?.isPlaying ?? false;
    final title = np?.currentPath == null
        ? 'Lofi Focus'
        : p.basenameWithoutExtension(np!.currentPath!);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CoffeeColors.mocha.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                VinylDisc(size: 40, spinning: isPlaying),
                const SizedBox(width: 10),
                Flexible(child: _TrackNameCompact(title: title)),
              ],
            )
          else ...[
            VinylDisc(size: 72, spinning: isPlaying),
            const SizedBox(height: 12),
            _TrackName(title: title, hasTrack: hasTrack),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  color: CoffeeColors.foam,
                  tooltip: hasTrack ? null : 'Add a music folder in Music',
                  onPressed: () async {
                    final player = ref.read(musicPlayerProvider);
                    if (hasTrack) {
                      await player.toggle();
                      return;
                    }
                    final settings = ref.read(settingsProvider).value;
                    if (settings != null &&
                        settings.musicFolder.isNotEmpty) {
                      final tracks =
                          await ref.read(libraryTracksProvider.future);
                      if (tracks.isNotEmpty) {
                        await player.playQueue(
                          tracks.map((t) => t.path).toList(),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.skip_next_rounded),
                  color: CoffeeColors.foam,
                  tooltip: hasTrack ? 'Next track' : null,
                  onPressed: (hasTrack && (np?.queue.length ?? 0) > 1)
                      ? () => ref.read(musicPlayerProvider).next()
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackName extends StatelessWidget {
  const _TrackName({required this.title, required this.hasTrack});

  final String title;
  final bool hasTrack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CoffeeColors.foam,
            fontSize: 12,
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          hasTrack ? 'On the turntable' : 'Add a music folder in Music',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

class _TrackNameCompact extends StatelessWidget {
  const _TrackNameCompact({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: CoffeeColors.foam,
        fontSize: 12,
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
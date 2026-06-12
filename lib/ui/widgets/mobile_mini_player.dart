import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'cover_art.dart';

/// Compact mini player for the mobile shell.
///
/// Sticks above the `NavigationBar`. If nothing is playing, it collapses
/// to zero height (takes up no space). Tapping any part except the
/// play/next buttons opens [NowPlayingScreen].
class MobileMiniPlayer extends ConsumerWidget {
  const MobileMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playbackSnapshotProvider).valueOrNull;
    final track = snap?.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final controller = ref.watch(playerControllerProvider);
    final position = snap?.position ?? Duration.zero;
    final duration = snap?.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: const Color(0xFF202020),
      child: InkWell(
        onTap: () => openNowPlayingScreen(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CoverArt(
                      coverPath: track.coverPath,
                      size: 44,
                      borderRadius: BorderRadius.circular(8),
                      fallbackIcon: Icons.music_note,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      (snap?.playing ?? false)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: controller.playPause,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      size: 26,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: controller.next,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Thin, non-interactive progress indicator (tapping below
              // opens Now Playing, which has a full-size seek bar).
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

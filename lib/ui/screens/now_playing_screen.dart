import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/browse_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/lyrics_offset_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/lyrics/lrc_parser.dart';
import '../../services/player_service.dart';
import '../utils/duration_format.dart';
import '../widgets/cover_art.dart';
import '../widgets/flat_track_shape.dart';
import '../widgets/lyrics_side_panel.dart';
import '../widgets/track_actions.dart';

/// Opens the fullscreen Now Playing screen on top of the current route.
void openNowPlayingScreen(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(playbackSnapshotProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: snapAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
          data: (snap) {
            final track = snap.currentTrack;
            if (track == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.playerNothingPlaying,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.commonClose),
                    ),
                  ],
                ),
              );
            }
            return _NowPlayingContent(track: track, snap: snap);
          },
        ),
      ),
    );
  }
}

class _NowPlayingContent extends ConsumerStatefulWidget {
  final Track track;
  final PlaybackSnapshot snap;
  const _NowPlayingContent({required this.track, required this.snap});

  @override
  ConsumerState<_NowPlayingContent> createState() =>
      _NowPlayingContentState();
}

class _NowPlayingContentState extends ConsumerState<_NowPlayingContent> {
  bool _lyricsExpanded = false;

  Track get track => widget.track;
  PlaybackSnapshot get snap => widget.snap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _lyricsExpanded
          ? _buildExpanded(context)
          : _buildNormal(context),
    );
  }

  Widget _buildNormal(BuildContext context) {
    final controller = ref.watch(playerControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isFav = track.id == null
        ? track.isFavorite
        : ref.watch(isTrackFavoriteProvider(track.id!)).valueOrNull ??
            track.isFavorite;
    final buffering = snap.buffering;
    final isLoading = buffering && snap.duration == Duration.zero;

    return Column(
      key: const ValueKey('np-normal'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              _CollapsePillButton(
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.lyrics_outlined),
                iconSize: 24,
                tooltip: l10n.playerLyricsTooltip,
                onPressed: () => setState(() => _lyricsExpanded = true),
              ),
              Builder(
                builder: (innerCtx) => IconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  iconSize: 24,
                  tooltip: l10n.playerActionsTooltip,
                  onPressed: () => showTrackActionsMenu(
                    innerCtx,
                    ref,
                    track,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final coverSize = constraints.maxWidth.clamp(220.0, 480.0);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: CoverArt(
                              coverPath: track.coverPath,
                              size: coverSize,
                              borderRadius: BorderRadius.circular(24),
                              fallbackIcon: Icons.music_note,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          track.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _FullscreenSeekBar(
                          position: snap.position,
                          duration: snap.duration,
                          buffered: snap.bufferedPosition,
                          onSeek: controller.seek,
                        ),
                        const SizedBox(height: 20),
                        _FullscreenControls(
                          playing: snap.playing,
                          isLoading: isLoading,
                          repeatMode: snap.repeatMode,
                          isFavorite: isFav,
                          canFavorite: track.id != null,
                          onToggleFavorite: track.id == null
                              ? null
                              : () => ref
                                  .read(favoritesNotifierProvider.notifier)
                                  .toggleTrack(track.id!),
                          onPrevious: controller.previous,
                          onPlayPause: controller.playPause,
                          onNext: controller.next,
                          onCycleRepeat: controller.cycleRepeat,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(playerControllerProvider);
    final isFav = track.id == null
        ? track.isFavorite
        : ref.watch(isTrackFavoriteProvider(track.id!)).valueOrNull ??
            track.isFavorite;
    final isLoading = snap.buffering && snap.duration == Duration.zero;
    return Stack(
      key: const ValueKey('np-expanded'),
      children: [
        Row(
          children: [
            // Left column: cover, metadata, thin progress bar.
            // Everything is constrained to the cover's width so the
            // slider doesn't stretch across the whole column.
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 12, 24),
                child: LayoutBuilder(builder: (ctx, c) {
                  final coverSize = c.maxWidth.clamp(180.0, 480.0).toDouble();
                  return Center(
                    child: SizedBox(
                      width: coverSize,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CoverWithHoverControls(
                            coverPath: track.coverPath,
                            size: coverSize,
                            playing: snap.playing,
                            isLoading: isLoading,
                            repeatMode: snap.repeatMode,
                            isFavorite: isFav,
                            canFavorite: track.id != null,
                            onToggleFavorite: track.id == null
                                ? null
                                : () => ref
                                    .read(favoritesNotifierProvider.notifier)
                                    .toggleTrack(track.id!),
                            onPrevious: controller.previous,
                            onPlayPause: controller.playPause,
                            onNext: controller.next,
                            onCycleRepeat: controller.cycleRepeat,
                            onMore: () => showTrackActionsMenu(
                              context,
                              ref,
                              track,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            track.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.displayArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _SlimSeekBar(
                            position: snap.position,
                            duration: snap.duration,
                            onSeek: controller.seek,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Right column: lyrics, fade at top and bottom.
            // `const` is critical — otherwise the pane is recreated on
            // every position tick (60Hz), and the ListView/itemBuilder/
            // lines get rebuilt too. The pane reads all the data it needs
            // through providers.
            const Expanded(
              flex: 3,
              child: _ExpandedLyricsPane(),
            ),
          ],
        ),
        // Top right corner: "LRCLib sync" + "collapse".
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundSyncButton(track: track),
              const SizedBox(width: 8),
              _RoundCollapseButton(
                onTap: () => setState(() => _lyricsExpanded = false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cover art in expanded mode with a player-controls overlay that appears
/// on mouse hover. The overlay layout mirrors the regular Now Playing
/// screen but is more compact: a top row (prev/play/next) and a bottom
/// row (more/repeat/favorite). Controls fade out after a short timeout
/// once the mouse leaves; on touch the overlay is always visible.
class _CoverWithHoverControls extends StatefulWidget {
  final String? coverPath;
  final double size;
  final bool playing;
  final bool isLoading;
  final RepeatMode repeatMode;
  final bool isFavorite;
  final bool canFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onCycleRepeat;
  final VoidCallback onMore;

  const _CoverWithHoverControls({
    required this.coverPath,
    required this.size,
    required this.playing,
    required this.isLoading,
    required this.repeatMode,
    required this.isFavorite,
    required this.canFavorite,
    required this.onToggleFavorite,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onCycleRepeat,
    required this.onMore,
  });

  @override
  State<_CoverWithHoverControls> createState() =>
      _CoverWithHoverControlsState();
}

class _CoverWithHoverControlsState extends State<_CoverWithHoverControls> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final showControls = _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CoverArt(
              coverPath: widget.coverPath,
              size: widget.size,
              borderRadius: BorderRadius.circular(24),
              fallbackIcon: Icons.music_note,
            ),
            // Scrim — dims the cover so the controls are readable.
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: showControls ? 1.0 : 0.0,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !showControls,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top: empty on the left, to leave room for the
                        // top control row centered above.
                        const SizedBox.shrink(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _OverlayRoundButton(
                              icon: Icons.skip_previous_rounded,
                              tooltip: l10n.playerPreviousTooltip,
                              onPressed: widget.onPrevious,
                            ),
                            const SizedBox(width: 8),
                            _OverlayBigPlayPause(
                              playing: widget.playing,
                              loading: widget.isLoading,
                              onPressed: widget.onPlayPause,
                              accent: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            _OverlayRoundButton(
                              icon: Icons.skip_next_rounded,
                              tooltip: l10n.playerNextTooltip,
                              onPressed: widget.onNext,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _OverlayRoundButton(
                              icon: Icons.more_horiz_rounded,
                              tooltip: l10n.playerActionsTooltip,
                              onPressed: widget.onMore,
                            ),
                            _OverlayRoundButton(
                              icon: widget.repeatMode == RepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              tooltip: switch (widget.repeatMode) {
                                RepeatMode.off => l10n.playerRepeatOff,
                                RepeatMode.all => l10n.playerRepeatAll,
                                RepeatMode.one => l10n.playerRepeatOne,
                              },
                              active: widget.repeatMode != RepeatMode.off,
                              onPressed: widget.onCycleRepeat,
                            ),
                            _OverlayRoundButton(
                              icon: widget.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              tooltip: widget.isFavorite
                                  ? l10n.playerRemoveFavorite
                                  : l10n.playerAddFavorite,
                              activeColor: Colors.redAccent,
                              active: widget.isFavorite,
                              onPressed: widget.canFavorite
                                  ? widget.onToggleFavorite
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final Color? activeColor;
  const _OverlayRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final iconColor = active
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : AppColors.textPrimary;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                icon,
                color: disabled
                    ? AppColors.textPrimary.withValues(alpha: 0.35)
                    : iconColor,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayBigPlayPause extends StatelessWidget {
  final bool playing;
  final bool loading;
  final Color accent;
  final VoidCallback onPressed;
  const _OverlayBigPlayPause({
    required this.playing,
    required this.loading,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.black),
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 34,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final Future<void> Function(Duration) onSeek;
  const _FullscreenSeekBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
  });

  @override
  State<_FullscreenSeekBar> createState() => _FullscreenSeekBarState();
}

class _FullscreenSeekBarState extends State<_FullscreenSeekBar> {
  double? _dragValue;
  bool _dragging = false;

  double get _value {
    if (_dragValue != null) return _dragValue!;
    if (widget.duration.inMilliseconds == 0) return 0;
    return widget.position.inMilliseconds / widget.duration.inMilliseconds;
  }

  Duration get _displayPosition {
    if (_dragValue != null) {
      return Duration(
        milliseconds:
            (_dragValue!.clamp(0.0, 1.0) * widget.duration.inMilliseconds)
                .round(),
      );
    }
    return widget.position;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bufferedFraction = widget.duration.inMilliseconds == 0
        ? 0.0
        : (widget.buffered.inMilliseconds / widget.duration.inMilliseconds)
            .clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                  trackShape: const FlatTrackShape(),
                  activeTrackColor: _dragging
                      ? theme.colorScheme.primary
                      : AppColors.textPrimary,
                  inactiveTrackColor:
                      AppColors.textMuted.withValues(alpha: 0.4),
                  thumbColor: AppColors.textPrimary,
                  overlayColor: Colors.white.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _value.clamp(0.0, 1.0),
                  onChanged: widget.duration == Duration.zero
                      ? null
                      : (v) {
                          setState(() {
                            _dragValue = v;
                            _dragging = true;
                          });
                        },
                  onChangeEnd: (v) {
                    final pos = Duration(
                      milliseconds:
                          (v * widget.duration.inMilliseconds).round(),
                    );
                    widget.onSeek(pos);
                    setState(() {
                      _dragValue = null;
                      _dragging = false;
                    });
                  },
                ),
              ),
              IgnorePointer(
                child: SizedBox(
                  height: 4,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: bufferedFraction,
                      child: Container(color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                formatDuration(_displayPosition),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(widget.duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullscreenControls extends StatelessWidget {
  final bool playing;
  final bool isLoading;
  final RepeatMode repeatMode;
  final bool isFavorite;
  final bool canFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onCycleRepeat;
  const _FullscreenControls({
    required this.playing,
    required this.isLoading,
    required this.repeatMode,
    required this.isFavorite,
    required this.canFavorite,
    required this.onToggleFavorite,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onCycleRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PillIconButton(
          icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 30,
          color: isFavorite ? Colors.redAccent : AppColors.textSecondary,
          tooltip: isFavorite ? l10n.playerRemoveFavorite : l10n.playerAddFavorite,
          onPressed: canFavorite ? onToggleFavorite : null,
        ),
        const SizedBox(width: 12),
        _PillIconButton(
          icon: Icons.skip_previous_rounded,
          size: 32,
          color: AppColors.textPrimary,
          tooltip: l10n.playerPreviousTooltip,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 16),
        _BigPlayPauseButton(
          playing: playing,
          loading: isLoading,
          onPressed: onPlayPause,
        ),
        const SizedBox(width: 16),
        _PillIconButton(
          icon: Icons.skip_next_rounded,
          size: 32,
          color: AppColors.textPrimary,
          tooltip: l10n.playerNextTooltip,
          onPressed: onNext,
        ),
        const SizedBox(width: 24),
        _RepeatButton(mode: repeatMode, onPressed: onCycleRepeat),
      ],
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  const _PillIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      iconSize: size + 8,
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}

class _BigPlayPauseButton extends StatelessWidget {
  final bool playing;
  final bool loading;
  final VoidCallback onPressed;
  const _BigPlayPauseButton({
    required this.playing,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.black),
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 44,
                  ),
          ),
        ),
      ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  final RepeatMode mode;
final VoidCallback onPressed;
  const _RepeatButton({required this.mode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final active = mode != RepeatMode.off;
    final color = active ? theme.colorScheme.primary : AppColors.textSecondary;
    return _PillIconButton(
      icon: mode == RepeatMode.one
          ? Icons.repeat_one_rounded
          : Icons.repeat_rounded,
      color: color,
      tooltip: switch (mode) {
        RepeatMode.off => l10n.playerRepeatOff,
        RepeatMode.all => l10n.playerRepeatAll,
        RepeatMode.one => l10n.playerRepeatOne,
      },
      onPressed: onPressed,
    );
  }
}

/// Lyrics dialog content. Subscribes to the up-to-date track from the
/// database so that after a manual sync (or background enrichment via
/// Genius) the panel immediately shows the updated LRC/plain text without
/// reopening.
class LyricsDialogContent extends ConsumerWidget {
  final Track track;
  const LyricsDialogContent({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allTracksProvider);
    final fresh = track.id == null
        ? track
        : all.firstWhere(
            (t) => t.id == track.id,
            orElse: () => track,
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context)!.lyricsTitle,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white24),
        Expanded(
          child: LyricsSidePanel(
            lrcContent: fresh.lyricsLrc,
            plainLyrics: fresh.lyricsText,
            duration: fresh.duration,
            track: fresh,
          ),
        ),
      ],
    );
  }
}


class _CollapsePillButton extends StatelessWidget {
  const _CollapsePillButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13,
          color: AppColors.textPrimary,
        );
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Text(AppLocalizations.of(context)!.playerCollapse, style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round arrow button in the top right corner of expanded lyrics mode —
/// returns to the regular Now Playing view.
class _RoundCollapseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RoundCollapseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: CircleBorder(
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textPrimary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar with no thumb and no time labels — for the left
/// column in expanded mode. Tap/drag on the line seeks.
class _SlimSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Future<void> Function(Duration) onSeek;
  const _SlimSeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_SlimSeekBar> createState() => _SlimSeekBarState();
}

class _SlimSeekBarState extends State<_SlimSeekBar> {
  double? _dragFraction;

  double get _value {
    if (_dragFraction != null) return _dragFraction!.clamp(0, 1);
    if (widget.duration.inMilliseconds == 0) return 0;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  void _seekTo(double fraction) {
    final pos = Duration(
      milliseconds: (fraction * widget.duration.inMilliseconds).round(),
    );
    widget.onSeek(pos);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final width = c.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          setState(() =>
              _dragFraction = (d.localPosition.dx / width).clamp(0.0, 1.0));
        },
        onHorizontalDragUpdate: (d) {
          setState(() =>
              _dragFraction = (d.localPosition.dx / width).clamp(0.0, 1.0));
        },
        onHorizontalDragEnd: (_) {
          final f = _dragFraction;
          if (f != null) _seekTo(f);
          setState(() => _dragFraction = null);
        },
        onTapDown: (d) {
          final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
          _seekTo(f);
        },
        child: SizedBox(
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: _value,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Right column in expanded mode: either large synchronized lyrics with
/// highlighting and auto-scroll, or small plain text with scrolling
/// (if there's no LRC).
///
/// Shows a placeholder if there's no lyrics at all.
class _ExpandedLyricsPane extends ConsumerStatefulWidget {
  const _ExpandedLyricsPane();

  @override
  ConsumerState<_ExpandedLyricsPane> createState() =>
      _ExpandedLyricsPaneState();
}

class _ExpandedLyricsPaneState extends ConsumerState<_ExpandedLyricsPane> {
  final _scrollController = ScrollController();
  int? _lastCurrentIndex;

  /// Fixed line height. With a dynamic font size, lines could "jump", so
  /// each line's container has a fixed height and the text is centered
  /// inside it. The height has extra room for a large font size.
  static const double _lineExtent = 104.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// The scroll target is chosen so the center of the selected item
  /// matches the center of the viewport. Thanks to the large top/bottom
  /// padding (=viewport/2), this also works for the first/last line.
  void _scrollToCurrent(int index) {
    if (_lastCurrentIndex == index) return;
    if (!_scrollController.hasClients) return;
    final isFirstScroll = _lastCurrentIndex == null;
    _lastCurrentIndex = index;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = (index * _lineExtent).clamp(0.0, maxScroll);
    if (isFirstScroll) {
      // First scroll: do NOT use jumpTo. Empirically, jumpTo on a fresh
      // ScrollController leaves the position in a state that causes the
      // first line to visually jitter by sub-pixels (observed: scrolling
      // back and forth once makes the jitter go away). animateTo with a
      // 1ms duration runs the controller through
      // DrivenScrollActivity -> IdleScrollActivity, which is what a
      // normal scroll does, and stabilizes the position.
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read the current track via select — rebuild only happens when the
    // track changes, not on every position tick.
    final track = ref.watch(
      playbackSnapshotProvider.select((s) => s.valueOrNull?.currentTrack),
    );
    if (track == null) {
      return const SizedBox.shrink();
    }

    // Fresh track from the library — picked up immediately after
    // sync/enrichment without reopening the screen.
    final all = ref.watch(allTracksProvider);
    final fresh = track.id == null
        ? track
        : all.firstWhere(
            (t) => t.id == track.id,
            orElse: () => track,
          );

    final lrcContent = fresh.lyricsLrc;
    final plainLyrics = fresh.lyricsText;

    final lrcLines = lrcContent != null && lrcContent.isNotEmpty
        ? parseLrc(lrcContent)
        : <LrcLine>[];
    final hasLrc = lrcLines.isNotEmpty;

    if (!hasLrc) {
      final plainList = (plainLyrics ?? '')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      Widget body;
      if (plainList.isEmpty) {
        body = Center(
          child: Text(
            AppLocalizations.of(context)!.lyricsNotFound,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textMuted,
              fontSize: 15,
            ),
          ),
        );
      } else {
        body = _PlainLyricsScroll(lines: plainList);
      }
      return body;
    }

    final offsetMs = ref.watch(lyricsOffsetMsProvider);

    // currentIndex is computed via select on position — Riverpod will
    // rebuild this widget ONLY when the index actually changes. Without
    // this, the pane (and the whole ListView with its lines) would
    // rebuild 60+ times/sec, and the first line would jitter by
    // sub-pixels due to repeated Center/FittedBox/Text layout.
    final currentIndex = ref.watch(
      playbackSnapshotProvider.select<int>((async) {
        final position = async.valueOrNull?.position ?? Duration.zero;
        final lookupPos = position - Duration(milliseconds: offsetMs);
        final current = findCurrentLine(lrcLines, lookupPos);
        if (current == null) return -1;
        for (var i = 0; i < lrcLines.length; i++) {
          if (lrcLines[i] == current) return i;
        }
        return -1;
      }),
    );

    if (currentIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent(currentIndex);
      });
    }

    return LayoutBuilder(builder: (ctx, c) {
      final viewport = c.maxHeight;
      // Top/bottom padding = "half the viewport minus half a line". This
      // allows scrolling ANY line (including the first and last) exactly
      // to the center of the window — i.e. "the playing line is always
      // centered".
      final edgePad = (viewport / 2 - _lineExtent / 2).clamp(0.0, viewport);
      return ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.18, 0.82, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scrollController,
          // Without explicit physics, the default on desktop may be
          // bouncing on some Flutter versions — which causes a micro
          // "settle" of the position at the boundary (target = 0), seen
          // as jitter on the first line. ClampingScrollPhysics clamps
          // hard and doesn't bounce.
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: edgePad),
          itemCount: lrcLines.length,
          itemExtent: _lineExtent,
          itemBuilder: (ctx, i) {
            final isCurrent = i == currentIndex;
            return _ExpandedLyricLine(
              text: lrcLines[i].text,
              isCurrent: isCurrent,
            );
          },
        ),
      );
    });
  }
}

/// Round sync button in the top right corner of expanded mode.
/// Styled identically to `_RoundCollapseButton`. Triggers the LRCLib
/// flow via `PlayerController.syncLyrics`.
class _RoundSyncButton extends ConsumerStatefulWidget {
  final Track track;
  const _RoundSyncButton({required this.track});

  @override
  ConsumerState<_RoundSyncButton> createState() => _RoundSyncButtonState();
}

class _RoundSyncButtonState extends ConsumerState<_RoundSyncButton> {
  bool _running = false;

  Future<void> _run() async {
    final track = widget.track;
    if (track.id == null) return;
    final controller = ref.read(playerControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _running = true);
    String? error;
    try {
      await controller.syncLyrics(trackId: track.id!);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => _running = false);
    }
    if (error != null && mounted) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasLrc = (widget.track.lyricsLrc ?? '').trim().isNotEmpty;
    final tooltip = hasLrc ? l10n.lyricsResync : l10n.lyricsSync;
    final canTap = !_running && widget.track.id != null;
    return Material(
      color: Colors.white.withValues(alpha: canTap ? 0.08 : 0.04),
      shape: CircleBorder(
        side: BorderSide(
          color: Colors.white.withValues(alpha: canTap ? 0.22 : 0.10),
          width: 1,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: canTap ? _run : null,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.textPrimary),
                      ),
                    )
                  : Icon(
                      Icons.sync_rounded,
                      color: canTap
                          ? AppColors.textPrimary
                          : AppColors.textPrimary.withValues(alpha: 0.35),
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single line in expanded mode. Layout is computed at the "active"
/// size (fontSize 30); inactive lines are scaled visually via
/// Transform.scale without affecting layout. The active line has its
/// own color/weight, animated without touching intrinsicWidth (because
/// the text is always rendered at fontSize 30, changes only happen in
/// the DefaultTextStyle above).
class _ExpandedLyricLine extends StatelessWidget {
  final String text;
  final bool isCurrent;
  const _ExpandedLyricLine({required this.text, required this.isCurrent});

  static const double _activeFontSize = 30.0;
  static const double _inactiveScale = 20.0 / 30.0;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.textPrimary;
    final inactiveColor = AppColors.textSecondary.withValues(alpha: 0.35);
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Center(
          child: AnimatedScale(
            scale: isCurrent ? 1.0 : _inactiveScale,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  color: isCurrent ? activeColor : inactiveColor,
                  fontSize: _activeFontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
                child: Text(
                  text,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain text without timestamps: small font, scrollable, left-aligned
/// (like regular "text for reading" rather than a "lyrics presentation").
class _PlainLyricsScroll extends StatelessWidget {
  final List<String> lines;
  const _PlainLyricsScroll({required this.lines});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      itemCount: lines.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          lines[i],
          style: const TextStyle(
            fontFamily: AppFonts.family,
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/browse_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/player_service.dart';
import '../screens/now_playing_screen.dart';
import '../utils/duration_format.dart';
import 'cover_art.dart';
import 'flat_track_shape.dart';
import 'track_actions.dart';

class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(playbackSnapshotProvider);
    final controller = ref.watch(playerControllerProvider);
    return snapshotAsync.when(
      loading: () => const _Stub(),
      error: (e, _) => _Stub(error: e.toString()),
      data: (snap) => _PlayerBarContent(
        track: snap.currentTrack,
        playing: snap.playing,
        buffering: snap.buffering,
        duration: snap.duration,
        shuffle: snap.shuffle,
        repeatMode: snap.repeatMode,
        error: snap.error,
        volume: snap.volume,
        muted: snap.muted,
        controller: controller,
      ),
    );
  }
}

class _Stub extends StatelessWidget {
  final String? error;
  const _Stub({this.error});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 96,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      alignment: Alignment.center,
      child: Text(
        error == null ? l10n.playerNothingPlaying : l10n.commonError(error!),
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

class _PlayerBarContent extends ConsumerWidget {
  final Track? track;
  final bool playing;
  final bool buffering;
  final Duration duration;
  final bool shuffle;
  final RepeatMode repeatMode;
  final String? error;
  final double volume;
  final bool muted;
  final PlayerController controller;

  const _PlayerBarContent({
    required this.track,
    required this.playing,
    required this.buffering,
    required this.duration,
    required this.shuffle,
    required this.repeatMode,
    required this.error,
    required this.volume,
    required this.muted,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isLoading = buffering && duration == Duration.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null)
          _ErrorBanner(
            message: error!,
            onDismiss: controller.clearError,
          ),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TopSlider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: compact ? 180 : 260,
                          child: track == null
                              ? Center(
                                  child: Text(
                                    l10n.playerNothingPlaying,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                )
                              : _NowPlayingInfo(track: track!),
                        ),
                        Expanded(
                          child: Center(
                            child: _ControlsPill(
                              playing: playing,
                              repeatMode: repeatMode,
                              isLoading: isLoading,
                              controller: controller,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: compact ? 180 : 240,
                          child: _ExtraControls(
                            volume: volume,
                            muted: muted,
                            controller: controller,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopSlider extends ConsumerWidget {
  const _TopSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      playbackSnapshotProvider
          .select((s) => s.valueOrNull?.position ?? Duration.zero),
    );
    final duration = ref.watch(
      playbackSnapshotProvider
          .select((s) => s.valueOrNull?.duration ?? Duration.zero),
    );
    final buffered = ref.watch(
      playbackSnapshotProvider
          .select((s) => s.valueOrNull?.bufferedPosition ?? Duration.zero),
    );
    final controller = ref.watch(playerControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: _SeekBar(
        position: position,
        duration: duration,
        buffered: buffered,
        onSeek: controller.seek,
      ),
    );
  }
}

class _NowPlayingInfo extends ConsumerStatefulWidget {
  final Track track;
  const _NowPlayingInfo({required this.track});

  @override
  ConsumerState<_NowPlayingInfo> createState() => _NowPlayingInfoState();
}

class _NowPlayingInfoState extends ConsumerState<_NowPlayingInfo> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isFav = track.id == null
        ? track.isFavorite
        : ref.watch(isTrackFavoriteProvider(track.id!)).valueOrNull ??
            track.isFavorite;
    return Row(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => openNowPlayingScreen(context),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CoverArt(coverPath: track.coverPath, size: 48),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _hovering ? 1.0 : 0.0,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(48 * 0.12),
                    ),
                    child: const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
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
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                track.displayArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Builder(
          builder: (innerCtx) => IconButton(
            iconSize: 20,
            splashRadius: 20,
            tooltip: l10n.playerActionsTooltip,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () => showTrackActionsMenu(innerCtx, ref, track),
          ),
        ),
        IconButton(
          iconSize: 20,
          splashRadius: 20,
          tooltip: isFav ? l10n.playerRemoveFavorite : l10n.playerAddFavorite,
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.redAccent : AppColors.textSecondary,
          ),
          onPressed: track.id == null
              ? null
              : () => ref
                  .read(favoritesNotifierProvider.notifier)
                  .toggleTrack(track.id!),
        ),
      ],
    );
  }
}

class _ControlsPill extends StatelessWidget {
  final bool playing;
  final RepeatMode repeatMode;
  final bool isLoading;
  final PlayerController controller;
  const _ControlsPill({
    required this.playing,
    required this.repeatMode,
    required this.isLoading,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillIconButton(
            icon: Icons.skip_previous,
            size: 22,
            color: AppColors.textPrimary,
            tooltip: l10n.playerPreviousTooltip,
            onPressed: controller.previous,
          ),
          const SizedBox(width: 6),
          _PlayPauseButton(
            playing: playing,
            loading: isLoading,
            onPressed: controller.playPause,
          ),
          const SizedBox(width: 6),
          _PillIconButton(
            icon: Icons.skip_next,
            size: 22,
            color: AppColors.textPrimary,
            tooltip: l10n.playerNextTooltip,
            onPressed: controller.next,
          ),
          const SizedBox(width: 8),
          _RepeatButton(
            mode: repeatMode,
            onPressed: controller.cycleRepeat,
          ),
        ],
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  const _PillIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      iconSize: size + 6,
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _ExtraControls extends StatelessWidget {
  final double volume;
  final bool muted;
  final PlayerController controller;
  const _ExtraControls({
    required this.volume,
    required this.muted,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayVolume = muted ? 0.0 : volume;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
            displayVolume == 0
                ? Icons.volume_off_rounded
                : displayVolume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            color: AppColors.textSecondary,
          ),
          tooltip: muted ? l10n.playerUnmuteTooltip : l10n.playerMuteTooltip,
          onPressed: controller.toggleMute,
        ),
        SizedBox(
          width: 110,
          child: _VolumeSlider(
            value: displayVolume,
            onChanged: controller.setVolume,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade900.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: onDismiss,
            tooltip: AppLocalizations.of(context)!.commonClose,
          ),
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool playing;
  final bool loading;
  final VoidCallback onPressed;
  const _PlayPauseButton({
    required this.playing,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 30,
                    ),
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

class _SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final Future<void> Function(Duration) onSeek;
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;
  bool _dragging = false;

  double get _value {
    if (_dragValue != null) return _dragValue!;
    if (widget.duration.inMilliseconds == 0) return 0;
    return widget.position.inMilliseconds / widget.duration.inMilliseconds;
  }

  /// The position shown to the user. While dragging, this is the target
  /// point the thumb is being dragged to; at rest it is the actual
  /// playback position. Otherwise, while dragging the time digits would
  /// stay frozen even though the thumb visually moves.
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
        Stack(
          alignment: Alignment.center,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                trackShape: const FlatTrackShape(),
                activeTrackColor: _dragging
                    ? theme.colorScheme.primary
                    : AppColors.textPrimary,
                inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.4),
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
                height: 3,
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

class _VolumeSlider extends StatelessWidget {
  final double value;
  final Future<void> Function(double) onChanged;
  const _VolumeSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        trackShape: const FlatTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: AppColors.textPrimary,
        inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.4),
        thumbColor: AppColors.textPrimary,
        overlayColor: Colors.white.withValues(alpha: 0.12),
      ),
      child: Slider(
        value: value.clamp(0.0, 1.0),
        onChanged: onChanged,
      ),
    );
  }
}

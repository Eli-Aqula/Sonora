import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/track.dart';
import '../../providers/browse_provider.dart';
import '../utils/duration_format.dart';
import 'cover_art.dart';
import 'equalizer_icon.dart';
import 'track_actions.dart';

class TrackList extends ConsumerWidget {
  final List<Track> tracks;
  final int? currentIndex;
  final void Function(int index)? onTapIndex;
  final void Function(int index)? onRemove;
  final bool scrollable;
  final bool showFavoriteButton;
  final bool showEmptyState;
  final String? emptyText;

  const TrackList({
    super.key,
    required this.tracks,
    this.currentIndex,
    this.onTapIndex,
    this.onRemove,
    this.scrollable = true,
    this.showFavoriteButton = true,
    this.showEmptyState = true,
    this.emptyText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (tracks.isEmpty) {
      if (!showEmptyState) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text(
            emptyText ?? l10n.trackListEmpty,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final children = <Widget>[
      for (var i = 0; i < tracks.length; i++)
        _Row(
          key: tracks[i].id != null
              ? ValueKey<int>(tracks[i].id!)
              : ValueKey<String>('${tracks[i].path}#$i'),
          track: tracks[i],
          index: i,
          isCurrent: currentIndex == i,
          onTap: onTapIndex == null ? null : () => onTapIndex!(i),
          onRemove: onRemove == null ? null : () => onRemove!(i),
          showFavoriteButton: showFavoriteButton,
        ),
    ];
    if (scrollable) {
      return ListView.builder(
        itemCount: tracks.length,
        padding: const EdgeInsets.only(bottom: 16),
        itemBuilder: (context, i) => children[i],
      );
    }
    // In non-scrollable mode we use a plain Column — no ListView/ScrollView,
    // the content takes up exactly as much space as it needs.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  final Track track;
  final int index;
  final bool isCurrent;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showFavoriteButton;

  const _Row({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    this.onTap,
    this.onRemove,
    this.showFavoriteButton = true,
  });

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  bool _hovering = false;
  final LayerLink _moreLink = LayerLink();

  static const _hoverColor = Color(0x14FFFFFF);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accent = AppColors.accent;
    final active = widget.isCurrent;

    final inner = InkWell(
      onTap: widget.onTap,
      onSecondaryTap: widget.onRemove,
      onHover: (h) => setState(() => _hovering = h),
      borderRadius: active
          ? BorderRadius.circular(20)
          : BorderRadius.circular(16),
      hoverColor: _hoverColor,
      highlightColor: Colors.white.withValues(alpha: 0.06),
      splashColor: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: active
                  ? Center(
                      child: EqualizerIcon(
                        color: accent,
                        size: 16,
                      ),
                    )
                  : Text(
                      '${widget.index + 1}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            CoverArt(coverPath: widget.track.coverPath, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: active ? accent : null,
                      fontWeight: active ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatDuration(widget.track.duration),
              style: theme.textTheme.bodySmall,
            ),
            if (widget.showFavoriteButton) ...[
              const SizedBox(width: 4),
              _FavoriteButton(track: widget.track),
            ],
            if (widget.track.id != null) ...[
              const SizedBox(width: 4),
              CompositedTransformTarget(
                link: _moreLink,
                child: Builder(
                  builder: (innerCtx) => IconButton(
                    iconSize: 18,
                    splashRadius: 18,
                    tooltip: l10n.playerActionsTooltip,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => showTrackActionsMenu(
                      innerCtx,
                      ref,
                      widget.track,
                      layerLink: _moreLink,
                    ),
                  ),
                ),
              ),
            ],
            if (widget.onRemove != null) ...[
              const SizedBox(width: 4),
              IconButton(
                iconSize: 18,
                splashRadius: 18,
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
              ),
            ],
          ],
        ),
      ),
    );

    if (!active) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: _hovering
              ? _hoverColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: inner,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: inner,
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  final Track track;
  const _FavoriteButton({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Reactively subscribe to the "favorite" state for this track — so
    // the icon recolors immediately on click, without reloading the list.
    final isFavAsync = track.id == null
        ? const AsyncValue<bool>.data(false)
        : ref.watch(isTrackFavoriteProvider(track.id!));
    final isFav = isFavAsync.valueOrNull ?? track.isFavorite;
    return IconButton(
      iconSize: 18,
      splashRadius: 18,
      tooltip: isFav ? l10n.playerRemoveFavorite : l10n.playerAddFavorite,
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? Colors.redAccent : AppColors.textSecondary,
      ),
      onPressed: track.id == null
          ? null
          : () async {
              await ref
                  .read(favoritesNotifierProvider.notifier)
                  .toggleTrack(track.id!);
            },
    );
  }
}

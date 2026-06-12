import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../providers/browse_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../utils/duration_format.dart';
import 'cover_art.dart';
import 'equalizer_icon.dart';
import 'tag_editor_dialog.dart';

class TrackTile extends ConsumerWidget {
  final Track track;
  final int index;
  final List<Track> queue;
  final VoidCallback? onTap;
  final bool isCurrent;
  final Widget? trailing;

  const TrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.queue,
    this.onTap,
    this.isCurrent = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(playerControllerProvider);
    final theme = Theme.of(context);
    final titleColor =
        isCurrent ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => controller.playTrack(track, context: queue),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: isCurrent
                    ? Center(
                        child: EqualizerIcon(
                          color: theme.colorScheme.primary,
                          size: 14,
                        ),
                      )
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              CoverArt(coverPath: track.coverPath, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null) trailing!,
              if (trailing == null) ...[
                IconButton(
                  iconSize: 18,
                  splashRadius: 18,
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => _showContextMenu(context, ref, track),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: Text(
                    formatDuration(track.duration),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    // Reactively read the "favorite" state at the moment the menu opens —
    // otherwise the item's icon won't update after a previous toggle.
    final isFav = track.id == null
        ? track.isFavorite
        : ref.read(isTrackFavoriteProvider(track.id!)).valueOrNull ??
            track.isFavorite;
    final action = await showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surfaceElevated,
      items: [
        PopupMenuItem(
          value: 'play_next',
          child: ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: Text(l10n.trackPlay),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'queue',
          child: ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: Text(l10n.trackAddToQueue),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: ListTile(
            leading: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : null,
            ),
            title: Text(isFav ? l10n.playerRemoveFavorite : l10n.playerAddFavorite),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'playlist',
          child: ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: Text(l10n.trackAddToPlaylistEllipsis),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'edit_tags',
          child: ListTile(
            leading: const Icon(Icons.edit_note_rounded),
            title: Text(l10n.trackEditTagsEllipsis),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    final player = ref.read(playerControllerProvider);
    final playlists = ref.read(playlistsProvider.notifier);
    switch (action) {
      case 'play_next':
        await player.playTrack(track, context: queue);
        break;
      case 'queue':
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (track.id == null) {
          messenger?.showSnackBar(
            SnackBar(content: Text(l10n.trackNotInLibrary)),
          );
          break;
        }
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.trackAddedToQueue(track.displayTitle)),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'favorite':
        if (track.id == null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(l10n.trackNotInLibrary)),
          );
          break;
        }
        final isFav = await ref
            .read(favoritesNotifierProvider.notifier)
            .toggleTrack(track.id!);
        if (!context.mounted) break;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(isFav
                ? l10n.trackAddedToFavorites(track.displayTitle)
                : l10n.trackRemovedFromFavorites(track.displayTitle)),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'playlist':
        if (track.id == null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(l10n.trackNotInLibrary)),
          );
          break;
        }
        final playlistsList = ref.read(playlistsProvider).valueOrNull ?? const <Playlist>[];
        if (playlistsList.isEmpty) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(l10n.trackCreatePlaylistFirst)),
          );
          break;
        }
        final Playlist? chosen = await showModalBottomSheet<Playlist>(
          context: context,
          backgroundColor: AppColors.surfaceElevated,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    l10n.trackAddToPlaylist,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                for (final p in playlistsList)
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(p.name),
                    subtitle: Text(l10n.homeTracksCount(p.trackCount)),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
              ],
            ),
          ),
        );
        if (chosen != null && chosen.id != null && context.mounted) {
          await playlists.addTrack(chosen.id!, track.id!);
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(l10n.trackAddedToPlaylist(chosen.name)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        break;
      case 'edit_tags':
        final messenger = ScaffoldMessenger.maybeOf(context);
        final updated =
            await showTagEditorDialog(context: context, track: track);
        if (updated != null && context.mounted) {
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l10n.trackTagsUpdated(updated.displayTitle)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../utils/duration_format.dart';
import '../widgets/app_dialog.dart';
import '../widgets/cover_art.dart';
import '../widgets/track_actions.dart';
import '../widgets/track_list.dart';

class PlaylistView extends ConsumerWidget {
  final Playlist playlist;
  final VoidCallback onBack;
  const PlaylistView({super.key, required this.playlist, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tracksAsync = ref.watch(playlistTracksProvider(playlist.id!));
    final controller = ref.read(playlistsProvider.notifier);
    final player = ref.read(playerControllerProvider);
    final snapshot = ref.watch(playbackSnapshotProvider);
    final theme = Theme.of(context);

    final totalDuration = tracksAsync.maybeWhen(
      data: (t) => t.fold<Duration>(Duration.zero, (a, b) => a + b.duration),
      orElse: () => Duration.zero,
    );

    final currentIndex = snapshot.maybeWhen(
      data: (s) {
        final current = s.currentTrack;
        if (current == null) return null;
        final list = tracksAsync.valueOrNull;
        if (list == null) return null;
        // First by id (stable across shuffle/enrichment), then by
        // normalized path.
        if (current.id != null) {
          final i = list.indexWhere((t) => t.id == current.id);
          if (i >= 0) return i;
        }
        final norm = current.path.replaceAll('\\', '/').toLowerCase();
        final j = list.indexWhere(
          (t) => t.path.replaceAll('\\', '/').toLowerCase() == norm,
        );
        return j >= 0 ? j : null;
      },
      orElse: () => null,
    );

    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _PillIconButton(
                  icon: Icons.arrow_back,
                  tooltip: l10n.commonBack,
                  onTap: onBack,
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: tracksAsync.when(
              data: (tracks) => _Content(
                playlist: playlist,
                tracks: tracks,
                totalDuration: totalDuration,
                currentIndex: currentIndex,
                onPlay: () => player.playQueue(tracks),
                onShuffle: () => player.shuffleList(tracks),
                onTapIndex: (i) => player.playQueue(tracks, startIndex: i),
                onRemoveTrack: (i) async {
                  final t = tracks[i];
                  if (t.id != null) {
                    await controller.removeTrack(playlist.id!, t.id!);
                  }
                },
                onRename: () => _renameDialog(context, ref),
                onDelete: () => _confirmDelete(context, ref),
                onSetCover: () async {
                  try {
                    await controller.pickAndSetCover(playlist.id!);
                  } catch (e) {
                    if (context.mounted) {
                      await showAppDialog<void>(
                        context: context,
                        title: l10n.sidebarCoverSetFailedTitle,
                        content: Text('$e',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        actions: [
                          AppDialogAction(
                            label: l10n.commonOk,
                            primary: true,
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      );
                    }
                  }
                },
                onClearCover: () => controller.clearCover(playlist.id!),
                theme: theme,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: playlist.name);
    final newName = await showAppDialog<String>(
      context: context,
      title: l10n.commonRename,
      contentBuilder: (ctx) => AppTextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        AppDialogAction(
          label: l10n.commonCancel,
          onTap: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: l10n.commonSave,
          primary: true,
          onTap: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(playlistsProvider.notifier).rename(playlist.id!, newName);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showAppDialog<bool>(
      context: context,
      title: l10n.sidebarDeletePlaylistTitle,
      content: Text(
        l10n.sidebarDeletePlaylistConfirm(playlist.name),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        AppDialogAction(
          label: l10n.commonCancel,
          onTap: () => Navigator.pop(context, false),
        ),
        AppDialogAction(
          label: l10n.commonDelete,
          danger: true,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirm == true) {
      await ref.read(playlistsProvider.notifier).delete(playlist.id!);
      if (context.mounted) onBack();
    }
  }
}

class _Content extends StatelessWidget {
  final Playlist playlist;
  final List<Track> tracks;
  final Duration totalDuration;
  final int? currentIndex;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final void Function(int) onTapIndex;
  final void Function(int) onRemoveTrack;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetCover;
  final VoidCallback onClearCover;
  final ThemeData theme;

  const _Content({
    required this.playlist,
    required this.tracks,
    required this.totalDuration,
    required this.currentIndex,
    required this.onPlay,
    required this.onShuffle,
    required this.onTapIndex,
    required this.onRemoveTrack,
    required this.onRename,
    required this.onDelete,
    required this.onSetCover,
    required this.onClearCover,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            playlist: playlist,
            trackCount: tracks.length,
            totalDuration: totalDuration,
            canPlay: tracks.isNotEmpty,
            onPlay: onPlay,
            onShuffle: onShuffle,
            onRename: onRename,
            onDelete: onDelete,
            onSetCover: onSetCover,
            onClearCover: onClearCover,
            theme: theme,
          ),
        ),
        if (tracks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Text(
                  l10n.playlistEmptyMessage,
                  style: const TextStyle(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: TrackList(
              tracks: tracks,
              scrollable: false,
              currentIndex: currentIndex,
              onTapIndex: onTapIndex,
              onRemove: onRemoveTrack,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Playlist playlist;
  final int trackCount;
  final Duration totalDuration;
  final bool canPlay;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetCover;
  final VoidCallback onClearCover;
  final ThemeData theme;

  const _Header({
    required this.playlist,
    required this.trackCount,
    required this.totalDuration,
    required this.canPlay,
    required this.onPlay,
    required this.onShuffle,
    required this.onRename,
    required this.onDelete,
    required this.onSetCover,
    required this.onClearCover,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cover = playlist.effectiveCoverPath;
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CoverTile(
            coverPath: cover,
            hasCustomCover: playlist.coverPath != null,
            onSetCover: onSetCover,
            onClearCover: onClearCover,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l10n.playlistLabel,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _metaLine(l10n),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _PillActionButton(
                      icon: Icons.play_arrow,
                      label: l10n.playlistListen,
                      onPressed: canPlay ? onPlay : null,
                    ),
                    const SizedBox(width: 8),
                    _PillActionButton(
                      icon: Icons.shuffle,
                      label: l10n.playlistShuffle,
                      onPressed: canPlay ? onShuffle : null,
                    ),
                    const Spacer(),
                    _PillIconButton(
                      icon: Icons.edit,
                      tooltip: l10n.commonRename,
                      onTap: onRename,
                    ),
                    const SizedBox(width: 8),
                    _PillIconButton(
                      icon: Icons.delete_outline,
                      tooltip: l10n.commonDelete,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine(AppLocalizations l10n) {
    final parts = <String>[
      l10n.homeTracksCount(trackCount),
      if (totalDuration > Duration.zero) formatLongDuration(l10n, totalDuration),
    ];
    return parts.join(' • ');
  }
}

class _CoverTile extends StatefulWidget {
  final String? coverPath;
  final bool hasCustomCover;
  final VoidCallback onSetCover;
  final VoidCallback onClearCover;
  const _CoverTile({
    required this.coverPath,
    required this.hasCustomCover,
    required this.onSetCover,
    required this.onClearCover,
  });

  @override
  State<_CoverTile> createState() => _CoverTileState();
}

class _CoverTileState extends State<_CoverTile> {
  final LayerLink _menuLink = LayerLink();

  Future<void> _openMenu(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showAppPopupMenu<String>(
      context: context,
      anchor: Offset.zero,
      link: _menuLink,
      items: [
        AppMenuItem(
          value: 'set',
          icon: Icons.image_outlined,
          label: widget.hasCustomCover
              ? l10n.sidebarChangeCover
              : l10n.sidebarSetCover,
        ),
        if (widget.hasCustomCover)
          AppMenuItem(
            value: 'clear',
            icon: Icons.image_not_supported_outlined,
            label: l10n.sidebarRemoveCover,
          ),
      ],
    );
    if (action == 'set') widget.onSetCover();
    if (action == 'clear') widget.onClearCover();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onSetCover,
        onSecondaryTap: () => _openMenu(context),
        onLongPress: () => _openMenu(context),
        child: Stack(
          children: [
            Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.coverPath != null
                  ? CoverArt(
                      key: ValueKey('pl_header_${widget.coverPath}'),
                      coverPath: widget.coverPath,
                      size: 192,
                      borderRadius: BorderRadius.circular(24),
                      fallbackIcon: Icons.queue_music,
                    )
                  : const Center(
                      child: Icon(
                        Icons.queue_music,
                        size: 96,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: CompositedTransformTarget(
                link: _menuLink,
                child: _PillIconButton(
                  icon: Icons.more_horiz,
                  tooltip: l10n.playlistCoverTooltip,
                  onTap: () => _openMenu(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _PillActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: enabled
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _PillIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

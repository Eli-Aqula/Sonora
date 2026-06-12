import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/album.dart';
import '../../data/models/track.dart';
import '../../providers/browse_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/player_provider.dart';
import '../utils/duration_format.dart';
import '../widgets/cover_art.dart';
import '../widgets/track_list.dart';

class AlbumView extends ConsumerWidget {
  final Album album;
  final VoidCallback onBack;
  const AlbumView({super.key, required this.album, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final key = AlbumKey(album.name, album.artist);
    final tracksAsync = ref.watch(albumTracksProvider(key));
    final snapshot = ref.watch(playbackSnapshotProvider);
    final player = ref.watch(playerControllerProvider);

    final totalDuration = tracksAsync.maybeWhen(
      data: (t) => t.fold<Duration>(Duration.zero, (a, b) => a + b.duration),
      orElse: () => Duration.zero,
    );

    final currentIndex = snapshot.maybeWhen(
      data: (s) {
        final current = s.currentTrack;
        final tracks = tracksAsync.valueOrNull;
        if (current == null || tracks == null) return null;
        return _indexForCurrent(tracks, current);
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
                _AlbumFavoritePill(album: album),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(album: album, totalDuration: totalDuration),
                ),
                SliverToBoxAdapter(
                  child: tracksAsync.when(
                    data: (tracks) {
                      if (tracks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Text(l10n.albumNoTracks,
                                style: const TextStyle(color: AppColors.textMuted)),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          TrackList(
                            tracks: tracks,
                            scrollable: false,
                            currentIndex: currentIndex,
                            onTapIndex: (i) => player.playQueue(
                              tracks,
                              startIndex: i,
                              albumKey: (
                                album: album.name,
                                artist: album.artist,
                              ),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Finds the position of the currently playing track in the album list.
  /// First by id (stable across shuffle/re-enrich), then falls back to
  /// path with case and slash normalization.
  int? _indexForCurrent(List<Track> tracks, Track current) {
    final id = current.id;
    if (id != null) {
      for (var i = 0; i < tracks.length; i++) {
        if (tracks[i].id == id) return i;
      }
    }
    final norm = _normPath(current.path);
    for (var i = 0; i < tracks.length; i++) {
      if (_normPath(tracks[i].path) == norm) return i;
    }
    return null;
  }

  String _normPath(String p) =>
      p.replaceAll('\\', '/').toLowerCase();
}

class _Header extends ConsumerWidget {
  final Album album;
  final Duration totalDuration;
  const _Header({required this.album, required this.totalDuration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Hero(
            tag: 'album-${album.name}-${album.artist}',
            child: CoverArt(
              coverPath: album.coverPath,
              size: 192,
              borderRadius: BorderRadius.circular(24),
              fallbackIcon: Icons.album,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(l10n.albumLabel, style: theme.textTheme.labelSmall),
                const SizedBox(height: 6),
                Text(
                  album.name,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine(AppLocalizations l10n) {
    final parts = <String>[
      album.artist,
      if (album.year != null) album.year.toString(),
      l10n.homeTracksCount(album.trackCount),
      formatLongDuration(l10n, totalDuration),
    ];
    return parts.join(' • ');
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

class _AlbumFavoritePill extends ConsumerStatefulWidget {
  final Album album;
  const _AlbumFavoritePill({required this.album});

  @override
  ConsumerState<_AlbumFavoritePill> createState() =>
      _AlbumFavoritePillState();
}

class _AlbumFavoritePillState extends ConsumerState<_AlbumFavoritePill> {
  bool? _isFav;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(libraryRepositoryProvider);
    final fav =
        await repo.isAlbumFavorite(widget.album.name, widget.album.artist);
    if (!mounted) return;
    setState(() {
      _isFav = fav;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final isFav = _isFav ?? false;
    return _PillIconButton(
      icon: isFav ? Icons.favorite : Icons.favorite_border,
      tooltip: isFav ? l10n.playerRemoveFavorite : l10n.playerAddFavorite,
      onTap: () async {
        final newVal = await ref
            .read(favoritesNotifierProvider.notifier)
            .toggleAlbum(widget.album.name, widget.album.artist);
        if (!mounted) return;
        setState(() => _isFav = newVal);
      },
    );
  }
}

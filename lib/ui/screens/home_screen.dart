import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/artist.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/browse_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/library_provider.dart';
import '../../providers/library_tab_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../screens/library_tab.dart';
import '../utils/duration_format.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_avatar.dart';
import '../widgets/cover_art.dart';
import '../widgets/marquee_text.dart';
import '../widgets/track_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    final snapshot = ref.watch(playbackSnapshotProvider);
    final theme = Theme.of(context);

    int? indexIn(List tracks) {
      final current = snapshot.valueOrNull?.currentTrack;
      if (current == null) return null;
      for (var i = 0; i < tracks.length; i++) {
        if (tracks[i].path == current.path) return i;
      }
      return null;
    }

    if (library.folders.isEmpty) {
      return _EmptyState(
        onPickFolder: () async {
          final path = await FilePicker.platform.getDirectoryPath();
          if (path != null) {
            await controller.addFolder(path);
          }
        },
      );
    }

    if (library.tracks.isEmpty && library.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalDuration = library.tracks.fold<Duration>(
      Duration.zero,
      (acc, t) => acc + t.duration,
    );
    final totalArtists = <String>{
      for (final t in library.tracks) t.displayArtist
    };
    final totalAlbums = <String>{
      for (final t in library.tracks) '${t.displayAlbum}|${t.displayArtist}'
    };
    // Sort by addedAt — modifiedAt changes when ID3 tags are edited
    // (e.g. via Genius), which would otherwise jump a track to the front
    // of "recently added" even though it's been in the library for a while.
    final recent = [...library.tracks]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final recentList = recent.take(4).toList();

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(l10n.navHome, style: theme.textTheme.headlineLarge),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatChip(
                          icon: Icons.music_note,
                          label: l10n.homeTracksCount(library.tracks.length),
                        ),
                        _StatChip(
                          icon: Icons.album,
                          label: l10n.homeAlbumsCount(totalAlbums.length),
                        ),
                        _StatChip(
                          icon: Icons.person,
                          label: l10n.homeArtistsCount(totalArtists.length),
                        ),
                        _StatChip(
                          icon: Icons.schedule,
                          label: formatLongDuration(l10n, totalDuration),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (library.loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    _PillActionButton(
                      icon: Icons.refresh,
                      label: l10n.homeRescan,
                      onPressed: () => controller.scan(),
                    ),
                ],
              ),
            ),
            const _NowPlayingSlot(),
            _SectionHeader(
              title: l10n.homeQuickActions,
              onAll: null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.play_arrow,
                      title: l10n.homeAllTracks,
                      subtitle: l10n.homeTracksCount(library.tracks.length),
                      onTap: () => ref
                          .read(playerControllerProvider)
                          .playQueue(library.tracks),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.shuffle,
                      title: l10n.homeShuffleTitle,
                      subtitle: l10n.homeShuffleSubtitle,
                      onTap: () => ref
                          .read(playerControllerProvider)
                          .shuffleList(library.tracks),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _FavoritesColumn(
                      onAll: () =>
                          ref.read(mainTabProvider.notifier).state = 3,
                      indexIn: indexIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _RecentSplitColumn(
                      tracks: recentList,
                      indexIn: indexIn,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _AlbumsRail(),
            const SizedBox(height: 24),
            const _ArtistsRail(),
            const SizedBox(height: 24),
            const _PlaylistsRail(),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAll;
  const _SectionHeader({required this.title, this.onAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const Spacer(),
          if (onAll != null)
            TextButton(
              onPressed: onAll,
              child: Text(AppLocalizations.of(context)!.commonSeeAll),
            ),
        ],
      ),
    );
  }
}

class _NowPlayingSlot extends ConsumerStatefulWidget {
  const _NowPlayingSlot();

  @override
  ConsumerState<_NowPlayingSlot> createState() => _NowPlayingSlotState();
}

class _NowPlayingSlotState extends ConsumerState<_NowPlayingSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Track? _shownTrack;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
      playbackSnapshotProvider
          .select((s) => s.valueOrNull?.currentTrack),
    );

    if (track == null && _shownTrack != null) {
      _shownTrack = null;
      _ctrl.reverse();
    } else if (track != null && _shownTrack == null) {
      _shownTrack = track;
      _ctrl.forward(from: 0);
    } else {
      _shownTrack = track;
    }

    return SizeTransition(
      sizeFactor: _ctrl,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _ctrl,
        child: track == null
            ? const SizedBox.shrink()
            : _NowPlayingCard(track: track),
      ),
    );
  }
}

class _NowPlayingCard extends ConsumerWidget {
  final Track track;
  const _NowPlayingCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playbackSnapshotProvider);
    final playing = snapshot.valueOrNull?.playing ?? false;
    final position = snapshot.valueOrNull?.position ?? Duration.zero;
    final duration = snapshot.valueOrNull?.duration ?? Duration.zero;
    final player = ref.read(playerControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: SizedBox(
        height: 120,
        child: Material(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CoverArt(
                  coverPath: track.coverPath,
                  size: 72,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.nowPlayingLabel,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                            fontFamily: AppFonts.family,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        MarqueeText(
                          text: track.displayTitle,
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        MarqueeText(
                          text:
                              '${track.displayArtist} • ${track.displayAlbum}',
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              formatDuration(position),
                              style: const TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: duration.inMilliseconds == 0
                                      ? 0
                                      : position.inMilliseconds /
                                          duration.inMilliseconds,
                                  minHeight: 3,
                                  backgroundColor: AppColors.highlight,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatDuration(duration),
                              style: const TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PillIconButton(
                    icon: playing ? Icons.pause : Icons.play_arrow,
                    size: 24,
                    onTap: player.playPause,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

class _AlbumsRail extends ConsumerWidget {
  const _AlbumsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(albumsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeAlbumsTitle,
          onAll: () {
            ref.read(mainTabProvider.notifier).state = 2;
            ref.read(libraryTabProvider.notifier).state = LibraryTab.albums;
            ref.read(libraryShowBackProvider.notifier).state = true;
          },
        ),
        SizedBox(
          height: 250,
          child: albumsAsync.when(
            data: (albums) {
              if (albums.isEmpty) {
                return Center(
                  child: Text(
                    l10n.homeNoAlbums,
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: albums.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final album = albums[i];
                  return SizedBox(
                    width: 180,
                    child: AlbumCard(
                      title: album.name,
                      subtitle: album.artist,
                      coverPath: album.coverPath,
                      albumName: album.name,
                      albumArtist: album.artist,
                      onTap: () => ref
                          .read(panelProvider.notifier)
                          .openAlbum(album),
                      onPlay: () async {
                        final tracks = await ref.read(
                          albumTracksProvider(
                            AlbumKey(album.name, album.artist),
                          ).future,
                        );
                        if (tracks.isEmpty) return;
                        await ref
                            .read(playerControllerProvider)
                            .playQueue(
                              tracks,
                              startIndex: 0,
                              albumKey: (
                                album: album.name,
                                artist: album.artist,
                              ),
                            );
                      },
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text(l10n.commonError('$e'), style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistsRail extends ConsumerWidget {
  const _ArtistsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final artistsAsync = ref.watch(artistsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeArtistsTitle,
          onAll: () {
            ref.read(mainTabProvider.notifier).state = 2;
            ref.read(libraryTabProvider.notifier).state = LibraryTab.artists;
            ref.read(libraryShowBackProvider.notifier).state = true;
          },
        ),
        SizedBox(
          height: 160,
          child: artistsAsync.when(
            data: (artists) {
              if (artists.isEmpty) {
                return Center(
                  child: Text(
                    l10n.homeNoArtists,
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: artists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  return _ArtistCircle(
                    artist: artists[i],
                    onTap: () => ref
                        .read(panelProvider.notifier)
                        .openArtist(artists[i]),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text(l10n.commonError('$e'), style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistCircle extends ConsumerStatefulWidget {
  final Artist artist;
  final VoidCallback onTap;
  const _ArtistCircle({required this.artist, required this.onTap});

  @override
  ConsumerState<_ArtistCircle> createState() => _ArtistCircleState();
}

class _ArtistCircleState extends ConsumerState<_ArtistCircle> {
  bool? _isFav;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(libraryRepositoryProvider);
    final fav = await repo.isArtistFavorite(widget.artist.name);
    if (!mounted) return;
    setState(() {
      _isFav = fav;
      _loading = false;
    });
  }

  @override
  void didUpdateWidget(covariant _ArtistCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist.name != widget.artist.name) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFav = _isFav ?? false;
    return SizedBox(
      width: 100,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Column(
          children: [
            Stack(
              children: [
                ArtistAvatar(
                  artistName: widget.artist.name,
                  size: 96,
                  iconSize: 48,
                ),
                if (!_loading)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () async {
                        final newVal = await ref
                            .read(favoritesNotifierProvider.notifier)
                            .toggleArtist(widget.artist.name);
                        if (!mounted) return;
                        setState(() => _isFav = newVal);
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsRail extends ConsumerWidget {
  const _PlaylistsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playlistsAsync = ref.watch(playlistsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.sidebarPlaylists,
          onAll: null,
        ),
        SizedBox(
          height: 64,
          child: playlistsAsync.when(
            data: (playlists) {
              if (playlists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    l10n.homeCreatePlaylistHint,
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return _PlaylistChip(
                    playlist: playlists[i],
                    onTap: () => ref
                        .read(panelProvider.notifier)
                        .openPlaylist(playlists[i]),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text(l10n.commonError('$e'), style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaylistChip extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  const _PlaylistChip({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = playlist.effectiveCoverPath;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: cover != null
                    ? CoverArt(
                        key: ValueKey('pl_chip_${playlist.id}_$cover'),
                        coverPath: cover,
                        size: 24,
                        borderRadius: BorderRadius.circular(6),
                        fallbackIcon: Icons.queue_music,
                      )
                    : const Icon(
                        Icons.queue_music,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                playlist.name,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              if (playlist.trackCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${playlist.trackCount}',
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesColumn extends ConsumerWidget {
  final VoidCallback onAll;
  final int? Function(List tracks) indexIn;
  const _FavoritesColumn({required this.onAll, required this.indexIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteTracksProvider);
    final player = ref.watch(playerControllerProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionHeader(title: AppLocalizations.of(context)!.navFavorites, onAll: onAll),
        _FavoritesBody(
          asyncTracks: favoritesAsync,
          indexIn: indexIn,
          player: player,
          theme: theme,
        ),
      ],
    );
  }
}

class _FavoritesBody extends StatelessWidget {
  final AsyncValue<List<Track>> asyncTracks;
  final int? Function(List tracks) indexIn;
  final PlayerController player;
  final ThemeData theme;
  const _FavoritesBody({
    required this.asyncTracks,
    required this.indexIn,
    required this.player,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Use the last successfully loaded data — the cache is updated locally
    // on toggle, so a loading state never occurs.
    final tracks = asyncTracks.valueOrNull;
    if (tracks == null) {
      return asyncTracks.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(AppLocalizations.of(context)!.commonError('$e'), style: theme.textTheme.bodySmall),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }
    if (tracks.isEmpty) {
      return const SizedBox.shrink();
    }
    final list = tracks.take(4).toList();
    return TrackList(
      tracks: list,
      scrollable: false,
      showEmptyState: false,
      currentIndex: indexIn(list),
      onTapIndex: (i) => player.playQueue(list, startIndex: i),
    );
  }
}

class _RecentSplitColumn extends ConsumerWidget {
  final List<Track> tracks;
  final int? Function(List tracks) indexIn;
  const _RecentSplitColumn({
    required this.tracks,
    required this.indexIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionHeader(title: AppLocalizations.of(context)!.homeRecentlyAdded, onAll: null),
        TrackList(
          tracks: tracks,
          scrollable: false,
          showEmptyState: false,
          currentIndex: indexIn(tracks),
          onTapIndex: (i) => player.playQueue(tracks, startIndex: i),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPickFolder;
  const _EmptyState({required this.onPickFolder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: const Icon(
                  Icons.library_music,
                  size: 48,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(l10n.homeEmptyTitle,
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                l10n.homeEmptyDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),              FilledButton.icon(
                icon: const Icon(Icons.folder),
                label: Text(l10n.homeChooseFolder),
                onPressed: onPickFolder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _PillActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
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
  final double size;
  final VoidCallback onTap;
  const _PillIconButton({
    required this.icon,
    required this.size,
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
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: size, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

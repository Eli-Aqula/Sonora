import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/browse_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_avatar.dart';
import '../widgets/artist_favorite_button.dart';
import '../widgets/track_list.dart';

enum FavoritesView { tracks, albums, artists }

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  FavoritesView _view = FavoritesView.tracks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(l10n.navFavorites, style: theme.textTheme.headlineLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ViewTab(
                          label: l10n.libraryTabTracks,
                          selected: _view == FavoritesView.tracks,
                          onTap: () =>
                              setState(() => _view = FavoritesView.tracks),
                        ),
                        const SizedBox(width: 8),
                        _ViewTab(
                          label: l10n.libraryTabAlbums,
                          selected: _view == FavoritesView.albums,
                          onTap: () =>
                              setState(() => _view = FavoritesView.albums),
                        ),
                        const SizedBox(width: 8),
                        _ViewTab(
                          label: l10n.libraryTabArtists,
                          selected: _view == FavoritesView.artists,
                          onTap: () =>
                              setState(() => _view = FavoritesView.artists),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_view) {
              FavoritesView.tracks => const _FavoriteTracksView(),
              FavoritesView.albums => const _FavoriteAlbumsView(),
              FavoritesView.artists => const _FavoriteArtistsView(),
            },
          ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ViewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.18);
    final textColor =
        selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(color: textColor, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _FavoriteTracksView extends ConsumerWidget {
  const _FavoriteTracksView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favoritesAsync = ref.watch(favoriteTracksProvider);
    final player = ref.watch(playerControllerProvider);
    final snapshot = ref.watch(playbackSnapshotProvider);
    // The cache is updated locally on toggle, so we use valueOrNull to
    // avoid showing a spinner during updates.
    final tracks = favoritesAsync.valueOrNull;
    if (tracks == null) {
      return favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
        data: (_) => const SizedBox.shrink(),
      );
    }
    if (tracks.isEmpty) {
      return _EmptyFavorites(text: l10n.favoritesNoTracks);
    }
    final currentTrack = snapshot.valueOrNull?.currentTrack;
    int? currentIndex;
    if (currentTrack != null) {
      final idx = tracks.indexWhere((t) => t.path == currentTrack.path);
      currentIndex = idx >= 0 ? idx : null;
    }
    return TrackList(
      tracks: tracks,
      currentIndex: currentIndex,
      onTapIndex: (i) => player.playQueue(tracks, startIndex: i),
    );
  }
}

class _FavoriteAlbumsView extends ConsumerWidget {
  const _FavoriteAlbumsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(favoriteAlbumsProvider);
    final player = ref.watch(playerControllerProvider);
    // The cache is updated locally on toggle — no loading state.
    final albums = albumsAsync.valueOrNull;
    if (albums == null) {
      return albumsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
        data: (_) => const SizedBox.shrink(),
      );
    }
    if (albums.isEmpty) {
      return _EmptyFavorites(text: l10n.favoritesNoAlbums);
    }
    final sorted = [...albums]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 270,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final a = sorted[i];
        return AlbumCard(
          key: ValueKey('fav-album-${a.name}|${a.artist}'),
          title: a.name,
          subtitle: a.artist,
          coverPath: a.coverPath,
          albumName: a.name,
          albumArtist: a.artist,
          onTap: () => ref.read(panelProvider.notifier).openAlbum(a),
          onPlay: () async {
            final tracks = await ref
                .read(libraryRepositoryProvider)
                .getAlbumTracks(a.name, a.artist);
            await player.playQueue(
              tracks,
              albumKey: (album: a.name, artist: a.artist),
            );
          },
        );
      },
    );
  }
}

class _FavoriteArtistsView extends ConsumerWidget {
  const _FavoriteArtistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final artistsAsync = ref.watch(favoriteArtistsProvider);
    // The cache is updated locally on toggle — no loading state.
    final artists = artistsAsync.valueOrNull;
    if (artists == null) {
      return artistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
        data: (_) => const SizedBox.shrink(),
      );
    }
    if (artists.isEmpty) {
      return _EmptyFavorites(text: l10n.favoritesNoArtists);
    }
    final sorted = [...artists]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(
        color: AppColors.divider,
        height: 1,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, i) {
        final a = sorted[i];
        return ListTile(
          key: ValueKey('fav-artist-${a.name}'),
          leading: ArtistAvatar(artistName: a.name),
          title: Text(a.name),
          subtitle: Text(l10n.libraryArtistAlbumsAndTracks(
            l10n.homeAlbumsCount(a.albumCount),
            l10n.homeTracksCount(a.trackCount),
          )),
          onTap: () => ref.read(panelProvider.notifier).openArtist(a),
          trailing: ArtistFavoriteButton(artistName: a.name),
        );
      },
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  final String text;
  const _EmptyFavorites({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.favorite_border,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

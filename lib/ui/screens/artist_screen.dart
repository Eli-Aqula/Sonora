import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/album.dart';
import '../../data/models/artist.dart';
import '../../providers/artist_metadata_provider.dart';
import '../../providers/browse_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/genius_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/genius/artist_image_store.dart';
import '../../services/genius/genius_client.dart';
import '../widgets/album_card.dart';
import '../widgets/genius_artist_dialog.dart';

class ArtistView extends ConsumerWidget {
  final Artist artist;
  final VoidCallback onBack;
  final void Function(Album) onOpenAlbum;
  const ArtistView({
    super.key,
    required this.artist,
    required this.onBack,
    required this.onOpenAlbum,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(artistAlbumsProvider(artist.name));
    final player = ref.watch(playerControllerProvider);
    final theme = Theme.of(context);
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
                if (ref.watch(geniusClientProvider) != null) ...[
                  _GeniusArtistPill(artist: artist),
                  const SizedBox(width: 8),
                ],
                _ArtistFavoritePill(artist: artist),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(artist: artist),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(l10n.homeAlbumsTitle, style: theme.textTheme.titleLarge),
                  ),
                ),
                albumsAsync.when(
                  data: (albums) => SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisExtent: 270,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: albums.length,
                      itemBuilder: (context, i) {
                        final a = albums[i];
                        return AlbumCard(
                          title: a.name,
                          subtitle: l10n.homeTracksCount(a.trackCount),
                          coverPath: a.coverPath,
                          albumName: a.name,
                          albumArtist: a.artist,
                          onTap: () => onOpenAlbum(a),
                          onPlay: () async {
                            final tracks = await ref
                                .read(libraryRepositoryProvider)
                                .getAlbumTracks(a.name, a.artist);
                            await player.playQueue(
                              tracks,
                              albumKey: (
                                album: a.name,
                                artist: a.artist,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(child: Text(l10n.commonError('$e'))),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final Artist artist;
  const _Header({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final meta = ref.watch(artistMetadataByNameProvider(artist.name));
    final imagePath = meta?.imagePath;
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 192,
                height: 192,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath == null || imagePath.isEmpty
                    ? const Icon(Icons.person,
                        color: AppColors.textMuted, size: 96)
                    : Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person,
                            color: AppColors.textMuted, size: 96),
                      ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(l10n.artistLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text(
                      artist.name,
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
                      l10n.libraryArtistAlbumsAndTracks(
                        l10n.homeAlbumsCount(artist.albumCount),
                        l10n.homeTracksCount(artist.trackCount),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (meta?.description != null && meta!.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              meta.description!,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GeniusArtistPill extends ConsumerStatefulWidget {
  final Artist artist;
  const _GeniusArtistPill({required this.artist});

  @override
  ConsumerState<_GeniusArtistPill> createState() => _GeniusArtistPillState();
}

class _GeniusArtistPillState extends ConsumerState<_GeniusArtistPill> {
  bool _running = false;

  Future<void> _run() async {
    final client = ref.read(geniusClientProvider);
    if (client == null) return;
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final id = await showGeniusArtistDialog(
        context: context,
        client: client,
        artist: widget.artist,
      );
      if (id == null || !mounted) return;
      final fetched = await client.getArtist(id);

      final old = ref.read(artistMetadataProvider.notifier).get(widget.artist.name);
      String? imagePath;
      if (fetched.imageUrl != null && fetched.imageUrl!.isNotEmpty) {
        imagePath = await ArtistImageStore.download(
          fetched.imageUrl!,
          geniusId: fetched.id,
        );
      }
      if (!mounted) return;
      if (old?.imagePath != null && old!.imagePath != imagePath) {
        await ArtistImageStore.delete(old.imagePath);
      }

      await ref.read(artistMetadataProvider.notifier).save(ArtistMetadata(
            name: widget.artist.name,
            geniusId: fetched.id,
            imagePath: imagePath ?? old?.imagePath,
            imageUrl: fetched.imageUrl,
            headerImageUrl: fetched.headerImageUrl,
            description: fetched.descriptionPlain,
            geniusUrl: fetched.url,
          ));
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.artistDataFetched(fetched.name)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on GeniusException catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.geniusError(e.message))),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.commonError('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _PillIconButton(
      icon: _running ? Icons.hourglass_top_rounded : Icons.search_rounded,
      tooltip: l10n.geniusFindArtist,
      onTap: _running ? () {} : _run,
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

class _ArtistFavoritePill extends ConsumerStatefulWidget {
  final Artist artist;
  const _ArtistFavoritePill({required this.artist});

  @override
  ConsumerState<_ArtistFavoritePill> createState() =>
      _ArtistFavoritePillState();
}

class _ArtistFavoritePillState extends ConsumerState<_ArtistFavoritePill> {
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
            .toggleArtist(widget.artist.name);
        if (!mounted) return;
        setState(() => _isFav = newVal);
      },
    );
  }
}

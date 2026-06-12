import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/browse_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/album_card.dart';

class AlbumCarousel extends ConsumerWidget {
  const AlbumCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(albumsProvider);
    return SizedBox(
      height: 220,
      child: albumsAsync.when(
        data: (albums) {
          if (albums.isEmpty) {
            return Center(
              child: Text(l10n.homeNoAlbums, style: const TextStyle(color: AppColors.textMuted)),
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
                width: 150,
                child: AlbumCard(
                  title: album.name,
                  subtitle: album.artist,
                  coverPath: album.coverPath,
                  albumName: album.name,
                  albumArtist: album.artist,
                  onTap: () => ref.read(panelProvider.notifier).openAlbum(album),
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
                          albumKey: (album: album.name, artist: album.artist),
                        );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
      ),
    );
  }
}
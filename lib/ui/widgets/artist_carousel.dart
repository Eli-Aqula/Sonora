import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/browse_provider.dart';
import '../../providers/panel_provider.dart';
import 'artist_avatar.dart';

class ArtistCarousel extends ConsumerWidget {
  const ArtistCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final artistsAsync = ref.watch(artistsProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: 120,
      child: artistsAsync.when(
        data: (artists) {
          if (artists.isEmpty) {
            return Center(
              child: Text(l10n.homeNoArtists, style: const TextStyle(color: AppColors.textMuted)),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final artist = artists[i];
              return SizedBox(
                width: 100,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => ref.read(panelProvider.notifier).openArtist(artist),
                  child: Column(
                    children: [
                      ArtistAvatar(
                        artistName: artist.name,
                        size: 80,
                        iconSize: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
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
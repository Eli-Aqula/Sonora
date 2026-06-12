import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/browse_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/player_provider.dart';
import 'cover_art.dart';
import 'equalizer_icon.dart';
import 'marquee_text.dart';

class AlbumCard extends ConsumerWidget {
  final String title;
  final String subtitle;
  final String? coverPath;
  final String? albumName;
  final String? albumArtist;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final bool showFavoriteButton;

  const AlbumCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverPath,
    this.albumName,
    this.albumArtist,
    this.onTap,
    this.onPlay,
    this.showFavoriteButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshot = ref.watch(playbackSnapshotProvider);
    final isQueueForThisAlbum = albumName != null &&
        albumArtist != null &&
        snapshot.valueOrNull?.currentAlbumKey != null &&
        snapshot.valueOrNull!.currentAlbumKey!.album == albumName &&
        snapshot.valueOrNull!.currentAlbumKey!.artist == albumArtist;
    final current = snapshot.valueOrNull?.currentTrack;
    final isPlayingThisTrack = current != null &&
        albumName != null &&
        albumArtist != null &&
        current.displayAlbum == albumName &&
        current.displayArtist == albumArtist;
    final isPlaying = snapshot.valueOrNull?.playing ?? false;
    final showEqualizer = isQueueForThisAlbum && isPlayingThisTrack && isPlaying;

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
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: CoverArt(
                          coverPath: coverPath,
                          fallbackIcon: Icons.album,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      if (showFavoriteButton &&
                          albumName != null &&
                          albumArtist != null)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: _AlbumFavoriteButton(
                            album: albumName!,
                            artist: albumArtist!,
                          ),
                        ),
                      if (onPlay != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                if (isQueueForThisAlbum) {
                                  ref
                                      .read(playerControllerProvider)
                                      .playPause();
                                } else {
                                  onPlay?.call();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: showEqualizer
                                    ? const EqualizerIcon(
                                        size: 22,
                                        color: Colors.white,
                                      )
                                    : const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MarqueeText(
                text: title,
                style: theme.textTheme.titleSmall ?? const TextStyle(),
              ),
              const SizedBox(height: 4),
              MarqueeText(
                text: subtitle,
                style: theme.textTheme.bodySmall ?? const TextStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumFavoriteButton extends ConsumerStatefulWidget {
  final String album;
  final String artist;
  const _AlbumFavoriteButton({required this.album, required this.artist});

  @override
  ConsumerState<_AlbumFavoriteButton> createState() =>
      _AlbumFavoriteButtonState();
}

class _AlbumFavoriteButtonState
    extends ConsumerState<_AlbumFavoriteButton> {
  bool? _isFav;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(libraryRepositoryProvider);
    final fav = await repo.isAlbumFavorite(widget.album, widget.artist);
    if (!mounted) return;
    setState(() {
      _isFav = fav;
      _loading = false;
    });
  }

  @override
  void didUpdateWidget(covariant _AlbumFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album != widget.album || oldWidget.artist != widget.artist) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final isFav = _isFav ?? false;
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(
        side: BorderSide(
          color: Color(0x4DFFFFFF),
          width: 1,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final newVal = await ref
              .read(favoritesNotifierProvider.notifier)
              .toggleAlbum(widget.album, widget.artist);
          if (!mounted) return;
          setState(() => _isFav = newVal);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.redAccent : Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

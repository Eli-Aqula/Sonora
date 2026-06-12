import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/track.dart';
import '../../providers/browse_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/library_provider.dart';
import '../../providers/library_tab_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/artist_avatar.dart';
import '../widgets/artist_favorite_button.dart';
import '../widgets/track_list.dart';
import 'library_tab.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    final tab = ref.watch(libraryTabProvider);
    final showBack = ref.watch(libraryShowBackProvider);
    final theme = Theme.of(context);
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
            child: Row(
              children: [
                if (showBack)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _PillIconButton(
                      icon: Icons.arrow_back,
                      tooltip: l10n.commonBack,
                      onTap: () {
                        ref.read(mainTabProvider.notifier).state = 0;
                        ref.read(libraryShowBackProvider.notifier).state =
                            false;
                      },
                    ),
                  ),
                Text(l10n.navLibrary, style: theme.textTheme.headlineLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: _Tabs(
                    current: tab,
                    onChanged: (t) =>
                        ref.read(libraryTabProvider.notifier).state = t,
                  ),
                ),
                const SizedBox(width: 8),
                _PillIconButton(
                  icon: Icons.add,
                  tooltip: l10n.libraryAddFolder,
                  onTap: () async {
                    final path = await FilePicker.platform.getDirectoryPath();
                    if (path != null) await controller.addFolder(path);
                  },
                ),
                const SizedBox(width: 8),
                _PillIconButton(
                  icon: Icons.refresh,
                  tooltip: l10n.homeRescan,
                  onTap: () => controller.scan(),
                ),
              ],
            ),
          ),
          if (library.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: switch (tab) {
              LibraryTab.tracks => _TracksTab(tracks: library.tracks),
              LibraryTab.albums => const _AlbumsTab(),
              LibraryTab.artists => const _ArtistsTab(),
              LibraryTab.folders => _FoldersTab(
                  folders: library.folders,
                  onAdd: () async {
                    final p = await FilePicker.platform.getDirectoryPath();
                    if (p != null) await controller.addFolder(p);
                  },
                  onRemove: (p) async {
                    final confirm = await showAppDialog<bool>(
                      context: context,
                      title: l10n.libraryRemoveFolderTitle,
                      content: Text(
                        l10n.libraryRemoveFolderConfirm(p),
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
                      await controller.removeFolder(p);
                      await controller.scan();
                    }
                  },
                ),
            },
          ),
        ],
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

class _Tabs extends StatelessWidget {
  final LibraryTab current;
  final ValueChanged<LibraryTab> onChanged;
  const _Tabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entries = [
      (LibraryTab.tracks, l10n.libraryTabTracks),
      (LibraryTab.albums, l10n.libraryTabAlbums),
      (LibraryTab.artists, l10n.libraryTabArtists),
      (LibraryTab.folders, l10n.libraryTabFolders),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in entries) ...[
            _PillTab(
              label: e.$2,
              selected: current == e.$1,
              onTap: () => onChanged(e.$1),
              textStyle: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;
  const _PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.textStyle,
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
            style: textStyle?.copyWith(color: textColor) ??
                TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }
}

class _TracksTab extends ConsumerWidget {
  final List<Track> tracks;
  const _TracksTab({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final snapshot = ref.watch(playbackSnapshotProvider);
    final currentIndex = snapshot.maybeWhen(
      data: (s) {
        final current = s.currentTrack;
        if (current == null) return null;
        for (var i = 0; i < tracks.length; i++) {
          if (tracks[i].path == current.path) return i;
        }
        return null;
      },
      orElse: () => null,
    );
    return TrackList(
      tracks: tracks,
      currentIndex: currentIndex,
      onTapIndex: (i) => player.playQueue(tracks, startIndex: i),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = ref.watch(albumsProvider);
    final player = ref.watch(playerControllerProvider);
    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return _Empty(text: l10n.homeNoAlbums);
        }
        final sorted = [...albums]
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
              title: a.name,
              subtitle: a.artist,
              coverPath: a.coverPath,
              albumName: a.name,
              albumArtist: a.artist,
              onTap: () {
                ref.read(panelProvider.notifier).openAlbum(a);
              },
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final artistsAsync = ref.watch(artistsProvider);
    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return _Empty(text: l10n.homeNoArtists);
        }
        final sorted = [...artists]
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
              leading: ArtistAvatar(artistName: a.name),
              title: Text(a.name),
              subtitle: Text(l10n.libraryArtistAlbumsAndTracks(
                l10n.homeAlbumsCount(a.albumCount),
                l10n.homeTracksCount(a.trackCount),
              )),
              onTap: () =>
                  ref.read(panelProvider.notifier).openArtist(a),
              trailing: ArtistFavoriteButton(artistName: a.name),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
    );
  }
}

class _FoldersTab extends ConsumerWidget {
  final List<String> folders;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  const _FoldersTab({
    required this.folders,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.libraryNoFolders,
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.libraryAddFolder),
              onPressed: onAdd,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: folders.length,
      separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final f = folders[i];
        return ListTile(
          leading: const Icon(Icons.folder_rounded),
          title: Text(_basename(f), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => onRemove(f),
          ),
        );
      },
    );
  }

  String _basename(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final idx = path.lastIndexOf(sep);
    return idx == -1 ? path : path.substring(idx + 1);
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}

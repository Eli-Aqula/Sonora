import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/main_tab_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/player_bar.dart';
import '../widgets/sidebar.dart';
import 'album_screen.dart';
import 'artist_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'playlist_view.dart';
import 'search_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _mainTabsCount = 4;

  static const _mainViews = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final panel = ref.watch(panelProvider);
    final mainTab = ref.watch(mainTabProvider);

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: _selectedIndex(
              mainTab,
              panel,
              playlists.valueOrNull,
            ),
            onSelect: (i) => _onSelect(
              ref,
              i,
              panel,
              playlists.valueOrNull,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IndexedStack(
                          index: mainTab,
                          children: _mainViews,
                        ),
                      ),
                      if (panel.isNotEmpty)
                        Positioned.fill(
                          child: _buildPanelView(
                            context,
                            ref,
                            panel,
                            playlists.valueOrNull,
                          ),
                        ),
                    ],
                  ),
                ),
                const PlayerBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _selectedIndex(int mainTab, List<PanelEntry> panel, List? list) {
    if (panel.isNotEmpty && panel.last is PlaylistPanel) {
      final playlists = list;
      if (playlists != null) {
        final p = (panel.last as PlaylistPanel).playlist;
        final i = playlists.indexWhere((pl) => pl.id == p.id);
        if (i >= 0) return _mainTabsCount + i;
      }
    }
    return mainTab;
  }

  void _onSelect(
    WidgetRef ref,
    int i,
    List<PanelEntry> panel,
    List? list,
  ) {
    if (i < _mainTabsCount) {
      ref.read(mainTabProvider.notifier).state = i;
      if (panel.isNotEmpty) {
        ref.read(panelProvider.notifier).clear();
      }
      return;
    }
    final playlists = list;
    if (playlists == null) return;
    final idx = i - _mainTabsCount;
    if (idx < 0 || idx >= playlists.length) return;
    ref.read(panelProvider.notifier).clear();
    ref.read(panelProvider.notifier).openPlaylist(playlists[idx]);
  }

  Widget _buildPanelView(BuildContext context, WidgetRef ref, List<PanelEntry> panel, List? list) {
    final top = panel.last;
    if (top is PlaylistPanel) {
      final playlists = list;
      final fresh = playlists?.firstWhere(
        (p) => p.id == top.playlist.id,
        orElse: () => top.playlist,
      );
      if (fresh != null) {
        return PlaylistView(
          playlist: fresh,
          onBack: () => ref.read(panelProvider.notifier).pop(),
        );
      }
    } else if (top is AlbumPanel) {
      return AlbumView(
        album: top.album,
        onBack: () => ref.read(panelProvider.notifier).pop(),
      );
    } else if (top is ArtistPanel) {
      return ArtistView(
        artist: top.artist,
        onBack: () => ref.read(panelProvider.notifier).pop(),
        onOpenAlbum: (album) =>
            ref.read(panelProvider.notifier).openAlbum(album),
      );
    }
    return const SizedBox.shrink();
  }
}

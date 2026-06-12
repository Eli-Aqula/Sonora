import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/mobile_mini_player.dart';
import 'album_screen.dart';
import 'artist_screen.dart';
import 'favorites_screen.dart';
import 'home_screen_mobile.dart';
import 'library_screen.dart';
import 'playlist_view.dart';
import 'search_screen.dart';

/// Root app shell for mobile (narrow screen).
///
/// Consists of:
/// - Stack:
///   - `IndexedStack` of four tabs (Home / Search / Library / Favorites)
///   - Playlist/Album/Artist panel overlay on top of the tabs
/// - Below it, the mini player ([MobileMiniPlayer]) above a `NavigationBar`.
///
/// The system back button is handled via `PopScope`: if a panel is open,
/// it's closed; otherwise the system is allowed to close the app.
class MobileAppShell extends ConsumerWidget {
  const MobileAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Watch playlistsProvider so child screens can read it without
    // extra loading states.
    ref.watch(playlistsProvider);
    final panel = ref.watch(panelProvider);
    final mainTab = ref.watch(mainTabProvider);

    return PopScope(
      canPop: panel.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && panel.isNotEmpty) {
          ref.read(panelProvider.notifier).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: SafeArea(
          // `bottom: false` — the mini player and NavigationBar handle the
          // bottom inset themselves via their own SafeArea below.
          bottom: false,
          child: Stack(
            children: [
              IndexedStack(
                index: mainTab,
                children: const [
                  MobileHomeScreen(),
                  SearchScreen(),
                  LibraryScreen(),
                  FavoritesScreen(),
                ],
              ),
              if (panel.isNotEmpty)
                Positioned.fill(
                  child: _MobilePanelHost(top: panel.last),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MobileMiniPlayer(),
              NavigationBar(
                selectedIndex: mainTab,
                onDestinationSelected: (i) {
                  ref.read(mainTabProvider.notifier).state = i;
                  if (panel.isNotEmpty) {
                    ref.read(panelProvider.notifier).clear();
                  }
                },
                backgroundColor: const Color(0xFF181818),
                indicatorColor: const Color(0x33FFFFFF),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.search_outlined),
                    selectedIcon: const Icon(Icons.search),
                    label: l10n.navSearch,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.library_music_outlined),
                    selectedIcon: const Icon(Icons.library_music),
                    label: l10n.navLibrary,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.favorite_border),
                    selectedIcon: const Icon(Icons.favorite),
                    label: l10n.navFavorites,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Routes the top entry of the panel stack to the right screen.
/// Since Album/Artist/PlaylistView draw their own `AppBar` via the
/// onBack callback, this is just a `Material` on top of the rest of the shell.
class _MobilePanelHost extends ConsumerWidget {
  final PanelEntry top;
  const _MobilePanelHost({required this.top});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = top;
    Widget child;
    if (entry is PlaylistPanel) {
      final playlists = ref.watch(playlistsProvider).valueOrNull;
      final fresh = playlists?.firstWhere(
            (p) => p.id == entry.playlist.id,
            orElse: () => entry.playlist,
          ) ??
          entry.playlist;
      child = PlaylistView(
        playlist: fresh,
        onBack: () => ref.read(panelProvider.notifier).pop(),
      );
    } else if (entry is AlbumPanel) {
      child = AlbumView(
        album: entry.album,
        onBack: () => ref.read(panelProvider.notifier).pop(),
      );
    } else if (entry is ArtistPanel) {
      child = ArtistView(
        artist: entry.artist,
        onBack: () => ref.read(panelProvider.notifier).pop(),
        onOpenAlbum: (album) =>
            ref.read(panelProvider.notifier).openAlbum(album),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Material(
      color: AppColors.background,
      child: child,
    );
  }
}

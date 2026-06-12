import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/album.dart';
import '../data/models/artist.dart';
import '../data/models/track.dart';
import 'core_providers.dart';
import 'library_provider.dart';

final albumsProvider = FutureProvider<List<Album>>((ref) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final list = await repo.getAlbums();
  list.shuffle(Random());
  return list;
});

final artistsProvider = FutureProvider<List<Artist>>((ref) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final list = await repo.getArtists();
  list.shuffle(Random());
  return list;
});

final albumTracksProvider =
    FutureProvider.family.autoDispose(((ref, AlbumKey key) async {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getAlbumTracks(key.album, key.artist);
}));

class AlbumKey {
  final String album;
  final String artist;
  const AlbumKey(this.album, this.artist);

  @override
  bool operator ==(Object other) =>
      other is AlbumKey &&
      other.album == album &&
      other.artist == artist;

  @override
  int get hashCode => Object.hash(album, artist);
}

final artistAlbumsProvider =
    FutureProvider.family.autoDispose((ref, String artist) async {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getArtistAlbums(artist);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final debouncedQueryProvider = StateProvider<String>((ref) => '');

final _searchDebouncerProvider = Provider.autoDispose<void>((ref) {
  Timer? timer;
  ref.listen<String>(searchQueryProvider, (prev, next) {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 250), () {
      ref.read(debouncedQueryProvider.notifier).state = next;
    });
  });
  ref.onDispose(() => timer?.cancel());
  return;
});

final searchResultsProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  ref.watch(_searchDebouncerProvider);
  final q = ref.watch(debouncedQueryProvider);
  if (q.trim().isEmpty) return const <Track>[];
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.searchTracks(q);
});

// ---- Favorites ----------------------------------------------------------

/// Manages "favorite" state — a shared notifier that updates the
/// provider caches on change without losing previous data.
class FavoritesNotifier extends StateNotifier<int> {
  FavoritesNotifier(this._ref) : super(0);
  final Ref _ref;

  Future<bool> toggleTrack(int trackId) async {
    final repo = _ref.read(libraryRepositoryProvider);
    final result = await repo.toggleTrackFavorite(trackId);
    state++;
    // Update the cache locally so the UI doesn't "flash" a loading state.
    _ref.read(_favoriteTracksCacheProvider.notifier).applyToggle(trackId, result);
    _ref.invalidate(isTrackFavoriteProvider(trackId));
    return result;
  }

  Future<bool> toggleAlbum(String album, String artist) async {
    final repo = _ref.read(libraryRepositoryProvider);
    final result = await repo.toggleAlbumFavorite(album, artist);
    state++;
    // Update the cache locally so the UI doesn't show a loading state.
    _ref.read(_favoriteAlbumsCacheProvider.notifier).applyToggle(album, artist, result);
    return result;
  }

  Future<bool> toggleArtist(String artist) async {
    final repo = _ref.read(libraryRepositoryProvider);
    final result = await repo.toggleArtistFavorite(artist);
    state++;
    // Update the cache locally so the UI doesn't show a loading state.
    _ref.read(_favoriteArtistsCacheProvider.notifier).applyToggle(artist, result);
    return result;
  }
}

final favoritesNotifierProvider =
    StateNotifierProvider<FavoritesNotifier, int>((ref) {
  return FavoritesNotifier(ref);
});

/// Cache of favorite tracks, updated locally on toggle and reloaded
/// from the DB on first access. This avoids widget flicker when
/// adding/removing favorites.
class _FavoriteTracksCacheNotifier
    extends StateNotifier<AsyncValue<List<Track>>> {
  _FavoriteTracksCacheNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _load();
  }
  final Ref _ref;

  Future<void> _load() async {
    final repo = _ref.read(libraryRepositoryProvider);
    try {
      final list = await repo.getFavoriteTracks();
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Applies the toggle locally — adds or removes the track from the
  /// cache without showing a loading state in the UI.
  void applyToggle(int trackId, bool isFav) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (isFav) {
      if (current.any((t) => t.id == trackId)) return;
      // Look up the track in the loaded library.
      final allTracks = _ref.read(libraryControllerProvider).tracks;
      Track? track;
      for (final t in allTracks) {
        if (t.id == trackId) {
          track = t;
          break;
        }
      }
      if (track == null) return;
      state = AsyncValue.data(
        <Track>[track.copyWith(isFavorite: true), ...current],
      );
    } else {
      state = AsyncValue.data(
        current.where((t) => t.id != trackId).toList(growable: false),
      );
    }
  }

  /// Full reload from the DB (used when needed).
  Future<void> refresh() async {
    final repo = _ref.read(libraryRepositoryProvider);
    final list = await repo.getFavoriteTracks();
    if (!mounted) return;
    state = AsyncValue.data(list);
  }
}

final _favoriteTracksCacheProvider = StateNotifierProvider<
    _FavoriteTracksCacheNotifier, AsyncValue<List<Track>>>((ref) {
  return _FavoriteTracksCacheNotifier(ref);
});

/// Public provider — a reactive list of favorite tracks.
/// Updates locally on toggle (without flicker) and picks up
/// changes from the DB on first load.
final favoriteTracksProvider = Provider<AsyncValue<List<Track>>>((ref) {
  ref.watch(favoritesNotifierProvider);
  return ref.watch(_favoriteTracksCacheProvider);
});

/// Cache of favorite albums — similar to tracks, updated locally
/// on toggle to avoid a loading state in the UI.
class _FavoriteAlbumsCacheNotifier
    extends StateNotifier<AsyncValue<List<Album>>> {
  _FavoriteAlbumsCacheNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _load();
  }
  final Ref _ref;

  Future<void> _load() async {
    final repo = _ref.read(libraryRepositoryProvider);
    try {
      final list = await repo.getFavoriteAlbums();
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void applyToggle(String album, String artist, bool isFav) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (isFav) {
      if (current.any((a) => a.name == album && a.artist == artist)) return;
      state = AsyncValue.data(<Album>[
        Album(name: album, artist: artist, coverPath: null, trackCount: 0),
        ...current,
      ]);
    } else {
      state = AsyncValue.data(
        current
            .where((a) => !(a.name == album && a.artist == artist))
            .toList(growable: false),
      );
    }
  }
}

final _favoriteAlbumsCacheProvider = StateNotifierProvider<
    _FavoriteAlbumsCacheNotifier, AsyncValue<List<Album>>>((ref) {
  return _FavoriteAlbumsCacheNotifier(ref);
});

final favoriteAlbumsProvider = Provider<AsyncValue<List<Album>>>((ref) {
  ref.watch(favoritesNotifierProvider);
  return ref.watch(_favoriteAlbumsCacheProvider);
});

/// Cache of favorite artists — similar to albums.
class _FavoriteArtistsCacheNotifier
    extends StateNotifier<AsyncValue<List<Artist>>> {
  _FavoriteArtistsCacheNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _load();
  }
  final Ref _ref;

  Future<void> _load() async {
    final repo = _ref.read(libraryRepositoryProvider);
    try {
      final list = await repo.getFavoriteArtists();
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void applyToggle(String artist, bool isFav) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (isFav) {
      if (current.any((a) => a.name == artist)) return;
      state = AsyncValue.data(<Artist>[
        Artist(name: artist, albumCount: 0, trackCount: 0),
        ...current,
      ]);
    } else {
      state = AsyncValue.data(
        current
            .where((a) => a.name != artist)
            .toList(growable: false),
      );
    }
  }
}

final _favoriteArtistsCacheProvider = StateNotifierProvider<
    _FavoriteArtistsCacheNotifier, AsyncValue<List<Artist>>>((ref) {
  return _FavoriteArtistsCacheNotifier(ref);
});

final favoriteArtistsProvider = Provider<AsyncValue<List<Artist>>>((ref) {
  ref.watch(favoritesNotifierProvider);
  return ref.watch(_favoriteArtistsCacheProvider);
});

/// Checks whether a track is a favorite. Reactive — updates when
/// the "favorite" state changes via [favoritesNotifierProvider].
final isTrackFavoriteProvider =
    FutureProvider.family.autoDispose<bool, int>((ref, trackId) async {
  ref.watch(favoritesNotifierProvider);
  // First check the local cache (faster, no DB access needed).
  final cached = ref.watch(_favoriteTracksCacheProvider).valueOrNull;
  if (cached != null) {
    return cached.any((t) => t.id == trackId);
  }
  final repo = ref.watch(libraryRepositoryProvider);
  final tracks = await repo.getFavoriteTracks();
  return tracks.any((t) => t.id == trackId);
});

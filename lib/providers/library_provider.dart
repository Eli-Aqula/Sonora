import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/track.dart';
import '../services/genius/genius_enricher.dart';
import '../services/metadata_writer.dart';
import '../services/metadata_reader.dart';
import '../ui/widgets/cover_art.dart';
import 'browse_provider.dart';
import 'core_providers.dart';
import 'genius_provider.dart';

class LibraryState {
  final List<Track> tracks;
  final List<String> folders;
  final bool loading;
  final double? scanProgress;
  final String? scanMessage;
  final int? scanTotal;

  const LibraryState({
    this.tracks = const [],
    this.folders = const [],
    this.loading = false,
    this.scanProgress,
    this.scanMessage,
    this.scanTotal,
  });

  LibraryState copyWith({
    List<Track>? tracks,
    List<String>? folders,
    bool? loading,
    double? scanProgress,
    String? scanMessage,
    int? scanTotal,
    bool resetProgress = false,
  }) {
    return LibraryState(
      tracks: tracks ?? this.tracks,
      folders: folders ?? this.folders,
      loading: loading ?? this.loading,
      scanProgress: resetProgress ? null : (scanProgress ?? this.scanProgress),
      scanMessage: resetProgress ? null : (scanMessage ?? this.scanMessage),
      scanTotal: resetProgress ? null : (scanTotal ?? this.scanTotal),
    );
  }
}

class LibraryController extends StateNotifier<LibraryState> {
  LibraryController(this._ref) : super(const LibraryState());
  final Ref _ref;

  Future<void> load() async {
    final repo = _ref.read(libraryRepositoryProvider);
    final folders = await repo.getWatchedFolders();
    final tracks = await repo.getAllTracks();
    state = state.copyWith(folders: folders, tracks: tracks);
  }

  Future<int> addFolder(String path) async {
    final repo = _ref.read(libraryRepositoryProvider);
    await repo.addWatchedFolder(path);
    await load();
    return scan(folders: [path], reset: false);
  }

  /// For Android: add individual audio files without folder watching
  Future<void> addAudioFiles(List<String> paths) async {
    final metadataReader = _ref.read(metadataReaderProvider);
    final newTracks = <Track>[];
    state = state.copyWith(loading: true, scanProgress: 0, scanMessage: 'Importing...');
    
    for (final path in paths) {
      try {
        final meta = await metadataReader.read(path);
        if (meta != null) {
          final stat = await File(path).stat();
          final track = Track(
            path: path,
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            albumArtist: meta.albumArtist,
            year: meta.year,
            trackNumber: meta.trackNumber,
            discNumber: meta.discNumber,
            duration: meta.duration,
            genre: meta.genre,
            bitrate: meta.bitrate,
            sampleRate: meta.sampleRate,
            fileSize: stat.size,
            coverPath: meta.coverPath,
            addedAt: stat.modified,
            modifiedAt: stat.modified,
          );
          final wasNew = (await _ref.read(libraryRepositoryProvider).getTrackByPath(path)) == null;
          await _ref.read(libraryRepositoryProvider).upsertTrack(track);
          if (wasNew) newTracks.add(track);
        }
      } catch (_) {}
    }
    
    state = state.copyWith(loading: false, resetProgress: true);
    await load();
  }

  Future<int> scan({List<String>? folders, bool reset = true}) async {
    final scanner = _ref.read(libraryScannerProvider);
    final target = folders ?? state.folders;
    if (target.isEmpty) {
      state = state.copyWith(loading: false, resetProgress: true);
      await load();
      return 0;
    }
    state = state.copyWith(
      loading: true,
      scanProgress: 0,
      scanMessage: 'Preparing…',
      scanTotal: null,
    );
    final newTracks = <Track>[];
    final added = await scanner.scan(
      folders: target,
      onProgress: (p) {
        state = state.copyWith(
          scanProgress: p.fraction,
          scanMessage: p.currentFile,
          scanTotal: p.total,
        );
      },
      onNewTrack: newTracks.add,
    );

    // Auto-enrichment via Genius — only if enabled in settings and a
    // valid token is present. We only run this over genuinely new
    // tracks so we don't hit Genius again on a re-scan.
    final enricher = _ref.read(geniusEnricherProvider);
    final autoEnrich = _ref.read(geniusAutoEnrichProvider);
    if (enricher != null && autoEnrich && newTracks.isNotEmpty) {
      var done = 0;
      for (final track in newTracks) {
        state = state.copyWith(
          scanMessage:
              'Enriching ${done + 1}/${newTracks.length}: ${track.displayTitle}',
        );
        try {
          final result = await enricher.enrichTrack(track);
          if (result != null) {
            try {
              await updateTrackTags(track, result.edits);
            } finally {
              await GeniusEnricher.disposeEnrichment(result);
            }
          }
        } catch (_) {
          // Network/ID3/etc failed — skip this track and move on.
        }
        done++;
      }
    }

    state = state.copyWith(loading: false, resetProgress: reset);
    await load();
    return added;
  }

  Future<void> removeFolder(String path) async {
    final repo = _ref.read(libraryRepositoryProvider);
    await repo.removeWatchedFolder(path);
    await load();
  }

  /// Completely removes a track from disk and the DB, updating all
  /// dependent caches (library, favorites, albums, artists).
  Future<void> removeTrack(Track track) async {
    final repo = _ref.read(libraryRepositoryProvider);
    await repo.deleteTrack(track);
    await load();
    _ref.invalidate(albumsProvider);
    _ref.invalidate(artistsProvider);
    _ref.invalidate(favoriteTracksProvider);
    _ref.invalidate(favoriteAlbumsProvider);
    _ref.invalidate(favoriteArtistsProvider);
  }

  /// Writes [edits] to the [track]'s file and updates the corresponding
  /// record in the DB, preserving `id`, `addedAt`, and `isFavorite`.
  /// Returns the updated track.
  Future<Track> updateTrackTags(Track track, TagEdits edits) async {
    final writer = _ref.read(metadataWriterProvider);
    final repo = _ref.read(libraryRepositoryProvider);

    final oldCoverPath = track.coverPath;
    final meta = await writer.apply(track.path, edits);

    final stat = await File(track.path).stat();
    final updated = track.copyWith(
      title: meta.title,
      artist: meta.artist,
      album: meta.album,
      albumArtist: meta.albumArtist,
      year: meta.year,
      trackNumber: meta.trackNumber,
      discNumber: meta.discNumber,
      duration:
          meta.duration == Duration.zero ? track.duration : meta.duration,
      genre: meta.genre,
      coverPath: meta.coverPath,
      lyricsText: meta.lyrics,
      fileSize: stat.size,
      modifiedAt: stat.modified,
    );
    await repo.upsertTrack(updated);

    // Evict the image cache for both the old and new covers, otherwise
    // Flutter will show a stale image from memory (especially when the
    // cover is overwritten at the same path).
    if (oldCoverPath != null && oldCoverPath.isNotEmpty) {
      CoverArt.invalidate(oldCoverPath);
      PaintingBinding.instance.imageCache.evict(FileImage(File(oldCoverPath)));
    }
    if (meta.coverPath != null && meta.coverPath != oldCoverPath) {
      CoverArt.invalidate(meta.coverPath!);
      PaintingBinding.instance.imageCache.evict(FileImage(File(meta.coverPath!)));
    }

    await load();
    _ref.invalidate(albumsProvider);
    _ref.invalidate(artistsProvider);
    _ref.invalidate(favoriteTracksProvider);
    _ref.invalidate(favoriteAlbumsProvider);
    _ref.invalidate(favoriteArtistsProvider);
    return updated;
  }
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
  return LibraryController(ref);
});

final watchedFoldersProvider = Provider<List<String>>((ref) {
  return ref.watch(libraryControllerProvider).folders;
});

final allTracksProvider = Provider<List<Track>>((ref) {
  return ref.watch(libraryControllerProvider).tracks;
});

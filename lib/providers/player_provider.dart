import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/track.dart';
import '../services/player_service.dart';
import '../services/lyrics/lrclib_client.dart';
import '../services/lyrics/sylt_writer.dart';
import 'core_providers.dart';
import 'library_provider.dart';

final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) {
  final player = ref.watch(playerServiceProvider);
  return player.snapshot;
});

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController(ref);
});

class PlayerController {
  PlayerController(this._ref);
  final Ref _ref;

  PlayerService get _service => _ref.read(playerServiceProvider);

  Future<void> playQueue(
    List<Track> tracks, {
    int? startIndex,
    bool autoPlay = true,
    ({String album, String artist})? albumKey,
  }) {
    return _service.setQueue(
      tracks,
      startIndex: startIndex,
      autoPlay: autoPlay,
      albumKey: albumKey,
    );
  }

  Future<void> shuffleList(List<Track> tracks) => _service.shuffleList(tracks);

  Future<void> playTrack(Track track, {List<Track>? context}) {
    return _service.playTrack(track, context: context);
  }

  Future<void> playPause() async {
    final isPlaying = _service.snapshotValue.playing;
    if (isPlaying) {
      await _service.pause();
    } else {
      await _service.play();
    }
  }

  Future<void> next() => _service.next();
  Future<void> previous() => _service.previous();
  Future<void> seek(Duration p) => _service.seek(p);
  Future<void> setVolume(double v) => _service.setVolume(v);
  Future<void> toggleMute() => _service.toggleMute();
  Future<void> clearError() => _service.clearErrorAsync();
  Future<void> setSpeed(double s) => _service.setSpeed(s);
  Future<void> cycleRepeat() => _service.cycleRepeat();
  Future<void> jumpTo(int userIndex) => _service.jumpTo(userIndex);
  Future<void> removeFromQueue(int userIndex) =>
      _service.removeFromQueue(userIndex);

  Future<void> removeTrackFromQueue(String path) =>
      _service.removeTrackFromQueue(path);

  /// Syncs lyrics via LRCLib — an open database of professionally
  /// synced lyrics.
  ///
  /// Flow:
  /// 1. Get the up-to-date track from the library (for current tags).
  /// 2. Query LRCLib by `(artist, title, album, duration)`.
  ///    First an exact match, then a fuzzy search.
  /// 3. If `syncedLyrics` is present — store the LRC in the DB and SYLT in the MP3.
  /// 4. If only `plainLyrics` is present — update the plain text in the DB.
  /// 5. If nothing is found — throw [LrclibException(notFound)].
  Future<void> syncLyrics({
    required int trackId,
    String? audioPath, // not used by the LRCLib flow, kept for compatibility
    String? plainLyrics, // also unused; lyrics come from LRCLib
  }) async {
    final repo = _ref.read(libraryRepositoryProvider);
    final tracks = _ref.read(libraryControllerProvider).tracks;
    final track = tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => throw const LrclibException(
        LrclibErrorKind.notFound,
        'Track not found in the library',
      ),
    );
    if (track.displayTitle.trim().isEmpty ||
        track.displayArtist.trim().isEmpty ||
        track.displayArtist == 'Unknown Artist') {
      throw const LrclibException(
        LrclibErrorKind.notFound,
        'Valid tags (artist + title) are required for search. '
            'Try "Find on Genius" to fill in the tags.',
      );
    }

    final client = LrclibClient();
    LrclibResult? result;
    try {
      result = await client.findBest(
        trackName: track.displayTitle,
        artistName: track.displayArtist,
        albumName: track.album.isEmpty || track.album == 'Unknown Album'
            ? null
            : track.album,
        durationSeconds: track.duration.inSeconds > 0
            ? track.duration.inSeconds
            : null,
      );
    } finally {
      client.dispose();
    }

    if (result == null || (!result.hasSynced && !result.hasPlain)) {
      throw const LrclibException(
        LrclibErrorKind.notFound,
        'LRCLib found no lyrics for this track',
      );
    }

    if (result.hasSynced) {
      final lrc = result.syncedLyrics!.trim();
      await repo.updateLyricsLrc(trackId, lrc);
      // Also write SYLT to the MP3 — the lyrics stay even without the DB.
      final pathLower = (audioPath ?? track.path).toLowerCase();
      if (pathLower.endsWith('.mp3')) {
        try {
          await writeSyltLrcToMp3(
            filePath: audioPath ?? track.path,
            lrcContent: lrc,
          );
        } catch (_) {
          // Not critical: the LRC is in the DB regardless.
        }
      }
    }
    if (result.hasPlain) {
      // If the track doesn't have plain text yet — fill it in from LRCLib.
      if ((track.lyricsText ?? '').trim().isEmpty) {
        await repo.updateLyricsText(trackId, result.plainLyrics!.trim());
      }
    }

    await _ref.read(libraryControllerProvider.notifier).load();
  }
}

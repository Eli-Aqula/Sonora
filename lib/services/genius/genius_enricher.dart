import '../../data/models/track.dart';
import '../metadata_writer.dart';
import 'cover_downloader.dart';
import 'genius_client.dart';
import 'genius_models.dart';
import 'match_scorer.dart';

/// Result of automatically enriching a single track.
///
/// `edits` is the set of changes to apply to the file (via
/// `LibraryController.updateTrackTags`). If `edits.cover` is a
/// `CoverReplace`, it points to a temporary file; the calling code
/// **must** call [GeniusEnricher.disposeEnrichment] after writing.
class GeniusEnrichment {
  final GeniusSong song;
  final TagEdits edits;
  final double score;
  const GeniusEnrichment({
    required this.song,
    required this.edits,
    required this.score,
  });
}

/// Runs a single track through Genius and returns [TagEdits] that fill
/// in only the empty local fields. No side effects on the DB/files --
/// that's the responsibility of the calling code.
///
/// Usage:
/// ```dart
/// final r = await enricher.enrichTrack(track);
/// if (r != null) {
///   try {
///     await library.updateTrackTags(track, r.edits);
///   } finally {
///     await GeniusEnricher.disposeEnrichment(r);
///   }
/// }
/// ```
class GeniusEnricher {
  GeniusEnricher(this._client);
  final GeniusClient _client;

  /// Minimum score of the best hit for auto-applying without user
  /// involvement. 0.7 is an empirical compromise: lower catches too many
  /// false positives on one-word tracks and covers; higher and we'd skip
  /// some "good but not confident" matches (the user can pick those
  /// manually).
  static const autoApplyThreshold = 0.7;

  /// Returns null if:
  /// - nothing was found,
  /// - the best hit is below [autoApplyThreshold],
  /// - local tags are already complete and the cover is in place --
  ///   nothing to fill in.
  Future<GeniusEnrichment?> enrichTrack(Track track) async {
    final hits = await _client.search(buildGeniusQuery(track));
    final top = MatchScorer.topMatches(hits, track);
    if (top.isEmpty) return null;
    final best = top.first;
    if (best.score < autoApplyThreshold) return null;

    final songs = await MatchScorer.enrich(_client, [best.hit]);
    if (songs.isEmpty) return null;
    final song = songs.first;

    final edits = await _buildEdits(track, song);
    if (edits == null) return null;
    return GeniusEnrichment(song: song, edits: edits, score: best.score);
  }

  /// Deletes the temporary cover file from [enrichment] (if one was
  /// downloaded). Safe to call with null.
  static Future<void> disposeEnrichment(GeniusEnrichment enrichment) async {
    final c = enrichment.edits.cover;
    if (c is CoverReplace) {
      await CoverDownloader.deleteTemp(c.imagePath);
    }
  }

  // ─── Internals ────────────────────────────────────────────────────────

  /// Builds [TagEdits], filling in only the fields that are locally
  /// empty. Returns null if there's nothing to fill in (and in that case
  /// has already cleaned up the temporary cover file, if one was
  /// downloaded).
  Future<TagEdits?> _buildEdits(Track track, GeniusSong song) async {
    String? fillIfEmpty(String local, String? candidate) {
      if (local.isNotEmpty) return null;
      if (candidate == null) return null;
      final t = candidate.trim();
      return t.isEmpty ? null : t;
    }

    final title = fillIfEmpty(track.title, song.title);
    final artist = fillIfEmpty(track.artist, song.primaryArtistName);
    final album = fillIfEmpty(track.album, song.album?.name);
    final year = track.year == null ? song.releaseDate?.year : null;
    final lyrics = track.lyricsText == null ? song.lyricsText : null;

    String? tempCover;
    if (track.coverPath == null && track.id != null) {
      final coverUrl = song.songArtImageUrl ?? song.headerImageUrl;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        tempCover = await CoverDownloader.downloadToTemp(
          coverUrl,
          songId: track.id!,
        );
      }
    }

    final hasAny = title != null ||
        artist != null ||
        album != null ||
        year != null ||
        lyrics != null ||
        tempCover != null;
    if (!hasAny) {
      await CoverDownloader.deleteTemp(tempCover);
      return null;
    }

    return TagEdits(
      title: title,
      trackArtist: artist,
      album: album,
      year: year,
      lyrics: lyrics,
      cover: tempCover != null
          ? CoverReplace(tempCover)
          : const CoverKeep(),
    );
  }
}

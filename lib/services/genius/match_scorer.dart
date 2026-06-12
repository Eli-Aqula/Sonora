import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../data/models/track.dart';
import 'genius_client.dart';
import 'genius_models.dart';

/// Result of scoring a single hit: (hit, score 0..1).
class ScoredHit {
  final GeniusHit hit;
  final double score;
  const ScoredHit(this.hit, this.score);
}

/// Scoring and enrichment of Genius search results.
///
/// Uses simple string normalization + word-based Jaccard similarity. No
/// dependencies and no ML. Good enough for filtering out clearly bad
/// matches and ranking the good ones.
class MatchScorer {
  /// Minimum score for a hit to make it into the picker.
  static const minScore = 0.35;

  /// Number of top candidates after scoring that we enrich.
  static const topN = 5;

  // Component weights.
  static const _wTitle = 0.45;
  static const _wArtist = 0.30;
  static const _wDuration = 0.20;
  static const _wAlbum = 0.05;

  /// Scores a hit relative to the local track. Returns a number in
  /// [0..1].
  static double scoreHit(GeniusHit hit, Track track) {
    final t = tokenSetRatio(normalize(track.displayTitle),
        normalize(hit.titleWithFeatured.isNotEmpty
            ? hit.titleWithFeatured
            : hit.title));
    final a = tokenSetRatio(normalize(track.displayArtist),
        normalize(hit.primaryArtistName));
    final d = durationScore(hit.durationSeconds, track.duration.inSeconds);
    final al = albumScore(hit.album?.name, track.displayAlbum);

    var s = _wTitle * t + _wArtist * a + _wDuration * d + _wAlbum * al;
    if (s < 0) s = 0;
    if (s > 1) s = 1;
    return s;
  }

  /// Sorts hits by descending score, drops those < [minScore], takes
  /// [topN].
  static List<ScoredHit> topMatches(
      List<GeniusHit> hits, Track track) {
    final scored = <ScoredHit>[];
    for (final h in hits) {
      final s = scoreHit(h, track);
      if (s >= minScore) scored.add(ScoredHit(h, s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.length > topN) return scored.sublist(0, topN);
    return scored;
  }

  /// Enriches the list of hits with full song data (in order). Uses the
  /// client's cache, so repeated calls for the same id are instant.
  static Future<List<GeniusSong>> enrich(
      GeniusClient client, List<GeniusHit> hits) async {
    final out = <GeniusSong>[];
    for (final h in hits) {
      try {
        out.add(await client.getSong(h.id));
      } on GeniusException {
        // Don't fail the whole list because of one broken hit.
        continue;
      }
    }
    return out;
  }

  // ─── Normalization and similarity ──────────────────────────────────────

  /// Brings a string to a canonical form: lowercase, no diacritics, no
  /// content in brackets, no feat./ft./prod., no punctuation.
  static String normalize(String s) {
    var t = s.toLowerCase();
    // Remove the contents of brackets/parentheses: "(Remix 2020)" -> "".
    t = t.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]'), ' ');
    // Remove feat./production markers.
    final featPattern = RegExp(
      r'\b(feat\.?|featuring|ft\.?|prod\.?|produced by|with)\b.*$',
    );
    t = t.replaceAll(featPattern, '');
    // Strip everything that's not a letter/digit/whitespace.
    t = t.replaceAll(RegExp(r'[^a-zа-я0-9\s]'), ' ');
    // Collapse whitespace.
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// Jaccard similarity over sets of words. Returns 0..1.
  /// An empty string -> 0.
  static double tokenSetRatio(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final setA = a.split(' ').toSet();
    final setB = b.split(' ').toSet();
    if (setA.isEmpty || setB.isEmpty) return 0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  /// Comparison by duration: 0 if there's no data, 1 if <=2s, a linear
  /// falloff to 0 at 15s+.
  @visibleForTesting
  static double durationScore(int? hitSeconds, int trackSeconds) {
    if (hitSeconds == null || hitSeconds <= 0) return 0.5; // no data -- neutral
    if (trackSeconds <= 0) return 0.5;
    final diff = (hitSeconds - trackSeconds).abs();
    if (diff <= 2) return 1.0;
    if (diff >= 15) return 0.0;
    // Linear falloff from 1.0 (diff=2) to 0.0 (diff=15).
    return 1.0 - (diff - 2) / 13.0;
  }

  /// Bonus for an album match (0..1, low weight).
  @visibleForTesting
  static double albumScore(String? hitAlbum, String trackAlbum) {
    if (hitAlbum == null || hitAlbum.isEmpty) return 0;
    if (trackAlbum.isEmpty || trackAlbum == 'Unknown Album') return 0;
    return tokenSetRatio(normalize(hitAlbum), normalize(trackAlbum));
  }
}

/// Builds the initial Genius search query from a local track:
/// "artist title" (artist is omitted if empty or "Unknown Artist").
String buildGeniusQuery(Track track) {
  final title = track.displayTitle.trim();
  final artist = track.displayArtist.trim();
  if (artist.isEmpty || artist == 'Unknown Artist') {
    return title;
  }
  return '$artist $title';
}

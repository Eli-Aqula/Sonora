import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of an LRCLib request.
class LrclibResult {
  /// Synced LRC (with `[mm:ss.xx]` timecodes), if available.
  final String? syncedLyrics;

  /// Plain text without timecodes (always present for non-instrumentals).
  final String? plainLyrics;

  /// True if LRCLib marked the track as instrumental.
  final bool instrumental;

  /// Track name, artist and album as reported by LRCLib — for debugging/UI.
  final String trackName;
  final String artistName;
  final String albumName;

  const LrclibResult({
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.instrumental,
    this.syncedLyrics,
    this.plainLyrics,
  });

  bool get hasSynced => (syncedLyrics ?? '').trim().isNotEmpty;
  bool get hasPlain => (plainLyrics ?? '').trim().isNotEmpty;
}

enum LrclibErrorKind {
  notFound,
  network,
  server,
}

class LrclibException implements Exception {
  final LrclibErrorKind kind;
  final String message;
  const LrclibException(this.kind, this.message);
  @override
  String toString() => 'LrclibException($kind): $message';
}

/// HTTP client for LRCLib (https://lrclib.net/docs).
///
/// LRCLib is an open database of synced song lyrics. No authorization,
/// no quotas per the official rules. The quality is higher than any
/// automatic alignment because the LRC files are written by people.
///
/// Workflow:
/// 1. [getByMetadata] — exact search by artist+title+album+duration.
///    Returns the result if there's an exact `duration` match (±2 sec).
/// 2. [search] — fuzzy search as a fallback. We take the best hit from the top.
class LrclibClient {
  static const _base = 'https://lrclib.net';
  static const _ua =
      'Sonora/0.1 (https://github.com/local/sonora)';
  static const _timeout = Duration(seconds: 10);

  final http.Client _http;
  final bool _ownsHttp;

  LrclibClient({http.Client? client})
      : _http = client ?? http.Client(),
        _ownsHttp = client == null;

  void dispose() {
    if (_ownsHttp) _http.close();
  }

  /// A direct "give me an exact match" request. Returns null if no
  /// record exists (404). Throws on network/server errors.
  Future<LrclibResult?> getByMetadata({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    final params = <String, String>{
      'track_name': trackName,
      'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
      if (durationSeconds != null && durationSeconds > 0)
        'duration': durationSeconds.toString(),
    };
    final uri = Uri.parse('$_base/api/get').replace(queryParameters: params);
    try {
      final res = await _http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) {
        throw LrclibException(
          LrclibErrorKind.server,
          'HTTP ${res.statusCode}',
        );
      }
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map<String, dynamic>) {
        throw const LrclibException(
          LrclibErrorKind.server,
          'Malformed JSON from LRCLib',
        );
      }
      return _resultFromJson(json);
    } on TimeoutException {
      throw const LrclibException(
        LrclibErrorKind.network,
        'LRCLib request timed out',
      );
    } on LrclibException {
      rethrow;
    } catch (e) {
      throw LrclibException(LrclibErrorKind.network, 'Network error: $e');
    }
  }

  /// Fuzzy search. Returns the first result with syncedLyrics if any;
  /// otherwise the first result overall; otherwise null.
  Future<LrclibResult?> search({
    required String trackName,
    required String artistName,
    String? albumName,
  }) async {
    final params = <String, String>{
      'track_name': trackName,
      'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
    };
    final uri =
        Uri.parse('$_base/api/search').replace(queryParameters: params);
    try {
      final res = await _http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) {
        throw LrclibException(
          LrclibErrorKind.server,
          'HTTP ${res.statusCode}',
        );
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! List) return null;
      final items =
          body.whereType<Map<String, dynamic>>().map(_resultFromJson).toList();
      if (items.isEmpty) return null;
      final withSynced =
          items.firstWhere((r) => r.hasSynced, orElse: () => items.first);
      return withSynced;
    } on TimeoutException {
      throw const LrclibException(
        LrclibErrorKind.network,
        'LRCLib request timed out',
      );
    } on LrclibException {
      rethrow;
    } catch (e) {
      throw LrclibException(LrclibErrorKind.network, 'Network error: $e');
    }
  }

  /// A convenient "exact first, then fuzzy" flow.
  Future<LrclibResult?> findBest({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    final exact = await getByMetadata(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      durationSeconds: durationSeconds,
    );
    if (exact != null && (exact.hasSynced || exact.hasPlain)) return exact;
    return search(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
    );
  }

  Map<String, String> get _headers => {
        'User-Agent': _ua,
        'Accept': 'application/json',
      };

  static LrclibResult _resultFromJson(Map<String, dynamic> json) {
    return LrclibResult(
      trackName: (json['trackName'] as String?) ?? '',
      artistName: (json['artistName'] as String?) ?? '',
      albumName: (json['albumName'] as String?) ?? '',
      instrumental: (json['instrumental'] as bool?) ?? false,
      syncedLyrics: json['syncedLyrics'] as String?,
      plainLyrics: json['plainLyrics'] as String?,
    );
  }
}

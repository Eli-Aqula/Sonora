import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'genius_models.dart';
import 'lyrics_scraper.dart';

/// Exception thrown by the Genius client. [kind] is the category for the UI.
enum GeniusErrorKind {
  unauthorized,    // 401: invalid token
  notFound,        // 404
  rateLimited,     // 429
  server,          // 5xx
  network,         // timeout / no network / malformed JSON
}

class GeniusException implements Exception {
  final GeniusErrorKind kind;
  final String message;
  final int? statusCode;
  const GeniusException(this.kind, this.message, {this.statusCode});

  @override
  String toString() => 'GeniusException($kind, $statusCode): $message';
}

/// HTTP client for the Genius API.
///
/// Features:
/// - A single token for the entire lifetime of the instance.
/// - Throttling of ~1 request/sec between ANY two requests.
/// - A 10-second timeout per request.
/// - On a 429, one retry after 5 seconds, then an exception.
/// - An internal cache of full song data (by id) for the instance's
///   lifetime.
class GeniusClient {
  static const _apiHost = 'https://api.genius.com';
  static const _userAgent =
      'Sonora/0.1 (https://github.com/local/sonora)';
  static const _minRequestInterval = Duration(milliseconds: 1100);
  static const _retryDelay = Duration(seconds: 5);
  static const _requestTimeout = Duration(seconds: 10);

  final String token;
  final http.Client _http;

  /// Throttling chain: "is some request currently in flight".
  Future<void> _inflight = Future.value();
  DateTime? _lastRequest;

  /// Cache of full song data: id -> GeniusSong.
  final Map<int, GeniusSong> _songCache = <int, GeniusSong>{};

  /// Cache of artists for the instance's lifetime.
  final Map<int, GeniusArtist> _artistCache = <int, GeniusArtist>{};

  GeniusClient(this.token, {http.Client? client})
      : _http = client ?? http.Client();

  void dispose() {
    _http.close();
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      };

  // ─── High-level API ───────────────────────────────────────────────────

  /// Searches for songs. [query] does not need to be URL-encoded.
  Future<List<GeniusHit>> search(String query, {int perPage = 10}) async {
    final uri = Uri.parse('$_apiHost/search').replace(queryParameters: {
      'q': query,
      'per_page': perPage.toString(),
    });
    final body = await _getJson(uri);
    return GeniusSearchResponse.fromJson(body).hits;
  }

  /// Full song data by id. Cached.
  /// [textFormat] specifies which text variants to return (dom, plain,
  /// html). By default we request plain-text lyrics.
  ///
  /// If [fetchLyrics] = true (the default), additionally fetches the
  /// Genius page HTML and parses the plain-text lyrics from it -- the
  /// public API does not return lyrics, and without this
  /// `song.lyricsText` would always be `null`.
  Future<GeniusSong> getSong(
    int id, {
    String textFormat = 'plain',
    bool fetchLyrics = true,
  }) async {
    final cached = _songCache[id];
    if (cached != null) {
      if (!fetchLyrics || cached.lyricsText != null) return cached;
      // Cached without lyrics (e.g. after an album search with
      // fetchLyrics: false) -- fetch just the lyrics, without re-requesting
      // the full song data.
      final scraped = await _fetchLyricsForUrl(cached.url);
      if (scraped != null && scraped.isNotEmpty) {
        final updated = cached.copyWithLyrics(scraped);
        _songCache[id] = updated;
        return updated;
      }
      return cached;
    }
    final uri = Uri.parse('$_apiHost/songs/$id').replace(
      queryParameters: {'text_format': textFormat},
    );
    final body = await _getJson(uri);
    final response = body['response'] as Map<String, dynamic>?;
    if (response == null) {
      throw const GeniusException(
        GeniusErrorKind.server,
        'Empty response from Genius',
      );
    }
    final songJson = response['song'] is Map<String, dynamic>
        ? response['song'] as Map<String, dynamic>
        : response;
    var song = GeniusSong.fromJson(songJson);

    if (fetchLyrics && (song.lyricsText == null || song.lyricsText!.isEmpty)) {
      final scraped = await _fetchLyricsForUrl(song.url);
      if (scraped != null && scraped.isNotEmpty) {
        song = song.copyWithLyrics(scraped);
      }
    }

    _songCache[id] = song;
    return song;
  }

  /// Full artist data (`/artists/:id`). Cached.
  Future<GeniusArtist> getArtist(
    int id, {
    String textFormat = 'plain',
  }) async {
    final cached = _artistCache[id];
    if (cached != null) return cached;
    final uri = Uri.parse('$_apiHost/artists/$id').replace(
      queryParameters: {'text_format': textFormat},
    );
    final body = await _getJson(uri);
    final response = body['response'] as Map<String, dynamic>?;
    final artistJson = response?['artist'] as Map<String, dynamic>?;
    if (artistJson == null) {
      throw const GeniusException(
        GeniusErrorKind.server,
        'Empty response from /artists',
      );
    }
    final artist = GeniusArtist.fromJson(artistJson);
    _artistCache[id] = artist;
    return artist;
  }

  /// Fetches the Genius song page HTML and parses the lyrics. Goes
  /// through the same throttling -- Genius's public pages also don't like
  /// a high request rate. Returns `null` if the page is empty/failed to
  /// load.
  Future<String?> _fetchLyricsForUrl(String url) async {
    if (url.isEmpty) return null;
    await _throttle();
    try {
      return await fetchGeniusLyrics(url, client: _http);
    } catch (_) {
      return null;
    }
  }

  // ─── Internals ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    await _throttle();
    try {
      final res = await _http.get(uri, headers: _headers).timeout(_requestTimeout);
      if (res.statusCode == 429) {
        return _retryAfter429(uri);
      }
      return _parse(res, uri);
    } on TimeoutException {
      throw const GeniusException(
        GeniusErrorKind.network,
        'Genius request timed out',
      );
    } catch (e) {
      if (e is GeniusException) rethrow;
      throw GeniusException(
        GeniusErrorKind.network,
        'Network error: $e',
      );
    }
  }

  /// Throttling: guarantees that at least [_minRequestInterval] elapses
  /// between any two requests. Serializes requests via [_inflight].
  Future<void> _throttle() {
    final completer = Completer<void>();
    final prev = _inflight;
    _inflight = completer.future;
    Future<void>(() async {
      try {
        await prev;
      } catch (_) {
        // Ignore errors from the previous request -- we only care that
        // it has finished.
      }
      final now = DateTime.now();
      final last = _lastRequest;
      if (last != null) {
        final wait = _minRequestInterval - now.difference(last);
        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        }
      }
      _lastRequest = DateTime.now();
      completer.complete();
    });
    return completer.future;
  }

  Map<String, dynamic> _parse(http.Response res, Uri uri) {
    final status = res.statusCode;

    if (status == 401) {
      throw const GeniusException(
        GeniusErrorKind.unauthorized,
        'Genius token is invalid',
        statusCode: 401,
      );
    }
    if (status == 404) {
      throw const GeniusException(
        GeniusErrorKind.notFound,
        'Not found on Genius',
        statusCode: 404,
      );
    }
    if (status >= 500) {
      throw GeniusException(
        GeniusErrorKind.server,
        'Genius server unavailable (HTTP $status)',
        statusCode: status,
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw GeniusException(
        GeniusErrorKind.server,
        'Failed to parse Genius response (HTTP $status)',
        statusCode: status,
      );
    }

    if (status == 200) return body;

    throw GeniusException(
      GeniusErrorKind.server,
      'Genius returned HTTP $status',
      statusCode: status,
    );
  }

  Future<Map<String, dynamic>> _retryAfter429(Uri uri) async {
    await Future<void>.delayed(_retryDelay);
    _lastRequest = DateTime.now();
    final res =
        await _http.get(uri, headers: _headers).timeout(_requestTimeout);
    final code = res.statusCode;
    if (code == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw GeniusException(
      GeniusErrorKind.rateLimited,
      'Genius request rate limit exceeded',
      statusCode: code,
    );
  }
}

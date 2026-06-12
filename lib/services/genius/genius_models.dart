/// DTOs for Genius API responses.
///
/// Genius returns JSON shaped like:
/// ```json
/// { "meta": { "status": 200 }, "response": { ... } }
/// ```
/// or for errors: `{ "meta": { "status": 401, "message": "..." } }`.
library;

/// Year/month/day (may be absent).
class GeniusDateComponents {
  final int? year;
  final int? month;
  final int? day;
  const GeniusDateComponents({this.year, this.month, this.day});

  factory GeniusDateComponents.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GeniusDateComponents();
    return GeniusDateComponents(
      year: json['year'] as int?,
      month: json['month'] as int?,
      day: json['day'] as int?,
    );
  }
}

/// Album (nested object in `/songs/:id`, may be absent for singles).
class GeniusAlbum {
  final int? id;
  final String? name;
  final String? coverArtUrl;
  final String? artistName;
  const GeniusAlbum({this.id, this.name, this.coverArtUrl, this.artistName});

  factory GeniusAlbum.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GeniusAlbum();
    final artist = json['artist'] as Map<String, dynamic>?;
    return GeniusAlbum(
      id: json['id'] as int?,
      name: json['name'] as String?,
      coverArtUrl: json['cover_art_url'] as String?,
      artistName: artist?['name'] as String?,
    );
  }
}

/// A single search result (`hits[].result` in `/search`).
class GeniusHit {
  final int id;
  final String title;
  final String titleWithFeatured;
  final String primaryArtistName;
  final int? primaryArtistId;
  final String? headerImageUrl;
  final String? songArtImageUrl;
  final String url;
  final int? durationSeconds;
  final GeniusDateComponents? releaseDate;
  final GeniusAlbum? album;

  const GeniusHit({
    required this.id,
    required this.title,
    required this.titleWithFeatured,
    required this.primaryArtistName,
    required this.url,
    this.primaryArtistId,
    this.headerImageUrl,
    this.songArtImageUrl,
    this.durationSeconds,
    this.releaseDate,
    this.album,
  });

  factory GeniusHit.fromJson(Map<String, dynamic> json) {
    final artist = json['primary_artist'] as Map<String, dynamic>?;
    return GeniusHit(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      titleWithFeatured:
          (json['title_with_featured'] as String?) ?? (json['title'] as String?) ?? '',
      primaryArtistName: (artist?['name'] as String?) ?? '',
      primaryArtistId: (artist?['id'] as num?)?.toInt(),
      headerImageUrl: json['header_image_url'] as String?,
      songArtImageUrl: json['song_art_image_url'] as String?,
      url: (json['url'] as String?) ?? '',
      durationSeconds: (json['duration'] as num?)?.toInt(),
      releaseDate: GeniusDateComponents.fromJson(
        json['release_date_components'] as Map<String, dynamic>?,
      ),
      album: json['album'] is Map<String, dynamic>
          ? GeniusAlbum.fromJson(json['album'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Full song data (`/songs/:id`).
class GeniusSong {
  final int id;
  final String title;
  final String titleWithFeatured;
  final String primaryArtistName;
  final String artistNames;
  final String url;
  final int? durationSeconds;
  final String? headerImageUrl;
  final String? songArtImageUrl;
  final GeniusDateComponents? releaseDate;
  final GeniusAlbum? album;
  final String? lyricsText;

  const GeniusSong({
    required this.id,
    required this.title,
    required this.titleWithFeatured,
    required this.primaryArtistName,
    required this.artistNames,
    required this.url,
    this.durationSeconds,
    this.headerImageUrl,
    this.songArtImageUrl,
    this.releaseDate,
    this.album,
    this.lyricsText,
  });

  /// Returns a copy with [lyricsText] overwritten. Used when the lyrics
  /// have been fetched from the Genius page HTML (the API doesn't return
  /// them).
  GeniusSong copyWithLyrics(String? lyrics) {
    return GeniusSong(
      id: id,
      title: title,
      titleWithFeatured: titleWithFeatured,
      primaryArtistName: primaryArtistName,
      artistNames: artistNames,
      url: url,
      durationSeconds: durationSeconds,
      headerImageUrl: headerImageUrl,
      songArtImageUrl: songArtImageUrl,
      releaseDate: releaseDate,
      album: album,
      lyricsText: lyrics,
    );
  }

  factory GeniusSong.fromJson(Map<String, dynamic> json) {
    final artist = json['primary_artist'] as Map<String, dynamic>?;
    final album = json['album'];
    String? lyrics;
    final lyricsObj = json['lyrics'];
    if (lyricsObj is Map<String, dynamic>) {
      lyrics = lyricsObj['plain'] as String?;
    }
    return GeniusSong(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      titleWithFeatured:
          (json['title_with_featured'] as String?) ?? (json['title'] as String?) ?? '',
      primaryArtistName: (artist?['name'] as String?) ?? '',
      artistNames: (json['artist_names'] as String?) ??
          (artist?['name'] as String?) ??
          '',
      url: (json['url'] as String?) ?? '',
      durationSeconds: (json['duration'] as num?)?.toInt(),
      headerImageUrl: json['header_image_url'] as String?,
      songArtImageUrl: json['song_art_image_url'] as String?,
      releaseDate: GeniusDateComponents.fromJson(
        json['release_date_components'] as Map<String, dynamic>?,
      ),
      album: album is Map<String, dynamic>
          ? GeniusAlbum.fromJson(album)
          : null,
      lyricsText: lyrics,
    );
  }
}

/// Artist (minimum for the UI: name, photo, description).
class GeniusArtist {
  final int id;
  final String name;
  final String url;
  final String? imageUrl;
  final String? headerImageUrl;
  final String? descriptionPlain;
  final List<String> alternateNames;

  const GeniusArtist({
    required this.id,
    required this.name,
    required this.url,
    this.imageUrl,
    this.headerImageUrl,
    this.descriptionPlain,
    this.alternateNames = const [],
  });

  factory GeniusArtist.fromJson(Map<String, dynamic> json) {
    String? description;
    final desc = json['description'];
    if (desc is Map<String, dynamic>) {
      description = desc['plain'] as String?;
    }
    final alt = (json['alternate_names'] as List<dynamic>?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    return GeniusArtist(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
      headerImageUrl: json['header_image_url'] as String?,
      descriptionPlain: description,
      alternateNames: alt,
    );
  }
}

/// Response of `/search`: `response.hits[]` (each hit is `hits[].result`).
class GeniusSearchResponse {
  final List<GeniusHit> hits;
  const GeniusSearchResponse({required this.hits});

  factory GeniusSearchResponse.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>?;
    final rawHits = (response?['hits'] as List<dynamic>?) ?? const [];
    final hits = <GeniusHit>[];
    for (final h in rawHits) {
      final m = h as Map<String, dynamic>;
      final result = m['result'];
      if (result is Map<String, dynamic>) {
        hits.add(GeniusHit.fromJson(result));
      }
    }
    return GeniusSearchResponse(hits: hits);
  }
}

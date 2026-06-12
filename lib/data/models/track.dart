class Track {
  final int? id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final Duration duration;
  final String? genre;
  final int? bitrate;
  final int? sampleRate;
  final int? fileSize;
  final String? coverPath;
  final DateTime addedAt;
  final DateTime modifiedAt;
  final bool isFavorite;
  final String? lyricsText;
  final String? lyricsLrc;

  const Track({
    this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist,
    this.year,
    this.trackNumber,
    this.discNumber,
    required this.duration,
    this.genre,
    this.bitrate,
    this.sampleRate,
    this.fileSize,
    this.coverPath,
    required this.addedAt,
    required this.modifiedAt,
    this.isFavorite = false,
    this.lyricsText,
    this.lyricsLrc,
  });

  Track copyWith({
    int? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    int? year,
    int? trackNumber,
    int? discNumber,
    Duration? duration,
    String? genre,
    int? bitrate,
    int? sampleRate,
    int? fileSize,
    String? coverPath,
    DateTime? addedAt,
    DateTime? modifiedAt,
    bool? isFavorite,
    String? lyricsText,
    String? lyricsLrc,
  }) {
    return Track(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      duration: duration ?? this.duration,
      genre: genre ?? this.genre,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      fileSize: fileSize ?? this.fileSize,
      coverPath: coverPath ?? this.coverPath,
      addedAt: addedAt ?? this.addedAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      lyricsText: lyricsText ?? this.lyricsText,
      lyricsLrc: lyricsLrc ?? this.lyricsLrc,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'album_artist': albumArtist,
      'year': year,
      'track_number': trackNumber,
      'disc_number': discNumber,
      'duration_ms': duration.inMilliseconds,
      'genre': genre,
      'bitrate': bitrate,
      'sample_rate': sampleRate,
      'file_size': fileSize,
      'cover_path': coverPath,
      'added_at': addedAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
      'lyrics_text': lyricsText,
      'lyrics_lrc': lyricsLrc,
    };
  }

  factory Track.fromMap(Map<String, Object?> map) {
    return Track(
      id: map['id'] as int?,
      path: map['path'] as String,
      title: map['title'] as String,
      artist: (map['artist'] as String?) ?? 'Unknown Artist',
      album: (map['album'] as String?) ?? 'Unknown Album',
      albumArtist: map['album_artist'] as String?,
      year: map['year'] as int?,
      trackNumber: map['track_number'] as int?,
      discNumber: map['disc_number'] as int?,
      duration: Duration(milliseconds: (map['duration_ms'] as int?) ?? 0),
      genre: map['genre'] as String?,
      bitrate: map['bitrate'] as int?,
      sampleRate: map['sample_rate'] as int?,
      fileSize: map['file_size'] as int?,
      coverPath: map['cover_path'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['added_at'] as int?) ?? 0,
      ),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['modified_at'] as int?) ?? 0,
      ),
      isFavorite: (map['is_favorite'] as int?) == 1,
      lyricsText: map['lyrics_text'] as String?,
      lyricsLrc: map['lyrics_lrc'] as String?,
    );
  }

  String get displayTitle => title.isEmpty ? _basename(path) : title;
  String get displayArtist => artist.isEmpty ? 'Unknown Artist' : artist;
  String get displayAlbum => album.isEmpty ? 'Unknown Album' : album;

  static String _basename(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final idx = path.lastIndexOf(sep);
    final name = idx == -1 ? path : path.substring(idx + 1);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

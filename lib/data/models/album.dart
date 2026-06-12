class Album {
  final String name;
  final String artist;
  final int trackCount;
  final int? year;
  final String? coverPath;
  final Duration totalDuration;

  const Album({
    required this.name,
    required this.artist,
    required this.trackCount,
    this.year,
    this.coverPath,
    this.totalDuration = Duration.zero,
  });

  factory Album.fromMap(Map<String, Object?> map) {
    return Album(
      name: map['album'] as String,
      artist: (map['artist'] as String?) ?? 'Unknown Artist',
      trackCount: (map['track_count'] as int?) ?? 0,
      year: map['year'] as int?,
      coverPath: map['cover_path'] as String?,
      totalDuration: Duration(
        milliseconds: (map['total_duration'] as int?) ?? 0,
      ),
    );
  }
}

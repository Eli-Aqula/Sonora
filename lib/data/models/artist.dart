class Artist {
  final String name;
  final int trackCount;
  final int albumCount;
  final Duration totalDuration;

  const Artist({
    required this.name,
    required this.trackCount,
    this.albumCount = 0,
    this.totalDuration = Duration.zero,
  });

  factory Artist.fromMap(Map<String, Object?> map) {
    return Artist(
      name: map['artist'] as String,
      trackCount: (map['track_count'] as int?) ?? 0,
      albumCount: (map['album_count'] as int?) ?? 0,
      totalDuration: Duration(
        milliseconds: (map['total_duration'] as int?) ?? 0,
      ),
    );
  }
}

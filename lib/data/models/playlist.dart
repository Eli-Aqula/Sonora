class Playlist {
  final int? id;
  final String name;
  final String? description;
  final String? coverPath;
  final String? autoCoverPath;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int trackCount;

  const Playlist({
    this.id,
    required this.name,
    this.description,
    this.coverPath,
    this.autoCoverPath,
    required this.createdAt,
    required this.modifiedAt,
    this.trackCount = 0,
  });

  String? get effectiveCoverPath => coverPath ?? autoCoverPath;

  Playlist copyWith({
    int? id,
    String? name,
    String? description,
    String? coverPath,
    String? autoCoverPath,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? trackCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      autoCoverPath: autoCoverPath ?? this.autoCoverPath,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      trackCount: trackCount ?? this.trackCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_path': coverPath,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
    };
  }

  factory Playlist.fromMap(Map<String, Object?> map) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      coverPath: map['cover_path'] as String?,
      autoCoverPath: map['auto_cover_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['modified_at'] as int?) ?? 0,
      ),
      trackCount: (map['track_count'] as int?) ?? 0,
    );
  }
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Artist metadata fetched from Genius. Stored in SharedPreferences
/// as a JSON dictionary `name -> ArtistMetadata` under a single key,
/// because the library usually has no more than a thousand artists,
/// and keeping them in one object is simpler than splitting across keys.
class ArtistMetadata {
  final String name;
  final int geniusId;
  /// Path to the locally downloaded artist photo (persistent storage,
  /// see `ArtistImageStore`). The UI only displays the photo from this
  /// field — `imageUrl` is used only as the download source.
  final String? imagePath;
  final String? imageUrl;
  final String? headerImageUrl;
  final String? description;
  final String? geniusUrl;

  const ArtistMetadata({
    required this.name,
    required this.geniusId,
    this.imagePath,
    this.imageUrl,
    this.headerImageUrl,
    this.description,
    this.geniusUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'genius_id': geniusId,
        if (imagePath != null) 'image_path': imagePath,
        if (imageUrl != null) 'image_url': imageUrl,
        if (headerImageUrl != null) 'header_image_url': headerImageUrl,
        if (description != null) 'description': description,
        if (geniusUrl != null) 'genius_url': geniusUrl,
      };

  factory ArtistMetadata.fromJson(Map<String, dynamic> json) {
    return ArtistMetadata(
      name: (json['name'] as String?) ?? '',
      geniusId: (json['genius_id'] as num?)?.toInt() ?? 0,
      imagePath: json['image_path'] as String?,
      imageUrl: json['image_url'] as String?,
      headerImageUrl: json['header_image_url'] as String?,
      description: json['description'] as String?,
      geniusUrl: json['genius_url'] as String?,
    );
  }
}

const _kArtistMetadataKey = 'artist_metadata_v1';

class ArtistMetadataNotifier
    extends StateNotifier<Map<String, ArtistMetadata>> {
  ArtistMetadataNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kArtistMetadataKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final out = <String, ArtistMetadata>{};
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            out[key] = ArtistMetadata.fromJson(value);
          }
        });
        state = out;
      }
    } catch (_) {
      // Corrupted cache — ignore it and start fresh.
    }
  }

  Future<void> save(ArtistMetadata meta) async {
    state = {...state, _key(meta.name): meta};
    await _persist();
  }

  Future<void> remove(String name) async {
    final next = {...state}..remove(_key(name));
    state = next;
    await _persist();
  }

  ArtistMetadata? get(String name) => state[_key(name)];

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    state.forEach((key, value) => out[key] = value.toJson());
    await prefs.setString(_kArtistMetadataKey, jsonEncode(out));
  }

  /// Artist names may differ only in case/whitespace; normalize for
  /// reliable lookup.
  static String _key(String name) => name.trim().toLowerCase();
}

final artistMetadataProvider = StateNotifierProvider<ArtistMetadataNotifier,
    Map<String, ArtistMetadata>>((ref) {
  return ArtistMetadataNotifier();
});

/// Convenience family provider: returns the metadata for a specific
/// artist (or null if none is saved).
final artistMetadataByNameProvider =
    Provider.family<ArtistMetadata?, String>((ref, name) {
  final all = ref.watch(artistMetadataProvider);
  return all[ArtistMetadataNotifier._key(name)];
});

import 'dart:io';
import 'dart:typed_data';

import 'package:audiotags/audiotags.dart' as at;
import 'package:path/path.dart' as p;

import 'metadata_reader.dart';

/// Describes the desired change to a track's cover art.
sealed class CoverChange {
  const CoverChange();
}

/// Leave the cover art unchanged (default).
class CoverKeep extends CoverChange {
  const CoverKeep();
}

/// Remove the embedded cover art from the file.
class CoverRemove extends CoverChange {
  const CoverRemove();
}

/// Replace the cover art with the image read from [imagePath].
class CoverReplace extends CoverChange {
  final String imagePath;
  const CoverReplace(this.imagePath);
}

/// A snapshot of user-editable tags. All fields are optional:
/// an empty string → clear the tag, `null` → leave it untouched.
class TagEdits {
  final String? title;
  final String? trackArtist;
  final String? album;
  final String? albumArtist;
  final int? year;
  final int? trackNumber;
  final int? trackTotal;
  final int? discNumber;
  final int? discTotal;
  final String? genre;
  final String? lyrics;
  final double? bpm;
  final CoverChange cover;
  // Marker: the user explicitly opened the corresponding field and left
  // it empty → the tag should be cleared, not "left as-is".
  final Set<String> clearedFields;

  const TagEdits({
    this.title,
    this.trackArtist,
    this.album,
    this.albumArtist,
    this.year,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.genre,
    this.lyrics,
    this.bpm,
    this.cover = const CoverKeep(),
    this.clearedFields = const <String>{},
  });
}

/// Writes ID3/Vorbis/MP4 tags to an audio file using the `audiotags` package.
class MetadataWriter {
  MetadataWriter(this._reader);

  final MetadataReader _reader;

  /// Whether tag writing is supported for this file based on its extension.
  /// Matches the list of supported reads.
  bool isSupported(String path) => MetadataReader.isSupported(path);

  /// Applies [edits] to the file at [filePath], then re-reads the metadata
  /// and returns a fresh [MetadataResult] (with updated cover art etc.).
  /// Throws [MetadataWriteException] on error.
  Future<MetadataResult> apply(String filePath, TagEdits edits) async {
    if (!isSupported(filePath)) {
      throw const MetadataWriteException('File format is not supported');
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw const MetadataWriteException('File not found');
    }

    at.Tag? existing;
    try {
      existing = await at.AudioTags.read(filePath);
    } catch (_) {
      existing = null;
    }

    final pictures = _buildPictures(existing, edits.cover);

    String? pick(String key, String? candidate, String? previous) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
      if (edits.clearedFields.contains(key)) return null;
      return previous;
    }

    int? pickInt(String key, int? candidate, int? previous) {
      if (candidate != null) return candidate;
      if (edits.clearedFields.contains(key)) return null;
      return previous;
    }

    double? pickDouble(String key, double? candidate, double? previous) {
      if (candidate != null) return candidate;
      if (edits.clearedFields.contains(key)) return null;
      return previous;
    }

    final newTag = at.Tag(
      title: pick('title', edits.title, existing?.title),
      trackArtist:
          pick('trackArtist', edits.trackArtist, existing?.trackArtist),
      album: pick('album', edits.album, existing?.album),
      albumArtist:
          pick('albumArtist', edits.albumArtist, existing?.albumArtist),
      year: pickInt('year', edits.year, existing?.year),
      genre: pick('genre', edits.genre, existing?.genre),
      trackNumber:
          pickInt('trackNumber', edits.trackNumber, existing?.trackNumber),
      trackTotal:
          pickInt('trackTotal', edits.trackTotal, existing?.trackTotal),
      discNumber:
          pickInt('discNumber', edits.discNumber, existing?.discNumber),
      discTotal: pickInt('discTotal', edits.discTotal, existing?.discTotal),
      lyrics: pick('lyrics', edits.lyrics, existing?.lyrics),
      bpm: pickDouble('bpm', edits.bpm, existing?.bpm),
      pictures: pictures,
    );

    try {
      await at.AudioTags.write(filePath, newTag);
    } catch (e) {
      throw MetadataWriteException('Failed to write tags: $e');
    }

    final fresh = await _reader.read(filePath);
    if (fresh == null) {
      throw const MetadataWriteException(
        'File was written, but failed to re-read metadata',
      );
    }
    return fresh;
  }

  List<at.Picture> _buildPictures(at.Tag? existing, CoverChange change) {
    switch (change) {
      case CoverKeep():
        return existing?.pictures ?? const <at.Picture>[];
      case CoverRemove():
        return const <at.Picture>[];
      case CoverReplace(:final imagePath):
        final bytes = File(imagePath).readAsBytesSync();
        final mime = _mimeFromPath(imagePath);
        return <at.Picture>[
          at.Picture(
            pictureType: at.PictureType.coverFront,
            mimeType: mime,
            bytes: Uint8List.fromList(bytes),
          ),
        ];
    }
  }

  at.MimeType? _mimeFromPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return at.MimeType.png;
      case '.jpg':
      case '.jpeg':
        return at.MimeType.jpeg;
      case '.gif':
        return at.MimeType.gif;
      case '.bmp':
        return at.MimeType.bmp;
      case '.tif':
      case '.tiff':
        return at.MimeType.tiff;
      default:
        return at.MimeType.jpeg;
    }
  }
}

class MetadataWriteException implements Exception {
  final String message;
  const MetadataWriteException(this.message);
  @override
  String toString() => message;
}

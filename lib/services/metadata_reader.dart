import 'dart:io';
import 'dart:typed_data';

import 'package:audiotags/audiotags.dart' as at;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MetadataResult {
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
  final String? coverPath;
  final String? lyrics;

  const MetadataResult({
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
    this.coverPath,
    this.lyrics,
  });
}

class MetadataReader {
  static const supportedExtensions = [
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.opus',
    '.wav',
    '.wma',
  ];

  static bool isSupported(String path) {
    final ext = p.extension(path).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  Future<MetadataResult?> read(String filePath) async {
    if (!MetadataReader.isSupported(filePath)) return null;

    String title = '';
    String artist = '';
    String album = '';
    String? albumArtist;
    int? year;
    int? trackNumber;
    int? discNumber;
    Duration duration = Duration.zero;
String? genre;
     String? lyrics;
     int? bitrate;
     int? sampleRate;
     String? coverPath;

    try {
      final tag = await at.AudioTags.read(filePath);
      if (tag != null) {
        title = tag.title ?? '';
        artist = tag.trackArtist ?? tag.albumArtist ?? '';
        album = tag.album ?? '';
        albumArtist = tag.albumArtist;
        year = tag.year;
        trackNumber = tag.trackNumber;
        discNumber = tag.discNumber;
        genre = tag.genre;
        lyrics = tag.lyrics;
        if (tag.duration != null) {
          duration = Duration(seconds: tag.duration!.toInt());
        }
        if (tag.pictures.isNotEmpty) {
          coverPath = await _saveCover(filePath, tag.pictures.first);
        }
      }
    } catch (_) {
      // audiotags sometimes fails on a particular file — fall back below
    }

    if (duration == Duration.zero) {
      try {
        final file = File(filePath);
        final size = await file.length();
        bitrate ??= (size * 8 ~/ 1).clamp(0, 1);
      } catch (_) {}
    }

    if (title.isEmpty) title = p.basenameWithoutExtension(filePath);
    if (artist.isEmpty) artist = 'Unknown Artist';
    if (album.isEmpty) album = 'Unknown Album';

    return MetadataResult(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      year: year,
      trackNumber: trackNumber,
      discNumber: discNumber,
      duration: duration,
      genre: genre,
      bitrate: bitrate,
      sampleRate: sampleRate,
      coverPath: coverPath,
      lyrics: lyrics,
    );
  }

  Future<String> _saveCover(String audioPath, at.Picture picture) async {
    final cacheDir = await getApplicationSupportDirectory();
    final coversDir = Directory(p.join(cacheDir.path, 'covers'));
    if (!coversDir.existsSync()) {
      coversDir.createSync(recursive: true);
    }
    final hash = audioPath.hashCode.toRadixString(16);
    final ext = _pictureExtension(picture.mimeType);
    final file = File(p.join(coversDir.path, '$hash$ext'));
    final bytes = Uint8List.fromList(picture.bytes);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _pictureExtension(at.MimeType? mime) {
    switch (mime) {
      case at.MimeType.png:
        return '.png';
      case at.MimeType.jpeg:
        return '.jpg';
      case at.MimeType.gif:
        return '.gif';
      case at.MimeType.bmp:
        return '.bmp';
      case at.MimeType.tiff:
        return '.tiff';
      default:
        return '.jpg';
    }
  }
}

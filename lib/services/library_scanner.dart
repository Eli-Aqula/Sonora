import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/models/track.dart';
import '../data/repositories/library_repository.dart';
import 'metadata_reader.dart';

class ScanProgress {
  final int processed;
  final int total;
  final String currentFile;
  const ScanProgress({
    required this.processed,
    required this.total,
    required this.currentFile,
  });

  double get fraction => total == 0 ? 0 : processed / total;
}

class LibraryScanner {
  LibraryScanner(this._repo, this._reader);
  final LibraryRepository _repo;
  final MetadataReader _reader;

  Future<Set<String>> listAudioFiles(List<String> roots) async {
    final files = <String>{};
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && MetadataReader.isSupported(entity.path)) {
          files.add(entity.path);
        }
      }
    }
    return files;
  }

  Future<int> scan({
    required List<String> folders,
    void Function(ScanProgress progress)? onProgress,
    bool removeMissing = true,
    void Function(Track track)? onNewTrack,
  }) async {
    final allFiles = await listAudioFiles(folders);
    final total = allFiles.length;
    var processed = 0;
    var added = 0;

    if (removeMissing) {
      await _repo.removeMissingTracks(allFiles);
    }

    for (final filePath in allFiles) {
      onProgress?.call(ScanProgress(
        processed: processed,
        total: total,
        currentFile: filePath,
      ));

      try {
        final meta = await _reader.read(filePath);
        if (meta == null) continue;
        final stat = await File(filePath).stat();
        final track = Track(
          path: filePath,
          title: meta.title,
          artist: meta.artist,
          album: meta.album,
          albumArtist: meta.albumArtist,
          year: meta.year,
          trackNumber: meta.trackNumber,
          discNumber: meta.discNumber,
          duration: meta.duration,
          genre: meta.genre,
          bitrate: meta.bitrate,
          sampleRate: meta.sampleRate,
          fileSize: stat.size,
          coverPath: meta.coverPath,
          addedAt: stat.modified,
          modifiedAt: stat.modified,
        );
        // Distinguish a genuinely new track from a re-scan of an already
        // known file — `onNewTrack` should only fire on the first insert,
        // otherwise auto-enrichment would hit Genius for every track on
        // each rescan.
        final wasNew = (await _repo.getTrackByPath(filePath)) == null;
        final id = await _repo.upsertTrack(track);
        if (wasNew && onNewTrack != null) {
          onNewTrack(track.copyWith(id: id));
        }
        added++;
      } catch (_) {
        // skip the corrupt file
      }
      processed++;
    }

    onProgress?.call(ScanProgress(
      processed: total,
      total: total,
      currentFile: '',
    ));

    return added;
  }
}

class ScanFolders {
  static String summarize(String folder) {
    return p.basename(folder);
  }
}

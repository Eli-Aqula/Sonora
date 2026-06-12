import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cover_downloader.dart';

/// Persistent local storage for artist photos
/// (`<appSupport>/artist_covers/`).
///
/// Unlike [CoverDownloader.downloadToTemp] (temporary files for track
/// covers), files here are not deleted by the calling code -- they
/// persist until replaced by a new download for the same artist.
class ArtistImageStore {
  static const _timeout = Duration(seconds: 15);

  /// Downloads the image at [url] into the permanent folder. [geniusId]
  /// is used in the filename. Returns the file path, or `null` if the
  /// url is empty or a network error occurs.
  static Future<String?> download(String url, {required int geniusId}) async {
    if (url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final ext = CoverDownloader.extensionFromUrl(url, res.headers['content-type']);
      final dir = await _ensureDir();
      final filename =
          'artist_${geniusId}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final file = File(p.join(dir.path, filename));
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _ensureDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'artist_covers'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Deletes a previously downloaded file (if it exists). Safe to call
  /// with `null`/empty paths.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {
        // Not critical.
      }
    }
  }
}

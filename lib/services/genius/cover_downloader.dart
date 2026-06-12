import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads an image from a URL into a temporary file and returns the
/// path.
///
/// The file is saved to `<appSupport>/tmp/genius_<songId>_<ts>.<ext>`.
/// The calling code is responsible for deleting the file after use.
///
/// Returns `null` on a network error or if the URL is empty.
class CoverDownloader {
  static const _timeout = Duration(seconds: 15);

  /// [songId] is used in the filename for uniqueness and to make
  /// debugging easier (you can see which song the cover was downloaded
  /// for).
  static Future<String?> downloadToTemp(
    String url, {
    required int songId,
  }) async {
    if (url.isEmpty) return null;
    final res = await http
        .get(Uri.parse(url))
        .timeout(_timeout);
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
    final ext = extensionFromUrl(url, res.headers['content-type']);
    final dir = await _ensureTmpDir();
    final filename = 'genius_${songId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file.path;
  }

  static Future<Directory> _ensureTmpDir() async {
    final base = await getApplicationSupportDirectory();
    final tmp = Directory(p.join(base.path, 'tmp'));
    if (!await tmp.exists()) {
      await tmp.create(recursive: true);
    }
    return tmp;
  }

  /// Determines the file extension from the URL or content-type.
  static String extensionFromUrl(String url, String? contentType) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final urlExt = p.extension(uri.path).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
          .contains(urlExt)) {
        return urlExt == '.jpeg' ? '.jpg' : urlExt;
      }
    }
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('jpeg') || ct.contains('jpg')) return '.jpg';
    if (ct.contains('png')) return '.png';
    if (ct.contains('gif')) return '.gif';
    if (ct.contains('webp')) return '.webp';
    if (ct.contains('bmp')) return '.bmp';
    return '.jpg';
  }

  /// Deletes a previously downloaded file (if it exists). Safe to call
  /// with `null` paths -- nothing happens.
  static Future<void> deleteTemp(String? path) async {
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {
        // Not critical -- temp files don't take up much space and will
        // be overwritten on the next download.
      }
    }
  }
}

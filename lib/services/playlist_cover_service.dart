import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PlaylistCoverResult {
  final String absolutePath;
  final String extension;
  const PlaylistCoverResult({required this.absolutePath, required this.extension});
}

class PlaylistCoverService {
  static const _dirName = 'playlist_covers';
  static const _allowedExtensions = ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'];

  Future<Directory> _coversDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<PlaylistCoverResult?> pickAndSave(int playlistId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      dialogTitle: 'Choose playlist cover',
    );
    final picked = result?.files.single;
    final sourcePath = picked?.path;
    if (sourcePath == null) return null;

    final ext = p.extension(sourcePath).toLowerCase();
    final normalizedExt = ext.isEmpty ? '.png' : ext;
    final dir = await _coversDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dest = File(p.join(dir.path, 'p${playlistId}_$ts$normalizedExt'));
    await File(sourcePath).copy(dest.path);
    return PlaylistCoverResult(
      absolutePath: dest.path,
      extension: normalizedExt,
    );
  }

  Future<void> deleteFile(String? absolutePath) async {
    if (absolutePath == null) return;
    try {
      final f = File(absolutePath);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}

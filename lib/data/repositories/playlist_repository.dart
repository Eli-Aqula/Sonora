import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class PlaylistRepository {
  PlaylistRepository(this._db);
  final DatabaseHelper _db;

  Future<List<Playlist>> getAll() async {
    final database = await _db.database;
    final rows = await database.rawQuery('''
      SELECT p.*,
        (SELECT COUNT(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) AS track_count,
        (
          SELECT t.cover_path FROM playlist_tracks pt
          INNER JOIN tracks t ON t.id = pt.track_id
          WHERE pt.playlist_id = p.id AND t.cover_path IS NOT NULL
          ORDER BY pt.added_at DESC, pt.position DESC
          LIMIT 1
        ) AS auto_cover_path
      FROM playlists p
      ORDER BY p.modified_at DESC
    ''');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<Playlist?> getById(int id) async {
    final database = await _db.database;
    final rows = await database.rawQuery('''
      SELECT p.*,
        (SELECT COUNT(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) AS track_count,
        (
          SELECT t.cover_path FROM playlist_tracks pt
          INNER JOIN tracks t ON t.id = pt.track_id
          WHERE pt.playlist_id = p.id AND t.cover_path IS NOT NULL
          ORDER BY pt.added_at DESC, pt.position DESC
          LIMIT 1
        ) AS auto_cover_path
      FROM playlists p
      WHERE p.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    return Playlist.fromMap(rows.first);
  }

  Future<int> create(String name, {String? description}) async {
    final database = await _db.database;
    final now = DateTime.now();
    return database.insert('playlists', {
      'name': name,
      'description': description,
      'created_at': now.millisecondsSinceEpoch,
      'modified_at': now.millisecondsSinceEpoch,
    });
  }

  Future<void> rename(int id, String name) async {
    final database = await _db.database;
    await database.update(
      'playlists',
      {
        'name': name,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final database = await _db.database;
    await database.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setCover(int id, String? coverPath) async {
    final database = await _db.database;
    await database.update(
      'playlists',
      {
        'cover_path': coverPath,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Track>> getTracks(int playlistId) async {
    final database = await _db.database;
    final rows = await database.rawQuery('''
      SELECT t.* FROM tracks t
      INNER JOIN playlist_tracks pt ON pt.track_id = t.id
      WHERE pt.playlist_id = ?
      ORDER BY pt.position
    ''', [playlistId]);
    return rows.map(Track.fromMap).toList();
  }

  Future<void> addTrack(int playlistId, int trackId) async {
    final database = await _db.database;
    final maxRow = await database.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS p FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    );
    final position = (maxRow.first['p'] as int) + 1;
    await database.insert(
      'playlist_tracks',
      {
        'playlist_id': playlistId,
        'track_id': trackId,
        'position': position,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _touch(playlistId);
  }

  Future<void> addTracks(int playlistId, List<int> trackIds) async {
    final database = await _db.database;
    final maxRow = await database.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS p FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    );
    var position = (maxRow.first['p'] as int) + 1;
    final batch = database.batch();
    for (final id in trackIds) {
      batch.insert(
        'playlist_tracks',
        {
          'playlist_id': playlistId,
          'track_id': id,
          'position': position++,
          'added_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
    await _touch(playlistId);
  }

  Future<void> removeTrack(int playlistId, int trackId) async {
    final database = await _db.database;
    await database.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
    await _touch(playlistId);
  }

  Future<void> _touch(int playlistId) async {
    final database = await _db.database;
    await database.update(
      'playlists',
      {'modified_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }
}

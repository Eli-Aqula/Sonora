import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';

class LibraryRepository {
  LibraryRepository(this._db);
  final DatabaseHelper _db;

  // ---- Tracks -----------------------------------------------------------

  Future<int> upsertTrack(Track track) async {
    final db = await _db.database;
    final existing = await db.query(
      'tracks',
      columns: ['id'],
      where: 'path = ?',
      whereArgs: [track.path],
      limit: 1,
    );
    if (existing.isEmpty) {
      return db.insert('tracks', track.toMap()..remove('id'));
    }
    final id = existing.first['id'] as int;
    final map = track.toMap()..remove('id');
    await db.update('tracks', map, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<int> removeTrackByPath(String path) async {
    final db = await _db.database;
    return db.delete('tracks', where: 'path = ?', whereArgs: [path]);
  }

  /// Deletes a track from the DB along with its audio file and
  /// associated cover. Returns `true` if the operation completed
  /// without errors.
  Future<bool> deleteTrack(Track track) async {
    final db = await _db.database;
    var ok = true;
    final audio = File(track.path);
    if (await audio.exists()) {
      try {
        await audio.delete();
      } catch (_) {
        ok = false;
      }
    }
    if (track.coverPath != null && track.coverPath!.isNotEmpty) {
      final cover = File(track.coverPath!);
      if (await cover.exists()) {
        try {
          await cover.delete();
        } catch (_) {
          // Not critical — keep going.
        }
      }
    }
    await db.delete('tracks', where: 'id = ?', whereArgs: [track.id]);
    return ok;
  }

  Future<void> removeMissingTracks(Set<String> existingPaths) async {
    final db = await _db.database;
    final rows = await db.query('tracks', columns: ['path']);
    final allPaths = rows.map((r) => r['path'] as String).toList();
    final missing = allPaths.where((p) => !existingPaths.contains(p)).toList();
    if (missing.isEmpty) return;
    final placeholders = List.filled(missing.length, '?').join(',');
    await db.delete('tracks', where: 'path IN ($placeholders)', whereArgs: missing);
  }

  /// Deletes all tracks whose file path is inside [folderPath]. Used when a
  /// watched folder is removed, so its tracks (and the albums/artists
  /// derived from them) disappear immediately rather than lingering until
  /// the next scan happens to clean them up.
  Future<void> removeTracksInFolder(String folderPath) async {
    final db = await _db.database;
    final normalized = p.normalize(folderPath);
    final prefix = normalized.endsWith(Platform.pathSeparator)
        ? normalized
        : '$normalized${Platform.pathSeparator}';
    final rows = await db.query('tracks', columns: ['id', 'path']);
    final ids = rows
        .where((r) => (r['path'] as String).startsWith(prefix))
        .map((r) => r['id'] as int)
        .toList();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete('tracks', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<Track?> getTrackByPath(String path) async {
    final db = await _db.database;
    final rows = await db.query('tracks', where: 'path = ?', whereArgs: [path], limit: 1);
    if (rows.isEmpty) return null;
    return Track.fromMap(rows.first);
  }

  Future<List<Track>> getAllTracks({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'tracks',
      orderBy: orderBy ?? 'artist COLLATE NOCASE, album COLLATE NOCASE, disc_number, track_number, title COLLATE NOCASE',
      limit: limit,
      offset: offset,
    );
    return rows.map(Track.fromMap).toList();
  }

  Future<List<Track>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await _db.database;
    final like = '%${query.trim()}%';
    final rows = await db.query(
      'tracks',
      where: 'title LIKE ? OR artist LIKE ? OR album LIKE ?',
      whereArgs: [like, like, like],
      orderBy: 'title COLLATE NOCASE',
      limit: 500,
    );
    return rows.map(Track.fromMap).toList();
  }

  Future<int> trackCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM tracks');
    return (result.first['c'] as int?) ?? 0;
  }

  // ---- Albums / Artists -------------------------------------------------

  Future<List<Album>> getAlbums() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        album,
        COALESCE(NULLIF(album_artist, ''), artist) AS artist,
        MIN(year) AS year,
        COUNT(*) AS track_count,
        SUM(duration_ms) AS total_duration,
        (SELECT cover_path FROM tracks t2
         WHERE t2.album = tracks.album
           AND COALESCE(NULLIF(t2.album_artist, ''), t2.artist)
             = COALESCE(NULLIF(tracks.album_artist, ''), tracks.artist)
           AND t2.cover_path IS NOT NULL
         ORDER BY t2.disc_number, t2.track_number LIMIT 1) AS cover_path
      FROM tracks
      GROUP BY album,
        COALESCE(NULLIF(album_artist, ''), artist)
      ORDER BY album COLLATE NOCASE
    ''');
    return rows.map(Album.fromMap).toList();
  }

  Future<List<Track>> getAlbumTracks(String album, String artist) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT * FROM tracks
      WHERE album = ?
        AND COALESCE(NULLIF(album_artist, ''), artist) = ?
      ORDER BY disc_number, track_number, title COLLATE NOCASE
    ''', [album, artist]);
    return rows.map(Track.fromMap).toList();
  }

  Future<List<Artist>> getArtists() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        artist,
        COUNT(*) AS track_count,
        COUNT(DISTINCT album) AS album_count,
        SUM(duration_ms) AS total_duration
      FROM tracks
      GROUP BY artist
      ORDER BY artist COLLATE NOCASE
    ''');
    return rows.map(Artist.fromMap).toList();
  }

  Future<List<Album>> getArtistAlbums(String artist) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        album,
        ? AS artist,
        MIN(year) AS year,
        COUNT(*) AS track_count,
        SUM(duration_ms) AS total_duration,
        (SELECT cover_path FROM tracks t2
         WHERE t2.album = tracks.album AND t2.artist = ?
           AND t2.cover_path IS NOT NULL
         ORDER BY t2.disc_number, t2.track_number LIMIT 1) AS cover_path
      FROM tracks
      WHERE artist = ?
      GROUP BY album
      ORDER BY year, album COLLATE NOCASE
    ''', [artist, artist, artist]);
    return rows.map(Album.fromMap).toList();
  }

  // ---- Watched folders --------------------------------------------------

  Future<List<String>> getWatchedFolders() async {
    final db = await _db.database;
    final rows = await db.query('watched_folders', orderBy: 'added_at');
    return rows.map((r) => r['path'] as String).toList();
  }

  Future<void> addWatchedFolder(String path) async {
    final db = await _db.database;
    await db.insert(
      'watched_folders',
      {
        'path': path,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeWatchedFolder(String path) async {
    final db = await _db.database;
    await db.delete('watched_folders', where: 'path = ?', whereArgs: [path]);
  }

  // ---- Favorites --------------------------------------------------------

  /// Returns tracks added to favorites (sorted by date added
  /// descending, then by title).
  Future<List<Track>> getFavoriteTracks() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT * FROM tracks
      WHERE is_favorite = 1
      ORDER BY added_at DESC, title COLLATE NOCASE
    ''');
    return rows.map(Track.fromMap).toList();
  }

  /// Toggles the `is_favorite` flag for a track and returns the new value.
  Future<bool> toggleTrackFavorite(int trackId) async {
    final db = await _db.database;
    final current = await db.query(
      'tracks',
      columns: ['is_favorite'],
      where: 'id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    if (current.isEmpty) return false;
    final isFav = (current.first['is_favorite'] as int? ?? 0) == 1;
    final next = isFav ? 0 : 1;
    await db.update(
      'tracks',
      {'is_favorite': next},
      where: 'id = ?',
      whereArgs: [trackId],
    );
    return next == 1;
  }

  /// Returns albums added to favorites.
  Future<List<Album>> getFavoriteAlbums() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        fa.album,
        fa.artist,
        (SELECT MIN(year) FROM tracks t
         WHERE t.album = fa.album
           AND COALESCE(NULLIF(t.album_artist, ''), t.artist) = fa.artist) AS year,
        (SELECT COUNT(*) FROM tracks t
         WHERE t.album = fa.album
           AND COALESCE(NULLIF(t.album_artist, ''), t.artist) = fa.artist) AS track_count,
        (SELECT SUM(duration_ms) FROM tracks t
         WHERE t.album = fa.album
           AND COALESCE(NULLIF(t.album_artist, ''), t.artist) = fa.artist) AS total_duration,
        (SELECT cover_path FROM tracks t
         WHERE t.album = fa.album
           AND COALESCE(NULLIF(t.album_artist, ''), t.artist) = fa.artist
           AND t.cover_path IS NOT NULL
         ORDER BY t.disc_number, t.track_number LIMIT 1) AS cover_path
      FROM favorite_albums fa
      ORDER BY fa.added_at DESC
    ''');
    return rows.map(Album.fromMap).toList();
  }

  /// Adds an album to favorites.
  Future<void> addFavoriteAlbum(String album, String artist) async {
    final db = await _db.database;
    await db.insert(
      'favorite_albums',
      {
        'album': album,
        'artist': artist,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes an album from favorites.
  Future<void> removeFavoriteAlbum(String album, String artist) async {
    final db = await _db.database;
    await db.delete(
      'favorite_albums',
      where: 'album = ? AND artist = ?',
      whereArgs: [album, artist],
    );
  }

  /// Checks whether an album is a favorite.
  Future<bool> isAlbumFavorite(String album, String artist) async {
    final db = await _db.database;
    final rows = await db.query(
      'favorite_albums',
      where: 'album = ? AND artist = ?',
      whereArgs: [album, artist],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Toggles the "favorite" state for an album and returns the new value.
  Future<bool> toggleAlbumFavorite(String album, String artist) async {
    final isFav = await isAlbumFavorite(album, artist);
    if (isFav) {
      await removeFavoriteAlbum(album, artist);
      return false;
    } else {
      await addFavoriteAlbum(album, artist);
      return true;
    }
  }

  /// Returns artists added to favorites.
  Future<List<Artist>> getFavoriteArtists() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        fav.artist,
        (SELECT COUNT(*) FROM tracks t WHERE t.artist = fav.artist) AS track_count,
        (SELECT COUNT(DISTINCT album) FROM tracks t WHERE t.artist = fav.artist) AS album_count,
        (SELECT SUM(duration_ms) FROM tracks t WHERE t.artist = fav.artist) AS total_duration
      FROM favorite_artists fav
      ORDER BY fav.added_at DESC
    ''');
    return rows.map(Artist.fromMap).toList();
  }

  /// Adds an artist to favorites.
  Future<void> addFavoriteArtist(String artist) async {
    final db = await _db.database;
    await db.insert(
      'favorite_artists',
      {
        'artist': artist,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes an artist from favorites.
  Future<void> removeFavoriteArtist(String artist) async {
    final db = await _db.database;
    await db.delete(
      'favorite_artists',
      where: 'artist = ?',
      whereArgs: [artist],
    );
  }

  /// Checks whether an artist is a favorite.
  Future<bool> isArtistFavorite(String artist) async {
    final db = await _db.database;
    final rows = await db.query(
      'favorite_artists',
      where: 'artist = ?',
      whereArgs: [artist],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Toggles the "favorite" state for an artist and returns the new value.
  Future<bool> toggleArtistFavorite(String artist) async {
    final isFav = await isArtistFavorite(artist);
    if (isFav) {
      await removeFavoriteArtist(artist);
      return false;
    } else {
      await addFavoriteArtist(artist);
      return true;
    }
  }

  /// Updates synced lyrics (LRC) for a track.
  Future<void> updateLyricsLrc(int trackId, String lrc) async {
    final db = await _db.database;
    await db.update(
      'tracks',
      {'lyrics_lrc': lrc},
      where: 'id = ?',
      whereArgs: [trackId],
    );
  }

  /// Updates the plain text (without timecodes) for a track.
  Future<void> updateLyricsText(int trackId, String text) async {
    final db = await _db.database;
    await db.update(
      'tracks',
      {'lyrics_text': text},
      where: 'id = ?',
      whereArgs: [trackId],
    );
  }
}

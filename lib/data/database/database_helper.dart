import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'sonora.db';
  static const _dbVersion = 4;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    String path;
    if (Platform.isAndroid) {
      final databasesPath = await getDatabasesPath();
      path = p.join(databasesPath, _dbName);
    } else {
      final dir = await getApplicationSupportDirectory();
      await Directory(dir.path).create(recursive: true);
      path = p.join(dir.path, _dbName);
    }

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        album_artist TEXT,
        year INTEGER,
        track_number INTEGER,
        disc_number INTEGER,
        duration_ms INTEGER NOT NULL,
        genre TEXT,
        bitrate INTEGER,
        sample_rate INTEGER,
        file_size INTEGER,
        cover_path TEXT,
        lyrics_text TEXT,
        lyrics_lrc TEXT,
        added_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0
      );
    ''');

    batch.execute('CREATE INDEX idx_tracks_artist ON tracks(artist);');
    batch.execute('CREATE INDEX idx_tracks_album ON tracks(album);');
    batch.execute('CREATE INDEX idx_tracks_title ON tracks(title);');
    batch.execute('CREATE INDEX idx_tracks_path ON tracks(path);');
    batch.execute('CREATE INDEX idx_tracks_favorite ON tracks(is_favorite);');

    batch.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        cover_path TEXT,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE playlist_tracks (
        playlist_id INTEGER NOT NULL,
        track_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
      );
    ''');

    batch.execute('''
      CREATE TABLE watched_folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        added_at INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE favorite_albums (
        album TEXT NOT NULL,
        artist TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (album, artist)
      );
    ''');

    batch.execute('''
      CREATE TABLE favorite_artists (
        artist TEXT NOT NULL PRIMARY KEY,
        added_at INTEGER NOT NULL
      );
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      batch.execute('ALTER TABLE tracks ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;');
      batch.execute('CREATE INDEX idx_tracks_favorite ON tracks(is_favorite);');
      batch.execute('''
        CREATE TABLE favorite_albums (
          album TEXT NOT NULL,
          artist TEXT NOT NULL,
          added_at INTEGER NOT NULL,
          PRIMARY KEY (album, artist)
        );
      ''');
      batch.execute('''
        CREATE TABLE favorite_artists (
          artist TEXT NOT NULL PRIMARY KEY,
          added_at INTEGER NOT NULL
        );
      ''');
      await batch.commit(noResult: true);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE playlists ADD COLUMN cover_path TEXT;');
    }
    if (oldVersion < 4) {
      final batch = db.batch();
      batch.execute('ALTER TABLE tracks ADD COLUMN lyrics_text TEXT;');
      batch.execute('ALTER TABLE tracks ADD COLUMN lyrics_lrc TEXT;');
      await batch.commit(noResult: true);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
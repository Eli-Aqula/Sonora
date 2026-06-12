import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/playlist_repository.dart';
import '../services/library_scanner.dart';
import '../services/metadata_reader.dart';
import '../services/metadata_writer.dart';
import '../services/player_service.dart';
import '../services/playlist_cover_service.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.watch(databaseProvider));
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(ref.watch(databaseProvider));
});

final metadataReaderProvider = Provider<MetadataReader>((ref) {
  return MetadataReader();
});

final metadataWriterProvider = Provider<MetadataWriter>((ref) {
  return MetadataWriter(ref.watch(metadataReaderProvider));
});

final libraryScannerProvider = Provider<LibraryScanner>((ref) {
  return LibraryScanner(
    ref.watch(libraryRepositoryProvider),
    ref.watch(metadataReaderProvider),
  );
});

final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

final playlistCoverServiceProvider = Provider<PlaylistCoverService>((ref) {
  return PlaylistCoverService();
});

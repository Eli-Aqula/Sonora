import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/playlist.dart';
import '../ui/widgets/cover_art.dart';
import 'core_providers.dart';

final playlistsProvider =
    StateNotifierProvider<PlaylistsController, AsyncValue<List<Playlist>>>(
  (ref) => PlaylistsController(ref),
);

class PlaylistsController extends StateNotifier<AsyncValue<List<Playlist>>> {
  PlaylistsController(this._ref) : super(const AsyncValue.loading()) {
    _refresh();
  }
  final Ref _ref;

  Future<void> _refresh() async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(playlistRepositoryProvider);
      final list = await repo.getAll();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String? _coverOf(int id) {
    final list = state.valueOrNull;
    if (list == null) return null;
    for (final pl in list) {
      if (pl.id == id) return pl.coverPath;
    }
    return null;
  }

  Future<int> create(String name, {String? description}) async {
    final repo = _ref.read(playlistRepositoryProvider);
    final id = await repo.create(name, description: description);
    await _refresh();
    return id;
  }

  Future<void> rename(int id, String name) async {
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.rename(id, name);
    await _refresh();
  }

  Future<void> delete(int id) async {
    final oldCover = _coverOf(id);
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.delete(id);
    if (oldCover != null) {
      await _ref.read(playlistCoverServiceProvider).deleteFile(oldCover);
      CoverArt.invalidate(oldCover);
    }
    await _refresh();
  }

  Future<void> addTrack(int playlistId, int trackId) async {
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.addTrack(playlistId, trackId);
    await _refresh();
  }

  Future<void> addTracks(int playlistId, List<int> trackIds) async {
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.addTracks(playlistId, trackIds);
    await _refresh();
  }

  Future<void> removeTrack(int playlistId, int trackId) async {
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.removeTrack(playlistId, trackId);
    await _refresh();
  }

  Future<void> pickAndSetCover(int playlistId) async {
    final service = _ref.read(playlistCoverServiceProvider);
    final picked = await service.pickAndSave(playlistId);
    if (picked == null) return;
    final oldCover = _coverOf(playlistId);
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.setCover(playlistId, picked.absolutePath);
    if (oldCover != null && oldCover != picked.absolutePath) {
      await service.deleteFile(oldCover);
      CoverArt.invalidate(oldCover);
    }
    CoverArt.invalidate(picked.absolutePath);
    await _refresh();
  }

  Future<void> clearCover(int playlistId) async {
    final oldCover = _coverOf(playlistId);
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.setCover(playlistId, null);
    if (oldCover != null) {
      await _ref.read(playlistCoverServiceProvider).deleteFile(oldCover);
      CoverArt.invalidate(oldCover);
    }
    await _refresh();
  }
}

final playlistTracksProvider =
    FutureProvider.family.autoDispose((ref, int playlistId) async {
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.getTracks(playlistId);
});

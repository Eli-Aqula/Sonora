import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/track.dart';
import '../services/player_state_storage.dart';
import 'core_providers.dart';
import 'library_provider.dart';

class PlayerStateRestorer {
  PlayerStateRestorer(this._ref);
  final Ref _ref;

  bool _done = false;

  Future<void> tryRestore() async {
    if (_done) return;

    final service = _ref.read(playerServiceProvider);

    // Wait for the library to finish loading (in case of a cold start).
    final controller = _ref.read(libraryControllerProvider.notifier);
    await controller.load();
    final lib = _ref.read(libraryControllerProvider);
    final tracks = lib.tracks;

    final storage = PlayerStateStorage();
    final saved = await storage.load();
    if (saved == null) {
      _done = true;
      return;
    }

    // If the user is already playing something, don't restore.
    if (service.snapshotValue.currentTrack != null) {
      _done = true;
      return;
    }

    if (tracks.isEmpty) {
      // Restore only volume/mute.
      await service.restoreState(saved);
      _done = true;
      return;
    }

    final byPath = {for (final t in tracks) t.path: t};
    final restored = <Track>[];
    for (final p in saved.queuePaths) {
      final t = byPath[p];
      if (t != null) restored.add(t);
    }

    await service.restoreState(saved, tracks: restored);
    _done = true;
  }
}

final playerStateRestorerProvider = Provider<PlayerStateRestorer>((ref) {
  return PlayerStateRestorer(ref);
});

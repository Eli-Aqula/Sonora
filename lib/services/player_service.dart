import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:rxdart/rxdart.dart';

import '../data/models/track.dart';
import 'player_state_storage.dart';

enum RepeatMode { off, all, one }

class PlaybackSnapshot {
  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final bool playing;
  final bool completed;
  final bool buffering;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final bool shuffle;
  final RepeatMode repeatMode;
  final double volume;
  final bool muted;
  final String? error;
  final ({String album, String artist})? currentAlbumKey;

  const PlaybackSnapshot({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.playing = false,
    this.completed = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
    this.volume = 1.0,
    this.muted = false,
    this.error,
    this.currentAlbumKey,
  });

  PlaybackSnapshot copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    bool? playing,
    bool? completed,
    bool? buffering,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    bool? shuffle,
    RepeatMode? repeatMode,
    double? volume,
    bool? muted,
    String? error,
    bool clearError = false,
    ({String album, String artist})? currentAlbumKey,
    bool clearAlbumKey = false,
  }) {
    return PlaybackSnapshot(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      completed: completed ?? this.completed,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      error: clearError ? null : (error ?? this.error),
      currentAlbumKey:
          clearAlbumKey ? null : (currentAlbumKey ?? this.currentAlbumKey),
    );
  }
}

class PlayerService {
  PlayerService() {
    _subscribe();
  }

  final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Sonora',
      logLevel: MPVLogLevel.warn,
    ),
  );

  final List<Track> _queue = [];
  int _currentIndex = 0;
  ({String album, String artist})? _currentAlbumKey;
  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  double _volume = 1.0;
  bool _muted = false;
  double? _volumeBeforeMute;
  bool _suppressPlaylistUpdates = false;

  // Suppresses state saves while restoration is in progress or has just
  // finished. Without this, opening a playlist makes MPV emit position 0,
  // and _saveState() would write 0 to disk before our seek can land.
  bool _suppressSaves = false;

  final _snapshotController = BehaviorSubject<PlaybackSnapshot>.seeded(
    const PlaybackSnapshot(),
  );
  Stream<PlaybackSnapshot> get snapshot => _snapshotController.stream;
  PlaybackSnapshot get snapshotValue => _snapshotController.value;
  Player get raw => _player;

  final PlayerStateStorage _storage = PlayerStateStorage();
  final List<StreamSubscription> _subs = [];
  Timer? _periodicSaveTimer;

  // Ensures the on-disk state is always up to date, even if the app
  // is closed "hard" (Alt+F4 / X / killed via task manager). With an
  // 800ms debounce we could lose up to the last 0.8s of playback.
  static const _periodicSaveInterval = Duration(seconds: 2);

  Future<void> init() async {
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      if (kDebugMode) print('MediaKit init failed: $e');
    }
    _volume = (_player.state.volume / 100.0).clamp(0.0, 1.0);
  }

  void _subscribe() {
    _subs.add(_player.stream.playlist.listen((_) {
      if (_suppressPlaylistUpdates) return;
      final idx = _player.state.playlist.index;
      if (idx >= 0 && idx != _currentIndex) {
        _currentIndex = idx;
        _emit();
        _saveStateNow();
      }
    }));

    _subs.add(_player.stream.playing.listen((p) {
      _emit(playing: p, clearError: true);
      _saveStateNow();
    }));

    _subs.add(_player.stream.completed.listen((c) {
      _emit(completed: c);
    }));

    _subs.add(_player.stream.position.listen((p) {
      _emit(position: p);
      // Restart the debounce — write to disk at least once every
      // _periodicSaveInterval, as long as the position keeps changing.
      _schedulePeriodicSave();
    }));

    _subs.add(_player.stream.duration.listen((d) {
      _emit(duration: d);
    }));

    _subs.add(_player.stream.buffer.listen((b) {
      _emit(buffered: b);
    }));

    _subs.add(_player.stream.buffering.listen((b) {
      _emit(buffering: b);
    }));

    _subs.add(_player.stream.volume.listen((v) {
      _volume = (v / 100.0).clamp(0.0, 1.0);
      if (_muted && _volume > 0) _muted = false;
      _emit();
      _saveStateNow();
    }));

    _subs.add(_player.stream.log.listen((log) {
      if (kDebugMode) print('[mpv] ${log.level}: ${log.text}');
    }));

    _subs.add(_player.stream.error.listen((err) {
      if (kDebugMode) print('Player error: $err');
      _emit(error: err);
    }));

    // Safety-net timer: even if the position isn't changing (e.g. paused),
    // periodically write out the last known state.
    _periodicSaveTimer = Timer.periodic(
      _periodicSaveInterval,
      (_) => _saveStateNow(),
    );
  }

  void _emit({
    bool? playing,
    bool? completed,
    bool? buffering,
    Duration? position,
    Duration? buffered,
    Duration? duration,
    String? error,
    bool clearError = false,
  }) {
    final current = _snapshotController.value;
    _snapshotController.add(current.copyWith(
      currentTrack: _currentTrack(),
      queue: List.unmodifiable(_queue),
      currentIndex: _currentIndex,
      playing: playing ?? current.playing,
      completed: completed ?? current.completed,
      buffering: buffering ?? current.buffering,
      position: position ?? current.position,
      bufferedPosition: buffered ?? current.bufferedPosition,
      duration: duration ?? current.duration,
      shuffle: _shuffle,
      repeatMode: _repeatMode,
      volume: _volume,
      muted: _muted,
      error: error,
      clearError: clearError,
      currentAlbumKey: _currentAlbumKey,
      clearAlbumKey: _currentAlbumKey == null,
    ));
  }

  Track? _currentTrack() {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  void _saveStateNow() {
    if (_suppressSaves) return;
    _storage.saveNow(_buildState());
  }

  /// Debounced save triggered on every position update.
  /// Guarantees a write at least once per [_periodicSaveInterval].
  void _schedulePeriodicSave() {
    if (_suppressSaves) return;
    _storage.save(_buildState());
  }

  /// Forces an immediate save of the current state to disk (no debounce).
  /// Called when the app is minimized/closed. Bypasses _suppressSaves —
  /// even if we're in the middle of restoration, the user has explicitly
  /// closed the app, so we need to persist the last correct state
  /// (the target, not 0).
  void flushState() {
    _storage.saveNow(_buildState());
  }

  SavedPlayerState _buildState() {
    if (_queue.isEmpty) {
      return SavedPlayerState(
        queuePaths: const [],
        currentIndex: 0,
        position: Duration.zero,
        volume: _volume,
        muted: _muted,
      );
    }
    return SavedPlayerState(
      queuePaths: _queue.map((t) => t.path).toList(growable: false),
      currentIndex: _currentIndex,
      position: _player.state.position,
      volume: _volume,
      muted: _muted,
    );
  }

  String _fileUri(String path) {
    final normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      return 'file://$normalized';
    }
    return 'file:///$normalized';
  }

  Future<void> setQueue(
    List<Track> tracks, {
    int? startIndex,
    bool autoPlay = true,
    ({String album, String artist})? albumKey,
  }) async {
    if (tracks.isEmpty) {
      await stop();
      return;
    }
    _suppressPlaylistUpdates = true;
    _queue
      ..clear()
      ..addAll(tracks);
    _currentIndex = (startIndex ?? 0).clamp(0, tracks.length - 1);

    // Auto-detect albumKey if not provided — needed for the equalizer
    if (albumKey == null) {
      final current = _queue[_currentIndex];
      final album = current.displayAlbum;
      final artist = current.albumArtist ?? current.artist;
      if (album.isNotEmpty && artist.isNotEmpty && 
          album != 'Unknown Album' && artist != 'Unknown Artist') {
        albumKey = (album: album, artist: artist);
      }
    }
    _currentAlbumKey = albumKey;

    final mediaList = tracks.map(_buildMedia).toList();
    final playlist = Playlist(mediaList, index: _currentIndex);

    try {
      await _player.open(playlist, play: false);
      await _player.jump(_currentIndex);
      await _applyShuffleAndRepeat();
      if (autoPlay) {
        await _player.play();
      }
    } catch (e) {
      if (kDebugMode) print('setQueue error: $e');
      _emit(error: e.toString());
    } finally {
      _suppressPlaylistUpdates = false;
      _emit();
      _saveStateNow();
    }
  }

  Media _buildMedia(Track t) {
    return Media(
      _fileUri(t.path),
      extras: {
        'title': t.displayTitle,
        'artist': t.displayArtist,
        'album': t.displayAlbum,
        if (t.coverPath != null) 'cover': _fileUri(t.coverPath!),
      },
    );
  }

  Future<void> playTrack(Track track, {List<Track>? context}) async {
    final list = context ?? _queue;
    final idx = list.indexWhere((t) => t.path == track.path);
    if (idx == -1) {
      final newList = [...list, track];
      await setQueue(newList, startIndex: newList.length - 1);
    } else {
      await setQueue(list, startIndex: idx);
    }
  }

  /// Replaces the queue with [tracks], shuffled randomly.
  /// The current track (if it's in [tracks]) is moved to the end of the
  /// queue, so each press of "Shuffle" starts a NEW random track from the
  /// beginning instead of continuing the current one.
  /// Always calls play() — this is an action, not a mode toggle.
  Future<void> shuffleList(List<Track> tracks) async {
    if (tracks.isEmpty) {
      await stop();
      return;
    }

    final current = _currentTrack();
    final currentPath = current?.path;

    // Shuffle all tracks except the current one (which we append at the end).
    // This guarantees the first track in the new queue differs from the
    // one currently playing.
    final List<Track> newQueue;
    if (currentPath != null && tracks.any((t) => t.path == currentPath)) {
      final rest = tracks.where((t) => t.path != currentPath).toList()..shuffle();
      newQueue = <Track>[...rest, current!];
    } else {
      newQueue = [...tracks]..shuffle();
    }

    _suppressPlaylistUpdates = true;
    _queue
      ..clear()
      ..addAll(newQueue);
    _currentIndex = 0;
    _shuffle = true;

    // Auto-detect albumKey from the first track — without this the
    // equalizer doesn't highlight on the album card and in lists after
    // shuffling, whereas setQueue (regular play) does the same thing.
    final first = newQueue[0];
    final firstAlbum = first.displayAlbum;
    final firstArtist = first.albumArtist ?? first.artist;
    if (firstAlbum.isNotEmpty &&
        firstArtist.isNotEmpty &&
        firstAlbum != 'Unknown Album' &&
        firstArtist != 'Unknown Artist') {
      _currentAlbumKey = (album: firstAlbum, artist: firstArtist);
    } else {
      _currentAlbumKey = null;
    }

    final mediaList = newQueue.map(_buildMedia).toList();
    try {
      await _player.open(Playlist(mediaList, index: 0), play: false);
      // Some versions of media_kit ignore the `index:` argument in the
      // Playlist constructor and start from the previously selected
      // position. Force-jump to 0 so the audio matches the UI.
      await _player.jump(0);
      await _applyShuffleAndRepeat();
      // Always start playback — this is "play in shuffled order", not
      // a pause-preserving reshuffle.
      await _player.play();
    } catch (e) {
      if (kDebugMode) print('shuffleList error: $e');
      _emit(error: e.toString());
    } finally {
      _suppressPlaylistUpdates = false;
      _currentIndex = 0;
      _emit(playing: true);
      _saveStateNow();
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    await _player.stop();
    _queue.clear();
    _currentIndex = 0;
    _currentAlbumKey = null;
    _emit();
    _saveStateNow();
  }

  /// Restores the saved player state: volume/mute and (if tracks are
  /// provided) the queue with its position. Without [tracks], only the
  /// volume is restored. The player always remains paused — the user
  /// presses play themselves.
  Future<void> restoreState(
    SavedPlayerState state, {
    List<Track>? tracks,
  }) async {
    _volume = state.volume.clamp(0.0, 1.0);
    _muted = state.muted;
    if (_muted) {
      await _player.setVolume(0);
    } else {
      await _player.setVolume(_volume * 100.0);
    }
    if (tracks != null && tracks.isNotEmpty) {
      final idx = state.currentIndex.clamp(0, tracks.length - 1).toInt();
      _suppressPlaylistUpdates = true;
      // Block saves during restoration: MPV emits position 0 right
      // after open(), and without blocking we'd overwrite the saved
      // position before the seek can take effect.
      _suppressSaves = true;
      _queue
        ..clear()
        ..addAll(tracks);
      _currentIndex = idx;
      final mediaList = tracks.map(_buildMedia).toList();
      try {
        await _player.open(Playlist(mediaList, index: idx), play: false);
        await _player.jump(idx);
        await _applyShuffleAndRepeat();
        await _waitForTrackLoaded();
        if (state.position > Duration.zero) {
          await _seekAndVerify(state.position);
        }
        // Ensure playback is paused after restoration
        await _player.pause();
      } catch (e) {
        if (kDebugMode) print('restoreState error: $e');
      } finally {
        _suppressPlaylistUpdates = false;
        // Give MPV another ~500ms to fully apply the position and
        // emit it on the stream. After that we allow saves again —
        // the next position update will overwrite it with the actual
        // position (which should now equal target).
        await Future.delayed(const Duration(milliseconds: 500));
        _suppressSaves = false;
        _emit(playing: false);
        // Immediately persist the result: write target even if MPV
        // hasn't yet updated state.position. That way, on the next
        // launch we'll try the same target instead of a stale 0.
        _storage.saveNow(SavedPlayerState(
          queuePaths: _queue.map((t) => t.path).toList(growable: false),
          currentIndex: _currentIndex,
          position: state.position,
          volume: _volume,
          muted: _muted,
        ));
      }
    } else {
      _emit();
      _saveStateNow();
    }
  }

  /// Waits until the file is actually loaded in MPV. `duration > 0` alone
  /// isn't enough: MPV may know the duration but not have demuxed the
  /// file yet, in which case seek lands nowhere.
  Future<void> _waitForTrackLoaded() async {
    // 1) Wait until the duration becomes known
    if (_player.state.duration <= Duration.zero) {
      try {
        await _player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Timeout — continue, try seeking anyway
      }
    }
    // 2) Wait until MPV "applies" the new file — signaled by the
    //    position starting to be emitted (often 0, sometimes the old
    //    value from the previous track — which is exactly what we
    //    need to filter out before seeking).
    try {
      final completer = Completer<void>();
      late StreamSubscription sub;
      sub = _player.stream.position.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future.timeout(const Duration(seconds: 2));
      await sub.cancel();
    } catch (_) {
      // Timeout — try seeking anyway
    }
  }

  /// Performs a seek and waits until MPV's position actually approaches
  /// [target]. Makes up to 3 attempts with increasing timeouts. Checks
  /// via a subscription to the position stream (rather than
  /// state.position, which can be a stale snapshot).
  Future<void> _seekAndVerify(Duration target) async {
    if (target <= Duration.zero) return;
    for (int attempt = 0; attempt < 3; attempt++) {
      await _player.seek(target);
      try {
        final completer = Completer<void>();
        late StreamSubscription sub;
        sub = _player.stream.position.listen((p) {
          if ((p - target).abs() < const Duration(milliseconds: 500)) {
            if (!completer.isCompleted) completer.complete();
          }
        });
        await completer.future.timeout(
          Duration(milliseconds: 1500 + attempt * 1000),
        );
        await sub.cancel();
        return; // successfully converged
      } catch (_) {
        // Timeout — try again
      }
    }
    if (kDebugMode) {
      print('seek failed: target=$target, actual=${_player.state.position}');
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    // Save immediately, so that closing the app doesn't lose the
    // user's seek on the progress bar.
    _saveStateNow();
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    _volume = clamped;
    if (clamped > 0 && _muted) {
      _muted = false;
      _volumeBeforeMute = null;
    }
    await _player.setVolume(clamped * 100.0);
    _emit();
    _saveStateNow();
  }

  Future<void> toggleMute() async {
    if (_muted) {
      final restore = (_volumeBeforeMute ?? 1.0).clamp(0.0, 1.0);
      _muted = false;
      _volumeBeforeMute = null;
      _volume = restore > 0 ? restore : 1.0;
      await _player.setVolume(_volume * 100.0);
    } else {
      _volumeBeforeMute = _volume > 0 ? _volume : null;
      _muted = true;
      await _player.setVolume(0);
    }
    _emit();
    _saveStateNow();
  }

  Future<void> setSpeed(double s) => _player.setRate(s.clamp(0.5, 2.0));

  void clearError() {
    final current = _snapshotController.value;
    if (current.error == null) return;
    _snapshotController.add(current.copyWith(clearError: true));
  }

  Future<void> clearErrorAsync() async {
    clearError();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_repeatMode == RepeatMode.one) {
      await _player.seek(Duration.zero);
      _saveStateNow();
      return;
    }
    final nextIdx = _currentIndex + 1;
    if (nextIdx >= _queue.length) {
      if (_repeatMode == RepeatMode.all) {
        await _player.jump(0);
      } else {
        await _player.pause();
        await _player.seek(Duration.zero);
      }
      _saveStateNow();
      return;
    }
    await _player.jump(nextIdx);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    final pos = _player.state.position;
    if (pos > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      _saveStateNow();
      return;
    }
    if (_currentIndex <= 0) {
      if (_repeatMode == RepeatMode.all) {
        await _player.jump(_queue.length - 1);
      } else {
        await _player.seek(Duration.zero);
      }
      _saveStateNow();
      return;
    }
    await _player.jump(_currentIndex - 1);
  }

  /// One-shot action: shuffles the current queue.
  /// The current track (if playing) stays at position 0 and continues
  /// playing from the same spot; the remaining tracks are put in random
  /// order. This is NOT a toggle mode — the button has no on/off state,
  /// each click just produces a new random permutation.
  Future<void> cycleRepeat() async {
    _repeatMode = RepeatMode.values[
        (_repeatMode.index + 1) % RepeatMode.values.length];
    await _applyShuffleAndRepeat();
    _emit();
  }

  Future<void> _applyShuffleAndRepeat() async {
    // We maintain queue order in Dart (see shuffleList / toggleShuffle),
    // so MPV's shuffle is always disabled — otherwise MPV would reshuffle
    // the playlist after our `open`, and the UI would drift from the audio.
    await _player.setShuffle(false);
    final mode = switch (_repeatMode) {
      RepeatMode.off => PlaylistMode.none,
      RepeatMode.all => PlaylistMode.loop,
      RepeatMode.one => PlaylistMode.single,
    };
    await _player.setPlaylistMode(mode);
  }

  Future<void> jumpTo(int userIndex) async {
    if (userIndex < 0 || userIndex >= _queue.length) return;
    await _player.jump(userIndex);
  }

  Future<void> removeFromQueue(int userIndex) async {
    if (userIndex < 0 || userIndex >= _queue.length) return;
    if (_queue.length == 1) {
      await stop();
      return;
    }
    _suppressPlaylistUpdates = true;
    _queue.removeAt(userIndex);
    if (_currentIndex > userIndex) {
      _currentIndex -= 1;
    } else if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    if (_currentIndex < 0) _currentIndex = 0;

    final newIdx = _currentIndex;
    final mediaList = _queue.map(_buildMedia).toList();
    try {
      await _player.open(Playlist(mediaList, index: newIdx), play: false);
      await _player.jump(newIdx);
      await _applyShuffleAndRepeat();
      if (_player.state.playing) {
        await _player.play();
      }
    } catch (e) {
      _emit(error: e.toString());
    } finally {
      _suppressPlaylistUpdates = false;
      _emit();
      _saveStateNow();
    }
  }

  /// Removes a track from the current queue by matching `path`. If the
  /// track isn't in the queue, does nothing. Handy for cleaning up the
  /// queue after a file is deleted from disk.
  Future<void> removeTrackFromQueue(String path) async {
    final idx = _queue.indexWhere((t) => t.path == path);
    if (idx < 0) return;
    await removeFromQueue(idx);
  }

  Future<void> dispose() async {
    _periodicSaveTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _snapshotController.close();
    await _player.dispose();
  }
}

class PositionData {
  final Duration position;
  final Duration buffered;
  final Duration duration;
  const PositionData(this.position, this.buffered, this.duration);
}

extension PlayerServicePosition on PlayerService {
  Stream<PositionData> get positionData =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        raw.stream.position,
        raw.stream.buffer,
        raw.stream.duration,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );
}

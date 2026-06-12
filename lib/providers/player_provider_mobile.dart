import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/track.dart';

final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) {
  return Stream.value(const PlaybackSnapshot());
});

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController();
});

class PlayerController {
  PlayerController();

  Future<void> playQueue(
    List<Track> tracks, {
    int? startIndex,
    bool autoPlay = true,
    dynamic albumKey,
  }) async {
    if (kDebugMode) print('Android: playQueue not implemented - no native audio libs');
  }

  Future<void> shuffleList(List<Track> tracks) async {
    if (kDebugMode) print('Android: shuffleList not implemented');
  }

  Future<void> play() async {}
  Future<void> pause() async {}
  Future<void> stop() async {}
  Future<void> next() async {}
  Future<void> previous() async {}
  Future<void> seek(Duration p) async {}
  Future<void> setVolume(double v) async {}
  Future<void> toggleMute() async {}
  Future<void> clearError() async {}
  Future<void> setSpeed(double s) async {}
  Future<void> cycleRepeat() async {}
  Future<void> jumpTo(int userIndex) async {}
  Future<void> removeFromQueue(int userIndex) async {}
  Future<void> removeTrackFromQueue(String path) async {}
}

enum RepeatMode { off, all, one }

class PlaybackSnapshot {
  final Track? currentTrack;
  final List queue;
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
  });
}
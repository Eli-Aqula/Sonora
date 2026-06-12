import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'lyrics_offset_ms_v1';

/// Global lyrics offset in milliseconds, relative to the player position.
/// Positive = lyrics "lag behind" (i.e. appear later than the audio) —
/// used when whisper produced the words earlier than they should be.
/// Negative — the opposite, lyrics "run ahead".
///
/// Applied at DISPLAY time: lookup_position = player_position − offset.
/// Does not change the stored LRC — can be adjusted back and forth
/// without re-syncing.
class LyricsOffsetNotifier extends StateNotifier<int> {
  LyricsOffsetNotifier() : super(_defaultMs) {
    _load();
  }

  static const int min = -5000;
  static const int max = 5000;

  /// Whisper.cpp word-level timestamps systematically run ~200-400ms
  /// ahead of the actual audio (a known quirk of the model's DTW attention).
  /// The default offset compensates for this out of the box.
  static const int _defaultMs = 300;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getInt(_key) ?? _defaultMs).clamp(min, max);
  }

  Future<void> set(int ms) async {
    final v = ms.clamp(min, max);
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, v);
  }

  Future<void> add(int deltaMs) => set(state + deltaMs);

  Future<void> reset() => set(0);
}

final lyricsOffsetMsProvider =
    StateNotifierProvider<LyricsOffsetNotifier, int>((ref) {
  return LyricsOffsetNotifier();
});

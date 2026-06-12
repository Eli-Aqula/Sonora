import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedPlayerState {
  final List<String> queuePaths;
  final int currentIndex;
  final Duration position;
  final double volume;
  final bool muted;

  const SavedPlayerState({
    required this.queuePaths,
    required this.currentIndex,
    required this.position,
    required this.volume,
    required this.muted,
  });

  Map<String, dynamic> toJson() => {
        'queuePaths': queuePaths,
        'currentIndex': currentIndex,
        'positionMs': position.inMilliseconds,
        'volume': volume,
        'muted': muted,
      };

  static SavedPlayerState? fromJson(Map<String, dynamic> json) {
    final paths = (json['queuePaths'] as List?)?.cast<String>();
    if (paths == null || paths.isEmpty) return null;
    return SavedPlayerState(
      queuePaths: paths,
      currentIndex: (json['currentIndex'] as int?) ?? 0,
      position: Duration(
        milliseconds: (json['positionMs'] as int?) ?? 0,
      ),
      volume: ((json['volume'] as num?) ?? 1.0).toDouble().clamp(0.0, 1.0),
      muted: (json['muted'] as bool?) ?? false,
    );
  }
}

class PlayerStateStorage {
  static const _key = 'player_state_v1';
  static const _saveDebounce = Duration(milliseconds: 800);

  Timer? _debounce;

  Future<SavedPlayerState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SavedPlayerState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  void save(SavedPlayerState state) {
    _debounce?.cancel();
    _debounce = Timer(_saveDebounce, () => _write(state));
  }

  Future<void> saveNow(SavedPlayerState state) async {
    _debounce?.cancel();
    await _write(state);
  }

  Future<void> _write(SavedPlayerState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    _debounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

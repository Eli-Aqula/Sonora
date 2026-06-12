import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/track.dart';

class SearchHistoryNotifier extends Notifier<List<Track>> {
  static const int _maxItems = 50;
  static const String _storageKey = 'search_history_v1';

  @override
  List<Track> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(Track.fromMap)
          .toList();
      state = List.unmodifiable(list);
    } catch (_) {
      // Ignore corrupted data.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.map((t) => t.toMap()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> add(Track track) async {
    final filtered = state.where((t) => t.path != track.path).toList();
    filtered.insert(0, track);
    if (filtered.length > _maxItems) {
      filtered.removeRange(_maxItems, filtered.length);
    }
    state = List.unmodifiable(filtered);
    await _save();
  }

  Future<void> clear() async {
    if (state.isEmpty) return;
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<Track>>(
  SearchHistoryNotifier.new,
);

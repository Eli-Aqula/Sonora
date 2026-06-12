import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/genius/genius_client.dart';
import '../services/genius/genius_enricher.dart';

/// Key for storing the Genius API client token in SharedPreferences.
const _kGeniusTokenKey = 'genius_token_v1';

/// Key for storing the "auto-refresh metadata on import" flag.
const _kGeniusAutoEnrichKey = 'genius_auto_enrich_v1';

/// Token state: `null` = not set, otherwise the token string.
///
/// Loading from SharedPreferences starts in the constructor. External code
/// can wait for it to finish via [ready] — this is critical for the
/// "Find on Genius" menu, which checks for the presence of a token once
/// at the moment of the click and is not reactive to the lazy load.
class GeniusTokenNotifier extends StateNotifier<String?> {
  GeniusTokenNotifier() : super(null) {
    _loadFuture = _load();
  }

  late final Future<void> _loadFuture;

  /// Completes once the initial load from SharedPreferences has finished.
  /// Awaiting it multiple times is safe (the Future is cached).
  Future<void> get ready => _loadFuture;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kGeniusTokenKey);
  }

  Future<void> set(String? token) async {
    final trimmed = token?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_kGeniusTokenKey);
    } else {
      await prefs.setString(_kGeniusTokenKey, value);
    }
  }

  Future<void> clear() => set(null);
}

final geniusTokenProvider =
    StateNotifierProvider<GeniusTokenNotifier, String?>((ref) {
  return GeniusTokenNotifier();
});

/// Flag: automatically enrich metadata when importing a folder.
class GeniusAutoEnrichNotifier extends StateNotifier<bool> {
  GeniusAutoEnrichNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kGeniusAutoEnrichKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGeniusAutoEnrichKey, value);
  }
}

final geniusAutoEnrichProvider =
    StateNotifierProvider<GeniusAutoEnrichNotifier, bool>((ref) {
  return GeniusAutoEnrichNotifier();
});

/// Genius HTTP client. Created only if a token is set; otherwise `null`.
///
/// When the token changes, the client is recreated automatically (Riverpod).
final geniusClientProvider = Provider<GeniusClient?>((ref) {
  final token = ref.watch(geniusTokenProvider);
  if (token == null || token.isEmpty) return null;
  final client = GeniusClient(token);
  ref.onDispose(client.dispose);
  return client;
});

/// Track enricher via Genius. Built on top of
/// [geniusClientProvider] — if no token is set, returns `null` and the
/// feature simply doesn't work (without crashing).
final geniusEnricherProvider = Provider<GeniusEnricher?>((ref) {
  final client = ref.watch(geniusClientProvider);
  if (client == null) return null;
  return GeniusEnricher(client);
});

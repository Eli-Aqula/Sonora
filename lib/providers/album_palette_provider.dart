import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

class AlbumPaletteCache extends Notifier<Map<String, Color>> {
  final Map<String, Future<Color?>> _inFlight = {};

  @override
  Map<String, Color> build() => const {};

  Color? peek(String? coverPath) {
    if (coverPath == null) return null;
    return state[coverPath];
  }

  Future<Color?> prefetch(String? coverPath) async {
    if (coverPath == null) return null;
    final cached = state[coverPath];
    if (cached != null) return cached;
    final pending = _inFlight[coverPath];
    if (pending != null) return pending;

    final future = _compute(coverPath);
    _inFlight[coverPath] = future;
    try {
      final color = await future;
      if (color != null) {
        state = {...state, coverPath: color};
      }
      return color;
    } finally {
      _inFlight.remove(coverPath);
    }
  }

  Future<Color?> _compute(String coverPath) async {
    final file = File(coverPath);
    if (!await file.exists()) return null;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(file),
        size: const Size(192, 192),
        maximumColorCount: 16,
      );
      return palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;
    } catch (_) {
      return null;
    }
  }
}

final albumPaletteCacheProvider =
    NotifierProvider<AlbumPaletteCache, Map<String, Color>>(
  AlbumPaletteCache.new,
);

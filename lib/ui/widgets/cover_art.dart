import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CoverArt extends StatefulWidget {
  final String? coverPath;
  final double size;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  const CoverArt({
    super.key,
    this.coverPath,
    this.size = 48,
    this.borderRadius,
    this.fallbackIcon = Icons.music_note,
  });

  /// Resets the internal cache of cover file existence. Call this when
  /// the cover file has been overwritten/deleted and future [CoverArt]
  /// instances need to recheck it on their next build.
  static void invalidate(String path) {
    _CoverArtState.invalidatePath(path);
  }

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt> {
  static final Map<String, bool> _existsCache = {};
  bool? _hasFile;

  /// Resets the "file exists" cache for the given path. Used after
  /// overwriting a cover on disk, so any live [CoverArt] instances
  /// recheck the file on their next `didUpdateWidget`.
  static void invalidatePath(String path) {
    _existsCache.remove(path);
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverPath != widget.coverPath) _resolve();
  }

  Future<void> _resolve() async {
    final path = widget.coverPath;
    if (path == null) {
      if (mounted) setState(() => _hasFile = false);
      return;
    }
    final cached = _existsCache[path];
    if (cached != null) {
      if (mounted) setState(() => _hasFile = cached);
      return;
    }
    final exists = await File(path).exists();
    _existsCache[path] = exists;
    if (mounted) setState(() => _hasFile = exists);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(widget.size * 0.12);
    final hasFile = _hasFile ?? false;
    if (_hasFile == null) {
      return _placeholder(radius);
    }
    if (hasFile) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(widget.coverPath!),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(radius),
        ),
      );
    }
    return _placeholder(radius);
  }

  Widget _placeholder(BorderRadius radius) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(
        widget.fallbackIcon,
        size: widget.size * 0.45,
        color: AppColors.textMuted,
      ),
    );
  }
}

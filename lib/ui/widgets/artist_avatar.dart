import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/artist_metadata_provider.dart';

/// Round artist avatar: a locally saved photo from Genius (if fetched),
/// otherwise a placeholder icon. The photo is read from disk, not the
/// network — see `ArtistImageStore`.
class ArtistAvatar extends ConsumerWidget {
  final String artistName;
  final double size;
  final double iconSize;

  const ArtistAvatar({
    super.key,
    required this.artistName,
    this.size = 40,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(artistMetadataByNameProvider(artistName));
    final imagePath = meta?.imagePath;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null || imagePath.isEmpty
          ? Icon(Icons.person_rounded,
              color: AppColors.textSecondary, size: iconSize)
          : Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.person_rounded,
                  color: AppColors.textSecondary, size: iconSize),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/browse_provider.dart';
import '../../providers/core_providers.dart';

/// Heart button for toggling an artist's "favorite" state directly from a
/// list. Loads the initial state from the database once and reacts
/// reactively to taps.
class ArtistFavoriteButton extends ConsumerStatefulWidget {
  final String artistName;
  const ArtistFavoriteButton({super.key, required this.artistName});

  @override
  ConsumerState<ArtistFavoriteButton> createState() =>
      _ArtistFavoriteButtonState();
}

class _ArtistFavoriteButtonState
    extends ConsumerState<ArtistFavoriteButton> {
  bool? _isFav;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(libraryRepositoryProvider);
    final fav = await repo.isArtistFavorite(widget.artistName);
    if (!mounted) return;
    setState(() {
      _isFav = fav;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 32, height: 32);
    final l10n = AppLocalizations.of(context)!;
    final isFav = _isFav ?? false;
    return IconButton(
      iconSize: 18,
      splashRadius: 18,
      tooltip: isFav ? l10n.playerRemoveFavorite : l10n.playerAddFavorite,
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? Colors.redAccent : AppColors.textSecondary,
      ),
      onPressed: () async {
        final newVal = await ref
            .read(favoritesNotifierProvider.notifier)
            .toggleArtist(widget.artistName);
        if (!mounted) return;
        setState(() => _isFav = newVal);
      },
    );
  }
}

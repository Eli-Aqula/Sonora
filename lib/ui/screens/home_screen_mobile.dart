import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/library_provider.dart';
import '../../providers/library_tab_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/android_permissions.dart';
import '../../ui/screens/library_tab.dart';
import '../utils/duration_format.dart';
import '../widgets/album_carousel.dart';
import '../widgets/artist_carousel.dart';
import '../widgets/cover_art.dart';
import '../widgets/settings_dialog.dart';

class MobileHomeScreen extends ConsumerWidget {
  const MobileHomeScreen({super.key});

  Future<void> _addAudioFiles(
      BuildContext context, LibraryController controller) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context)!;
    // On Android explicit permission is required, otherwise FilePicker
    // silently returns null/an empty list.
    final ok = await AndroidPermissions.ensureAudioAccess();
    if (!ok) {
      final permanently = await AndroidPermissions.isPermanentlyDenied();
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.mobileAudioPermissionMessage),
          duration: const Duration(seconds: 4),
          action: permanently
              ? SnackBarAction(
                  label: l10n.navSettings,
                  onPressed: AndroidPermissions.openSettings,
                )
              : null,
        ),
      );
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final paths = result.files
            .map((f) => f.path)
            .where((p) => p != null)
            .cast<String>()
            .toList();
        if (paths.isNotEmpty) {
          await controller.addAudioFiles(paths);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.mobileFilePickError('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    final snapshot = ref.watch(playbackSnapshotProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    int? indexIn(List tracks) {
      final current = snapshot.valueOrNull?.currentTrack;
      if (current == null) return null;
      for (var i = 0; i < tracks.length; i++) {
        if (tracks[i].path == current.path) return i;
      }
      return null;
    }

    // Empty = no tracks and no folders. On Android the user adds files
    // directly (without a watched folder), so checking only
    // `folders.isEmpty` would stay "empty" forever.
    final isEmpty = library.tracks.isEmpty && library.folders.isEmpty;

    if (isEmpty && library.loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isEmpty) {
      return _EmptyState(
        onPickFolder: () => _addAudioFiles(context, controller),
        onSettings: () => showSettingsDialog(context),
      );
    }

    final totalDuration = library.tracks.fold<Duration>(
      Duration.zero,
      (acc, t) => acc + t.duration,
    );
    // Sort by addedAt, not modifiedAt — otherwise after editing tags via
    // Genius a track jumps to the top of "recently added" even though
    // it has actually been in the library for a long time.
    final recent = [...library.tracks]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final recentList = recent.take(4).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Sonora'),
            backgroundColor: Colors.transparent,
            floating: true,
            actions: [
              if (library.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.homeRescan,
                  onPressed: () => controller.scan(),
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.navSettings,
                onPressed: () => showSettingsDialog(context),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeTracksCount(library.tracks.length),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        formatLongDuration(l10n, totalDuration),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const _QuickActionsSection(),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: l10n.homeRecentlyAdded,
                  onAll: () {
                    ref.read(mainTabProvider.notifier).state = 2;
                    ref.read(libraryTabProvider.notifier).state = LibraryTab.tracks;
                  },
                ),
                SizedBox(
                  height: 200,
                  child: _RecentTracksList(
                    tracks: recentList,
                    indexIn: indexIn,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: AlbumCarousel()),
          const SliverToBoxAdapter(child: ArtistCarousel()),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends ConsumerWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickButton(
              icon: Icons.play_arrow,
              label: l10n.homeAllTracks,
              onTap: () => ref
                  .read(playerControllerProvider)
                  .playQueue(library.tracks),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickButton(
              icon: Icons.shuffle,
              label: l10n.mobileShuffle,
              onTap: () => ref
                  .read(playerControllerProvider)
                  .shuffleList(library.tracks),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label, style: theme.textTheme.bodyMedium),
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAll;
  const _SectionHeader({required this.title, required this.onAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const Spacer(),
          TextButton(onPressed: onAll, child: Text(AppLocalizations.of(context)!.commonAll)),
        ],
      ),
    );
  }
}

class _RecentTracksList extends ConsumerWidget {
  final List tracks;
  final int? Function(List) indexIn;
  const _RecentTracksList({required this.tracks, required this.indexIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final track = tracks[i];
        return SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverArt(
                coverPath: track.coverPath,
                size: 140,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 8),
              Text(
                track.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                track.displayArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPickFolder;
  final VoidCallback onSettings;
  const _EmptyState({required this.onPickFolder, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sonora'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.navSettings,
            onPressed: onSettings,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_music, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 24),
              Text(l10n.mobileEmptyTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                l10n.mobileEmptyDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.folder),
                label: Text(l10n.mobileChooseFiles),
                onPressed: onPickFolder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
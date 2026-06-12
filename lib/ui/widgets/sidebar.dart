import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/playlist_provider.dart';
import 'app_dialog.dart';
import 'cover_art.dart';
import 'settings_dialog.dart';
import 'track_actions.dart';

class AppSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playlistsAsync = ref.watch(playlistsProvider);
    final theme = Theme.of(context);
    return Container(
      width: 220,
      color: AppColors.sidebar,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
            child: Text(
              'Sonora',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          _NavItem(
            icon: Icons.search,
            label: l10n.navSearch,
            active: widget.selectedIndex == 1,
            onTap: () => widget.onSelect(1),
          ),
          _NavItem(
            icon: Icons.home,
            label: l10n.navHome,
            active: widget.selectedIndex == 0,
            onTap: () => widget.onSelect(0),
          ),
          _NavItem(
            icon: Icons.favorite,
            label: l10n.navFavorites,
            active: widget.selectedIndex == 3,
            onTap: () => widget.onSelect(3),
          ),
          _NavItem(
            icon: Icons.library_music,
            label: l10n.navLibrary,
            active: widget.selectedIndex == 2,
            onTap: () => widget.onSelect(2),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.playlist_add, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.sidebarPlaylists, style: theme.textTheme.titleSmall),
              const Spacer(),
              _PillIconButton(
                icon: Icons.add,
                tooltip: l10n.sidebarCreatePlaylist,
                onTap: _createPlaylist,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: playlistsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Text(
                      l10n.sidebarPlaylistsEmpty,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    final idx = 4 + i;
                    final cover = p.effectiveCoverPath;
                    return _NavItem(
                      icon: Icons.playlist_play_rounded,
                      leading: cover != null
                          ? CoverArt(
                              key: ValueKey('pl_nav_cover_${p.id}_$cover'),
                              coverPath: cover,
                              size: 24,
                              borderRadius: BorderRadius.circular(6),
                              fallbackIcon: Icons.playlist_play_rounded,
                            )
                          : null,
                      label: p.name,
                      active: widget.selectedIndex == idx,
                      onTap: () => widget.onSelect(idx),
                      onMore: (ctx) => _showPlaylistMenu(ctx, p, idx),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => Text(l10n.commonError('$e'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.settings_outlined,
            label: l10n.navSettings,
            active: false,
            onTap: () => showSettingsDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final result = await showAppDialog<String>(
      context: context,
      title: l10n.sidebarNewPlaylistTitle,
      contentBuilder: (ctx) => AppTextField(
        controller: controller,
        hint: l10n.commonName,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        AppDialogAction(label: l10n.commonCancel, onTap: () => Navigator.pop(context)),
        AppDialogAction(
          label: l10n.commonCreate,
          primary: true,
          onTap: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(playlistsProvider.notifier).create(result);
    }
  }

  Future<void> _showPlaylistMenu(
    BuildContext buttonContext,
    Playlist playlist,
    int index,
  ) async {
    final l10n = AppLocalizations.of(buttonContext)!;
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlayBox =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final topRight = box.localToGlobal(
      box.size.topRight(Offset.zero),
      ancestor: overlayBox,
    );
    final action = await showAppPopupMenu<String>(
      context: buttonContext,
      anchor: topRight,
      items: [
        AppMenuItem(
          value: 'cover_set',
          icon: Icons.image_outlined,
          label: playlist.coverPath != null
              ? l10n.sidebarChangeCover
              : l10n.sidebarSetCover,
        ),
        if (playlist.coverPath != null)
          AppMenuItem(
            value: 'cover_clear',
            icon: Icons.image_not_supported_outlined,
            label: l10n.sidebarRemoveCover,
          ),
        AppMenuItem(
          value: 'rename',
          icon: Icons.edit_rounded,
          label: l10n.commonRename,
        ),
        AppMenuItem(
          value: 'delete',
          icon: Icons.delete_outline_rounded,
          label: l10n.commonDelete,
          danger: true,
        ),
      ],
    );
    if (action == null || !buttonContext.mounted) return;
    final controller = ref.read(playlistsProvider.notifier);
    if (action == 'cover_set') {
      try {
        await controller.pickAndSetCover(playlist.id!);
      } catch (e) {
        if (buttonContext.mounted) {
          await showAppDialog<void>(
            context: buttonContext,
            title: l10n.sidebarCoverSetFailedTitle,
            content: Text('$e',
                style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              AppDialogAction(
                label: l10n.commonOk,
                primary: true,
                onTap: () => Navigator.pop(buttonContext),
              ),
            ],
          );
        }
      }
    } else if (action == 'cover_clear') {
      await controller.clearCover(playlist.id!);
    } else if (action == 'rename') {
      final name = await _promptName(buttonContext, playlist.name);
      if (name != null && name.isNotEmpty && playlist.id != null) {
        await controller.rename(playlist.id!, name);
      }
    } else if (action == 'delete') {
      final confirm = await showAppDialog<bool>(
        context: buttonContext,
        title: l10n.sidebarDeletePlaylistTitle,
        content: Text(
          l10n.sidebarDeletePlaylistConfirm(playlist.name),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          AppDialogAction(
            label: l10n.commonCancel,
            onTap: () => Navigator.pop(buttonContext, false),
          ),
          AppDialogAction(
            label: l10n.commonDelete,
            danger: true,
            onTap: () => Navigator.pop(buttonContext, true),
          ),
        ],
      );
      if (confirm == true && playlist.id != null) {
        await controller.delete(playlist.id!);
        if (widget.selectedIndex == index && buttonContext.mounted) {
          widget.onSelect(0);
        }
      }
    }
  }

  Future<String?> _promptName(BuildContext context, String initial) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initial);
    return showAppDialog<String>(
      context: context,
      title: l10n.commonRename,
      contentBuilder: (ctx) => AppTextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        AppDialogAction(
          label: l10n.commonCancel,
          onTap: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: l10n.commonSave,
          primary: true,
          onTap: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _PillIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final Widget? leading;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final void Function(BuildContext)? onMore;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.leading,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.textPrimary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: active
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          onSecondaryTap: onMore == null ? null : () => onMore!(context),
          onLongPress: onMore == null ? null : () => onMore!(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: leading ?? Icon(icon, size: 20, color: color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (onMore != null)
                  Builder(
                    builder: (innerCtx) => IconButton(
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      splashRadius: 16,
                      icon: const Icon(Icons.more_horiz, size: 16),
                      color: AppColors.textMuted,
                      onPressed: () => onMore!(innerCtx),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

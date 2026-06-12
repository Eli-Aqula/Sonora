import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/genius_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/genius/cover_downloader.dart';
import '../../services/genius/genius_client.dart';
import '../../services/metadata_writer.dart';
import 'app_dialog.dart';
import 'genius_search_dialog.dart';
import 'tag_editor_dialog.dart';

/// Shows the app's custom popup menu (transparent background, white
/// outline, rounded corners) next to the `⋮` button in a track row.
///
/// If [layerLink] is provided, the menu is "pinned" to the button via
/// [CompositedTransformFollower] and follows it while scrolling.
Future<void> showTrackActionsMenu(
  BuildContext buttonContext,
  WidgetRef ref,
  Track track, {
  LayerLink? layerLink,
}) async {
  final box = buttonContext.findRenderObject() as RenderBox?;
  if (box == null) return;
  final overlayBox =
      Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
  final topRight = box.localToGlobal(
    box.size.topRight(Offset.zero),
    ancestor: overlayBox,
  );
  final l10n = AppLocalizations.of(buttonContext)!;
  // The "Find on Genius" item is only shown when a token is set and a
  // client can be created. ref.read is fine here — the menu opens in
  // response to a user action, no reactivity is needed.
  final geniusClient = ref.read(geniusClientProvider);
  final result = await showAppPopupMenu<String>(
    context: buttonContext,
    anchor: topRight,
    link: layerLink,
    items: [
      AppMenuItem(
        value: 'playlist',
        icon: Icons.playlist_add_rounded,
        label: l10n.trackAddToPlaylist,
      ),
      AppMenuItem(
        value: 'edit_tags',
        icon: Icons.edit_note_rounded,
        label: l10n.trackEditTags,
      ),
      if (geniusClient != null)
        AppMenuItem(
          value: 'find_genius',
          icon: Icons.search_rounded,
          label: l10n.trackFindOnGenius,
        ),
      AppMenuItem(
        value: 'delete',
        icon: Icons.delete_outline_rounded,
        label: l10n.trackDeleteFromDevice,
        danger: true,
      ),
    ],
  );
  if (result == null || !buttonContext.mounted) return;
  switch (result) {
    case 'playlist':
      await _addToPlaylistFlow(buttonContext, ref, track, layerLink: layerLink);
      break;
    case 'edit_tags':
      await _editTagsFlow(buttonContext, track);
      break;
    case 'find_genius':
      // No null check needed: this item is only shown when a client exists.
      await _findOnGeniusFlow(buttonContext, ref, geniusClient!, track);
      break;
    case 'delete':
      await _deleteFromDeviceFlow(buttonContext, ref, track);
      break;
  }
}

Future<void> _addToPlaylistFlow(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  LayerLink? layerLink,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (track.id == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l10n.trackNotInLibrary)),
    );
    return;
  }
  final playlistsList =
      ref.read(playlistsProvider).valueOrNull ?? const <Playlist>[];
  if (playlistsList.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l10n.trackCreatePlaylistFirst)),
    );
    return;
  }
  final chosen = await showAppPopupMenu<Playlist>(
    context: context,
    anchor: Offset.zero,
    link: layerLink,
    items: [
      for (final p in playlistsList)
        AppMenuItem(
          value: p,
          icon: Icons.queue_music_rounded,
          label: p.name,
          subtitle: l10n.homeTracksCount(p.trackCount),
        ),
    ],
  );
  if (chosen != null && chosen.id != null && context.mounted) {
    await ref
        .read(playlistsProvider.notifier)
        .addTrack(chosen.id!, track.id!);
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l10n.trackAddedToPlaylist(chosen.name)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

Future<void> _deleteFromDeviceFlow(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (track.id == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l10n.trackNotInLibrary)),
    );
    return;
  }
  final confirm = await showAppDialog<bool>(
    context: context,
    title: l10n.trackDeleteTitle,
    content: Text(
      l10n.trackDeleteConfirm(track.displayTitle),
      style: const TextStyle(color: AppColors.textSecondary),
    ),
    actions: [
      AppDialogAction(
        label: l10n.commonCancel,
        onTap: () => Navigator.pop(context, false),
      ),
      AppDialogAction(
        label: l10n.commonDelete,
        danger: true,
        onTap: () => Navigator.pop(context, true),
      ),
    ],
  );
  if (confirm != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  await ref.read(playerControllerProvider).removeTrackFromQueue(track.path);
  await ref.read(libraryControllerProvider.notifier).removeTrack(track);
  if (!context.mounted) return;
  messenger?.showSnackBar(
    SnackBar(
      content: Text(l10n.trackDeleted(track.displayTitle)),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> _editTagsFlow(BuildContext context, Track track) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context)!;
  final updated = await showTagEditorDialog(context: context, track: track);
  if (updated == null || !context.mounted) return;
  messenger?.showSnackBar(
    SnackBar(
      content: Text(l10n.trackTagsUpdated(updated.displayTitle)),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Opens the Genius picker; when a hit is selected, downloads its cover
/// art to a temp file and applies the chosen tags to the track via
/// [LibraryController] — exactly the same way the tag editor does.
///
/// The cover is always downloaded to temp to avoid cluttering permanent
/// storage; the temp file is deleted in `finally`.
Future<void> _findOnGeniusFlow(
  BuildContext context,
  WidgetRef ref,
  GeniusClient client,
  Track track,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (track.id == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l10n.trackNotInLibrary)),
    );
    return;
  }
  final song = await showGeniusSearchDialog(
    context: context,
    client: client,
    track: track,
  );
  if (song == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);

  String? tempCover;
  try {
    final coverUrl = song.songArtImageUrl ?? song.headerImageUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      tempCover = await CoverDownloader.downloadToTemp(
        coverUrl,
        songId: track.id!,
      );
    }
    if (!context.mounted) return;

    final edits = TagEdits(
      title: _nonEmpty(_stripTranslationSuffix(song.title)),
      trackArtist: _nonEmpty(_stripTranslationSuffix(song.primaryArtistName)),
      album: _nonEmpty(_stripTranslationSuffix(song.album?.name)),
      year: song.releaseDate?.year,
      // Lyrics are fetched by the scraper in GeniusClient.getSong() and
      // need to land both in the file (USLT/LYRICS) and in the DB via
      // MetadataReader.
      lyrics: _nonEmpty(song.lyricsText),
      cover: tempCover != null
          ? CoverReplace(tempCover)
          : const CoverKeep(),
    );
    await ref
        .read(libraryControllerProvider.notifier)
        .updateTrackTags(track, edits);

    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.trackTagsUpdatedFrom(song.title)),
        duration: const Duration(seconds: 2),
      ),
    );
  } on MetadataWriteException catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.trackTagsWriteFailed(e.message)),
        duration: const Duration(seconds: 3),
      ),
    );
  } on GeniusException catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.geniusError(e.message)),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.commonError('$e')),
        duration: const Duration(seconds: 3),
      ),
    );
  } finally {
    await CoverDownloader.deleteTemp(tempCover);
  }
}

/// Strips trailing English-translation/romanization markers that Genius
/// appends to titles of Cyrillic tracks. Two patterns:
///
/// 1. Explicit markers: `(English)`, `(Romanized)`, `[Translation]`,
///    `(Перевод)`, `(Romaji)`, `(Transliteration)` — always removed.
/// 2. Any trailing parenthetical containing **only Latin characters**, if
///    the remaining text contains Cyrillic: `Город (City)` → `Город`,
///    `Занесло (Skidded)` → `Занесло`. This is a typical Latin-script
///    title caption that Genius adds for Russian-speaking artists.
String? _stripTranslationSuffix(String? s) {
  if (s == null) return null;
  var t = s.trim();

  final explicitRe = RegExp(
    r'\s*[\(\[\{]\s*(?:english(?:\s+translation)?|romanized|romanization|'
    r'translation|перевод|romaji|transliteration)\s*[\)\]\}]\s*$',
    caseSensitive: false,
  );

  // A trailing parenthetical with only Latin characters, provided the
  // remaining text contains Cyrillic. Spaces, hyphens, apostrophes,
  // periods, and digits are allowed inside the parentheses.
  final cyrillicRe = RegExp(r'[Ѐ-ӿ]');
  final latinParenRe = RegExp(
    r"\s*[\(\[\{]\s*[A-Za-z][A-Za-z0-9\s'’\-\.&,]*\s*[\)\]\}]\s*$",
  );

  for (var i = 0; i < 3; i++) {
    var changed = false;
    final afterExplicit = t.replaceAll(explicitRe, '').trim();
    if (afterExplicit != t) {
      t = afterExplicit;
      changed = true;
    }
    // A Latin parenthetical is removed only if the remaining text contains Cyrillic.
    final m = latinParenRe.firstMatch(t);
    if (m != null) {
      final head = t.substring(0, m.start).trim();
      if (cyrillicRe.hasMatch(head)) {
        t = head;
        changed = true;
      }
    }
    if (!changed) break;
  }
  return t.isEmpty ? null : t;
}

/// Empty/whitespace string → null (so `MetadataWriter` keeps the previous
/// tag value instead of clearing it).
String? _nonEmpty(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// Description of a single custom menu item.
class AppMenuItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool danger;
  const AppMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
    this.danger = false,
  });
}

/// The app's custom popup menu.
/// The menu appears to the left of the anchor point (the top-right
/// corner of the button) so it doesn't overflow the right edge of the
/// screen, while visually sitting "at the right edge of the track".
///
/// If [link] is provided, the menu is "pinned" to that anchor via
/// [CompositedTransformFollower] and follows it while scrolling or any
/// other movement. In that case [anchor] is ignored.
Future<T?> showAppPopupMenu<T>({
  required BuildContext context,
  required Offset anchor,
  required List<AppMenuItem<T>> items,
  LayerLink? link,
}) async {
  final overlay = Overlay.of(context);
  final completer = _MenuCompleter<T>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _AppPopupMenuOverlay<T>(
      anchor: anchor,
      link: link,
      items: items,
      onSelected: (value) {
        if (!completer.isCompleted) {
          completer.complete(value);
          entry.remove();
        }
      },
      onDismiss: () {
        if (!completer.isCompleted) {
          completer.complete(null);
          entry.remove();
        }
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _MenuCompleter<T> {
  T? _value;
  bool _completed = false;
  final List<void Function(T?)> _listeners = [];
  bool get isCompleted => _completed;
  void complete(T? value) {
    if (_completed) return;
    _completed = true;
    _value = value;
    for (final l in _listeners) {
      l(value);
    }
  }

  Future<T?> get future {
    if (_completed) return Future.value(_value);
    final c = Completer<T?>();
    _listeners.add((v) => c.complete(v));
    return c.future;
  }
}

class _AppPopupMenuOverlay<T> extends StatelessWidget {
  final Offset anchor;
  final LayerLink? link;
  final List<AppMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final VoidCallback onDismiss;

  const _AppPopupMenuOverlay({
    required this.anchor,
    required this.items,
    required this.onSelected,
    required this.onDismiss,
    this.link,
  });

  static const _menuWidth = 240.0;
  static const _verticalGap = 4.0;
  static const _maxMenuHeight = 360.0;

  Widget _buildMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _menuWidth,
        constraints: BoxConstraints(maxHeight: _maxMenuHeight),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final item in items) ...[
                _MenuRow<T>(
                  item: item,
                  onTap: () => onSelected(item.value),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (link != null) {
      // The menu is "pinned" to the button: follows it while scrolling.
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onDismiss,
            ),
          ),
          CompositedTransformFollower(
            link: link!,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, _verticalGap),
            child: _buildMenu(),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
        // The menu's right edge aligns with the button's right edge —
        // visually the menu "grows left" from the track.
        double right = overlaySize.width - anchor.dx;
        if (right < 8) right = 8;
        if (right + _menuWidth > overlaySize.width - 8) {
          right = overlaySize.width - 8 - _menuWidth;
        }
        // If the menu doesn't fit below — open it above the button.
        final desiredTop = anchor.dy + _verticalGap;
        final overflowsBottom =
            desiredTop + _maxMenuHeight > overlaySize.height - 8;
        final double? top;
        final double? bottom;
        if (overflowsBottom) {
          top = null;
          bottom = overlaySize.height - anchor.dy + _verticalGap;
        } else {
          top = desiredTop;
          bottom = null;
        }
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onDismiss,
              ),
            ),
            Positioned(
              right: right,
              top: top,
              bottom: bottom,
              child: _buildMenu(),
            ),
          ],
        );
      },
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  final AppMenuItem<T> item;
  final VoidCallback onTap;
  const _MenuRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final danger = item.danger;
    final iconColor = danger ? Colors.redAccent : AppColors.textSecondary;
    final textColor =
        danger ? Colors.redAccent : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

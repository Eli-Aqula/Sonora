import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/metadata_writer.dart';

/// Shows the track-metadata edit dialog. Returns the updated track if the
/// user saved changes, otherwise `null`.
Future<Track?> showTagEditorDialog({
  required BuildContext context,
  required Track track,
}) {
  return showDialog<Track>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => _TagEditorDialog(track: track),
  );
}

class _TagEditorDialog extends ConsumerStatefulWidget {
  final Track track;
  const _TagEditorDialog({required this.track});

  @override
  ConsumerState<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends ConsumerState<_TagEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _album;
  late final TextEditingController _albumArtist;
  late final TextEditingController _year;
  late final TextEditingController _trackNumber;
  late final TextEditingController _discNumber;
  late final TextEditingController _genre;
  late final TextEditingController _bpm;
  late final TextEditingController _lyrics;

  // The original "displayed" values — used to determine whether the user
  // deliberately cleared a field (the tag should be erased) or simply
  // left it unchanged.
  late final String _origTitle;
  late final String _origArtist;
  late final String _origAlbum;
  late final String _origAlbumArtist;
  late final String _origYear;
  late final String _origTrackNumber;
  late final String _origDiscNumber;
  late final String _origGenre;
  late final String _origBpm;
  late final String _origLyrics;

  CoverChange _coverChange = const CoverKeep();
  String? _coverPreviewPath; // path to the preview file
  bool _coverRemoved = false;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.track;
    _origTitle = t.title;
    _origArtist = t.artist;
    _origAlbum = t.album;
    _origAlbumArtist = t.albumArtist ?? '';
    _origYear = t.year?.toString() ?? '';
    _origTrackNumber = t.trackNumber?.toString() ?? '';
    _origDiscNumber = t.discNumber?.toString() ?? '';
    _origGenre = t.genre ?? '';
    _origBpm = '';
    _origLyrics = '';

    _title = TextEditingController(text: _origTitle);
    _artist = TextEditingController(text: _origArtist);
    _album = TextEditingController(text: _origAlbum);
    _albumArtist = TextEditingController(text: _origAlbumArtist);
    _year = TextEditingController(text: _origYear);
    _trackNumber = TextEditingController(text: _origTrackNumber);
    _discNumber = TextEditingController(text: _origDiscNumber);
    _genre = TextEditingController(text: _origGenre);
    _bpm = TextEditingController(text: _origBpm);
    _lyrics = TextEditingController(text: _origLyrics);

    _coverPreviewPath = t.coverPath;
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    _albumArtist.dispose();
    _year.dispose();
    _trackNumber.dispose();
    _discNumber.dispose();
    _genre.dispose();
    _bpm.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'tif', 'tiff'],
      dialogTitle: AppLocalizations.of(context)!.tagEditorChooseCoverImageDialog,
    );
    if (!mounted) return;
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _coverChange = CoverReplace(path);
      _coverPreviewPath = path;
      _coverRemoved = false;
    });
  }

  void _removeCover() {
    setState(() {
      _coverChange = const CoverRemove();
      _coverPreviewPath = null;
      _coverRemoved = true;
    });
  }

  void _resetCover() {
    setState(() {
      _coverChange = const CoverKeep();
      _coverPreviewPath = widget.track.coverPath;
      _coverRemoved = false;
    });
  }

  TagEdits _collectEdits() {
    final clearedFields = <String>{};

    String? textValue(String key, TextEditingController c, String original) {
      final value = c.text.trim();
      if (value == original.trim()) return null; // unchanged
      if (value.isEmpty) {
        clearedFields.add(key);
        return null;
      }
      return value;
    }

    int? intValue(String key, TextEditingController c, String original) {
      final value = c.text.trim();
      if (value == original.trim()) return null;
      if (value.isEmpty) {
        clearedFields.add(key);
        return null;
      }
      return int.tryParse(value);
    }

    double? doubleValue(String key, TextEditingController c, String original) {
      final value = c.text.trim();
      if (value == original.trim()) return null;
      if (value.isEmpty) {
        clearedFields.add(key);
        return null;
      }
      return double.tryParse(value.replaceAll(',', '.'));
    }

    return TagEdits(
      title: textValue('title', _title, _origTitle),
      trackArtist: textValue('trackArtist', _artist, _origArtist),
      album: textValue('album', _album, _origAlbum),
      albumArtist: textValue('albumArtist', _albumArtist, _origAlbumArtist),
      year: intValue('year', _year, _origYear),
      trackNumber: intValue('trackNumber', _trackNumber, _origTrackNumber),
      discNumber: intValue('discNumber', _discNumber, _origDiscNumber),
      genre: textValue('genre', _genre, _origGenre),
      bpm: doubleValue('bpm', _bpm, _origBpm),
      lyrics: textValue('lyrics', _lyrics, _origLyrics),
      cover: _coverChange,
      clearedFields: clearedFields,
    );
  }

  bool _hasChanges() {
    if (_coverChange is! CoverKeep) return true;
    if (_title.text.trim() != _origTitle.trim()) return true;
    if (_artist.text.trim() != _origArtist.trim()) return true;
    if (_album.text.trim() != _origAlbum.trim()) return true;
    if (_albumArtist.text.trim() != _origAlbumArtist.trim()) return true;
    if (_year.text.trim() != _origYear.trim()) return true;
    if (_trackNumber.text.trim() != _origTrackNumber.trim()) return true;
    if (_discNumber.text.trim() != _origDiscNumber.trim()) return true;
    if (_genre.text.trim() != _origGenre.trim()) return true;
    if (_bpm.text.trim() != _origBpm.trim()) return true;
    if (_lyrics.text.trim() != _origLyrics.trim()) return true;
    return false;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_hasChanges()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final controller = ref.read(libraryControllerProvider.notifier);
    try {
      final updated = await controller.updateTrackTags(
        widget.track,
        _collectEdits(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on MetadataWriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context)!.commonError('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = ref.watch(playbackSnapshotProvider).valueOrNull;
    final isPlayingThisTrack =
        snapshot?.currentTrack?.path == widget.track.path &&
            (snapshot?.playing ?? false);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.label_outline_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.tagEditorTitle,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 20,
                    splashRadius: 18,
                    icon: const Icon(Icons.close_rounded),
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _shortPath(widget.track.path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              if (isPlayingThisTrack)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.amberAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.tagEditorPlayingWarning,
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            color: Colors.amberAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CoverEditor(
                        previewPath: _coverPreviewPath,
                        removed: _coverRemoved,
                        onPick: _saving ? null : _pickCover,
                        onRemove: _saving ? null : _removeCover,
                        onReset: _coverChange is CoverKeep || _saving
                            ? null
                            : _resetCover,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Field(label: l10n.tagEditorTitleField, controller: _title),
                            const SizedBox(height: 10),
                            _Field(label: l10n.tagEditorArtist, controller: _artist),
                            const SizedBox(height: 10),
                            _Field(label: l10n.tagEditorAlbum, controller: _album),
                            const SizedBox(height: 10),
                            _Field(
                                label: l10n.tagEditorAlbumArtist,
                                controller: _albumArtist),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: l10n.tagEditorYear,
                                    controller: _year,
                                    keyboard: TextInputType.number,
                                    formatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Field(
                                    label: l10n.tagEditorTrackNumber,
                                    controller: _trackNumber,
                                    keyboard: TextInputType.number,
                                    formatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Field(
                                    label: l10n.tagEditorDiscNumber,
                                    controller: _discNumber,
                                    keyboard: TextInputType.number,
                                    formatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _Field(
                                      label: l10n.tagEditorGenre, controller: _genre),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Field(
                                    label: 'BPM',
                                    controller: _bpm,
                                    keyboard:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    formatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]')),
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _Field(
                              label: l10n.lyricsTitle,
                              controller: _lyrics,
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: l10n.commonCancel,
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: _saving ? l10n.tagEditorSaving : l10n.commonSave,
                    primary: true,
                    onTap: _saving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortPath(String path) {
    const max = 70;
    if (path.length <= max) return path;
    return '…${path.substring(path.length - max)}';
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final int maxLines;
  final List<TextInputFormatter>? formatters;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboard,
    this.maxLines = 1,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          minLines: 1,
          inputFormatters: formatters,
          cursorColor: AppColors.textPrimary,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverEditor extends StatelessWidget {
  final String? previewPath;
  final bool removed;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;
  final VoidCallback? onReset;

  const _CoverEditor({
    required this.previewPath,
    required this.removed,
    required this.onPick,
    required this.onRemove,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const size = 180.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: previewPath != null && File(previewPath!).existsSync()
              ? Image.file(
                  File(previewPath!),
                  key: ValueKey(previewPath),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: size,
          child: Column(
            children: [
              _CoverButton(
                icon: Icons.image_outlined,
                label: l10n.tagEditorChooseCover,
                onTap: onPick,
              ),
              const SizedBox(height: 6),
              _CoverButton(
                icon: Icons.delete_outline_rounded,
                label: l10n.sidebarRemoveCover,
                onTap: onRemove,
                danger: true,
              ),
              if (onReset != null) ...[
                const SizedBox(height: 6),
                _CoverButton(
                  icon: Icons.undo_rounded,
                  label: l10n.tagEditorRevertCover,
                  onTap: onReset,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Icon(
        removed ? Icons.image_not_supported_outlined : Icons.music_note,
        size: 56,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const _CoverButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = !enabled
        ? AppColors.textMuted
        : (danger ? Colors.redAccent : AppColors.textPrimary);
    final border = !enabled
        ? Colors.white.withValues(alpha: 0.06)
        : (danger
            ? Colors.red.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.18));
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const _DialogButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color border;
    final Color text;
    final Color fill;
    if (primary) {
      border = enabled
          ? Colors.white.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.2);
      text = enabled ? AppColors.textPrimary : AppColors.textMuted;
      fill = enabled
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.transparent;
    } else {
      border = Colors.white.withValues(alpha: 0.18);
      text = enabled ? AppColors.textSecondary : AppColors.textMuted;
      fill = Colors.transparent;
    }
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

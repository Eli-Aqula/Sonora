import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/lyrics_offset_provider.dart';
import '../../providers/player_provider.dart';
import '../../data/models/track.dart';
import '../../services/lyrics/lrc_parser.dart';

/// Side lyrics panel with current-line highlighting and auto-scroll.
///
/// Accepts two sources:
/// - [lrcContent] — synchronized LRC (with `[mm:ss.xx]` timecodes);
/// - [plainLyrics] — plain text without timecodes.
///
/// If LRC is available, it's shown with highlighting and auto-scroll
/// following the player position. If only plain text is available, it's
/// shown statically without highlighting.
class LyricsSidePanel extends ConsumerStatefulWidget {
  final String? lrcContent;
  final String? plainLyrics;
  final Duration duration;
  final Track? track;

  const LyricsSidePanel({
    super.key,
    required this.lrcContent,
    required this.duration,
    this.plainLyrics,
    this.track,
  });

  @override
  ConsumerState<LyricsSidePanel> createState() => _LyricsSidePanelState();
}

class _LyricsSidePanelState extends ConsumerState<LyricsSidePanel> {
  final _scrollController = ScrollController();
  int? _lastCurrentIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Centers the selected line in the visible area.
  /// Approximate single-line height = 30 px (corrected on the fly once
  /// the controller knows the viewport).
  void _scrollToLine(int index, int totalLines) {
    if (totalLines == 0) return;
    if (_lastCurrentIndex == index) return;
    if (!_scrollController.hasClients) return;
    _lastCurrentIndex = index;

    const lineHeight = 30.0;
    final viewport = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final desired = index * lineHeight - (viewport / 2) + (lineHeight / 2);
    final target = desired.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lrcLines = widget.lrcContent != null && widget.lrcContent!.isNotEmpty
        ? parseLrc(widget.lrcContent!)
        : <LrcLine>[];
    final hasLrc = lrcLines.isNotEmpty;

    final plainLines = !hasLrc
        ? (widget.plainLyrics ?? '')
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList()
        : const <String>[];

    final snapshot = ref.watch(playbackSnapshotProvider).valueOrNull;
    final position = snapshot?.position ?? Duration.zero;
    // Lyrics offset: + → lyrics "lag behind" (compensates for whisper
    // timestamps that run ahead), − → lyrics run ahead. Applied only for
    // display purposes.
    final offsetMs = ref.watch(lyricsOffsetMsProvider);
    final lookupPosition = position - Duration(milliseconds: offsetMs);
    final currentLine =
        hasLrc ? findCurrentLine(lrcLines, lookupPosition) : null;
    final currentIndex = currentLine != null
        ? lrcLines.indexWhere((l) => l == currentLine)
        : -1;

    if (hasLrc && currentIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLine(currentIndex, lrcLines.length);
      });
    }

    final hasAnyText = hasLrc || plainLines.isNotEmpty;
    // The "Sync" button is available whenever plain text exists (even if
    // LRC already exists — the user may want to regenerate it).
    final canSync = widget.track?.id != null &&
        (widget.plainLyrics?.isNotEmpty ?? false);

    return Column(
      children: [
        if (!hasAnyText)
          Expanded(
            child: Center(
              child: Text(
                l10n.lyricsNotFound,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else if (hasLrc)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: lrcLines.length,
              itemBuilder: (context, index) {
                final line = lrcLines[index];
                final isCurrent = line == currentLine;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      color: isCurrent
                          ? Colors.greenAccent
                          : AppColors.textSecondary,
                      fontSize: isCurrent ? 16 : 14,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                );
              },
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: plainLines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    plainLines[index],
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        const Divider(height: 1),
        if (hasLrc) _OffsetControls(offsetMs: offsetMs, ref: ref),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: canSync ? () => _syncLyrics(context, widget.track!) : null,
            icon: const Icon(Icons.sync, size: 16),
            label: Text(hasLrc ? l10n.lyricsResync : l10n.lyricsSync),
          ),
        ),
      ],
    );
  }

  void _syncLyrics(BuildContext context, Track track) async {
    if (track.id == null) return;
    final controller =
        ProviderScope.containerOf(context).read(playerControllerProvider);
    // Use the plain text from props if set, otherwise from the track itself.
    final plainLyrics = widget.plainLyrics ?? track.lyricsText ?? '';
    if (plainLyrics.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(l10n.lyricsSyncingEllipsis),
          ],
        ),
      ),
    );

    String? errorMessage;
    try {
      await controller.syncLyrics(
        trackId: track.id!,
        audioPath: track.path,
        plainLyrics: plainLyrics,
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }

    if (errorMessage != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

/// Compact lyrics-offset panel. A positive offset delays line display
/// (when whisper timestamps run ahead), a negative offset shows lines
/// earlier.
///
/// Step is 100 ms on a short tap, 500 ms via the wider-step buttons.
/// Persisted globally in SharedPreferences.
class _OffsetControls extends StatelessWidget {
  final int offsetMs;
  final WidgetRef ref;
  const _OffsetControls({required this.offsetMs, required this.ref});

  String _format(AppLocalizations l10n, int ms) {
    if (ms == 0) return l10n.lyricsOffsetValue('0.0');
    final sign = ms > 0 ? '+' : '−';
    final abs = ms.abs();
    return l10n.lyricsOffsetValue('$sign${(abs / 1000).toStringAsFixed(1)}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(lyricsOffsetMsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            l10n.lyricsOffsetLabel,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            label: '−0.5',
            tooltip: l10n.lyricsEarlierBy('0.5'),
            onTap: () => notifier.add(-500),
          ),
          _StepButton(
            label: '−0.1',
            tooltip: l10n.lyricsEarlierBy('0.1'),
            onTap: () => notifier.add(-100),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => notifier.reset(),
                child: Text(
                  _format(l10n, offsetMs),
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    color: offsetMs == 0
                        ? AppColors.textSecondary
                        : Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            label: '+0.1',
            tooltip: l10n.lyricsLaterBy('0.1'),
            onTap: () => notifier.add(100),
          ),
          _StepButton(
            label: '+0.5',
            tooltip: l10n.lyricsLaterBy('0.5'),
            onTap: () => notifier.add(500),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  const _StepButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
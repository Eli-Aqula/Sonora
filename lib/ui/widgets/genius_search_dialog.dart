import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../l10n/app_localizations.dart';
import '../../services/genius/genius_client.dart';
import '../../services/genius/genius_models.dart';
import '../../services/genius/match_scorer.dart';

/// Genius search-results picker dialog.
///
/// Flow:
/// 1. Takes [track] and an optional [initialQuery] (built from
///    `artist + title` by default).
/// 2. `initState` kicks off an async chain: search → score → enrich.
/// 3. Once ready — a list of top-5 cards.
/// 4. The user picks one and taps "Apply" — the dialog closes with a
///    [GeniusSong] value.
/// 5. The user can adjust the query via the "Change…" button in the header.
///
/// Returns the selected [GeniusSong] or `null` (cancelled/no hits).
class GeniusSearchDialog extends StatefulWidget {
  final GeniusClient client;
  final Track track;
  final String initialQuery;

  const GeniusSearchDialog({
    super.key,
    required this.client,
    required this.track,
    required this.initialQuery,
  });

  @override
  State<GeniusSearchDialog> createState() => _GeniusSearchDialogState();
}

class _GeniusSearchDialogState extends State<GeniusSearchDialog> {
  late final TextEditingController _queryController;
  late String _query;

  /// Loading/error state.
  _LoadState _state = _LoadState.loading;
  String? _error;
  List<ScoredSong> _results = const [];

  /// Selected index (null = nothing selected).
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _queryController = TextEditingController(text: _query);
    _runSearch();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() {
      _state = _LoadState.loading;
      _error = null;
      _selectedIndex = null;
    });
    try {
      final hits = await widget.client.search(_query);
      final top = MatchScorer.topMatches(hits, widget.track);
      if (top.isEmpty) {
        if (!mounted) return;
        setState(() {
          _state = _LoadState.empty;
          _results = const [];
        });
        return;
      }
      final songs = await MatchScorer.enrich(widget.client, top.map((e) => e.hit).toList());
      if (!mounted) return;
      // Match enriched songs back to their scores (preserving the top order).
      final results = <ScoredSong>[];
      for (var i = 0; i < top.length; i++) {
        final song = songs.firstWhere(
          (s) => s.id == top[i].hit.id,
          orElse: () => songs.firstWhere((_) => true),
        );
        if (songs.isNotEmpty) {
          results.add(ScoredSong(song: song, score: top[i].score));
        }
      }
      // Sort: enriched songs may not have come back in the same order.
      results.sort((a, b) => b.score.compareTo(a.score));
      setState(() {
        _state = _LoadState.ready;
        _results = results;
      });
    } on GeniusException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _error = AppLocalizations.of(context)!.commonError('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                track: widget.track,
                state: _state,
                resultsCount: _results.length,
                onChangeQuery: _showQueryEditor,
                onRetry: _runSearch,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _buildBody(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: l10n.commonCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: l10n.commonApply,
                    primary: true,
                    onTap: _selectedIndex == null
                        ? null
                        : () => Navigator.of(context)
                            .pop(_results[_selectedIndex!].song),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    switch (_state) {
      case _LoadState.loading:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.geniusSearchingEllipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      case _LoadState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded,
                    size: 36, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(
                  l10n.geniusNoResultsFor(widget.track.displayTitle),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _showQueryEditor,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l10n.geniusChangeQuery),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 36, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  _error ?? l10n.geniusUnknownError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _runSearch,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.commonRetry),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      case _LoadState.ready:
        return ListView.separated(
          shrinkWrap: true,
          itemCount: _results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ResultCard(
            song: _results[i].song,
            score: _results[i].score,
            trackDurationSeconds: widget.track.duration.inSeconds,
            selected: _selectedIndex == i,
            onTap: () => setState(() => _selectedIndex = i),
          ),
        );
    }
  }

  Future<void> _showQueryEditor() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _QueryEditorDialog(
        controller: _queryController,
        onSubmit: (v) => Navigator.of(ctx).pop(v),
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      setState(() {
        _query = result.trim();
        _queryController.text = _query;
      });
      _runSearch();
    }
  }
}

enum _LoadState { loading, ready, empty, error }

class ScoredSong {
  final GeniusSong song;
  final double score;
  const ScoredSong({required this.song, required this.score});
}

class _Header extends StatelessWidget {
  final Track track;
  final _LoadState state;
  final int resultsCount;
  final VoidCallback onChangeQuery;
  final VoidCallback onRetry;

  const _Header({
    required this.track,
    required this.state,
    required this.resultsCount,
    required this.onChangeQuery,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String subtitle;
    switch (state) {
      case _LoadState.loading:
        subtitle = l10n.geniusSearchingShort;
        break;
      case _LoadState.ready:
        subtitle = l10n.geniusMatchesFound(resultsCount);
        break;
      case _LoadState.empty:
        subtitle = l10n.geniusNothingFound;
        break;
      case _LoadState.error:
        subtitle = l10n.geniusErrorLabel;
        break;
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.trackFindOnGenius,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${track.displayArtist} — ${track.displayTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          iconSize: 18,
          splashRadius: 18,
          tooltip: l10n.geniusChangeQuery,
          icon: const Icon(Icons.edit, color: AppColors.textSecondary),
          onPressed: onChangeQuery,
        ),
        IconButton(
          iconSize: 18,
          splashRadius: 18,
          tooltip: l10n.commonRetry,
          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final GeniusSong song;
  final double score;
  final int trackDurationSeconds;
  final bool selected;
  final VoidCallback onTap;

  const _ResultCard({
    required this.song,
    required this.score,
    required this.trackDurationSeconds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final durDelta = song.durationSeconds != null
        ? (song.durationSeconds! - trackDurationSeconds)
        : null;
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.10)
          : AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.10),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CoverThumb(url: song.songArtImageUrl ?? song.headerImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.primaryArtistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (song.album?.name != null && song.album!.name!.isNotEmpty)
                          Flexible(
                            child: Text(
                              song.album!.name!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.family,
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          Text(
                            l10n.geniusSingle,
                            style: const TextStyle(
                              fontFamily: AppFonts.family,
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (song.releaseDate?.year != null) ...[
                          const Text(' · ',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            '${song.releaseDate!.year}',
                            style: const TextStyle(
                              fontFamily: AppFonts.family,
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (durDelta != null && trackDurationSeconds > 0) ...[
                          const Text(' · ',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          _DurationDelta(deltaSeconds: durDelta),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ScoreBadge(score: score),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  final String? url;
  const _CoverThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.music_note,
            color: AppColors.textMuted, size: 24),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppColors.surfaceElevated,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (ctx, _, __) => Container(
          width: size,
          height: size,
          color: AppColors.surfaceElevated,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined,
              color: AppColors.textMuted, size: 20),
        ),
      ),
    );
  }
}

class _DurationDelta extends StatelessWidget {
  final int deltaSeconds;
  const _DurationDelta({required this.deltaSeconds});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final sign = deltaSeconds >= 0 ? '+' : '−';
    final abs = deltaSeconds.abs();
    final mm = (abs ~/ 60).toString().padLeft(1, '0');
    final ss = (abs % 60).toString().padLeft(2, '0');
    return Text(
      '$sign$mm:$ss',
      style: TextStyle(
        fontFamily: AppFonts.family,
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Color _color() {
    final a = deltaSeconds.abs();
    if (a <= 2) return Colors.greenAccent;
    if (a <= 5) return Colors.amberAccent;
    return Colors.redAccent;
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    Color color;
    if (score >= 0.75) {
      color = Colors.greenAccent;
    } else if (score >= 0.5) {
      color = Colors.amberAccent;
    } else {
      color = Colors.redAccent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontFamily: AppFonts.family,
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _QueryEditorDialog extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  const _QueryEditorDialog({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.geniusChangeQuery,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                cursorColor: AppColors.textPrimary,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                onSubmitted: onSubmit,
                decoration: InputDecoration(
                  hintText: l10n.geniusQueryHint,
                  hintStyle: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: l10n.commonCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: l10n.geniusSearchButton,
                    primary: true,
                    onTap: () => onSubmit(controller.text),
                  ),
                ],
              ),
            ],
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
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Material(
        color: primary ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: primary
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.family,
                color: primary ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the Genius picker dialog. Returns the selected [GeniusSong] or
/// `null` (cancelled / no results).
Future<GeniusSong?> showGeniusSearchDialog({
  required BuildContext context,
  required GeniusClient client,
  required Track track,
}) {
  final query = buildGeniusQuery(track);
  return showDialog<GeniusSong>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => GeniusSearchDialog(
      client: client,
      track: track,
      initialQuery: query,
    ),
  );
}

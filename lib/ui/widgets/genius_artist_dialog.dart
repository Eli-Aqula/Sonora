import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/artist.dart';
import '../../l10n/app_localizations.dart';
import '../../services/genius/genius_client.dart';
import '../../services/genius/match_scorer.dart';

/// Genius artist-picker dialog.
///
/// The Genius API has no direct /search/artists, so we collect unique
/// artists from /search?q=… results and load each one's photo and
/// description via /artists/:id.
class GeniusArtistDialog extends StatefulWidget {
  final GeniusClient client;
  final Artist artist;
  final String initialQuery;

  const GeniusArtistDialog({
    super.key,
    required this.client,
    required this.artist,
    required this.initialQuery,
  });

  @override
  State<GeniusArtistDialog> createState() => _GeniusArtistDialogState();
}

class _GeniusArtistDialogState extends State<GeniusArtistDialog> {
  late final TextEditingController _queryController;
  late String _query;

  _LoadState _state = _LoadState.loading;
  String? _error;
  List<_ScoredArtist> _results = const [];
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
      // Deduplicate by primary_artist.id and count popularity (the number
      // of hits from this artist in the results).
      final popByArtistId = <int, int>{};
      final nameByArtistId = <int, String>{};
      for (final h in hits) {
        final id = h.primaryArtistId;
        if (id == null) continue;
        popByArtistId[id] = (popByArtistId[id] ?? 0) + 1;
        nameByArtistId[id] ??= h.primaryArtistName;
      }
      if (popByArtistId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _state = _LoadState.empty;
          _results = const [];
        });
        return;
      }
      final scored = <_ScoredArtist>[];
      popByArtistId.forEach((id, pop) {
        final name = nameByArtistId[id] ?? '';
        if (name.isEmpty) return;
        final s = MatchScorer.tokenSetRatio(
          MatchScorer.normalize(name),
          MatchScorer.normalize(widget.artist.name),
        );
        final popFraction = pop / hits.length;
        scored.add(_ScoredArtist(
          id: id,
          name: name,
          score: (s * 0.7 + popFraction * 0.3).clamp(0.0, 1.0),
        ));
      });
      scored.sort((a, b) => b.score.compareTo(a.score));
      setState(() {
        _state = _LoadState.ready;
        _results = scored.take(5).toList();
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
                artist: widget.artist,
                state: _state,
                resultsCount: _results.length,
                onChangeQuery: _showQueryEditor,
                onRetry: _runSearch,
              ),
              const SizedBox(height: 12),
              Flexible(child: _buildBody()),
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
                            .pop(_results[_selectedIndex!].id),
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
                  l10n.geniusArtistSearchingEllipsis,
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
                  l10n.geniusNoResultsFor(widget.artist.name),
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
          itemBuilder: (context, i) => _ArtistCard(
            name: _results[i].name,
            score: _results[i].score,
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

class _ScoredArtist {
  final int id;
  final String name;
  final double score;
  const _ScoredArtist({
    required this.id,
    required this.name,
    required this.score,
  });
}

class _Header extends StatelessWidget {
  final Artist artist;
  final _LoadState state;
  final int resultsCount;
  final VoidCallback onChangeQuery;
  final VoidCallback onRetry;

  const _Header({
    required this.artist,
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
        subtitle = l10n.geniusArtistsFound(resultsCount);
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
                l10n.geniusFindArtist,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                artist.name,
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

class _ArtistCard extends StatelessWidget {
  final String name;
  final double score;
  final bool selected;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.name,
    required this.score,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person,
                    color: AppColors.textMuted, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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
                  hintText: l10n.geniusArtistQueryHint,
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

/// Opens the Genius artist picker. Returns the Genius id of the selected
/// artist or `null` (cancelled). Full data (photo, bio) is loaded by the
/// caller via `client.getArtist(id)`.
Future<int?> showGeniusArtistDialog({
  required BuildContext context,
  required GeniusClient client,
  required Artist artist,
}) {
  final query = artist.name;
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => GeniusArtistDialog(
      client: client,
      artist: artist,
      initialQuery: query,
    ),
  );
}

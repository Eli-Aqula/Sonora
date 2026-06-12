import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/track.dart';
import '../../providers/browse_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_history_provider.dart';
import '../widgets/track_list.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = ref.watch(searchQueryProvider);
    final debouncedQuery = ref.watch(debouncedQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final history = ref.watch(searchHistoryProvider);
    final snapshot = ref.watch(playbackSnapshotProvider);
    final player = ref.watch(playerControllerProvider);
    final theme = Theme.of(context);

    int? indexOf(List<Track> tracks) {
      final current = snapshot.valueOrNull?.currentTrack;
      if (current == null) return null;
      for (var i = 0; i < tracks.length; i++) {
        if (tracks[i].path == current.path) return i;
      }
      return null;
    }

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.navSearch, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            focusNode: _focus,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(Icons.search_rounded, color: AppColors.textSecondary),
              ),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              ref.read(searchQueryProvider.notifier).state = v;
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (debouncedQuery.trim().isEmpty) {
                  if (history.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.searchHistoryEmpty,
                        style: const TextStyle(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.searchHistoryTitle, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TrackList(
                          tracks: history,
                          currentIndex: indexOf(history),
                          onTapIndex: (i) {
                            player.playQueue(history, startIndex: i);
                          },
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.searchResultsFound(results.length),
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TrackList(
                        tracks: results,
                        currentIndex: indexOf(results),
                        onTapIndex: (i) {
                          _onPlayFromSearch(results, i);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
            ),
          ),
        ],
      ),
    );
  }

  void _onPlayFromSearch(List<Track> results, int i) {
    ref.read(searchHistoryProvider.notifier).add(results[i]);
    ref.read(playerControllerProvider).playQueue(results, startIndex: i);
  }
}

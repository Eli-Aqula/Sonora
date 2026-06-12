import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/models/track.dart';
import 'package:sonora/services/genius/genius_models.dart';
import 'package:sonora/services/genius/match_scorer.dart';

Track _track({
  String title = 'Hello',
  String artist = 'Adele',
  String album = '25',
  Duration duration = const Duration(seconds: 295),
  int? year = 2015,
}) {
  return Track(
    id: 1,
    path: '/tmp/track.mp3',
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    year: year,
    addedAt: DateTime(2024),
    modifiedAt: DateTime(2024),
  );
}

GeniusHit _hit({
  int id = 1,
  String title = 'Hello',
  String titleWithFeatured = 'Hello',
  String artist = 'Adele',
  String? album = '25',
  int? durationSeconds = 295,
  int? year = 2015,
}) {
  return GeniusHit(
    id: id,
    title: title,
    titleWithFeatured: titleWithFeatured,
    primaryArtistName: artist,
    url: 'https://genius.com/adele-hello-lyrics',
    durationSeconds: durationSeconds,
    releaseDate: year == null
        ? null
        : GeniusDateComponents(year: year, month: 1, day: 1),
    album: album == null ? null : GeniusAlbum(name: album, artistName: artist),
  );
}

void main() {
  group('buildGeniusQuery', () {
    test('joins artist and title', () {
      expect(buildGeniusQuery(_track()), 'Adele Hello');
    });

    test('skips Unknown Artist', () {
      expect(
        buildGeniusQuery(_track(artist: 'Unknown Artist')),
        'Hello',
      );
    });

    test('skips empty artist', () {
      expect(buildGeniusQuery(_track(artist: '')), 'Hello');
    });

    test('keeps title even when empty (falls back to filename)', () {
      // displayTitle откатывается на basename файла, когда title пуст —
      // так что пустой title всё равно даёт непустой поисковый запрос.
      expect(
        buildGeniusQuery(_track(title: '', artist: 'Adele')),
        'Adele track',
      );
    });
  });

  group('normalize', () {
    test('lowercases', () {
      expect(MatchScorer.normalize('HELLO'), 'hello');
    });

    test('strips parens content', () {
      expect(MatchScorer.normalize('Hello (Remix 2020)'), 'hello');
      expect(MatchScorer.normalize('Hello [Live]'), 'hello');
    });

    test('strips feat/ft/prod/with suffix', () {
      expect(MatchScorer.normalize('Hello feat. Adele'), 'hello');
      expect(MatchScorer.normalize('Hello ft John'), 'hello');
      expect(MatchScorer.normalize('Hello produced by X'), 'hello');
      expect(MatchScorer.normalize('Hello with Mary'), 'hello');
    });

    test('keeps cyrillic letters and digits', () {
      expect(MatchScorer.normalize('Платина — Один дома 2'), 'платина один дома 2');
    });

    test('strips punctuation but keeps spaces', () {
      expect(MatchScorer.normalize("Don't Stop Me Now!"), 'don t stop me now');
    });

    test('collapses whitespace', () {
      expect(MatchScorer.normalize('  hello   world  '), 'hello world');
    });
  });

  group('tokenSetRatio', () {
    test('identical non-empty strings → 1.0', () {
      expect(MatchScorer.tokenSetRatio('hello world', 'hello world'), 1.0);
    });

    test('one empty string → 0', () {
      expect(MatchScorer.tokenSetRatio('', 'hello'), 0);
      expect(MatchScorer.tokenSetRatio('hello', ''), 0);
    });

    test('disjoint sets → 0', () {
      expect(MatchScorer.tokenSetRatio('foo bar', 'baz qux'), 0);
    });

    test('partial overlap (Jaccard)', () {
      // {a, b} ∩ {b, c} = {b}, union = {a, b, c} → 1/3.
      expect(
        MatchScorer.tokenSetRatio('a b', 'b c'),
        closeTo(1 / 3, 1e-9),
      );
    });

    test('order independent', () {
      expect(
        MatchScorer.tokenSetRatio('a b c', 'c b a'),
        closeTo(1.0, 1e-9),
      );
    });
  });

  group('durationScore', () {
    test('null hit duration → neutral 0.5', () {
      expect(MatchScorer.durationScore(null, 100), 0.5);
    });

    test('zero track duration → neutral 0.5', () {
      expect(MatchScorer.durationScore(200, 0), 0.5);
    });

    test('within 2s → 1.0', () {
      expect(MatchScorer.durationScore(100, 100), 1.0);
      expect(MatchScorer.durationScore(102, 100), 1.0);
      expect(MatchScorer.durationScore(98, 100), 1.0);
    });

    test('at 15s+ diff → 0.0', () {
      expect(MatchScorer.durationScore(115, 100), 0.0);
      expect(MatchScorer.durationScore(85, 100), 0.0);
    });

    test('linear decay in between', () {
      // diff=8 → 1.0 - (8-2)/13 ≈ 0.5385
      expect(MatchScorer.durationScore(108, 100), closeTo(1.0 - 6 / 13, 1e-9));
    });
  });

  group('albumScore', () {
    test('both empty / Unknown → 0', () {
      expect(MatchScorer.albumScore(null, 'Unknown Album'), 0);
      expect(MatchScorer.albumScore('', ''), 0);
    });

    test('identical → 1.0', () {
      expect(MatchScorer.albumScore('25', '25'), 1.0);
    });

    test('case-insensitive', () {
      expect(MatchScorer.albumScore('Hello World', 'hello world'), 1.0);
    });
  });

  group('scoreHit', () {
    test('perfect match (incl. album + duration) → ~1.0', () {
      final s = MatchScorer.scoreHit(_hit(), _track());
      // title 1.0 * 0.45 + artist 1.0 * 0.30 + dur 1.0 * 0.20 + album 1.0 * 0.05
      expect(s, closeTo(1.0, 1e-9));
    });

    test('title mismatch drops score below 1', () {
      final s = MatchScorer.scoreHit(
        _hit(
          title: 'Completely Different',
          titleWithFeatured: 'Completely Different',
        ),
        _track(),
      );
      // title 0 + artist 1 + duration 1 + album 1 → 0.55
      expect(s, closeTo(0.55, 1e-9));
    });

    test('artist mismatch drops score', () {
      final s = MatchScorer.scoreHit(
        _hit(artist: 'Madonna'),
        _track(),
      );
      expect(s, lessThan(0.85));
    });

    test('duration within 2s keeps max duration score', () {
      final s = MatchScorer.scoreHit(
        _hit(durationSeconds: 297),
        _track(duration: const Duration(seconds: 295)),
      );
      expect(s, closeTo(1.0, 1e-9));
    });

    test('duration off by 15s+ drops score meaningfully', () {
      final s = MatchScorer.scoreHit(
        _hit(durationSeconds: 320),
        _track(duration: const Duration(seconds: 295)),
      );
      // 0.45*1.0 + 0.30*1.0 + 0.20*0.0 + 0.05*1.0 = 0.80
      expect(s, closeTo(0.80, 1e-9));
    });
  });

  group('topMatches', () {
    test('drops below minScore', () {
      // Полностью чужой артист + название + сильно другая длительность →
      // все компоненты ~0, итог < minScore.
      final hits = [
        _hit(
          id: 1,
          title: 'Random Noise',
          titleWithFeatured: 'Random Noise',
          artist: 'Madonna',
          durationSeconds: 100,
        ),
      ];
      expect(MatchScorer.topMatches(hits, _track()), isEmpty);
    });

    test('sorts by score descending', () {
      final hits = [
        _hit(id: 1, title: 'Hello', artist: 'Adele'),
        _hit(id: 2, title: 'Hello', artist: 'Madonna'),
        _hit(id: 3, title: 'Almost Hello', artist: 'Adele'),
      ];
      final top = MatchScorer.topMatches(hits, _track());
      expect(top.map((s) => s.hit.id), [1, 3, 2]);
    });

    test('caps at topN', () {
      // All identical hits → all score ~1.0; topN=5 should cap.
      final hits = List.generate(8, (i) => _hit(id: i + 1));
      final top = MatchScorer.topMatches(hits, _track());
      expect(top.length, MatchScorer.topN);
      expect(top.length, lessThanOrEqualTo(5));
    });

    test('empty input → empty result', () {
      expect(MatchScorer.topMatches([], _track()), isEmpty);
    });
  });
}

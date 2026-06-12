import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonora/services/genius/genius_client.dart';

void main() {
  group('GeniusClient.search', () {
    http.Response? mockResponse;

    setUp(() {
      mockResponse = null;
    });

    test('200 with valid hits returns list', () async {
      mockResponse = http.Response(
        jsonEncode({
          'response': {
            'hits': [
              {
                'result': {
                  'id': 123,
                  'title': 'Hello',
                  'title_with_featured': 'Hello',
                  'primary_artist': {'name': 'Adele'},
                  'url': 'https://genius.com/adele-hello-lyrics',
                }
              }
            ]
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      );

      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async => mockResponse!),
      );

      final hits = await client.search('hello');
      expect(hits.length, 1);
      expect(hits.first.id, 123);
      expect(hits.first.title, 'Hello');
      expect(hits.first.primaryArtistName, 'Adele');

      client.dispose();
    });

    test('200 with empty hits returns empty list', () async {
      mockResponse = http.Response(
        jsonEncode({'response': {'hits': []}}),
        200,
      );

      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async => mockResponse!),
      );

      final hits = await client.search('notfound');
      expect(hits, isEmpty);

      client.dispose();
    });

    test('401 throws unauthorized', () async {
      mockResponse = http.Response(
        jsonEncode({'meta': {'status': 401, 'message': 'unauthorized'}}),
        401,
      );

      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async => mockResponse!),
      );

      bool threw = false;
      try {
        await client.search('any');
      } on GeniusException catch (e) {
        threw = e.kind == GeniusErrorKind.unauthorized;
      }
      expect(threw, true);

      client.dispose();
    });

    test('404 throws notFound', () async {
      mockResponse = http.Response('', 404);

      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async => mockResponse!),
      );

      bool threw = false;
      try {
        await client.search('any');
      } on GeniusException catch (e) {
        threw = e.kind == GeniusErrorKind.notFound;
      }
      expect(threw, true);

      client.dispose();
    });

    test('500 throws server', () async {
      mockResponse = http.Response('', 500);

      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async => mockResponse!),
      );

      bool threw = false;
      try {
        await client.search('any');
      } on GeniusException catch (e) {
        threw = e.kind == GeniusErrorKind.server;
      }
      expect(threw, true);

      client.dispose();
    });

    test('malformed JSON throws server', () async {
      mockResponse = http.Response('not json at all', 200);

      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async => mockResponse!),
      );

      bool threw = false;
      try {
        await client.search('any');
      } on GeniusException catch (e) {
        threw = e.kind == GeniusErrorKind.server;
      }
      expect(threw, true);

      client.dispose();
    });
  });

  group('GeniusClient.getSong', () {
    test('200 returns GeniusSong (без подгрузки lyrics)', () async {
      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async {
          final uri = request.url.toString();
          expect(uri, contains('/songs/'));
          return http.Response(
            jsonEncode({
              'response': {
                'song': {
                  'id': 456,
                  'title': 'Hello',
                  'title_with_featured': 'Hello',
                  'primary_artist': {'name': 'Adele'},
                  'url': 'https://genius.com/adele-hello-lyrics',
                  'duration': 295,
                }
              }
            }),
            200,
          );
        }),
      );

      final song = await client.getSong(456, fetchLyrics: false);
      expect(song.id, 456);
      expect(song.title, 'Hello');
      expect(song.primaryArtistName, 'Adele');
      expect(song.durationSeconds, 295);

      client.dispose();
    });

    test('подгружает lyrics из HTML страницы Genius', () async {
      const html = '''
<html><body>
<div data-lyrics-container="true" class="x">
Line one<br/>Line two<br/><a href="#">Line three</a>
</div>
</body></html>
''';
      final client = GeniusClient(
        'test-token',
        client: MockClient((request) async {
          final uri = request.url.toString();
          if (uri.contains('api.genius.com')) {
            return http.Response(
              jsonEncode({
                'response': {
                  'song': {
                    'id': 789,
                    'title': 'Hello',
                    'title_with_featured': 'Hello',
                    'primary_artist': {'name': 'Adele'},
                    'url': 'https://genius.com/adele-hello-lyrics',
                  }
                }
              }),
              200,
            );
          }
          return http.Response(html, 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
      );

      final song = await client.getSong(789);
      expect(song.id, 789);
      expect(song.lyricsText, isNotNull);
      expect(song.lyricsText, contains('Line one'));
      expect(song.lyricsText, contains('Line two'));
      expect(song.lyricsText, contains('Line three'));

      client.dispose();
    });
  });
}
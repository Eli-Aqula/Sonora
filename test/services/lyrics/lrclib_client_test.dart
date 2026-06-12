import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonora/services/lyrics/lrclib_client.dart';

void main() {
  group('LrclibClient.getByMetadata', () {
    test('200 → возвращает результат с syncedLyrics', () async {
      final client = LrclibClient(
        client: MockClient((req) async {
          expect(req.url.path, '/api/get');
          expect(req.url.queryParameters['artist_name'], 'Adele');
          return http.Response(
            jsonEncode({
              'trackName': 'Hello',
              'artistName': 'Adele',
              'albumName': '25',
              'duration': 295,
              'instrumental': false,
              'plainLyrics': 'Hello, it\'s me',
              'syncedLyrics': '[00:01.00] Hello, it\'s me',
            }),
            200,
          );
        }),
      );
      final r = await client.getByMetadata(
        trackName: 'Hello',
        artistName: 'Adele',
        durationSeconds: 295,
      );
      expect(r, isNotNull);
      expect(r!.hasSynced, true);
      expect(r.hasPlain, true);
      expect(r.syncedLyrics, contains('Hello'));
      client.dispose();
    });

    test('404 → возвращает null', () async {
      final client = LrclibClient(
        client: MockClient((req) async => http.Response('', 404)),
      );
      final r = await client.getByMetadata(
        trackName: 'Unknown',
        artistName: 'Nobody',
      );
      expect(r, isNull);
      client.dispose();
    });

    test('500 → бросает server', () async {
      final client = LrclibClient(
        client: MockClient((req) async => http.Response('', 500)),
      );
      bool threw = false;
      try {
        await client.getByMetadata(
          trackName: 'X',
          artistName: 'Y',
        );
      } on LrclibException catch (e) {
        threw = e.kind == LrclibErrorKind.server;
      }
      expect(threw, true);
      client.dispose();
    });
  });

  group('LrclibClient.search', () {
    test('возвращает первый хит с syncedLyrics при наличии', () async {
      final client = LrclibClient(
        client: MockClient((req) async {
          expect(req.url.path, '/api/search');
          return http.Response(
            jsonEncode([
              {
                'trackName': 'Hello',
                'artistName': 'Adele',
                'instrumental': false,
                'plainLyrics': 'plain only',
              },
              {
                'trackName': 'Hello',
                'artistName': 'Adele',
                'instrumental': false,
                'plainLyrics': 'plain',
                'syncedLyrics': '[00:01.00] synced',
              },
            ]),
            200,
          );
        }),
      );
      final r = await client.search(
        trackName: 'Hello',
        artistName: 'Adele',
      );
      expect(r, isNotNull);
      expect(r!.hasSynced, true);
      expect(r.syncedLyrics, contains('synced'));
      client.dispose();
    });

    test('пустой массив → null', () async {
      final client = LrclibClient(
        client: MockClient((req) async => http.Response('[]', 200)),
      );
      final r = await client.search(trackName: 'x', artistName: 'y');
      expect(r, isNull);
      client.dispose();
    });
  });

  group('LrclibClient.findBest', () {
    test('getByMetadata дал ответ — search не вызывается', () async {
      var searchCalls = 0;
      final client = LrclibClient(
        client: MockClient((req) async {
          if (req.url.path == '/api/search') {
            searchCalls++;
            return http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode({
              'trackName': 'A',
              'artistName': 'B',
              'albumName': '',
              'instrumental': false,
              'syncedLyrics': '[00:01.00] x',
            }),
            200,
          );
        }),
      );
      final r = await client.findBest(
        trackName: 'A',
        artistName: 'B',
      );
      expect(r, isNotNull);
      expect(searchCalls, 0);
      client.dispose();
    });

    test('getByMetadata=null → fallback на search', () async {
      var searchCalls = 0;
      final client = LrclibClient(
        client: MockClient((req) async {
          if (req.url.path == '/api/get') {
            return http.Response('', 404);
          }
          searchCalls++;
          return http.Response(
            jsonEncode([
              {
                'trackName': 'A',
                'artistName': 'B',
                'instrumental': false,
                'syncedLyrics': '[00:01.00] x',
              }
            ]),
            200,
          );
        }),
      );
      final r = await client.findBest(trackName: 'A', artistName: 'B');
      expect(r, isNotNull);
      expect(searchCalls, 1);
      client.dispose();
    });
  });
}

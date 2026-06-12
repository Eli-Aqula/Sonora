import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/services/genius/cover_downloader.dart';

void main() {
  group('CoverDownloader.extensionFromUrl', () {
    test('extracts jpg from URL', () {
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover.jpg',
        null,
      ), '.jpg');
    });

    test('extracts jpeg and normalizes to jpg', () {
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover.jpeg',
        null,
      ), '.jpg');
    });

    test('extracts png', () {
      expect(
        CoverDownloader.extensionFromUrl(
          'https://img.com/cover.PNG',
          null,
        ),
        '.png',
      );
    });

    test('extracts gif, webp, bmp', () {
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover.gif',
        null,
      ), '.gif');
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover.webp',
        null,
      ), '.webp');
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover.bmp',
        null,
      ), '.bmp');
    });

    test('uses content-type when URL has no supported ext', () {
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover',
        'image/png',
      ), '.png');
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover',
        'image/jpeg',
      ), '.jpg');
    });

    test('URL ext wins over content-type', () {
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover.png',
        'image/jpeg',
      ), '.png');
    });

    test('unknown extension and no content-type → jpg default', () {
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover',
        null,
      ), '.jpg');
    });

    test('unknown extension with unknown content-type → jpg default', () {
      expect(CoverDownloader.extensionFromUrl(
        'https://img.com/cover',
        'application/pdf',
      ), '.jpg');
    });
  });

  group('CoverDownloader.deleteTemp', () {
    test('accepts null', () async {
      // Should not throw
      await CoverDownloader.deleteTemp(null);
    });

    test('accepts empty string', () async {
      await CoverDownloader.deleteTemp('');
    });

    test('removes existing file', () async {
      final tempDir = await Directory.systemTemp.createTemp('cover_test');
      final file = File('${tempDir.path}/test.jpg');
      await file.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      expect(await file.exists(), true);

      await CoverDownloader.deleteTemp(file.path);
      expect(await file.exists(), false);
      // Cleanup temp dir
      await tempDir.delete(recursive: true);
    });

    test('does not throw on non-existent path', () async {
      // Should silently succeed
      await CoverDownloader.deleteTemp('/nonexistent/path/file.jpg');
    });
  });
}
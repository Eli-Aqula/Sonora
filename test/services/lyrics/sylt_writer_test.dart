import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sonora/services/lyrics/lrc_parser.dart';
import 'package:sonora/services/lyrics/sylt_writer.dart';

void main() {
  group('writeSyltToMp3', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('sonora_sylt_');
    });

    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    /// Делает «фейковый» MP3: ID3v2.4 заголовок без фреймов + 200 байт
    /// мусора как «аудио».
    Future<String> makeFakeMp3({bool withTag = true}) async {
      final file = File(p.join(tmp.path, 'a.mp3'));
      final builder = BytesBuilder();
      if (withTag) {
        builder.add([0x49, 0x44, 0x33, 4, 0, 0]); // ID3v2.4
        builder.add([0, 0, 0, 0]); // size = 0
      }
      builder.add(List<int>.filled(200, 0xAB));
      await file.writeAsBytes(builder.takeBytes());
      return file.path;
    }

    test('добавляет SYLT-фрейм к MP3 без существующего тега', () async {
      final path = await makeFakeMp3(withTag: false);
      await writeSyltToMp3(
        filePath: path,
        lines: const [
          LrcLine(time: Duration(milliseconds: 1000), text: 'Hello'),
          LrcLine(time: Duration(milliseconds: 3500), text: 'world'),
        ],
        language: 'eng',
      );

      final bytes = await File(path).readAsBytes();
      // Должен начинаться с 'ID3'.
      expect(String.fromCharCodes(bytes.sublist(0, 3)), 'ID3');
      // Должен содержать 'SYLT' где-то.
      final idx = _indexOf(bytes, 'SYLT'.codeUnits);
      expect(idx, greaterThan(0));
      // Должен содержать "Hello" и "world" в UTF-8.
      expect(_indexOf(bytes, 'Hello'.codeUnits), greaterThan(idx));
      expect(_indexOf(bytes, 'world'.codeUnits), greaterThan(idx));
      // Должен сохранить хвост (200 байт мусора).
      expect(bytes.length, greaterThan(200));
    });

    test('заменяет существующий SYLT-фрейм', () async {
      final path = await makeFakeMp3();
      await writeSyltToMp3(
        filePath: path,
        lines: const [
          LrcLine(time: Duration(milliseconds: 0), text: 'old line'),
        ],
      );
      await writeSyltToMp3(
        filePath: path,
        lines: const [
          LrcLine(time: Duration(milliseconds: 500), text: 'new line'),
        ],
      );
      final bytes = await File(path).readAsBytes();
      // Старой строки быть не должно.
      expect(_indexOf(bytes, 'old line'.codeUnits), -1);
      // Новая — есть.
      expect(_indexOf(bytes, 'new line'.codeUnits), greaterThan(0));
      // SYLT — должен встретиться ровно один раз.
      final count = _countOccurrences(bytes, 'SYLT'.codeUnits);
      expect(count, 1);
    });

    test('бросает при пустом списке строк', () async {
      final path = await makeFakeMp3();
      expect(
        () => writeSyltToMp3(filePath: path, lines: const []),
        throwsA(isA<SyltIoException>()),
      );
    });

    test('бросает при неверном language', () async {
      final path = await makeFakeMp3();
      expect(
        () => writeSyltToMp3(
          filePath: path,
          lines: const [
            LrcLine(time: Duration.zero, text: 'x'),
          ],
          language: 'ru',
        ),
        throwsA(isA<SyltIoException>()),
      );
    });
  });
}

int _indexOf(Uint8List haystack, List<int> needle) {
  if (needle.isEmpty) return 0;
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

int _countOccurrences(Uint8List haystack, List<int> needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var i = 0;
  while (i <= haystack.length - needle.length) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      count++;
      i += needle.length;
    } else {
      i++;
    }
  }
  return count;
}

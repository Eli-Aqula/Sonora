import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final class _LrcLine extends Struct {
  external Pointer<Utf8> text;
  @Uint32()
  external int timeMs;
}

typedef _AlignLyricsC = Pointer<_LrcLine> Function(
    Pointer<Utf8> audioPath,
    Pointer<Utf8> lyricsText,
    Pointer<Uint32> outLen);

typedef _AlignLyricsDart = Pointer<_LrcLine> Function(
    Pointer<Utf8> audioPath,
    Pointer<Utf8> lyricsText,
    Pointer<Uint32> outLen);

typedef _CheckModelAvailableC = Int8 Function(Pointer<Utf8> modelPath);
typedef _CheckModelAvailableDart = int Function(Pointer<Utf8> modelPath);

abstract class NativeLyrics {
  static final DynamicLibrary _lib = Platform.isWindows
      ? DynamicLibrary.open('sonora_native.dll')
      : DynamicLibrary.process();

  static final _align = _lib
      .lookup<NativeFunction<_AlignLyricsC>>('align_lyrics')
          .asFunction<_AlignLyricsDart>();

  static final _check = _lib
      .lookup<NativeFunction<_CheckModelAvailableC>>('check_model_available')
          .asFunction<_CheckModelAvailableDart>();

  static Future<List<LrcLine>> align(String audioPath, String lyricsText) async {
    final audioPtr = audioPath.toNativeUtf8();
    final lyricsPtr = lyricsText.toNativeUtf8();
    final lenPtr = calloc<Uint32>();

    final result = _align(audioPtr, lyricsPtr, lenPtr);
    final len = lenPtr.value;

    final lines = <LrcLine>[];
    for (var i = 0; i < len; i++) {
      final line = result[i];
      lines.add(LrcLine(
        timeMs: line.timeMs,
        text: line.text.toDartString(),
      ));
    }

    calloc.free(audioPtr);
    calloc.free(lyricsPtr);
    calloc.free(lenPtr);

    return lines;
  }

  static bool checkModel(String modelPath) {
    final ptr = modelPath.toNativeUtf8();
    final result = _check(ptr);
    calloc.free(ptr);
    return result != 0;
  }
}

class LrcLine {
  final int timeMs;
  final String text;

  LrcLine({required this.timeMs, required this.text});
}
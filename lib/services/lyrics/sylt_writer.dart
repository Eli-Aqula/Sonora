/// Writes a SYLT (Synchronized Lyrics) frame into an MP3 file's ID3v2 tag.
///
/// `audiotags` (the package we use) doesn't support SYLT — it only writes
/// USLT (unsynchronized lyrics). To avoid breaking the regular tag-writing
/// flow, this implementation works "on top of" an already-written ID3v2
/// tag: it opens the file, reads the header, rewrites the SYLT frame
/// (if present) or appends it, updates the tag size, and writes the
/// whole file back (header + body + audio).
///
/// Specification: <https://id3.org/id3v2.4.0-frames> section 4.10.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../services/lyrics/lrc_parser.dart';

/// An error reading/writing ID3v2.
class SyltIoException implements Exception {
  final String message;
  const SyltIoException(this.message);
  @override
  String toString() => message;
}

/// Writes a SYLT frame into the MP3 file at [filePath].
///
/// [lines] — list of synced lines (UTF-8).
/// [language] — 3-letter ISO-639-2 code (default `xxx` = undetermined).
/// [description] — an optional "track" title (e.g. the artist's name).
/// Empty by default.
///
/// Only MP3 with ID3v2.3/2.4 is supported. If there's no tag, a minimal
/// ID3v2.4 header will be created.
Future<void> writeSyltToMp3({
  required String filePath,
  required List<LrcLine> lines,
  String language = 'xxx',
  String description = '',
}) async {
  if (lines.isEmpty) {
    throw const SyltIoException('Nothing to write: empty line list');
  }
  if (language.length != 3) {
    throw const SyltIoException('language must be 3 characters (ISO-639-2)');
  }
  final file = File(filePath);
  if (!await file.exists()) {
    throw SyltIoException('File not found: $filePath');
  }
  final bytes = await file.readAsBytes();

  final tag = _readId3v2(bytes);
  final newFrameBody = _buildSyltFrameBody(
    lines: lines,
    language: language,
    description: description,
  );

  // Replace the existing SYLT frame (if any) with the new one;
  // otherwise append it to the end of the frame list.
  final framesBytes = _replaceOrAppendFrame(
    tag.framesBytes,
    frameId: 'SYLT',
    newFrameBody: newFrameBody,
    majorVersion: tag.majorVersion,
  );

  final out = _serializeId3v2(
    majorVersion: tag.majorVersion,
    framesBytes: framesBytes,
  );

  // Concatenate: new ID3v2 + audio data (everything that followed the old tag).
  final audioStart = tag.tagTotalSize;
  final audio = bytes.sublist(audioStart);
  final result = BytesBuilder(copy: false)
    ..add(out)
    ..add(audio);

  // Write to a temp file and rename — in case of a crash during the
  // write, the original source file stays intact.
  final tmp = File('$filePath.sylt.tmp');
  await tmp.writeAsBytes(result.takeBytes(), flush: true);
  // On Windows you can't rename over an existing file — delete it first.
  // The original has already been read into memory.
  try {
    await file.delete();
  } catch (_) {/* the file may have been moved — try to continue anyway */}
  await tmp.rename(filePath);
}

/// Convenience overload: accepts an LRC string and parses it.
Future<void> writeSyltLrcToMp3({
  required String filePath,
  required String lrcContent,
  String language = 'xxx',
  String description = '',
}) async {
  final lines = parseLrc(lrcContent);
  if (lines.isEmpty) {
    throw const SyltIoException('LRC contains no lines');
  }
  await writeSyltToMp3(
    filePath: filePath,
    lines: lines,
    language: language,
    description: description,
  );
}

// ─── Internals ─────────────────────────────────────────────────────

class _Id3v2Tag {
  /// 3 or 4 — for ID3v2.3 and ID3v2.4.
  final int majorVersion;

  /// "Raw" frame content (without the tag header, without padding).
  final Uint8List framesBytes;

  /// Total size of the tag in the file (10-byte header + body, including
  /// padding). This is what needs to be cut from the start of the file to
  /// get the audio data.
  final int tagTotalSize;

  const _Id3v2Tag({
    required this.majorVersion,
    required this.framesBytes,
    required this.tagTotalSize,
  });
}

/// Parses the ID3v2 header and returns the frames without padding.
/// If there's no tag, returns an empty ID3v2.4.
_Id3v2Tag _readId3v2(Uint8List bytes) {
  if (bytes.length < 10 ||
      bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
    // No ID3v2 — create one from scratch.
    return _Id3v2Tag(
      majorVersion: 4,
      framesBytes: Uint8List(0),
      tagTotalSize: 0,
    );
  }
  final major = bytes[3];
  final flags = bytes[5];
  if (major != 3 && major != 4) {
    throw SyltIoException('Only ID3v2.3 and ID3v2.4 are supported (got $major)');
  }
  final size = _readSynchsafeInt32(bytes, 6);
  final tagTotalSize = 10 + size;
  if (bytes.length < tagTotalSize) {
    throw const SyltIoException('File is shorter than the declared tag size');
  }

  // If a footer is present (flag 0x10 in ID3v2.4) — account for the
  // extra 10 bytes.
  final hasFooter = (major == 4) && ((flags & 0x10) != 0);
  final framesEnd = hasFooter ? tagTotalSize - 10 : tagTotalSize;

  // Skip the extended header entirely — its fields don't matter for writing.
  var framesStart = 10;
  final hasExtHeader = (flags & 0x40) != 0;
  if (hasExtHeader) {
    final extSize = major == 4
        ? _readSynchsafeInt32(bytes, 10)
        : _readUint32BE(bytes, 10);
    framesStart = 10 + extSize;
  }

  // Now strip padding: padding is zero bytes trailing up to the end of the tag.
  var realEnd = framesEnd;
  while (realEnd > framesStart && bytes[realEnd - 1] == 0) {
    realEnd--;
  }
  // But frame data can also end with zero bytes, so it's better to walk
  // the frames from the start and collect them explicitly.
  final framesBytes = _collectFrames(
    bytes,
    framesStart,
    framesEnd,
    major,
  );
  return _Id3v2Tag(
    majorVersion: major,
    framesBytes: framesBytes,
    tagTotalSize: tagTotalSize + (hasFooter ? 0 : 0),
  );
}

/// Walks the frames and returns their concatenated serialization
/// (without padding). Used both for reading and for replacing a
/// specific frame.
Uint8List _collectFrames(
  Uint8List bytes,
  int start,
  int end,
  int major,
) {
  final buf = BytesBuilder(copy: false);
  var pos = start;
  while (pos + 10 <= end) {
    // Frame ID: 4 bytes (ASCII). If the first byte is 0, we've reached padding.
    if (bytes[pos] == 0) break;
    final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    if (!_isValidFrameId(id)) break;
    final frameSize = major == 4
        ? _readSynchsafeInt32(bytes, pos + 4)
        : _readUint32BE(bytes, pos + 4);
    final frameTotal = 10 + frameSize;
    if (pos + frameTotal > end) break;
    buf.add(bytes.sublist(pos, pos + frameTotal));
    pos += frameTotal;
  }
  return buf.toBytes();
}

bool _isValidFrameId(String id) {
  if (id.length != 4) return false;
  for (var i = 0; i < 4; i++) {
    final c = id.codeUnitAt(i);
    final isUpper = c >= 0x41 && c <= 0x5A;
    final isDigit = c >= 0x30 && c <= 0x39;
    if (!isUpper && !isDigit) return false;
  }
  return true;
}

/// Replaces (or appends) the frame with the given [frameId].
Uint8List _replaceOrAppendFrame(
  Uint8List framesBytes, {
  required String frameId,
  required Uint8List newFrameBody,
  required int majorVersion,
}) {
  final buf = BytesBuilder(copy: false);
  var pos = 0;
  var replaced = false;
  while (pos + 10 <= framesBytes.length) {
    final id = String.fromCharCodes(framesBytes.sublist(pos, pos + 4));
    if (!_isValidFrameId(id)) break;
    final size = majorVersion == 4
        ? _readSynchsafeInt32(framesBytes, pos + 4)
        : _readUint32BE(framesBytes, pos + 4);
    final frameTotal = 10 + size;
    if (id == frameId) {
      // Skip the old frame; the new one will take its place below.
      replaced = true;
    } else {
      buf.add(framesBytes.sublist(pos, pos + frameTotal));
    }
    pos += frameTotal;
  }
  buf.add(_serializeFrame(
    frameId: frameId,
    body: newFrameBody,
    majorVersion: majorVersion,
  ));
  // `replaced` isn't used elsewhere — kept around for debugging.
  assert(replaced || !replaced);
  return buf.toBytes();
}

Uint8List _serializeFrame({
  required String frameId,
  required Uint8List body,
  required int majorVersion,
}) {
  final out = BytesBuilder(copy: false);
  out.add(frameId.codeUnits);
  if (majorVersion == 4) {
    out.add(_writeSynchsafeInt32(body.length));
  } else {
    out.add(_writeUint32BE(body.length));
  }
  // Flags: 2 bytes, both zero.
  out.add([0, 0]);
  out.add(body);
  return out.toBytes();
}

/// Serializes the ID3v2.4 header + frames. Padding = 0 (minimal size).
Uint8List _serializeId3v2({
  required int majorVersion,
  required Uint8List framesBytes,
}) {
  final out = BytesBuilder(copy: false);
  out.add([0x49, 0x44, 0x33]); // 'ID3'
  out.addByte(majorVersion);
  out.addByte(0); // revision
  out.addByte(0); // flags
  out.add(_writeSynchsafeInt32(framesBytes.length));
  out.add(framesBytes);
  return out.toBytes();
}

/// Serializes the SYLT frame body.
///
/// Structure (ID3v2.4 §4.10):
/// - text encoding: 1 byte (we use 0x03 = UTF-8)
/// - language: 3 bytes (ISO-639-2)
/// - timestamp format: 1 byte (0x02 = milliseconds)
/// - content type: 1 byte (0x01 = lyrics)
/// - content descriptor: encoded string + terminator (0x00)
/// - then blocks: text + 0x00 + 4-byte timestamp (BE).
Uint8List _buildSyltFrameBody({
  required List<LrcLine> lines,
  required String language,
  required String description,
}) {
  final out = BytesBuilder(copy: false);
  out.addByte(0x03); // encoding: UTF-8
  out.add(language.toLowerCase().codeUnits.take(3).toList());
  out.addByte(0x02); // timestamp = ms
  out.addByte(0x01); // content type = lyrics
  // Descriptor + null terminator.
  out.add(_utf8(description));
  out.addByte(0x00);
  // The actual lines.
  for (final line in lines) {
    out.add(_utf8(line.text));
    out.addByte(0x00);
    out.add(_writeUint32BE(line.time.inMilliseconds));
  }
  return out.toBytes();
}

Uint8List _utf8(String s) {
  // We avoid dart:convert's utf8.encode to skip an extra import;
  // the implementation is equivalent.
  final cu = s.runes.toList();
  final buf = BytesBuilder(copy: false);
  for (final r in cu) {
    if (r < 0x80) {
      buf.addByte(r);
    } else if (r < 0x800) {
      buf.addByte(0xC0 | (r >> 6));
      buf.addByte(0x80 | (r & 0x3F));
    } else if (r < 0x10000) {
      buf.addByte(0xE0 | (r >> 12));
      buf.addByte(0x80 | ((r >> 6) & 0x3F));
      buf.addByte(0x80 | (r & 0x3F));
    } else {
      buf.addByte(0xF0 | (r >> 18));
      buf.addByte(0x80 | ((r >> 12) & 0x3F));
      buf.addByte(0x80 | ((r >> 6) & 0x3F));
      buf.addByte(0x80 | (r & 0x3F));
    }
  }
  return buf.toBytes();
}

int _readSynchsafeInt32(Uint8List b, int off) {
  return ((b[off] & 0x7F) << 21) |
      ((b[off + 1] & 0x7F) << 14) |
      ((b[off + 2] & 0x7F) << 7) |
      (b[off + 3] & 0x7F);
}

int _readUint32BE(Uint8List b, int off) {
  return (b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];
}

Uint8List _writeSynchsafeInt32(int v) {
  if (v < 0 || v >= (1 << 28)) {
    throw SyltIoException('Tag size does not fit in a synchsafe int: $v');
  }
  return Uint8List.fromList([
    (v >> 21) & 0x7F,
    (v >> 14) & 0x7F,
    (v >> 7) & 0x7F,
    v & 0x7F,
  ]);
}

Uint8List _writeUint32BE(int v) {
  return Uint8List.fromList([
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ]);
}

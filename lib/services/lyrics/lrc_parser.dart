import 'package:flutter/foundation.dart';

/// Represents a single LRC line with a timecode.
@immutable
class LrcLine {
  final Duration time;
  final String text;
  const LrcLine({required this.time, required this.text});

  Duration get startTime => time;
  Duration get endTime => Duration.zero; // computed at the list level

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LrcLine && time == other.time && text == other.text;

  @override
  int get hashCode => time.hashCode ^ text.hashCode;
}

/// Parses an LRC string into a list of lines.
/// Format: `[mm:ss.xx] text` or `[mm:ss.xxx] text`
List<LrcLine> parseLrc(String lrcContent) {
  final lines = <LrcLine>[];
  final linePattern = RegExp(r'\[(\d+):(\d{2})(?:[.:](\d{2}))?\]\s*(.*)');
  for (final rawLine in lrcContent.split('\n')) {
    final match = linePattern.firstMatch(rawLine);
    if (match == null) continue;
    final min = int.parse(match[1]!);
    final sec = int.parse(match[2]!);
    final frac = int.parse(match[3] ?? '0');
    final text = match[4]!.trim();
    if (text.isEmpty) continue;
    final time = Duration(
      minutes: min,
      seconds: sec,
      milliseconds: frac * 10,
    );
    lines.add(LrcLine(time: time, text: text));
  }
  return lines;
}

/// Finds the current line based on the position within the track.
LrcLine? findCurrentLine(List<LrcLine> lines, Duration position) {
  if (lines.isEmpty) return null;
  LrcLine? current;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final nextTime = i + 1 < lines.length ? lines[i + 1].time : null;
    if (position >= line.time && (nextTime == null || position < nextTime)) {
      current = line;
      break;
    }
  }
  return current;
}

/// Builds an LRC string from a list of lines.
String buildLrc(List<LrcLine> lines) {
  final buf = StringBuffer();
  for (final line in lines) {
    final min = line.time.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = line.time.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (line.time.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    buf.writeln('[$min:$sec.$ms] ${line.text}');
  }
  return buf.toString();
}
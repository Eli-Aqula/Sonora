/// Scraper for song lyrics from a Genius page.
///
/// The Genius API does not return lyrics (the `lyrics` field is only
/// available to paid clients with extended access). So, given the
/// public song URL from the `/songs/:id` or `/search` response, we
/// fetch the HTML and extract the contents of the
/// `data-lyrics-container="true"` blocks.
///
/// Format: a single HTML markup with `<br/>` for line breaks, `<a>` for
/// links, and sometimes `<i>`/`<b>` for styling. We only need plain
/// text with line breaks.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches the Genius page HTML at [pageUrl] and extracts the plain-text
/// lyrics.
///
/// Returns `null` if:
/// - the page did not load (any HTTP status != 200),
/// - no `data-lyrics-container` was found,
/// - the extracted text is empty after normalization.
///
/// Never throws -- this is a "best effort" background operation.
Future<String?> fetchGeniusLyrics(
  String pageUrl, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final h = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final res = await h.get(
      Uri.parse(pageUrl),
      headers: const {
        // Without a browser User-Agent, Genius sometimes returns a
        // truncated/anti-bot version of the page without lyrics
        // containers.
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'ru,en;q=0.8',
      },
    ).timeout(timeout);
    if (res.statusCode != 200) return null;
    final html = utf8.decode(res.bodyBytes, allowMalformed: true);
    final text = extractLyricsFromHtml(html);
    if (text == null || text.trim().isEmpty) return null;
    return text;
  } catch (_) {
    return null;
  } finally {
    if (ownsClient) h.close();
  }
}

/// Extracts plain text from the HTML of a Genius page.
///
/// Visible for tests: a pure function, no network access.
String? extractLyricsFromHtml(String html) {
  final containers = _findLyricsContainers(html);
  if (containers.isEmpty) return null;

  final buf = StringBuffer();
  for (final c in containers) {
    final cleaned = _cleanContainer(c);
    if (cleaned.isEmpty) continue;
    if (buf.isNotEmpty) buf.write('\n');
    buf.write(cleaned);
  }
  final result = _postProcess(buf.toString());
  return result.isEmpty ? null : result;
}

// ─── Internals ────────────────────────────────────────────────────────

/// Finds all `<div data-lyrics-container="true">...</div>` blocks and
/// returns their "innards".
///
/// Additionally prefers containers whose class contains the substring
/// `Lyrics__Container` or `lyrics-container` -- this is a more specific
/// marker of the actual lyrics block in modern Genius pages. The page
/// header ("Contributors", language switcher, the "Title Lyrics"
/// heading) sometimes also carries `data-lyrics-container="true"`, but
/// does NOT have the right class. So:
/// - if at least one container with the right class is found, we take
///   only those;
/// - otherwise, fall back to all `data-lyrics-container="true"`
///   containers (old/non-standard layouts).
List<String> _findLyricsContainers(String html) {
  final strict = <String>[];
  final loose = <String>[];
  final openRe = RegExp(
    r'<div\b([^>]*)\bdata-lyrics-container\s*=\s*"true"([^>]*)>',
    caseSensitive: false,
  );
  final classRe = RegExp(r'\bclass\s*=\s*"([^"]*)"', caseSensitive: false);
  final lyricsClass = RegExp(
    r'Lyrics__Container|lyrics-container|Lyrics-sc',
    caseSensitive: false,
  );

  for (final m in openRe.allMatches(html)) {
    final startBody = m.end;
    final end = _findMatchingClose(html, startBody);
    if (end < 0) continue;
    final body = html.substring(startBody, end);

    final openTag = html.substring(m.start, m.end);
    final classMatch = classRe.firstMatch(openTag);
    final classes = classMatch?.group(1) ?? '';

    if (lyricsClass.hasMatch(classes)) {
      strict.add(body);
    } else {
      loose.add(body);
    }
  }
  return strict.isNotEmpty ? strict : loose;
}

/// Returns the position of the `</div>` that closes the open `<div>`,
/// starting the search at position [from]. Tracks the nesting balance
/// of `<div>` tags. Returns -1 if not found.
int _findMatchingClose(String html, int from) {
  final tagRe = RegExp(r'<(/?)div\b[^>]*>', caseSensitive: false);
  var depth = 1;
  var pos = from;
  while (pos < html.length) {
    final m = tagRe.firstMatch(html.substring(pos));
    if (m == null) return -1;
    final closing = m.group(1) == '/';
    if (closing) {
      depth--;
      if (depth == 0) return pos + m.start;
    } else {
      depth++;
    }
    pos += m.end;
  }
  return -1;
}

/// Turns an HTML fragment into plain text: `<br>` -> `\n`, tags are
/// dropped, entities are decoded.
String _cleanContainer(String html) {
  var t = html;
  // <br>, <br/>, <br /> -> line break.
  t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  // Paragraphs: each closed paragraph = a line break.
  t = t.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  // Genius sometimes inserts inline <div>s inside the container -- turn
  // opening/closing tags into line breaks so verses don't run together.
  t = t.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
  t = t.replaceAll(RegExp(r'<div\b[^>]*>', caseSensitive: false), '\n');
  // Strip all remaining tags.
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');
  // HTML entities.
  t = _decodeEntities(t);
  return t;
}

/// Final cleanup of the merged text.
String _postProcess(String s) {
  // Normalize line breaks.
  var t = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  // Remove NBSP and zero-width characters.
  t = t.replaceAll(' ', ' ');
  t = t.replaceAll(RegExp(r'[​-‍﻿]'), '');
  // Trim trailing whitespace on each line.
  final lines = t.split('\n').map((l) => l.trimRight()).toList();
  // Remove section-header lines: "[Verse 1]", "[Chorus]", "[Chorus: ...]".
  // Genius uses these for structure; in LRC they only get in the way of
  // matching.
  final filtered = <String>[];
  for (final raw in lines) {
    final trimmed = raw.trim();
    if (_isSectionHeader(trimmed)) continue;
    filtered.add(raw);
  }
  // Collapse 3+ consecutive blank lines down to at most 1.
  final compact = <String>[];
  var blankRun = 0;
  for (final l in filtered) {
    if (l.trim().isEmpty) {
      blankRun++;
      if (blankRun <= 1) compact.add('');
    } else {
      blankRun = 0;
      compact.add(l);
    }
  }
  // Remove leading/trailing blank lines.
  while (compact.isNotEmpty && compact.first.trim().isEmpty) {
    compact.removeAt(0);
  }
  while (compact.isNotEmpty && compact.last.trim().isEmpty) {
    compact.removeLast();
  }
  // Strip the Genius "preamble": "N Contributors", "Translations", the
  // language list, the "Title Lyrics" heading -- these arrive in the
  // shared container mixed in with the actual lyrics.
  _stripPreamble(compact);
  // And trailing noise: "You might also like", "Embed", view counters
  // like "28K".
  _stripTrailing(compact);
  // Sometimes Genius (especially for instrumentals and tracks without
  // official lyrics) puts paragraphs from the "About this song" section
  // into the lyrics container. Such chunks are prose sentences that have
  // nothing to do with the song.
  _dropProseDescriptions(compact);
  return compact.join('\n');
}

/// List of language names in their own languages -- Genius uses these in
/// the "Translations" switcher. Matching is exact (whole line).
const _languageNames = <String>{
  'english', 'español', 'français', 'deutsch', 'italiano', 'português',
  'türkçe', 'polski', 'nederlands', 'svenska', 'norsk', 'dansk', 'suomi',
  'русский', 'українська', 'беларуская', 'қазақша', 'azərbaycan',
  'romaji', 'romanization', 'transliteration',
  '日本語', '한국어', '中文', '繁體中文', '简体中文', 'العربية', 'فارسی',
  'עברית', 'ελληνικά', 'magyar', 'čeština', 'slovenčina', 'română',
  'български', 'srpski', 'hrvatski', 'tiếng việt', 'bahasa indonesia',
  'tagalog', 'हिन्दी', 'বাংলা', 'ภาษาไทย',
};

/// True for lines that are DEFINITELY Genius preamble noise (and not a
/// piece of the actual lyrics).
bool _isPreambleNoise(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return true;
  final lower = s.toLowerCase();
  // "24 Contributors", "1 Contributor", possibly with a trailing "...".
  if (RegExp(r'^\d+\s+contributors?\b').hasMatch(lower)) return true;
  // "Translations" / "Translation".
  if (lower == 'translations' || lower == 'translation') return true;
  if (lower == 'переводы' || lower == 'перевод') return true;
  // "Read More", "Show More", "Edit Lyrics".
  if (lower == 'read more' || lower == 'show more') return true;
  if (lower == 'edit lyrics' || lower == 'edit') return true;
  // Track title: "<Title> Lyrics" -- a short line ending in " Lyrics".
  // It's very rare for an actual lyric line to end with the standalone
  // word "Lyrics".
  if (s.length < 120 &&
      (s.endsWith(' Lyrics') ||
          s.endsWith(' lyrics') ||
          s.endsWith(' LYRICS'))) {
    return true;
  }
  // A standalone "Lyrics" used as a separator.
  if (lower == 'lyrics') return true;
  // A language name acting as a switcher entry.
  if (_languageNames.contains(lower)) return true;
  // A run-on language switcher with no spaces:
  // "EnglishDeutschFrançaisItalianoRomanization". This happens when
  // Genius renders the languages as inline buttons with no separators
  // and our _cleanContainer joins them together.
  if (_isConcatenatedLanguageRow(s)) return true;
  return false;
}

/// Heuristic for a CamelCase run-on of 2+ known language names.
/// Criteria:
/// - contains only letters (any alphabet);
/// - up to 120 characters long (longer is already direct content);
/// - has at least 2 "lowercase -> uppercase" transitions (CamelCase
///   boundaries);
/// - contains a substring from [_languageNames].
bool _isConcatenatedLanguageRow(String s) {
  if (s.length < 6 || s.length > 120) return false;
  if (!RegExp(r'^[\p{L}\p{M}]+$', unicode: true).hasMatch(s)) return false;
  final lower = s.toLowerCase();
  final hasLang = _languageNames.any((l) => lower.contains(l));
  if (!hasLang) return false;
  final transitions =
      RegExp(r'\p{Ll}\p{Lu}', unicode: true).allMatches(s).length;
  return transitions >= 2;
}

/// Strips leading preamble lines up to the first "real" piece of lyrics.
/// We limit the scan to the first 14 lines -- beyond that it's
/// definitely lyrics.
void _stripPreamble(List<String> lines) {
  const maxScan = 14;
  var stripped = 0;
  while (lines.isNotEmpty && stripped < maxScan) {
    if (_isPreambleNoise(lines.first)) {
      lines.removeAt(0);
      stripped++;
    } else {
      break;
    }
  }
}

/// True for lines that Genius appends at the very end of the container.
bool _isTrailingNoise(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return true;
  final lower = s.toLowerCase();
  if (lower.startsWith('you might also like')) return true;
  if (lower == 'embed') return true;
  if (lower.startsWith('see ') && lower.contains(' live')) return true;
  // "1.2K", "28K", "5.4M" -- the song's view counter at the very bottom.
  if (RegExp(r'^\d+(\.\d+)?\s*[km]$', caseSensitive: false).hasMatch(s)) {
    return true;
  }
  return false;
}

void _stripTrailing(List<String> lines) {
  const maxScan = 12;
  var stripped = 0;
  while (lines.isNotEmpty && stripped < maxScan) {
    if (_isTrailingNoise(lines.last)) {
      lines.removeLast();
      stripped++;
    } else {
      break;
    }
  }
}

/// True for lines that look like a prose description paragraph rather
/// than song lyrics. Heuristic:
/// - length > 140 characters (real lyric lines are usually shorter);
/// - has at least one internal "end of sentence + capital letter"
///   transition (`. C`, `! T`, `? A`) -- real lyric lines almost never
///   contain this, even long verses get split by `<br>`.
/// Extra safeguard: a very long line (>220) ending in a period is also
/// treated as prose -- typical of "About this song".
bool _isProseDescription(String s) {
  if (s.length < 140) return false;
  final sentEnds = RegExp(r'[.!?]\s+[A-ZА-ЯЁЇЄІҐ]').allMatches(s).length;
  if (sentEnds >= 1) return true;
  if (s.length > 220 && RegExp(r'[.!?]$').hasMatch(s.trim())) return true;
  return false;
}

void _dropProseDescriptions(List<String> lines) {
  lines.removeWhere(_isProseDescription);
  // Clean up any blank lines orphaned at the start/end.
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
}

bool _isSectionHeader(String s) {
  if (s.length < 3) return false;
  if (!(s.startsWith('[') && s.endsWith(']'))) return false;
  // There must be no line break inside the brackets, and there must be
  // some text.
  final inner = s.substring(1, s.length - 1).trim();
  if (inner.isEmpty) return false;
  return true;
}

/// Decodes the subset of HTML entities that actually shows up on Genius
/// (ampersand/quotes/typography/&#NNN;).
String _decodeEntities(String s) {
  // Numeric entities: &#1234; and &#x1A2B;
  var t = s.replaceAllMapped(
    RegExp(r'&#(x?)([0-9a-fA-F]+);'),
    (m) {
      final hex = (m.group(1) ?? '').toLowerCase() == 'x';
      final raw = m.group(2)!;
      final code = int.tryParse(raw, radix: hex ? 16 : 10);
      if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
      try {
        return String.fromCharCode(code);
      } catch (_) {
        return m.group(0)!;
      }
    },
  );
  // Named entities.
  const named = <String, String>{
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
    '&ndash;': '–',
    '&mdash;': '—',
    '&hellip;': '…',
    '&laquo;': '«',
    '&raquo;': '»',
    '&lsquo;': '‘',
    '&rsquo;': '’',
    '&ldquo;': '“',
    '&rdquo;': '”',
  };
  named.forEach((k, v) {
    t = t.replaceAll(k, v);
  });
  return t;
}

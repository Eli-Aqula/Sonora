import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/services/genius/lyrics_scraper.dart';

void main() {
  group('extractLyricsFromHtml', () {
    test('возвращает null если контейнеров нет', () {
      const html = '<html><body><div>no lyrics here</div></body></html>';
      expect(extractLyricsFromHtml(html), isNull);
    });

    test('извлекает строки из одного контейнера, <br/> → перенос', () {
      const html = '''
<div data-lyrics-container="true" class="Lyrics-x">
Line one<br/>Line two<br>Line three
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      final lines = out.split('\n');
      expect(lines, contains('Line one'));
      expect(lines, contains('Line two'));
      expect(lines, contains('Line three'));
    });

    test('склеивает два контейнера через перенос', () {
      const html = '''
<div data-lyrics-container="true">Verse 1<br/>Verse 1 line two</div>
<div>some other div</div>
<div data-lyrics-container="true">Verse 2 line one<br/>Verse 2 line two</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('Verse 1'));
      expect(out, contains('Verse 1 line two'));
      expect(out, contains('Verse 2 line one'));
      expect(out, contains('Verse 2 line two'));
    });

    test('удаляет inline-теги, оставляет текст', () {
      const html = '''
<div data-lyrics-container="true">
<a href="/q">Linked</a> word<br/><i>italic</i> bit
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('Linked word'));
      expect(out, contains('italic bit'));
      expect(out, isNot(contains('<a')));
      expect(out, isNot(contains('<i')));
    });

    test('декодирует HTML-сущности', () {
      const html = '''
<div data-lyrics-container="true">
You &amp; me &mdash; forever<br/>I&#39;m yours
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('You & me — forever'));
      expect(out, contains("I'm yours"));
    });

    test('отрезает структурные заголовки [Verse]/[Chorus]', () {
      const html = '''
<div data-lyrics-container="true">
[Verse 1]<br/>Real line<br/>[Chorus]<br/>Another real line
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('Real line'));
      expect(out, contains('Another real line'));
      expect(out, isNot(contains('[Verse 1]')));
      expect(out, isNot(contains('[Chorus]')));
    });

    test('возвращает null, если после очистки пусто', () {
      const html = '<div data-lyrics-container="true">[Intro]</div>';
      expect(extractLyricsFromHtml(html), isNull);
    });

    test('держит порядок и не теряет первую/последнюю строку', () {
      const html = '''
<div data-lyrics-container="true">First<br/>Middle<br/>Last</div>
''';
      final out = extractLyricsFromHtml(html)!;
      final lines = out.split('\n');
      expect(lines.first, 'First');
      expect(lines.last, 'Last');
      expect(lines, contains('Middle'));
    });

    test('игнорирует регистр атрибута data-lyrics-container', () {
      const html = '<DIV DATA-LYRICS-CONTAINER="true">Hello</DIV>';
      expect(extractLyricsFromHtml(html), contains('Hello'));
    });

    test('отрезает преамбулу «N Contributors / Translations / English / '
        'Title Lyrics»', () {
      const html = '''
<div data-lyrics-container="true">
24 Contributors<br/>
Translations<br/>
Русский<br/>
English<br/>
Some Song Title Lyrics<br/>
[Verse 1]<br/>
First real line<br/>
Second real line
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('First real line'));
      expect(out, contains('Second real line'));
      expect(out, isNot(contains('24 Contributors')));
      expect(out, isNot(contains('Translations')));
      expect(out, isNot(contains('Some Song Title Lyrics')));
      expect(out, isNot(contains('English')));
      expect(out, isNot(contains('Русский')));
    });

    test('отрезает хвостовой шум «You might also like / Embed / 28K»', () {
      const html = '''
<div data-lyrics-container="true">
Last real line<br/>
You might also like<br/>
Embed<br/>
28K
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('Last real line'));
      expect(out, isNot(contains('You might also like')));
      expect(out, isNot(contains('Embed')));
      expect(out, isNot(contains('28K')));
    });

    test('предпочитает контейнер с классом «Lyrics__Container» если он есть', () {
      // Header-блок Genius может тоже носить data-lyrics-container="true";
      // настоящий — отличается по классу.
      const html = '''
<div data-lyrics-container="true" class="LyricsHeader-sc-xyz">
24 Contributors<br/>
Translations<br/>
Some Song Lyrics
</div>
<div data-lyrics-container="true" class="Lyrics__Container-sc-abc">
First real line<br/>
Second real line
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('First real line'));
      expect(out, contains('Second real line'));
      expect(out, isNot(contains('24 Contributors')));
      expect(out, isNot(contains('Translations')));
      expect(out, isNot(contains('Some Song Lyrics')));
    });

    test('fallback на все data-lyrics-container, если нужного класса нет', () {
      const html = '''
<div data-lyrics-container="true">
Verse one<br/>Verse two
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('Verse one'));
      expect(out, contains('Verse two'));
    });

    test('не отрезает текст, который только начинается с слова «English»', () {
      // Защита от ложноположительных: «English mornings, lovely sun» —
      // настоящая строка песни.
      const html = '''
<div data-lyrics-container="true">
[Verse 1]<br/>
English mornings, lovely sun<br/>
On the river
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('English mornings, lovely sun'));
    });

    test('отрезает абзац «About this song», случайно попавший в lyrics-контейнер',
        () {
      const html = '''
<div data-lyrics-container="true">
Песня является кавером стиха «Эмалированное судно» русского поэта Бориса Рыжего, который покончил жизнь самоубийством в возрасте 26 лет. Свои произведения он посвящал темам отчаяния и преступности в постсоветской России.<br/>
[Куплет 1]<br/>
Гражданин учил Гражданина<br/>
Жить, как надо
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('Гражданин учил Гражданина'));
      expect(out, contains('Жить, как надо'));
      expect(out, isNot(contains('кавером стиха')));
      expect(out, isNot(contains('Бориса Рыжего')));
      expect(out, isNot(contains('покончил жизнь')));
    });

    test('лечит реальный кейс «Молчат Дома — Судно»: слитный переключатель '
        'языков + заголовок Lyrics + абзац описания с Read More',
        () {
      const html = '''
<div data-lyrics-container="true">
EnglishDeutschFrançaisItalianoRomanization<br/>
Судно (Борис Рыжий) (Sudno) Lyrics<br/>
Песня является кавером стиха «Эмалированное судно» русского поэта Бориса Рыжего, который покончил жизнь самоубийством в возрасте 26 лет. Свои произведения он посвящал темам отчаяния и преступности в... Read More<br/>
[Куплет 1]<br/>
Эмалированное судно<br/>
Окошко, тумбочка, кровать<br/>
Жить тяжело и неуютно<br/>
Зато уютно умирать
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('Эмалированное судно'));
      expect(out, contains('Окошко, тумбочка, кровать'));
      expect(out, contains('Жить тяжело и неуютно'));
      expect(out, contains('Зато уютно умирать'));
      expect(out, isNot(contains('EnglishDeutsch')));
      expect(out, isNot(contains('Lyrics')));
      expect(out, isNot(contains('Read More')));
      expect(out, isNot(contains('Бориса Рыжего')));
    });

    test('не путает длинную строку lyrics с прозой, пока в ней одно предложение',
        () {
      // Реальные строки lyrics редко достигают 140 символов, но если
      // достигают — там обычно не больше одной точки. Такую строку
      // мы не должны отрезать.
      const html = '''
<div data-lyrics-container="true">
[Verse]<br/>
This is a single very long lyrical line that contains many words and goes on and on without ending — like a stream of consciousness<br/>
Short follow-up
</div>
''';
      final out = extractLyricsFromHtml(html)!;
      expect(out, contains('stream of consciousness'));
    });
  });
}

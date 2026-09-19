import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_desktop_lyrics/flutter_desktop_lyrics.dart';

void main() {
  test('DesktopLyrics.isLyricsWindow detects multi_window correctly', () {
    expect(DesktopLyrics.isLyricsWindow([]), isFalse);
    expect(DesktopLyrics.isLyricsWindow(['some_file.mp3']), isFalse);
    expect(
      DesktopLyrics.isLyricsWindow([
        'multi_window',
        '2',
        '{"type":"desktop_lyrics"}',
      ]),
      isTrue,
    );
  });

  test('DesktopLyricLine JSON serialization handles karaoke words and translation', () {
    final line = DesktopLyricLine(
      timestampMs: 1200,
      text: 'Hello world',
      translation: '你好世界',
      words: const [
        DesktopLyricWord(timestampMs: 1200, durationMs: 400, text: 'Hello '),
        DesktopLyricWord(timestampMs: 1600, durationMs: 500, text: 'world'),
      ],
    );

    final json = line.toJson();
    final restored = DesktopLyricLine.fromJson(json);

    expect(restored.text, 'Hello world');
    expect(restored.translation, '你好世界');
    expect(restored.isKaraoke, isTrue);
    expect(restored.words?.length, 2);
    expect(restored.words?[1].durationMs, 500);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_desktop_lyrics/flutter_desktop_lyrics.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  if (DesktopLyrics.isLyricsWindow(args)) {
    runApp(DesktopLyrics.createLyricsWindowApp(args));
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _controller = DesktopLyrics.controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Desktop Lyrics Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await _controller.show();
                  await _controller.updatePlaybackState(
                    isPlaying: true,
                    positionMs: 1200,
                    title: 'Song Demo',
                    artist: 'Artist Demo',
                  );
                  await _controller.updateLyricLine(
                    const DesktopLyricLine(
                      timestampMs: 1000,
                      text: 'Never gonna give you up',
                      translation: '永远不会放弃你',
                      words: [
                        DesktopLyricWord(timestampMs: 1000, durationMs: 400, text: 'Never '),
                        DesktopLyricWord(timestampMs: 1400, durationMs: 300, text: 'gonna '),
                        DesktopLyricWord(timestampMs: 1700, durationMs: 400, text: 'give '),
                        DesktopLyricWord(timestampMs: 2100, durationMs: 300, text: 'you '),
                        DesktopLyricWord(timestampMs: 2400, durationMs: 500, text: 'up'),
                      ],
                    ),
                  );
                },
                child: const Text('显示桌面歌词'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _controller.hide(),
                child: const Text('隐藏桌面歌词'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _controller.setLocked(!_controller.isLocked),
                child: const Text('切换锁定状态 (穿透鼠标点击)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

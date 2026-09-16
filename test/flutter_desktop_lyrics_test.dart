import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_desktop_lyrics/flutter_desktop_lyrics.dart';
import 'package:flutter_desktop_lyrics/flutter_desktop_lyrics_platform_interface.dart';
import 'package:flutter_desktop_lyrics/flutter_desktop_lyrics_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterDesktopLyricsPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDesktopLyricsPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterDesktopLyricsPlatform initialPlatform = FlutterDesktopLyricsPlatform.instance;

  test('$MethodChannelFlutterDesktopLyrics is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterDesktopLyrics>());
  });

  test('getPlatformVersion', () async {
    FlutterDesktopLyrics flutterDesktopLyricsPlugin = FlutterDesktopLyrics();
    MockFlutterDesktopLyricsPlatform fakePlatform = MockFlutterDesktopLyricsPlatform();
    FlutterDesktopLyricsPlatform.instance = fakePlatform;

    expect(await flutterDesktopLyricsPlugin.getPlatformVersion(), '42');
  });
}

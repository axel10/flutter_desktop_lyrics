
import 'flutter_desktop_lyrics_platform_interface.dart';

class FlutterDesktopLyrics {
  Future<String?> getPlatformVersion() {
    return FlutterDesktopLyricsPlatform.instance.getPlatformVersion();
  }
}

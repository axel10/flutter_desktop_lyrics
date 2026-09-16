import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_desktop_lyrics_platform_interface.dart';

/// An implementation of [FlutterDesktopLyricsPlatform] that uses method channels.
class MethodChannelFlutterDesktopLyrics extends FlutterDesktopLyricsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_desktop_lyrics');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}

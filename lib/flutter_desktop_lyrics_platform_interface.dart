import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_desktop_lyrics_method_channel.dart';

abstract class FlutterDesktopLyricsPlatform extends PlatformInterface {
  /// Constructs a FlutterDesktopLyricsPlatform.
  FlutterDesktopLyricsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDesktopLyricsPlatform _instance = MethodChannelFlutterDesktopLyrics();

  /// The default instance of [FlutterDesktopLyricsPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterDesktopLyrics].
  static FlutterDesktopLyricsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterDesktopLyricsPlatform] when
  /// they register themselves.
  static set instance(FlutterDesktopLyricsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

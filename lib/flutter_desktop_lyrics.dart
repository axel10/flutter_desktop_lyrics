import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';

export 'src/models/lyrics_data.dart';
export 'src/models/lyrics_action.dart';
export 'src/platform/lyrics_native_window.dart';
export 'src/controller/desktop_lyrics_controller.dart';
export 'src/ui/apple_karaoke_text.dart';
export 'src/ui/desktop_lyrics_view.dart';
export 'src/ui/desktop_lyrics_window_app.dart';

import 'src/controller/desktop_lyrics_controller.dart';
import 'src/ui/desktop_lyrics_window_app.dart';

class DesktopLyrics {
  DesktopLyrics._();

  /// 主窗口控制器单例
  static DesktopLyricsController get controller => DesktopLyricsController.instance;

  /// 判断当前启动参数是否为桌面歌词子窗口
  static bool isLyricsWindow(List<String> args) {
    if (args.isEmpty || args.first != 'multi_window') return false;
    if (args.length >= 3 && args[2].contains('desktop_lyrics')) {
      return true;
    }
    return false;
  }

  /// 构建桌面歌词子窗口的根 App 组件
  static Widget createLyricsWindowApp(List<String> args) {
    final windowId = args.length > 1 ? args[1] : '1';
    Map<String, dynamic> initialData = {};
    if (args.length > 2) {
      try {
        initialData = jsonDecode(args[2]) as Map<String, dynamic>;
      } catch (e, stack) {
        debugPrint('[DesktopLyrics] Failed to decode initialData: $e\n$stack');
      }
    }
    final windowController = WindowController.fromWindowId(windowId);
    return DesktopLyricsWindowApp(
      windowController: windowController,
      initialData: initialData,
    );
  }
}

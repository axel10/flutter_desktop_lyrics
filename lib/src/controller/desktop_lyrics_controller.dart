import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import '../models/lyrics_data.dart';
import '../models/lyrics_action.dart';

class DesktopLyricsController extends ChangeNotifier {
  DesktopLyricsController._();
  static final DesktopLyricsController instance = DesktopLyricsController._();

  WindowController? _windowController;
  bool _isLocked = false;
  DesktopLyricsStyle _style = const DesktopLyricsStyle();
  DesktopLyricLine? _currentLine;
  DesktopPlaybackState _playbackState = DesktopPlaybackState(
    isPlaying: false,
    positionMs: 0,
    timestampMs: DateTime.now().millisecondsSinceEpoch,
  );

  void Function(DesktopLyricsAction action)? _actionListener;

  bool get isShowing => _windowController != null;
  bool get isLocked => _isLocked;
  DesktopLyricsStyle get style => _style;
  DesktopLyricLine? get currentLine => _currentLine;
  DesktopPlaybackState get playbackState => _playbackState;

  void setActionListener(void Function(DesktopLyricsAction action)? listener) {
    _actionListener = listener;
  }

  /// 注册主窗口的 IPC 消息接收（用于接收子窗口点击的切歌、暂停、锁定等）
  Future<void> initializeMainChannel() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      final currentEngineController = await WindowController.fromCurrentEngine();
      currentEngineController.setWindowMethodHandler((call) async {
        if (call.method == 'onLyricsAction') {
          if (call.arguments is String) {
            try {
              final jsonMap = jsonDecode(call.arguments as String) as Map<String, dynamic>;
              final action = DesktopLyricsAction.fromJson(jsonMap);
              _handleReceivedAction(action);
            } catch (e, stack) {
              debugPrint('[DesktopLyricsController] Error parsing onLyricsAction: $e\n$stack');
            }
          }
          return true;
        }
        return null;
      });
    } catch (e, stack) {
      debugPrint('[DesktopLyricsController] initializeMainChannel error: $e\n$stack');
    }
  }

  void _handleReceivedAction(DesktopLyricsAction action) {
    if (action.type == DesktopLyricsActionType.toggleLock) {
      if (action.data != null && action.data!['locked'] is bool) {
        _isLocked = action.data!['locked'] as bool;
        notifyListeners();
      }
    } else if (action.type == DesktopLyricsActionType.increaseFontSize ||
        action.type == DesktopLyricsActionType.decreaseFontSize) {
      if (action.data != null && action.data!['fontSize'] is num) {
        final newSize = (action.data!['fontSize'] as num).toDouble();
        _style = _style.copyWith(
          fontSize: newSize,
          translationFontSize: (newSize * 0.58).clamp(11.0, 36.0),
        );
        notifyListeners();
      }
    } else if (action.type == DesktopLyricsActionType.close) {
      hide();
    }
    _actionListener?.call(action);
  }

  /// 打开或显示桌面歌词窗口
  Future<void> show({DesktopLyricsStyle? initialStyle}) async {
    if (!Platform.isWindows) return;
    if (initialStyle != null) {
      _style = initialStyle;
    }

    await initializeMainChannel();

    String currentEngineId = '0';
    try {
      final current = await WindowController.fromCurrentEngine();
      currentEngineId = current.windowId;
    } catch (_) {}

    if (_windowController != null) {
      try {
        await _windowController!.show();
        await _syncFullState();
        notifyListeners();
        return;
      } catch (_) {
        _windowController = null;
      }
    }

    // 检查系统中是否已经存在已运行的桌面歌词窗口（例如 Hot Restart 后的孤儿窗口）
    try {
      final allWindows = await WindowController.getAll();
      final lyricsWindows = allWindows.where((w) {
        if (w.windowId == currentEngineId) return false;
        return w.arguments.contains('desktop_lyrics');
      }).toList();

      if (lyricsWindows.isNotEmpty) {
        _windowController = lyricsWindows.first;
        await _windowController!.show();
        await _syncFullState();

        // 如果存在多余的重复歌词窗口（如之前 hot restart 堆叠的），隐藏多余的
        for (int i = 1; i < lyricsWindows.length; i++) {
          try {
            await lyricsWindows[i].hide();
          } catch (_) {}
        }

        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[DesktopLyricsController] Failed to query existing windows: $e');
    }

    final initData = {
      'type': 'desktop_lyrics',
      'mainWindowId': currentEngineId,
      'isLocked': _isLocked,
      'style': _style.toJson(),
      'playbackState': _playbackState.toJson(),
      if (_currentLine != null) 'currentLine': _currentLine!.toJson(),
    };

    final window = await WindowController.create(
      WindowConfiguration(arguments: jsonEncode(initData), hiddenAtLaunch: false),
    );
    _windowController = window;

    await window.show();
    notifyListeners();
  }

  /// 隐藏桌面歌词窗口
  Future<void> hide() async {
    if (_windowController != null) {
      try {
        await _windowController!.hide();
      } catch (_) {}
      _windowController = null;
      notifyListeners();
    } else {
      // 容错：如果 _windowController 为空（如 hot restart 后用户直接关闭），也清理已存在的歌词窗口
      try {
        final current = await WindowController.fromCurrentEngine();
        final allWindows = await WindowController.getAll();
        for (final w in allWindows) {
          if (w.windowId != current.windowId && w.arguments.contains('desktop_lyrics')) {
            await w.hide();
          }
        }
      } catch (_) {}
    }
  }

  /// 切换显示/隐藏
  Future<void> toggleShow() async {
    if (isShowing) {
      await hide();
    } else {
      await show();
    }
  }

  /// 切换锁定状态
  Future<void> setLocked(bool locked) async {
    _isLocked = locked;
    notifyListeners();
    if (_windowController != null) {
      try {
        await _windowController!.invokeMethod('setLocked', locked);
      } catch (e) {
        debugPrint('[DesktopLyricsController] setLocked IPC error: $e');
      }
    }
  }

  /// 更新样式设置（字号、对齐、颜色等）
  Future<void> setStyle(DesktopLyricsStyle newStyle) async {
    _style = newStyle;
    notifyListeners();
    if (_windowController != null) {
      try {
        await _windowController!.invokeMethod('updateStyle', newStyle.toJson());
      } catch (e) {
        debugPrint('[DesktopLyricsController] updateStyle IPC error: $e');
      }
    }
  }

  /// 同步当前歌词行（原文 + 翻译 + 逐字时间戳）
  Future<void> updateLyricLine(DesktopLyricLine? line) async {
    _currentLine = line;
    if (_windowController != null) {
      try {
        await _windowController!.invokeMethod('updateLine', line?.toJson());
      } catch (e) {
        debugPrint('[DesktopLyricsController] updateLine IPC error: $e');
      }
    }
  }

  /// 同步当前播放状态与基准时间戳
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required int positionMs,
    String? title,
    String? artist,
  }) async {
    _playbackState = DesktopPlaybackState(
      isPlaying: isPlaying,
      positionMs: positionMs,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      title: title ?? _playbackState.title,
      artist: artist ?? _playbackState.artist,
    );
    if (_windowController != null) {
      try {
        await _windowController!.invokeMethod('updatePlayback', _playbackState.toJson());
      } catch (e) {
        debugPrint('[DesktopLyricsController] updatePlayback IPC error: $e');
      }
    }
  }

  Future<void> _syncFullState() async {
    if (_windowController == null) return;
    String currentEngineId = '0';
    try {
      final current = await WindowController.fromCurrentEngine();
      currentEngineId = current.windowId;
    } catch (_) {}

    try {
      await _windowController!.invokeMethod('syncState', {
        'mainWindowId': currentEngineId,
        'isLocked': _isLocked,
        'style': _style.toJson(),
        'playbackState': _playbackState.toJson(),
        if (_currentLine != null) 'currentLine': _currentLine!.toJson(),
      });
    } catch (e) {
      debugPrint('[DesktopLyricsController] syncState IPC error: $e');
    }
  }
}

import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lyrics_data.dart';
import '../models/lyrics_action.dart';
import '../platform/lyrics_native_window.dart';
import 'desktop_lyrics_view.dart';

class DesktopLyricsWindowApp extends StatefulWidget {
  final WindowController windowController;
  final Map<String, dynamic> initialData;

  const DesktopLyricsWindowApp({
    super.key,
    required this.windowController,
    required this.initialData,
  });

  @override
  State<DesktopLyricsWindowApp> createState() => _DesktopLyricsWindowAppState();
}

class _DesktopLyricsWindowAppState extends State<DesktopLyricsWindowApp> {
  DesktopLyricLine? _currentLine;
  DesktopPlaybackState _playbackState = DesktopPlaybackState(
    isPlaying: false,
    positionMs: 0,
    timestampMs: DateTime.now().millisecondsSinceEpoch,
  );
  DesktopLyricsStyle _style = const DesktopLyricsStyle();
  bool _isLocked = false;
  String _mainWindowId = '0';

  static const double minFontSize = 16.0;
  static const double maxFontSize = 56.0;
  static const double stepFontSize = 2.0;

  static (double, double) _calculateWindowSize(double fontSize) {
    final width = (960.0 + (fontSize - 28.0) * 22.0).clamp(720.0, 1800.0);
    final height = (150.0 + (fontSize - 28.0) * 3.2).clamp(118.0, 260.0);
    return (width, height);
  }

  Future<void> _resizeWindowToFontSize(double fontSize) async {
    final (targetWidth, targetHeight) = _calculateWindowSize(fontSize);
    final bounds = await LyricsNativeWindow.instance.getWindowBounds();
    if (bounds != null) {
      final currentX = bounds['x'] ?? 0.0;
      final currentY = bounds['y'] ?? 0.0;
      final currentW = bounds['width'] ?? targetWidth;
      final currentH = bounds['height'] ?? targetHeight;

      final newX = currentX - (targetWidth - currentW) / 2.0;
      final newY = currentY - (targetHeight - currentH) / 2.0;

      await LyricsNativeWindow.instance.setWindowBounds(
        x: newX,
        y: newY,
        width: targetWidth,
        height: targetHeight,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _parseInitialData(widget.initialData);

    // 1. 初始化原生 Win32 透明置顶窗口（根据初始字号计算初始宽高）
    final (initW, initH) = _calculateWindowSize(_style.fontSize);
    LyricsNativeWindow.instance.initializeLyricsWindow(
      width: initW,
      height: initH,
    );

    // 2. 注册 IPC 消息处理
    widget.windowController.setWindowMethodHandler(_handleWindowMethod);
  }

  void _parseInitialData(Map<String, dynamic> data) {
    if (data['mainWindowId'] != null) {
      _mainWindowId = data['mainWindowId'].toString();
    }
    if (data['playbackState'] != null) {
      _playbackState = DesktopPlaybackState.fromJson(
        Map<String, dynamic>.from(data['playbackState'] as Map),
      );
    }
    if (data['currentLine'] != null) {
      _currentLine = DesktopLyricLine.fromJson(
        Map<String, dynamic>.from(data['currentLine'] as Map),
      );
    }
    if (data['style'] != null) {
      _style = DesktopLyricsStyle.fromJson(
        Map<String, dynamic>.from(data['style'] as Map),
      );
    }
    if (data['isLocked'] != null) {
      _isLocked = data['isLocked'] as bool;
    }
  }

  Future<dynamic> _handleWindowMethod(MethodCall call) async {
    switch (call.method) {
      case 'syncState':
        final map = Map<String, dynamic>.from(call.arguments as Map);
        setState(() {
          _parseInitialData(map);
        });
        _resizeWindowToFontSize(_style.fontSize);
        return true;

      case 'updateLine':
        if (call.arguments != null) {
          final lineMap = Map<String, dynamic>.from(call.arguments as Map);
          setState(() {
            _currentLine = DesktopLyricLine.fromJson(lineMap);
          });
        } else {
          setState(() {
            _currentLine = null;
          });
        }
        return true;

      case 'updatePlayback':
        final pbMap = Map<String, dynamic>.from(call.arguments as Map);
        setState(() {
          _playbackState = DesktopPlaybackState.fromJson(pbMap);
        });
        return true;

      case 'updateStyle':
        final styleMap = Map<String, dynamic>.from(call.arguments as Map);
        final newStyle = DesktopLyricsStyle.fromJson(styleMap);
        setState(() {
          _style = newStyle;
        });
        _resizeWindowToFontSize(newStyle.fontSize);
        return true;

      case 'setLocked':
        final locked = call.arguments as bool? ?? false;
        setState(() {
          _isLocked = locked;
        });
        return true;
    }
    return null;
  }

  void _onAction(DesktopLyricsAction action) {
    if (action.type == DesktopLyricsActionType.toggleLock) {
      final newLock = !_isLocked;
      setState(() {
        _isLocked = newLock;
      });
      _sendActionToMain(DesktopLyricsAction(
        type: DesktopLyricsActionType.toggleLock,
        data: {'locked': newLock},
      ));
      return;
    }

    if (action.type == DesktopLyricsActionType.increaseFontSize) {
      if (_style.fontSize >= maxFontSize) return;
      final newSize = (_style.fontSize + stepFontSize).clamp(minFontSize, maxFontSize);
      final newTranslationSize = (newSize * 0.58).clamp(11.0, 36.0);
      setState(() {
        _style = _style.copyWith(
          fontSize: newSize,
          translationFontSize: newTranslationSize,
        );
      });
      _resizeWindowToFontSize(newSize);
      _sendActionToMain(DesktopLyricsAction(
        type: DesktopLyricsActionType.increaseFontSize,
        data: {'fontSize': newSize},
      ));
      return;
    }

    if (action.type == DesktopLyricsActionType.decreaseFontSize) {
      if (_style.fontSize <= minFontSize) return;
      final newSize = (_style.fontSize - stepFontSize).clamp(minFontSize, maxFontSize);
      final newTranslationSize = (newSize * 0.58).clamp(11.0, 36.0);
      setState(() {
        _style = _style.copyWith(
          fontSize: newSize,
          translationFontSize: newTranslationSize,
        );
      });
      _resizeWindowToFontSize(newSize);
      _sendActionToMain(DesktopLyricsAction(
        type: DesktopLyricsActionType.decreaseFontSize,
        data: {'fontSize': newSize},
      ));
      return;
    }

    _sendActionToMain(action);
  }

  void _sendActionToMain(DesktopLyricsAction action) {
    try {
      final mainController = WindowController.fromWindowId(_mainWindowId);
      mainController.invokeMethod('onLyricsAction', jsonEncode(action.toJson()));
    } catch (e, stack) {
      debugPrint('[DesktopLyrics] Failed to send action to main: $e\n$stack');
    }
  }

  static const List<String> defaultFontFamilyFallback = [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Heiti SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'sans-serif',
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: _style.fontFamily ?? 'Segoe UI',
        fontFamilyFallback: _style.fontFamilyFallback ?? defaultFontFamilyFallback,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: DesktopLyricsView(
            currentLine: _currentLine,
            playbackState: _playbackState,
            style: _style,
            isLocked: _isLocked,
            onAction: _onAction,
          ),
        ),
      ),
    );
  }
}

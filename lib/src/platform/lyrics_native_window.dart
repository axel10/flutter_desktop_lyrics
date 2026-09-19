import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LyricsNativeWindow {
  LyricsNativeWindow._();
  static final LyricsNativeWindow instance = LyricsNativeWindow._();

  static const MethodChannel _channel = MethodChannel('flutter_desktop_lyrics');

  /// 初始化桌面歌词子窗口（无边框、置顶、透明客户区、不在任务栏显示）
  Future<bool> initializeLyricsWindow({
    double width = 920,
    double height = 150,
    double? x,
    double? y,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('initializeLyricsWindow', {
        'width': width,
        'height': height,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
      });
      return res ?? false;
    } catch (e, stack) {
      debugPrint('[LyricsNativeWindow] initializeLyricsWindow error: $e\n$stack');
      return false;
    }
  }

  /// 设置锁定状态下的点击穿透（WS_EX_TRANSPARENT）
  Future<bool> setClickThrough(bool enabled) async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setClickThrough', enabled);
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 设置置顶
  Future<bool> setAlwaysOnTop(bool isAlwaysOnTop) async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setAlwaysOnTop', isAlwaysOnTop);
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 原生拖拽移动窗口
  Future<bool> startDragging() async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startDragging');
      return res ?? false;
    } catch (e, stack) {
      debugPrint('[LyricsNativeWindow] startDragging error: $e\n$stack');
      return false;
    }
  }

  /// 设置窗口坐标与尺寸
  Future<bool> setWindowBounds({
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setWindowBounds', {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前窗口坐标与尺寸
  Future<Map<String, double>?> getWindowBounds() async {
    if (!Platform.isWindows && !Platform.isMacOS) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getWindowBounds');
      if (res == null) return null;
      return {
        'x': (res['x'] as num?)?.toDouble() ?? 0.0,
        'y': (res['y'] as num?)?.toDouble() ?? 0.0,
        'width': (res['width'] as num?)?.toDouble() ?? 0.0,
        'height': (res['height'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      return null;
    }
  }

  /// 显示窗口
  Future<bool> showWindow() async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('showWindow');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 隐藏窗口
  Future<bool> hideWindow() async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hideWindow');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }
}

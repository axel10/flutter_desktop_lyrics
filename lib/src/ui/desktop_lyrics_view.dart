import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/lyrics_data.dart';
import '../models/lyrics_action.dart';
import '../platform/lyrics_native_window.dart';
import 'apple_karaoke_text.dart';

const List<String> _defaultFontFamilyFallback = [
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'PingFang SC',
  'Heiti SC',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'sans-serif',
];

class DesktopLyricsView extends StatefulWidget {
  final DesktopLyricLine? currentLine;
  final DesktopPlaybackState playbackState;
  final DesktopLyricsStyle style;
  final bool isLocked;
  final ValueChanged<DesktopLyricsAction> onAction;

  const DesktopLyricsView({
    super.key,
    required this.currentLine,
    required this.playbackState,
    required this.style,
    required this.isLocked,
    required this.onAction,
  });

  @override
  State<DesktopLyricsView> createState() => _DesktopLyricsViewState();
}

class _DesktopLyricsViewState extends State<DesktopLyricsView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _lastSyncTime = DateTime.now();
  int _lastSyncPositionMs = 0;
  bool _isPlaying = false;
  int _currentInterpolatedMs = 0;

  bool _isHovered = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _lastSyncPositionMs = widget.playbackState.positionMs;
    _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(widget.playbackState.timestampMs);
    _isPlaying = widget.playbackState.isPlaying;

    _ticker = createTicker((_) {
      if (_isPlaying) {
        final elapsedMs = DateTime.now().difference(_lastSyncTime).inMilliseconds;
        final nowMs = _lastSyncPositionMs + elapsedMs;
        if (mounted) {
          setState(() {
            _currentInterpolatedMs = nowMs;
          });
        }
      }
    });

    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant DesktopLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackState.positionMs != oldWidget.playbackState.positionMs ||
        widget.playbackState.isPlaying != oldWidget.playbackState.isPlaying ||
        widget.playbackState.timestampMs != oldWidget.playbackState.timestampMs) {
      _lastSyncPositionMs = widget.playbackState.positionMs;
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(widget.playbackState.timestampMs);
      _isPlaying = widget.playbackState.isPlaying;
      _currentInterpolatedMs = _lastSyncPositionMs;
      _updateTicker();
    }
  }

  void _updateTicker() {
    if (_isPlaying) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _onMouseEnter() {
    _hideControlsTimer?.cancel();
    if (mounted) {
      setState(() {
        _isHovered = true;
      });
    }
  }

  void _onMouseExit() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _isHovered = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.currentLine;
    final hasTranslation = line?.translation != null && line!.translation!.trim().isNotEmpty;

    return MouseRegion(
      onEnter: (_) => _onMouseEnter(),
      onExit: (_) => _onMouseExit(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 悬浮交互背板（未锁定且悬停时显示磨砂微黑底，锁定或平时完全 100% 透明）
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _isHovered && !widget.isLocked
                    ? Colors.black.withValues(alpha: 0.38)
                    : Colors.transparent,
                border: _isHovered && !widget.isLocked
                    ? Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1)
                    : null,
              ),
            ),
          ),

          // 2. 全区域拖拽手势层（仅在未锁定状态下响应拖拽，随手按住背景或空白处均可移动窗口）
          if (!widget.isLocked)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) {
                  LyricsNativeWindow.instance.startDragging();
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                ),
              ),
            ),

          // 3. 核心歌词区：原文一行/多行 + 翻译一行/多行（约束可用宽度，长歌词自动折行）
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: widget.style.alignment == 'left'
                          ? Alignment.centerLeft
                          : Alignment.center,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: widget.style.alignment == 'left'
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.center,
                          children: [
                            // 3.1 原文行（支持自动折行与逐字平滑扫光）
                            if (line != null)
                              AppleKaraokeLineWidget(
                                line: line,
                                currentMs: _currentInterpolatedMs,
                                style: widget.style,
                              )
                            else
                              Text(
                                widget.playbackState.title.isNotEmpty
                                    ? widget.playbackState.title
                                    : 'Vynody Desktop Lyrics',
                                textAlign: widget.style.alignment == 'left'
                                    ? TextAlign.left
                                    : TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: widget.style.fontFamily,
                                  fontFamilyFallback: widget.style.fontFamilyFallback ?? _defaultFontFamilyFallback,
                                  fontSize: widget.style.fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Color(widget.style.activeColor),
                                  shadows: const [
                                    Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black),
                                  ],
                                ),
                              ),

                            // 3.2 翻译行（支持长句自动换行）
                            if (hasTranslation) ...[
                              const SizedBox(height: 4),
                              Text(
                                line.translation!.trim(),
                                textAlign: widget.style.alignment == 'left'
                                    ? TextAlign.left
                                    : TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: widget.style.fontFamily,
                                  fontFamilyFallback: widget.style.fontFamilyFallback ?? _defaultFontFamilyFallback,
                                  fontSize: widget.style.translationFontSize,
                                  fontWeight: FontWeight.normal,
                                  color: Color(widget.style.translationColor),
                                  shadows: widget.style.hasShadow
                                      ? const [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 4.0,
                                            color: Color(0xCC000000),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. 顶部浮动控制胶囊条（悬停时淡入，锁定状态下依然可呼出并支持解锁）
          Positioned(
            top: 6,
            child: AnimatedOpacity(
              opacity: _isHovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isHovered,
                child: _buildHoverToolbar(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoverToolbar(BuildContext context) {
    final fontSize = widget.style.fontSize;
    final isMinSize = fontSize <= 16.0;
    final isMaxSize = fontSize >= 56.0;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 拖拽把手（仅在未锁定状态下高亮，锁定状态下变灰禁用）
          GestureDetector(
            onPanStart: (_) {
              if (!widget.isLocked) {
                LyricsNativeWindow.instance.startDragging();
              }
            },
            child: MouseRegion(
              cursor: widget.isLocked ? SystemMouseCursors.basic : SystemMouseCursors.move,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: widget.isLocked
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 上一曲
          _ToolbarButton(
            icon: Icons.skip_previous_rounded,
            tooltip: '上一曲',
            onTap: () => widget.onAction(
              const DesktopLyricsAction(type: DesktopLyricsActionType.previous),
            ),
          ),

          // 播放 / 暂停
          _ToolbarButton(
            icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: _isPlaying ? '暂停' : '播放',
            onTap: () => widget.onAction(
              const DesktopLyricsAction(type: DesktopLyricsActionType.togglePlay),
            ),
          ),

          // 下一曲
          _ToolbarButton(
            icon: Icons.skip_next_rounded,
            tooltip: '下一曲',
            onTap: () => widget.onAction(
              const DesktopLyricsAction(type: DesktopLyricsActionType.next),
            ),
          ),

          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 14,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 4),

          // 缩小字号
          _ToolbarButton(
            icon: Icons.text_decrease_rounded,
            tooltip: isMinSize ? '已达最小字号 (${fontSize.toInt()})' : '缩小字号 (${fontSize.toInt()})',
            color: isMinSize ? Colors.white38 : null,
            onTap: () => widget.onAction(
              const DesktopLyricsAction(type: DesktopLyricsActionType.decreaseFontSize),
            ),
          ),

          // 放大字号
          _ToolbarButton(
            icon: Icons.text_increase_rounded,
            tooltip: isMaxSize ? '已达最大字号 (${fontSize.toInt()})' : '放大字号 (${fontSize.toInt()})',
            color: isMaxSize ? Colors.white38 : null,
            onTap: () => widget.onAction(
              const DesktopLyricsAction(type: DesktopLyricsActionType.increaseFontSize),
            ),
          ),

          // 锁定 / 解锁按钮
          _ToolbarButton(
            icon: widget.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            tooltip: widget.isLocked ? '已锁定位置 (点击解锁)' : '锁定歌词 (固定位置)',
            color: widget.isLocked ? Colors.amberAccent : Colors.white.withValues(alpha: 0.9),
            onTap: () => widget.onAction(
              const DesktopLyricsAction(type: DesktopLyricsActionType.toggleLock),
            ),
          ),

          // 关闭桌面歌词
          _ToolbarButton(
            icon: Icons.close_rounded,
            tooltip: '关闭桌面歌词',
            color: Colors.redAccent.shade100,
            onTap: () => widget.onAction(
              const DesktopLyricsAction(type: DesktopLyricsActionType.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Icon(
            icon,
            size: 16,
            color: color ?? Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

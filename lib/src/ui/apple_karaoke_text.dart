import 'package:flutter/material.dart';
import '../models/lyrics_data.dart';

/// 苹果风格逐字卡拉OK扫光组件
class AppleKaraokeLineWidget extends StatelessWidget {
  final DesktopLyricLine line;
  final int currentMs;
  final DesktopLyricsStyle style;

  const AppleKaraokeLineWidget({
    super.key,
    required this.line,
    required this.currentMs,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Color(style.activeColor);
    final inactiveColor = Color(style.inactiveColor);

    final textStyle = TextStyle(
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback ?? const [
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'PingFang SC',
        'Heiti SC',
        'Noto Sans CJK SC',
        'Noto Sans SC',
        'Source Han Sans SC',
        'sans-serif',
      ],
      fontSize: style.fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
      height: 1.2,
      shadows: style.hasShadow
          ? const [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 6.0,
                color: Color(0xBF000000),
              ),
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2.0,
                color: Color(0xE6000000),
              ),
            ]
          : null,
    );

    final words = line.words;
    if (words == null || words.isEmpty) {
      // 普通非逐字歌词行
      return Text(
        line.text.trim().isEmpty ? '...' : line.text,
        textAlign: style.alignment == 'left' ? TextAlign.left : TextAlign.center,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        style: textStyle.copyWith(color: activeColor),
      );
    }

    // 过滤并处理空格
    final validWords = <DesktopLyricWord>[];
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.text.trim().isEmpty) continue;
      if (validWords.isEmpty) {
        validWords.add(DesktopLyricWord(
          timestampMs: w.timestampMs,
          durationMs: w.durationMs,
          text: w.text.trimLeft(),
        ));
      } else if (w.text.startsWith(RegExp(r'^\s+'))) {
        final last = validWords.removeLast();
        final lastText = last.text.endsWith(' ') ? last.text : '${last.text} ';
        validWords.add(DesktopLyricWord(
          timestampMs: last.timestampMs,
          durationMs: last.durationMs,
          text: lastText,
        ));
        validWords.add(DesktopLyricWord(
          timestampMs: w.timestampMs,
          durationMs: w.durationMs,
          text: w.text.trimLeft(),
        ));
      } else {
        validWords.add(w);
      }
    }

    if (validWords.isEmpty) {
      return Text(
        line.text,
        textAlign: style.alignment == 'left' ? TextAlign.left : TextAlign.center,
        style: textStyle.copyWith(color: activeColor),
      );
    }

    return Wrap(
      alignment: style.alignment == 'left' ? WrapAlignment.start : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: validWords.map((word) {
        final startMs = word.timestampMs;
        final durationMs = word.durationMs;

        double progress = 0.0;
        if (currentMs >= startMs + durationMs) {
          progress = 1.0;
        } else if (currentMs >= startMs && durationMs > 0) {
          progress = (currentMs - startMs) / durationMs;
        }

        return _AppleSingleWordHighlight(
          text: word.text,
          progress: progress,
          style: textStyle,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        );
      }).toList(),
    );
  }
}

class _WordProgressClipper extends CustomClipper<Rect> {
  final double progress;

  const _WordProgressClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);
  }

  @override
  bool shouldReclip(covariant _WordProgressClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

class _AppleSingleWordHighlight extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final Color activeColor;
  final Color inactiveColor;

  const _AppleSingleWordHighlight({
    required this.text,
    required this.progress,
    required this.style,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.0) {
      return Text(
        text,
        style: style.copyWith(color: inactiveColor),
      );
    }

    if (progress >= 1.0) {
      return Text(
        text,
        style: style.copyWith(color: activeColor),
      );
    }

    final cleanStyle = style.copyWith(shadows: const []);

    return Stack(
      children: [
        // 底层：未变亮颜色及正常文字深色阴影，保证文字可读性
        Text(
          text,
          style: style.copyWith(color: inactiveColor),
        ),
        // 上层：已变亮的高亮颜色，按进度裁剪填充，不带阴影以完全去掉发光光晕
        ClipRect(
          clipper: _WordProgressClipper(progress),
          child: Text(
            text,
            style: cleanStyle.copyWith(color: activeColor),
          ),
        ),
      ],
    );
  }
}

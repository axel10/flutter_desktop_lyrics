import 'package:flutter/foundation.dart';

class DesktopLyricWord {
  final int timestampMs;
  final int durationMs;
  final String text;

  const DesktopLyricWord({
    required this.timestampMs,
    required this.durationMs,
    required this.text,
  });

  factory DesktopLyricWord.fromJson(Map<String, dynamic> json) {
    return DesktopLyricWord(
      timestampMs: json['timestampMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'timestampMs': timestampMs,
        'durationMs': durationMs,
        'text': text,
      };
}

class DesktopLyricLine {
  final int timestampMs;
  final String text;
  final String? translation;
  final List<DesktopLyricWord>? words;

  const DesktopLyricLine({
    required this.timestampMs,
    required this.text,
    this.translation,
    this.words,
  });

  bool get isKaraoke => words != null && words!.isNotEmpty;

  factory DesktopLyricLine.fromJson(Map<String, dynamic> json) {
    return DesktopLyricLine(
      timestampMs: json['timestampMs'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String?,
      words: (json['words'] as List<dynamic>?)
          ?.map((e) => DesktopLyricWord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestampMs': timestampMs,
        'text': text,
        if (translation != null) 'translation': translation,
        if (words != null) 'words': words!.map((w) => w.toJson()).toList(),
      };
}

class DesktopPlaybackState {
  final bool isPlaying;
  final int positionMs;
  final int timestampMs;
  final String title;
  final String artist;

  const DesktopPlaybackState({
    required this.isPlaying,
    required this.positionMs,
    required this.timestampMs,
    this.title = '',
    this.artist = '',
  });

  factory DesktopPlaybackState.fromJson(Map<String, dynamic> json) {
    return DesktopPlaybackState(
      isPlaying: json['isPlaying'] as bool? ?? false,
      positionMs: json['positionMs'] as int? ?? 0,
      timestampMs: json['timestampMs'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'timestampMs': timestampMs,
        'title': title,
        'artist': artist,
      };
}

class DesktopLyricsStyle {
  final double fontSize;
  final double translationFontSize;
  final int activeColor;
  final int inactiveColor;
  final int translationColor;
  final bool hasShadow;
  final String alignment; // 'left' or 'center'
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  const DesktopLyricsStyle({
    this.fontSize = 28.0,
    this.translationFontSize = 16.0,
    this.activeColor = 0xFFFFFFFF,
    this.inactiveColor = 0x88FFFFFF,
    this.translationColor = 0xCCEEEEEE,
    this.hasShadow = true,
    this.alignment = 'center',
    this.fontFamily,
    this.fontFamilyFallback,
  });

  DesktopLyricsStyle copyWith({
    double? fontSize,
    double? translationFontSize,
    int? activeColor,
    int? inactiveColor,
    int? translationColor,
    bool? hasShadow,
    String? alignment,
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    return DesktopLyricsStyle(
      fontSize: fontSize ?? this.fontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      translationColor: translationColor ?? this.translationColor,
      hasShadow: hasShadow ?? this.hasShadow,
      alignment: alignment ?? this.alignment,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
    );
  }

  factory DesktopLyricsStyle.fromJson(Map<String, dynamic> json) {
    return DesktopLyricsStyle(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28.0,
      translationFontSize: (json['translationFontSize'] as num?)?.toDouble() ?? 16.0,
      activeColor: json['activeColor'] as int? ?? 0xFFFFFFFF,
      inactiveColor: json['inactiveColor'] as int? ?? 0x88FFFFFF,
      translationColor: json['translationColor'] as int? ?? 0xCCEEEEEE,
      hasShadow: json['hasShadow'] as bool? ?? true,
      alignment: json['alignment'] as String? ?? 'center',
      fontFamily: json['fontFamily'] as String?,
      fontFamilyFallback: (json['fontFamilyFallback'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'translationFontSize': translationFontSize,
        'activeColor': activeColor,
        'inactiveColor': inactiveColor,
        'translationColor': translationColor,
        'hasShadow': hasShadow,
        'alignment': alignment,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontFamilyFallback != null) 'fontFamilyFallback': fontFamilyFallback,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopLyricsStyle &&
          runtimeType == other.runtimeType &&
          fontSize == other.fontSize &&
          translationFontSize == other.translationFontSize &&
          activeColor == other.activeColor &&
          inactiveColor == other.inactiveColor &&
          translationColor == other.translationColor &&
          hasShadow == other.hasShadow &&
          alignment == other.alignment &&
          fontFamily == other.fontFamily &&
          listEquals(fontFamilyFallback, other.fontFamilyFallback);

  @override
  int get hashCode => Object.hash(
        fontSize,
        translationFontSize,
        activeColor,
        inactiveColor,
        translationColor,
        hasShadow,
        alignment,
        fontFamily,
        Object.hashAll(fontFamilyFallback ?? const []),
      );
}

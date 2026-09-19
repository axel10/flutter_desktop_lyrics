enum DesktopLyricsActionType {
  togglePlay,
  next,
  previous,
  toggleLock,
  close,
  increaseFontSize,
  decreaseFontSize,
}

class DesktopLyricsAction {
  final DesktopLyricsActionType type;
  final Map<String, dynamic>? data;

  const DesktopLyricsAction({
    required this.type,
    this.data,
  });

  factory DesktopLyricsAction.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'togglePlay';
    final type = DesktopLyricsActionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => DesktopLyricsActionType.togglePlay,
    );
    return DesktopLyricsAction(
      type: type,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (data != null) 'data': data,
      };
}

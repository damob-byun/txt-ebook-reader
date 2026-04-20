enum TouchZoneStyle {
  leftRight,
  anywhereNext,
  bottomNext,
  lShape,
}

class AppSettings {
  final bool useVolumeKeys;
  final bool useTouchTurn;
  final bool useScrollMode;
  final TouchZoneStyle touchZoneStyle;

  AppSettings({
    this.useVolumeKeys = false,
    this.useTouchTurn = true,
    this.useScrollMode = false,
    this.touchZoneStyle = TouchZoneStyle.leftRight,
  });

  AppSettings copyWith({
    bool? useVolumeKeys,
    bool? useTouchTurn,
    bool? useScrollMode,
    TouchZoneStyle? touchZoneStyle,
  }) {
    return AppSettings(
      useVolumeKeys: useVolumeKeys ?? this.useVolumeKeys,
      useTouchTurn: useTouchTurn ?? this.useTouchTurn,
      useScrollMode: useScrollMode ?? this.useScrollMode,
      touchZoneStyle: touchZoneStyle ?? this.touchZoneStyle,
    );
  }

  Map<String, dynamic> toJson() => {
    'useVolumeKeys': useVolumeKeys,
    'useTouchTurn': useTouchTurn,
    'useScrollMode': useScrollMode,
    'touchZoneStyle': touchZoneStyle.index,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    useVolumeKeys: json['useVolumeKeys'] ?? false,
    useTouchTurn: json['useTouchTurn'] ?? true,
    useScrollMode: json['useScrollMode'] ?? false,
    touchZoneStyle: TouchZoneStyle.values[json['touchZoneStyle'] ?? 0],
  );
}

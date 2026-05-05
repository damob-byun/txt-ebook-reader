enum TouchZoneStyle {
  leftRight,
  anywhereNext,
  bottomNext,
  lShape,
}

class AppSettings {
  final bool useTouchTurn;
  final bool useScrollMode;
  final bool usePageAnimation;
  final TouchZoneStyle touchZoneStyle;

  AppSettings({
    this.useTouchTurn = true,
    this.useScrollMode = false,
    this.usePageAnimation = true,
    this.touchZoneStyle = TouchZoneStyle.leftRight,
  });

  AppSettings copyWith({
    bool? useTouchTurn,
    bool? useScrollMode,
    bool? usePageAnimation,
    TouchZoneStyle? touchZoneStyle,
  }) {
    return AppSettings(
      useTouchTurn: useTouchTurn ?? this.useTouchTurn,
      useScrollMode: useScrollMode ?? this.useScrollMode,
      usePageAnimation: usePageAnimation ?? this.usePageAnimation,
      touchZoneStyle: touchZoneStyle ?? this.touchZoneStyle,
    );
  }

  Map<String, dynamic> toJson() => {
    'useTouchTurn': useTouchTurn,
    'useScrollMode': useScrollMode,
    'usePageAnimation': usePageAnimation,
    'touchZoneStyle': touchZoneStyle.index,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    useTouchTurn: json['useTouchTurn'] ?? true,
    useScrollMode: json['useScrollMode'] ?? false,
    usePageAnimation: json['usePageAnimation'] ?? true,
    touchZoneStyle: TouchZoneStyle.values[json['touchZoneStyle'] ?? 0],
  );
}

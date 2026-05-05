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
  final bool isDarkMode;

  AppSettings({
    this.useTouchTurn = true,
    this.useScrollMode = false,
    this.usePageAnimation = true,
    this.touchZoneStyle = TouchZoneStyle.leftRight,
    this.isDarkMode = false,
  });

  AppSettings copyWith({
    bool? useTouchTurn,
    bool? useScrollMode,
    bool? usePageAnimation,
    TouchZoneStyle? touchZoneStyle,
    bool? isDarkMode,
  }) {
    return AppSettings(
      useTouchTurn: useTouchTurn ?? this.useTouchTurn,
      useScrollMode: useScrollMode ?? this.useScrollMode,
      usePageAnimation: usePageAnimation ?? this.usePageAnimation,
      touchZoneStyle: touchZoneStyle ?? this.touchZoneStyle,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'useTouchTurn': useTouchTurn,
    'useScrollMode': useScrollMode,
    'usePageAnimation': usePageAnimation,
    'touchZoneStyle': touchZoneStyle.index,
    'isDarkMode': isDarkMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    useTouchTurn: json['useTouchTurn'] ?? true,
    useScrollMode: json['useScrollMode'] ?? false,
    usePageAnimation: json['usePageAnimation'] ?? true,
    touchZoneStyle: TouchZoneStyle.values[json['touchZoneStyle'] ?? 0],
    isDarkMode: json['isDarkMode'] ?? false,
  );
}

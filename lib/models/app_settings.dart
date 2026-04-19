class AppSettings {
  final bool useVolumeKeys;
  final bool useTouchTurn;
  final bool useScrollMode;

  AppSettings({
    this.useVolumeKeys = false,
    this.useTouchTurn = true,
    this.useScrollMode = false,
  });

  AppSettings copyWith({
    bool? useVolumeKeys,
    bool? useTouchTurn,
    bool? useScrollMode,
  }) {
    return AppSettings(
      useVolumeKeys: useVolumeKeys ?? this.useVolumeKeys,
      useTouchTurn: useTouchTurn ?? this.useTouchTurn,
      useScrollMode: useScrollMode ?? this.useScrollMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'useVolumeKeys': useVolumeKeys,
    'useTouchTurn': useTouchTurn,
    'useScrollMode': useScrollMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    useVolumeKeys: json['useVolumeKeys'] ?? false,
    useTouchTurn: json['useTouchTurn'] ?? true,
    useScrollMode: json['useScrollMode'] ?? false,
  );
}

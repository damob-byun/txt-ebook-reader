enum ReaderTheme { classic, night, sepia, soft }

class ReaderSettings {
  final double fontSize;
  final String fontFamily;
  final String encoding;
  final ReaderTheme theme;
  final double lineSpacing;
  final double horizontalPadding;
  final double verticalPadding;

  ReaderSettings({
    this.fontSize = 18.0,
    this.fontFamily = 'Georgia',
    this.encoding = 'auto',
    this.theme = ReaderTheme.classic,
    this.lineSpacing = 1.7,
    this.horizontalPadding = 24.0,
    this.verticalPadding = 32.0,
  });

  ReaderSettings copyWith({
    double? fontSize,
    String? fontFamily,
    String? encoding,
    ReaderTheme? theme,
    double? lineSpacing,
    double? horizontalPadding,
    double? verticalPadding,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      encoding: encoding ?? this.encoding,
      theme: theme ?? this.theme,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'encoding': encoding,
    'theme': theme.index,
    'lineSpacing': lineSpacing,
    'horizontalPadding': horizontalPadding,
    'verticalPadding': verticalPadding,
  };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) => ReaderSettings(
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
    fontFamily: json['fontFamily'] ?? 'Georgia',
    encoding: json['encoding'] ?? 'auto',
    theme: ReaderTheme.values[json['theme'] ?? 0],
    lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.7,
    horizontalPadding: (json['horizontalPadding'] as num?)?.toDouble() ?? 24.0,
    verticalPadding: (json['verticalPadding'] as num?)?.toDouble() ?? 32.0,
  );
}

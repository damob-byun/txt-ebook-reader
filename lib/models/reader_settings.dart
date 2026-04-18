enum ReaderTheme {
  classic,
  night,
  sepia,
  soft,
}

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
    this.fontFamily = 'Inter',
    this.encoding = 'auto',
    this.theme = ReaderTheme.classic,
    this.lineSpacing = 1.5,
    this.horizontalPadding = 24.0,
    this.verticalPadding = 32.0,
  });

  ReaderSettings copyWith({
    double? fontSize,
    String? fontFamily,
    String? encoding,
    ReaderTheme? theme,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      encoding: encoding ?? this.encoding,
      theme: theme ?? this.theme,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'encoding': encoding,
        'theme': theme.index,
        'lineSpacing': lineSpacing,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) => ReaderSettings(
        fontSize: json['fontSize']?.toDouble() ?? 18.0,
        fontFamily: json['fontFamily'] ?? 'Inter',
        encoding: json['encoding'] ?? 'auto',
        theme: ReaderTheme.values[json['theme'] ?? 0],
        lineSpacing: json['lineSpacing']?.toDouble() ?? 1.5,
      );
}

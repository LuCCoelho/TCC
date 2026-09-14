import 'dart:convert';

import 'package:flutter/painting.dart';

class FieldStyleConfig {
  const FieldStyleConfig({
    this.label = 'Campo',
    this.fontFamily = 'serif',
    this.fontSize = 14,
    this.color = '#1C140C',
    this.alignment = 'center',
    this.borderColor,
    this.borderWidth = 0,
    this.fontWeight = 'regular',
    this.backgroundColor,
    this.italic = false,
  });

  final String label;
  final String fontFamily;
  final double fontSize;
  final String color;
  final String alignment;
  final String? borderColor;
  final double borderWidth;
  final String fontWeight;
  final String? backgroundColor;
  final bool italic;

  FontWeight get flutterWeight => switch (fontWeight) {
        'bold' => FontWeight.w700,
        'medium' => FontWeight.w500,
        _ => FontWeight.w400,
      };

  TextAlign get textAlign => switch (alignment) {
        'left' => TextAlign.left,
        'right' => TextAlign.right,
        _ => TextAlign.center,
      };

  Alignment get boxAlignment => switch (alignment) {
        'left' => Alignment.centerLeft,
        'right' => Alignment.centerRight,
        _ => Alignment.center,
      };

  Color parseColor(String hex, {Color fallback = const Color(0xFF1C140C)}) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return fallback;
    return Color(int.parse(value, radix: 16));
  }

  Color get foreground => parseColor(color);
  Color? get background =>
      backgroundColor == null ? null : parseColor(backgroundColor!);
  Color? get border =>
      borderColor == null ? null : parseColor(borderColor!, fallback: const Color(0xFF000000));

  FieldStyleConfig copyWith({
    String? label,
    String? fontFamily,
    double? fontSize,
    String? color,
    String? alignment,
    String? borderColor,
    bool clearBorderColor = false,
    double? borderWidth,
    String? fontWeight,
    String? backgroundColor,
    bool clearBackgroundColor = false,
    bool? italic,
  }) {
    return FieldStyleConfig(
      label: label ?? this.label,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      alignment: alignment ?? this.alignment,
      borderColor: clearBorderColor ? null : (borderColor ?? this.borderColor),
      borderWidth: borderWidth ?? this.borderWidth,
      fontWeight: fontWeight ?? this.fontWeight,
      backgroundColor:
          clearBackgroundColor ? null : (backgroundColor ?? this.backgroundColor),
      italic: italic ?? this.italic,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'color': color,
        'alignment': alignment,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
        'fontWeight': fontWeight,
        'backgroundColor': backgroundColor,
        'italic': italic,
      };

  factory FieldStyleConfig.fromJson(String raw) {
    if (raw.isEmpty) return const FieldStyleConfig();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FieldStyleConfig(
        label: map['label'] as String? ?? 'Campo',
        fontFamily: map['fontFamily'] as String? ?? 'serif',
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14,
        color: map['color'] as String? ?? '#1C140C',
        alignment: map['alignment'] as String? ?? 'center',
        borderColor: map['borderColor'] as String?,
        borderWidth: (map['borderWidth'] as num?)?.toDouble() ?? 0,
        fontWeight: map['fontWeight'] as String? ?? 'regular',
        backgroundColor: map['backgroundColor'] as String?,
        italic: map['italic'] as bool? ?? false,
      );
    } catch (_) {
      return const FieldStyleConfig();
    }
  }

  String encode() => jsonEncode(toJson());
}

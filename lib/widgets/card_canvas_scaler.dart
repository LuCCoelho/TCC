import 'package:flutter/widgets.dart';

class CardCanvasScaler {
  static const mmPerInch = 25.4;
  static const referenceDpi = 96.0;

  static Size physicalPx(double widthMm, double heightMm, {double dpi = referenceDpi}) {
    return Size(mmToPx(widthMm, dpi: dpi), mmToPx(heightMm, dpi: dpi));
  }

  static double mmToPx(double mm, {double dpi = referenceDpi}) => mm / mmPerInch * dpi;

  static Size fit(Size available, double widthMm, double heightMm, {double padding = 0}) {
    final maxW = (available.width - padding).clamp(1, double.infinity);
    final maxH = (available.height - padding).clamp(1, double.infinity);
    final aspect = widthMm / heightMm;
    var width = maxW.toDouble();
    var height = width / aspect;
    if (height > maxH) {
      height = maxH.toDouble();
      width = height * aspect;
    }
    return Size(width, height);
  }

  static Rect fieldRect({
    required Size canvasSize,
    required double xPctg,
    required double yPctg,
    required double wPctg,
    required double hPctg,
  }) {
    return Rect.fromLTWH(
      canvasSize.width * xPctg / 100,
      canvasSize.height * yPctg / 100,
      canvasSize.width * wPctg / 100,
      canvasSize.height * hPctg / 100,
    );
  }
}

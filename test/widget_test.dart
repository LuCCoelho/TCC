import 'package:cartas/widgets/card_canvas_scaler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CardCanvasScaler preserva a proporção 63×88', () {
    final fitted = CardCanvasScaler.fit(const Size(630, 880), 63, 88);
    expect(fitted.width / fitted.height, closeTo(63 / 88, 0.001));
  });

  test('percentuais viram retângulo dentro do canvas', () {
    final rect = CardCanvasScaler.fieldRect(
      canvasSize: const Size(100, 200),
      xPctg: 10,
      yPctg: 20,
      wPctg: 50,
      hPctg: 25,
    );
    expect(rect, const Rect.fromLTWH(10, 40, 50, 50));
  });
}

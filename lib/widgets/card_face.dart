import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/db/app_database.dart';
import 'card_canvas_scaler.dart';
import 'field_renderer.dart';

class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.widthMm,
    required this.heightMm,
    required this.fields,
    this.values = const {},
    this.onTapField,
    this.selectedFieldId,
    this.showPlaceholders = true,
    this.printMode = false,
    this.maxSize,
  });

  final double widthMm;
  final double heightMm;
  final List<FieldDefinition> fields;
  final Map<String, FieldValue> values;
  final FieldTap? onTapField;
  final String? selectedFieldId;
  final bool showPlaceholders;
  final bool printMode;
  final Size? maxSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = maxSize ??
            Size(
              constraints.maxWidth.isFinite ? constraints.maxWidth : 300,
              constraints.maxHeight.isFinite ? constraints.maxHeight : 420,
            );
        final canvas = CardCanvasScaler.fit(available, widthMm, heightMm);
        final sorted = [...fields]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return SizedBox(
          width: canvas.width,
          height: canvas.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (printMode) _BleedMarks(size: canvas),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: printMode ? BorderRadius.zero : BorderRadius.circular(8),
                  boxShadow: printMode
                      ? const []
                      : [
                          BoxShadow(
                            color: AppColors.paperShadow.withValues(alpha: 0.55),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                  border: Border.all(color: AppColors.paperBorder.withValues(alpha: 0.7), width: 1.2),
                ),
                child: Stack(
                  children: [
                    for (final field in sorted)
                      FieldRenderer(
                        field: field,
                        value: values[field.id],
                        canvasSize: canvas,
                        onTap: onTapField,
                        showPlaceholder: showPlaceholders,
                        selected: selectedFieldId == field.id,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BleedMarks extends StatelessWidget {
  const _BleedMarks({required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: _CropMarksPainter());
  }
}

class _CropMarksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mist
      ..strokeWidth = 1;
    const mark = 10.0;
    canvas.drawLine(const Offset(-mark, 0), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, -mark), const Offset(0, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width + mark, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, -mark), paint);
    canvas.drawLine(Offset(0, size.height), Offset(-mark, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height + mark), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width + mark, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height + mark), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

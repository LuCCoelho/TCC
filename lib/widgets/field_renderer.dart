import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/db/app_database.dart';
import '../domain/enums.dart';
import '../domain/field_style.dart';
import 'card_canvas_scaler.dart';
import 'image_picker_helper.dart';

typedef FieldTap = void Function(FieldDefinition field);

class FieldRenderer extends StatelessWidget {
  const FieldRenderer({
    super.key,
    required this.field,
    this.value,
    required this.canvasSize,
    this.onTap,
    this.showPlaceholder = true,
    this.interactive = false,
    this.selected = false,
  });

  final FieldDefinition field;
  final FieldValue? value;
  final Size canvasSize;
  final FieldTap? onTap;
  final bool showPlaceholder;
  final bool interactive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final style = FieldStyleConfig.fromJson(field.styleConfig);
    final rect = CardCanvasScaler.fieldRect(
      canvasSize: canvasSize,
      xPctg: field.xPctg,
      yPctg: field.yPctg,
      wPctg: field.wPctg,
      hPctg: field.hPctg,
    );
    final scale = canvasSize.width / 252; // ~63mm at 96dpi
    final type = FieldType.parse(field.type);

    Widget child = switch (type) {
      FieldType.texto => _TextFieldBody(style: style, value: value, scale: scale, showPlaceholder: showPlaceholder),
      FieldType.imagem => _ImageFieldBody(style: style, value: value, showPlaceholder: showPlaceholder),
      FieldType.icone => _IconFieldBody(style: style, value: value, scale: scale, showPlaceholder: showPlaceholder),
    };

    if (style.background != null || (style.borderWidth > 0 && style.border != null)) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          border: style.borderWidth > 0 && style.border != null
              ? Border.all(color: style.border!, width: style.borderWidth * scale.clamp(0.6, 2.2))
              : null,
        ),
        child: child,
      );
    }

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap!(field),
        child: DecoratedBox(
          decoration: selected
              ? BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 1.6),
                )
              : const BoxDecoration(),
          child: IgnorePointer(ignoring: !interactive, child: child),
        ),
      ),
    );
  }
}

class _TextFieldBody extends StatelessWidget {
  const _TextFieldBody({
    required this.style,
    required this.value,
    required this.scale,
    required this.showPlaceholder,
  });

  final FieldStyleConfig style;
  final FieldValue? value;
  final double scale;
  final bool showPlaceholder;

  @override
  Widget build(BuildContext context) {
    final text = value?.testValue?.trim() ?? '';
    final empty = text.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Align(
        alignment: style.boxAlignment,
        child: Text(
          empty ? (showPlaceholder ? style.label : '') : text,
          textAlign: style.textAlign,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: style.fontFamily == 'sans' ? 'sans-serif' : 'serif',
            fontSize: (style.fontSize * scale).clamp(7, 42),
            fontWeight: style.flutterWeight,
            fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
            color: empty ? style.foreground.withValues(alpha: 0.35) : style.foreground,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _ImageFieldBody extends StatelessWidget {
  const _ImageFieldBody({
    required this.style,
    required this.value,
    required this.showPlaceholder,
  });

  final FieldStyleConfig style;
  final FieldValue? value;
  final bool showPlaceholder;

  @override
  Widget build(BuildContext context) {
    final path = value?.imagePath;
    if (path == null || path.isEmpty) {
      if (!showPlaceholder) return const SizedBox.expand();
      return ColoredBox(
        color: AppColors.parchment.withValues(alpha: 0.35),
        child: const Center(
          child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryDeep),
        ),
      );
    }
    if (ImagePickerHelper.isRemote(path)) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const _BrokenImage(),
      );
    }
    if (kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _BrokenImage(),
      );
    }
    return FutureBuilder<File?>(
      future: ImagePickerHelper.resolveLocal(path),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return const _BrokenImage();
        }
        return Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      },
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.inkSoft,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.mist),
      ),
    );
  }
}

class _IconFieldBody extends StatelessWidget {
  const _IconFieldBody({
    required this.style,
    required this.value,
    required this.scale,
    required this.showPlaceholder,
  });

  final FieldStyleConfig style;
  final FieldValue? value;
  final double scale;
  final bool showPlaceholder;

  @override
  Widget build(BuildContext context) {
    final name = value?.testValue ?? '';
    final icon = iconForName(name);
    if (icon == null) {
      if (!showPlaceholder) return const SizedBox.expand();
      return Icon(Icons.star_border, color: style.foreground.withValues(alpha: 0.4), size: 18 * scale);
    }
    return Center(child: Icon(icon, color: style.foreground, size: (22 * scale).clamp(12, 48)));
  }
}

IconData? iconForName(String name) {
  const catalog = <String, IconData>{
    'auto_awesome': Icons.auto_awesome,
    'bolt': Icons.bolt,
    'water': Icons.water_drop,
    'forest': Icons.forest,
    'local_fire_department': Icons.local_fire_department,
    'pets': Icons.pets,
    'castle': Icons.castle,
    'gavel': Icons.gavel,
    'shield': Icons.shield_moon,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'visibility': Icons.visibility,
    'nightlight': Icons.nightlight,
    'menu_book': Icons.menu_book,
  };
  return catalog[name];
}

const kIconCatalog = <String, IconData>{
  'auto_awesome': Icons.auto_awesome,
  'bolt': Icons.bolt,
  'water': Icons.water_drop,
  'forest': Icons.forest,
  'local_fire_department': Icons.local_fire_department,
  'pets': Icons.pets,
  'castle': Icons.castle,
  'gavel': Icons.gavel,
  'shield': Icons.shield_moon,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'visibility': Icons.visibility,
  'nightlight': Icons.nightlight,
  'menu_book': Icons.menu_book,
};

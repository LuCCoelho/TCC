import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../../domain/enums.dart';
import '../../domain/field_style.dart';
import '../../widgets/image_picker_helper.dart';
import '../db/app_database.dart';
import '../repositories/card_repositories.dart';
import '../repositories/content_repositories.dart';

class ExportConfig {
  const ExportConfig({
    this.bleedMm = 3,
    this.dpi = 300,
    this.startIndex = 0,
    this.endIndex,
    this.collectionId,
  });

  final double bleedMm;
  final int dpi;
  final int startIndex;
  final int? endIndex;
  final String? collectionId;

  Map<String, dynamic> toJson() => {
        'bleedMm': bleedMm,
        'dpi': dpi,
        'startIndex': startIndex,
        'endIndex': endIndex,
        'collectionId': collectionId,
      };

  factory ExportConfig.fromJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ExportConfig(
        bleedMm: (map['bleedMm'] as num?)?.toDouble() ?? 3,
        dpi: (map['dpi'] as num?)?.toInt() ?? 300,
        startIndex: (map['startIndex'] as num?)?.toInt() ?? 0,
        endIndex: (map['endIndex'] as num?)?.toInt(),
        collectionId: map['collectionId'] as String?,
      );
    } catch (_) {
      return const ExportConfig();
    }
  }

  String encode() => jsonEncode(toJson());
}

class ExportService {
  ExportService({
    required this.blueprints,
    required this.cards,
    required this.collections,
  });

  final BlueprintRepository blueprints;
  final CardRepository cards;
  final CollectionRepository collections;

  Future<String> exportCollection({
    required Collection collection,
    required ExportFormat format,
    required ExportConfig config,
    void Function(double progress)? onProgress,
  }) async {
    final blueprint = await blueprints.getById(collection.blueprintId);
    if (blueprint == null) {
      throw StateError('Blueprint da coleção não encontrado');
    }
    final fields = await blueprints.fieldsOf(blueprint.id);
    var rows = await cards.listByCollection(collection.id);
    final end = (config.endIndex ?? rows.length).clamp(0, rows.length);
    final start = config.startIndex.clamp(0, end);
    rows = rows.sublist(start, end);

    final payloads = <CardWithValues>[];
    for (var i = 0; i < rows.length; i++) {
      final full = await cards.getWithValues(rows[i].id);
      if (full != null) payloads.add(full);
      onProgress?.call((i + 1) / (rows.length + 1));
    }

    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(dir.path, 'exports'));
    if (!await exportDir.exists()) await exportDir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'naipe-${collection.name}-$stamp.${format.fileExtension}';
    final output = p.join(exportDir.path, filename);

    switch (format) {
      case ExportFormat.pdf:
        await File(output).writeAsBytes(await _pdf(blueprint, fields, payloads, config));
      case ExportFormat.json:
        await File(output).writeAsString(await _json(collection, blueprint, fields, payloads));
      case ExportFormat.xml:
        await File(output).writeAsString(_xml(collection, blueprint, fields, payloads));
      case ExportFormat.tabletopSimulator:
        await File(output).writeAsString(_tts(collection, blueprint, fields, payloads));
    }
    onProgress?.call(1);
    return kIsWeb ? filename : output;
  }

  Future<Uint8List> _pdf(
    Blueprint blueprint,
    List<FieldDefinition> fields,
    List<CardWithValues> payloads,
    ExportConfig config,
  ) async {
    final doc = pw.Document();
    final pageW = PdfPageFormat.mm * (blueprint.cardWidthMm + config.bleedMm * 2);
    final pageH = PdfPageFormat.mm * (blueprint.cardHeightMm + config.bleedMm * 2);
    final format = PdfPageFormat(pageW, pageH, marginAll: 0);

    for (final payload in payloads) {
      final images = <String, pw.ImageProvider>{};
      for (final field in fields) {
        if (FieldType.parse(field.type) != FieldType.imagem) continue;
        final path = payload.values[field.id]?.imagePath;
        if (path == null || path.isEmpty) continue;
        final bytes = await _imageBytes(path);
        if (bytes != null) {
          images[field.id] = pw.MemoryImage(bytes);
        }
      }
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) {
            return pw.Padding(
              padding: pw.EdgeInsets.all(PdfPageFormat.mm * config.bleedMm),
              child: pw.Stack(
                children: [
                  pw.Container(color: PdfColor.fromInt(0xFFF3E6C8)),
                  for (final field in fields)
                    pw.Positioned(
                      left: field.xPctg / 100 * PdfPageFormat.mm * blueprint.cardWidthMm,
                      top: field.yPctg / 100 * PdfPageFormat.mm * blueprint.cardHeightMm,
                      child: pw.SizedBox(
                        width: field.wPctg / 100 * PdfPageFormat.mm * blueprint.cardWidthMm,
                        height: field.hPctg / 100 * PdfPageFormat.mm * blueprint.cardHeightMm,
                        child: _pdfField(field, payload.values[field.id], images[field.id]),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }
    return doc.save();
  }

  pw.Widget _pdfField(FieldDefinition field, FieldValue? value, pw.ImageProvider? image) {
    final type = FieldType.parse(field.type);
    final style = FieldStyleConfig.fromJson(field.styleConfig);
    if (type == FieldType.imagem) {
      if (image == null) return pw.Container(color: PdfColors.grey300);
      return pw.Image(image, fit: pw.BoxFit.cover);
    }
    final text = value?.testValue ?? '';
    return pw.Container(
      alignment: style.alignment == 'left'
          ? pw.Alignment.centerLeft
          : style.alignment == 'right'
              ? pw.Alignment.centerRight
              : pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: style.fontSize,
          color: PdfColor.fromInt(style.foreground.toARGB32()),
        ),
      ),
    );
  }

  Future<String> _json(
    Collection collection,
    Blueprint blueprint,
    List<FieldDefinition> fields,
    List<CardWithValues> payloads,
  ) async {
    return const JsonEncoder.withIndent('  ').convert({
      'collection': collection.name,
      'blueprint': {
        'name': blueprint.name,
        'width_mm': blueprint.cardWidthMm,
        'height_mm': blueprint.cardHeightMm,
      },
      'cards': [
        for (final payload in payloads)
          {
            'id': payload.card.id,
            'sort_order': payload.card.sortOrder,
            'fields': {
              for (final field in fields)
                FieldStyleConfig.fromJson(field.styleConfig).label: {
                  'type': field.type,
                  'text': payload.values[field.id]?.testValue,
                  'image_path': payload.values[field.id]?.imagePath,
                },
            },
          },
      ],
    });
  }

  String _xml(
    Collection collection,
    Blueprint blueprint,
    List<FieldDefinition> fields,
    List<CardWithValues> payloads,
  ) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('collection', nest: () {
      builder.attribute('name', collection.name);
      builder.element('blueprint', nest: () {
        builder.attribute('name', blueprint.name);
        builder.attribute('width_mm', '${blueprint.cardWidthMm}');
        builder.attribute('height_mm', '${blueprint.cardHeightMm}');
      });
      for (final payload in payloads) {
        builder.element('card', nest: () {
          builder.attribute('id', payload.card.id);
          for (final field in fields) {
            builder.element('field', nest: () {
              builder.attribute('label', FieldStyleConfig.fromJson(field.styleConfig).label);
              builder.attribute('type', field.type);
              final value = payload.values[field.id];
              if ((value?.testValue ?? '').isNotEmpty) builder.text(value!.testValue!);
              if ((value?.imagePath ?? '').isNotEmpty) {
                builder.attribute('image_path', value!.imagePath!);
              }
            });
          }
        });
      }
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _tts(
    Collection collection,
    Blueprint blueprint,
    List<FieldDefinition> fields,
    List<CardWithValues> payloads,
  ) {
    return const JsonEncoder.withIndent('  ').convert({
      'SaveName': collection.name,
      'Date': DateTime.now().toIso8601String(),
      'ObjectStates': [
        {
          'Name': 'Deck',
          'Nickname': collection.name,
          'DeckIDs': [for (var i = 0; i < payloads.length; i++) 100 + i],
          'CustomDeck': {
            '1': {
              'FaceURL': 'file://local-export',
              'BackURL': 'file://local-back',
              'NumWidth': 10,
              'NumHeight': 7,
              'BackIsHidden': true,
            },
          },
          'ContainedObjects': [
            for (var i = 0; i < payloads.length; i++)
              {
                'Name': 'Card',
                'Nickname': payloads[i]
                        .values
                        .values
                        .map((value) => value.testValue)
                        .whereType<String>()
                        .where((text) => text.isNotEmpty)
                        .firstOrNull ??
                    'Carta ${i + 1}',
                'CardID': 100 + i,
                'Description': payloads[i]
                    .values
                    .values
                    .map((value) => value.testValue ?? '')
                    .where((text) => text.isNotEmpty)
                    .join('\n'),
              },
          ],
        },
      ],
    });
  }

  Future<Uint8List?> _imageBytes(String path) async {
    if (ImagePickerHelper.isRemote(path)) {
      return null;
    }
    final file = await ImagePickerHelper.resolveLocal(path);
    if (file == null) return null;
    return file.readAsBytes();
  }
}

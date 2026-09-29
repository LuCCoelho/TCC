import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../domain/field_style.dart';
import '../db/app_database.dart';

class SeedData {
  static const userId = 'user-demo-naipe';
  static const projectId = 'project-circulo-de-bruma';
  static const blueprintId = 'blueprint-carta-padrao';
  static const collectionId = 'collection-set-demo';

  static Future<void> ensure(AppDatabase db) async {
    final existing = await db.select(db.users).getSingleOrNull();
    if (existing != null) {
      await _ensureDemoFieldOrder(db);
      return;
    }
    await db.transaction(() async {
      final now = DateTime.now();
      await db.into(db.users).insert(UsersCompanion.insert(
            id: userId,
            email: 'luisa@ufba.br',
            username: 'luisa',
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.projects).insert(ProjectsCompanion.insert(
            id: projectId,
            userId: userId,
            name: 'Círculo de Bruma',
            description: const Value(
              'Set de demonstração com cartas de névoa, maré e cinzas.',
            ),
            createdAt: now.subtract(const Duration(days: 2)),
            updatedAt: now.subtract(const Duration(hours: 5)),
            syncedAt: Value(now.subtract(const Duration(hours: 6))),
          ));
      await db.into(db.blueprints).insert(BlueprintsCompanion.insert(
            id: blueprintId,
            projectId: projectId,
            name: 'Carta padrão 63×88',
            cardWidthMm: 63,
            cardHeightMm: 88,
            updatedAt: now,
          ));

      final fields = _defaultFields(now);
      for (final field in fields) {
        await db.into(db.fieldDefinitions).insert(field);
      }
      await (db.update(db.blueprints)
            ..where((row) => row.id.equals(blueprintId)))
          .write(BlueprintsCompanion(layoutFields: Value(_layoutSnapshot(fields))));

      await db.into(db.collections).insert(CollectionsCompanion.insert(
            id: collectionId,
            projectId: projectId,
            blueprintId: blueprintId,
            name: 'Set de demonstração',
            category: const Value('nevoa'),
            updatedAt: now,
          ));

      await _insertCard(
        db,
        sortOrder: 0,
        values: {
          'name': 'Guardiã da Bruma',
          'cost': '3',
          'type': 'Criatura — Espírito',
          'text': 'Quando entrar, olhe as duas primeiras cartas do seu grimório.',
          'stats': '2/4',
        },
      );
      await _insertCard(
        db,
        sortOrder: 1,
        values: {
          'name': 'Farol Submerso',
          'cost': '2',
          'type': 'Artefato — Local',
          'text': 'No início do seu turno, ganhe 1 de névoa.',
          'stats': '',
        },
      );
      await _insertCard(
        db,
        sortOrder: 2,
        values: {
          'name': 'Corvo de Cinzas',
          'cost': '1',
          'type': 'Criatura — Ave',
          'text': 'Voar. Quando atacar, descarte uma carta e compre uma.',
          'stats': '1/1',
        },
      );
    });
  }

  static List<FieldDefinitionsCompanion> _defaultFields(DateTime now) {
    FieldDefinitionsCompanion field({
      required String id,
      required String type,
      required double x,
      required double y,
      required double w,
      required double h,
      required int order,
      required FieldStyleConfig style,
    }) {
      return FieldDefinitionsCompanion.insert(
        id: id,
        blueprintId: blueprintId,
        type: type,
        xPctg: x,
        yPctg: y,
        wPctg: w,
        hPctg: h,
        styleConfig: Value(style.encode()),
        sortOrder: order,
      );
    }

    return [
      field(
        id: 'field-name',
        type: 'texto',
        x: 6,
        y: 4,
        w: 70,
        h: 8,
        order: 0,
        style: const FieldStyleConfig(
          label: 'Nome',
          fontFamily: 'serif',
          fontSize: 13,
          fontWeight: 'bold',
          alignment: 'left',
          color: '#1C140C',
        ),
      ),
      field(
        id: 'field-cost',
        type: 'texto',
        x: 80,
        y: 4,
        w: 14,
        h: 8,
        order: 3,
        style: const FieldStyleConfig(
          label: 'Custo',
          fontFamily: 'sans',
          fontSize: 14,
          fontWeight: 'bold',
          color: '#F7F1E3',
          backgroundColor: '#3A2A16',
        ),
      ),
      field(
        id: 'field-art',
        type: 'imagem',
        x: 8,
        y: 14,
        w: 84,
        h: 42,
        order: 2,
        style: const FieldStyleConfig(
          label: 'Arte',
          borderColor: '#C4A35A',
          borderWidth: 1.2,
        ),
      ),
      field(
        id: 'field-type',
        type: 'texto',
        x: 8,
        y: 57,
        w: 84,
        h: 6,
        order: 4,
        style: const FieldStyleConfig(
          label: 'Tipo',
          fontFamily: 'serif',
          fontSize: 10,
          fontWeight: 'medium',
          alignment: 'left',
          italic: true,
        ),
      ),
      field(
        id: 'field-text',
        type: 'texto',
        x: 8,
        y: 64,
        w: 84,
        h: 22,
        order: 5,
        style: const FieldStyleConfig(
          label: 'Texto',
          fontFamily: 'serif',
          fontSize: 9,
          alignment: 'left',
          color: '#2A2118',
        ),
      ),
      field(
        id: 'field-stats',
        type: 'texto',
        x: 72,
        y: 87,
        w: 20,
        h: 8,
        order: 6,
        style: const FieldStyleConfig(
          label: 'Poder',
          fontFamily: 'sans',
          fontSize: 12,
          fontWeight: 'bold',
          backgroundColor: '#F7F1E3',
          borderColor: '#3A2A16',
          borderWidth: 0.8,
        ),
      ),
      field(
        id: 'field-icon',
        type: 'icone',
        x: 8,
        y: 87,
        w: 8,
        h: 8,
        order: 1,
        style: const FieldStyleConfig(label: 'Símbolo', color: '#8C2F2B'),
      ),
    ];
  }

  /// Atualiza a ordem do blueprint de demo em bancos já populados
  /// (Nome e Símbolo como os dois primeiros campos da lista).
  static Future<void> _ensureDemoFieldOrder(AppDatabase db) async {
    const orderById = <String, int>{
      'field-name': 0,
      'field-icon': 1,
      'field-art': 2,
      'field-cost': 3,
      'field-type': 4,
      'field-text': 5,
      'field-stats': 6,
    };
    var changed = false;
    for (final entry in orderById.entries) {
      final rows = await (db.update(db.fieldDefinitions)
            ..where((row) => row.id.equals(entry.key)))
          .write(FieldDefinitionsCompanion(sortOrder: Value(entry.value)));
      if (rows > 0) changed = true;
    }
    if (!changed) return;
    final fields = await (db.select(db.fieldDefinitions)
          ..where((row) => row.blueprintId.equals(blueprintId))
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
    if (fields.isEmpty) return;
    await (db.update(db.blueprints)..where((row) => row.id.equals(blueprintId)))
        .write(BlueprintsCompanion(
      layoutFields: Value(jsonEncode([
        for (final field in fields)
          {
            'id': field.id,
            'type': field.type,
            'x_pctg': field.xPctg,
            'y_pctg': field.yPctg,
            'w_pctg': field.wPctg,
            'h_pctg': field.hPctg,
            'style_config': FieldStyleConfig.fromJson(field.styleConfig).toJson(),
            'sort_order': field.sortOrder,
          },
      ])),
      updatedAt: Value(DateTime.now()),
    ));
  }

  static String _layoutSnapshot(List<FieldDefinitionsCompanion> fields) {
    return jsonEncode([
      for (final field in fields)
        {
          'id': field.id.value,
          'type': field.type.value,
          'x_pctg': field.xPctg.value,
          'y_pctg': field.yPctg.value,
          'w_pctg': field.wPctg.value,
          'h_pctg': field.hPctg.value,
          'style_config': FieldStyleConfig.fromJson(field.styleConfig.value).toJson(),
          'sort_order': field.sortOrder.value,
        },
    ]);
  }

  static Future<void> _insertCard(
    AppDatabase db, {
    required int sortOrder,
    required Map<String, String> values,
  }) async {
    final now = DateTime.now();
    final cardId = newId();
    await db.into(db.gameCards).insert(GameCardsCompanion.insert(
          id: cardId,
          collectionId: collectionId,
          blueprintId: blueprintId,
          sortOrder: sortOrder,
          updatedAt: now,
        ));
    final mapping = {
      'name': 'field-name',
      'cost': 'field-cost',
      'type': 'field-type',
      'text': 'field-text',
      'stats': 'field-stats',
    };
    final fields = await (db.select(db.fieldDefinitions)
          ..where((row) => row.blueprintId.equals(blueprintId)))
        .get();
    for (final field in fields) {
      String? text;
      if (field.id == 'field-icon') {
        text = 'auto_awesome';
      } else {
        for (final entry in mapping.entries) {
          if (entry.value == field.id) {
            text = values[entry.key];
          }
        }
      }
      await db.into(db.fieldValues).insert(FieldValuesCompanion.insert(
            id: newId(),
            cardId: cardId,
            fieldDefinitionId: field.id,
            testValue: Value(text),
            updatedAt: now,
          ));
    }
  }
}

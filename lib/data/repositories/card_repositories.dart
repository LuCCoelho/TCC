import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../domain/enums.dart';
import '../db/app_database.dart';
import 'content_repositories.dart';

class CardRepository {
  CardRepository(this._db);
  final AppDatabase _db;

  Future<List<GameCard>> listByCollection(String collectionId) {
    return (_db.select(_db.gameCards)
          ..where((row) =>
              row.collectionId.equals(collectionId) & row.isDeleted.equals(false))
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
  }

  Stream<List<CardWithValues>> watchByCollection(String collectionId) {
    final cardStream = (_db.select(_db.gameCards)
          ..where((row) =>
              row.collectionId.equals(collectionId) & row.isDeleted.equals(false))
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .watch();

    return cardStream.asyncMap((cards) async {
      if (cards.isEmpty) return <CardWithValues>[];
      final values = await (_db.select(_db.fieldValues)
            ..where((row) => row.cardId.isIn(cards.map((card) => card.id))))
          .get();
      final grouped = <String, Map<String, FieldValue>>{};
      for (final value in values) {
        grouped.putIfAbsent(value.cardId, () => {})[value.fieldDefinitionId] =
            value;
      }
      return [
        for (final card in cards)
          CardWithValues(card: card, values: grouped[card.id] ?? {}),
      ];
    });
  }

  Future<CardWithValues?> getWithValues(String cardId) async {
    final card = await (_db.select(_db.gameCards)
          ..where((row) => row.id.equals(cardId)))
        .getSingleOrNull();
    if (card == null) return null;
    final values = await (_db.select(_db.fieldValues)
          ..where((row) => row.cardId.equals(cardId)))
        .get();
    return CardWithValues(
      card: card,
      values: {for (final value in values) value.fieldDefinitionId: value},
    );
  }

  Future<GameCard> createEmpty({
    required String collectionId,
    required String blueprintId,
  }) {
    return _db.transaction(() async {
      final existing = await listByCollection(collectionId);
      final nextOrder =
          existing.isEmpty ? 0 : existing.map((card) => card.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      final now = DateTime.now();
      final card = GameCardsCompanion.insert(
        id: newId(),
        collectionId: collectionId,
        blueprintId: blueprintId,
        sortOrder: nextOrder,
        updatedAt: now,
      );
      await _db.into(_db.gameCards).insert(card);
      final fields = await (_db.select(_db.fieldDefinitions)
            ..where((row) => row.blueprintId.equals(blueprintId)))
          .get();
      for (final field in fields) {
        await _db.into(_db.fieldValues).insert(FieldValuesCompanion.insert(
              id: newId(),
              cardId: card.id.value,
              fieldDefinitionId: field.id,
              updatedAt: now,
            ));
      }
      return (await (_db.select(_db.gameCards)
            ..where((row) => row.id.equals(card.id.value)))
          .getSingle());
    });
  }

  Future<GameCard> duplicate(String cardId) {
    return _db.transaction(() async {
      final source = await getWithValues(cardId);
      if (source == null) {
        throw StateError('Carta não encontrada');
      }
      final copy = await createEmpty(
        collectionId: source.card.collectionId,
        blueprintId: source.card.blueprintId,
      );
      for (final entry in source.values.entries) {
        await upsertValue(
          cardId: copy.id,
          fieldDefinitionId: entry.key,
          testValue: entry.value.testValue,
          imagePath: entry.value.imagePath,
        );
      }
      return copy;
    });
  }

  Future<void> softDelete(String cardId) {
    return (_db.update(_db.gameCards)..where((row) => row.id.equals(cardId)))
        .write(GameCardsCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> reorder(String collectionId, List<String> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.gameCards)
              ..where((row) => row.id.equals(orderedIds[i])))
            .write(GameCardsCompanion(
          sortOrder: Value(i),
          updatedAt: Value(DateTime.now()),
        ));
      }
    });
  }

  Future<void> upsertValue({
    required String cardId,
    required String fieldDefinitionId,
    String? testValue,
    String? imagePath,
  }) async {
    final existing = await (_db.select(_db.fieldValues)
          ..where((row) =>
              row.cardId.equals(cardId) &
              row.fieldDefinitionId.equals(fieldDefinitionId)))
        .getSingleOrNull();
    final now = DateTime.now();
    if (existing == null) {
      await _db.into(_db.fieldValues).insert(FieldValuesCompanion.insert(
            id: newId(),
            cardId: cardId,
            fieldDefinitionId: fieldDefinitionId,
            testValue: Value(testValue),
            imagePath: Value(imagePath),
            updatedAt: now,
          ));
    } else {
      await (_db.update(_db.fieldValues)
            ..where((row) => row.id.equals(existing.id)))
          .write(FieldValuesCompanion(
        testValue: Value(testValue),
        imagePath: Value(imagePath),
        updatedAt: Value(now),
      ));
    }
    await (_db.update(_db.gameCards)..where((row) => row.id.equals(cardId)))
        .write(GameCardsCompanion(updatedAt: Value(now)));
  }

  Future<void> batchApply({
    required List<String> cardIds,
    required String fieldDefinitionId,
    String? testValue,
    String? imagePath,
  }) {
    return _db.transaction(() async {
      for (final cardId in cardIds) {
        await upsertValue(
          cardId: cardId,
          fieldDefinitionId: fieldDefinitionId,
          testValue: testValue,
          imagePath: imagePath,
        );
      }
    });
  }

  Future<Map<String, FieldValue>> snapshotValues(List<String> cardIds) async {
    if (cardIds.isEmpty) return {};
    final values = await (_db.select(_db.fieldValues)
          ..where((row) => row.cardId.isIn(cardIds)))
        .get();
    return {for (final value in values) value.id: value};
  }

  Future<GameCard> insertImported({
    required String collectionId,
    required String blueprintId,
    required int sortOrder,
    required Map<String, ({String? text, String? image})> fieldPayload,
  }) {
    return _db.transaction(() async {
      final now = DateTime.now();
      final card = GameCardsCompanion.insert(
        id: newId(),
        collectionId: collectionId,
        blueprintId: blueprintId,
        sortOrder: sortOrder,
        updatedAt: now,
      );
      await _db.into(_db.gameCards).insert(card);
      for (final entry in fieldPayload.entries) {
        await _db.into(_db.fieldValues).insert(FieldValuesCompanion.insert(
              id: newId(),
              cardId: card.id.value,
              fieldDefinitionId: entry.key,
              testValue: Value(entry.value.text),
              imagePath: Value(entry.value.image),
              updatedAt: now,
            ));
      }
      return (await (_db.select(_db.gameCards)
            ..where((row) => row.id.equals(card.id.value)))
          .getSingle());
    });
  }
}

class ExportJobRepository {
  ExportJobRepository(this._db);
  final AppDatabase _db;

  Stream<List<ExportJob>> watchByProject(String projectId) {
    return (_db.select(_db.exportJobs)
          ..where((row) => row.projectId.equals(projectId))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Future<ExportJob> create({
    required String projectId,
    required ExportFormat format,
    required String exportConfig,
  }) async {
    final companion = ExportJobsCompanion.insert(
      id: newId(),
      projectId: projectId,
      format: format.name,
      status: ExportJobStatus.pending.name,
      exportConfig: Value(exportConfig),
      createdAt: DateTime.now(),
    );
    await _db.into(_db.exportJobs).insert(companion);
    return (await (_db.select(_db.exportJobs)
          ..where((row) => row.id.equals(companion.id.value)))
        .getSingle());
  }

  Future<void> updateStatus(
    String id, {
    required ExportJobStatus status,
    String? outputPath,
  }) {
    return (_db.update(_db.exportJobs)..where((row) => row.id.equals(id))).write(
      ExportJobsCompanion(
        status: Value(status.name),
        outputPath: outputPath == null ? const Value.absent() : Value(outputPath),
      ),
    );
  }
}

class ChangeLogRepository {
  ChangeLogRepository(this._db);
  final AppDatabase _db;

  Stream<List<ChangeLog>> watchByProject(String projectId) {
    return (_db.select(_db.changeLogs)
          ..where((row) => row.projectId.equals(projectId))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Future<void> append({
    required String projectId,
    required String entityType,
    required String entityId,
    required String action,
    required String snapshotJson,
    required String summary,
  }) {
    return _db.into(_db.changeLogs).insert(ChangeLogsCompanion.insert(
          id: newId(),
          projectId: projectId,
          entityType: entityType,
          entityId: entityId,
          action: action,
          snapshotJson: snapshotJson,
          summary: summary,
          createdAt: DateTime.now(),
        ));
  }

  Future<ChangeLog?> getById(String id) {
    return (_db.select(_db.changeLogs)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }
}

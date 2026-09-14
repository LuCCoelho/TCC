import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../domain/field_style.dart';
import '../db/app_database.dart';

class CardWithValues {
  const CardWithValues({required this.card, required this.values});

  final GameCard card;
  final Map<String, FieldValue> values;
}

class UserRepository {
  UserRepository(this._db);
  final AppDatabase _db;

  Future<User?> current() =>
      _db.select(_db.users).getSingleOrNull();

  Future<void> updateProfile({required String username, required String email}) {
    return _db.transaction(() async {
      final user = await current();
      if (user == null) return;
      await (_db.update(_db.users)..where((row) => row.id.equals(user.id)))
          .write(UsersCompanion(
        username: Value(username),
        email: Value(email),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }
}

class ProjectRepository {
  ProjectRepository(this._db);
  final AppDatabase _db;

  Stream<List<Project>> watchAll() {
    return (_db.select(_db.projects)
          ..where((row) => row.isDeleted.equals(false))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
        .watch();
  }

  Future<Project?> getById(String id) {
    return (_db.select(_db.projects)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Project> create({
    required String userId,
    required String name,
    String description = '',
  }) async {
    final now = DateTime.now();
    final project = ProjectsCompanion.insert(
      id: newId(),
      userId: userId,
      name: name,
      description: Value(description),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.projects).insert(project);
    return (await getById(project.id.value))!;
  }

  Future<void> rename(String id, {required String name, String? description}) {
    return (_db.update(_db.projects)..where((row) => row.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(name),
        description: description == null ? const Value.absent() : Value(description),
        updatedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ),
    );
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.projects)..where((row) => row.id.equals(id))).write(
      ProjectsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ),
    );
  }

  Future<int> pendingCount() async {
    final rows = await (_db.select(_db.projects)
          ..where((row) => row.isDeleted.equals(false)))
        .get();
    return rows.where((row) => row.syncedAt == null || row.updatedAt.isAfter(row.syncedAt!)).length;
  }

  Future<void> markAllSynced() async {
    final now = DateTime.now();
    await _db.update(_db.projects).write(ProjectsCompanion(syncedAt: Value(now)));
  }
}

class BlueprintRepository {
  BlueprintRepository(this._db);
  final AppDatabase _db;

  Stream<List<Blueprint>> watchByProject(String projectId) {
    return (_db.select(_db.blueprints)
          ..where((row) =>
              row.projectId.equals(projectId) & row.isDeleted.equals(false))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
        .watch();
  }

  Stream<List<Blueprint>> watchAll() {
    return (_db.select(_db.blueprints)
          ..where((row) => row.isDeleted.equals(false))
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .watch();
  }

  Future<Blueprint?> getById(String id) {
    return (_db.select(_db.blueprints)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<FieldDefinition>> fieldsOf(String blueprintId) {
    return (_db.select(_db.fieldDefinitions)
          ..where((row) => row.blueprintId.equals(blueprintId))
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
  }

  Stream<List<FieldDefinition>> watchFields(String blueprintId) {
    return (_db.select(_db.fieldDefinitions)
          ..where((row) => row.blueprintId.equals(blueprintId))
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .watch();
  }

  Future<Blueprint> create({
    required String projectId,
    required String name,
    required double widthMm,
    required double heightMm,
  }) async {
    final now = DateTime.now();
    final companion = BlueprintsCompanion.insert(
      id: newId(),
      projectId: projectId,
      name: name,
      cardWidthMm: widthMm,
      cardHeightMm: heightMm,
      updatedAt: now,
    );
    await _db.into(_db.blueprints).insert(companion);
    return (await getById(companion.id.value))!;
  }

  Future<void> saveLayout({
    required Blueprint blueprint,
    required List<FieldDefinition> fields,
  }) {
    return _db.transaction(() async {
      final existing = await fieldsOf(blueprint.id);
      final incomingIds = fields.map((field) => field.id).toSet();
      for (final old in existing) {
        if (!incomingIds.contains(old.id)) {
          await (_db.delete(_db.fieldDefinitions)
                ..where((row) => row.id.equals(old.id)))
              .go();
        }
      }
      for (final field in fields) {
        await _db.into(_db.fieldDefinitions).insertOnConflictUpdate(
              FieldDefinitionsCompanion(
                id: Value(field.id),
                blueprintId: Value(blueprint.id),
                type: Value(field.type),
                xPctg: Value(field.xPctg),
                yPctg: Value(field.yPctg),
                wPctg: Value(field.wPctg),
                hPctg: Value(field.hPctg),
                styleConfig: Value(field.styleConfig),
                sortOrder: Value(field.sortOrder),
              ),
            );
      }
      await (_db.update(_db.blueprints)
            ..where((row) => row.id.equals(blueprint.id)))
          .write(BlueprintsCompanion(
        name: Value(blueprint.name),
        cardWidthMm: Value(blueprint.cardWidthMm),
        cardHeightMm: Value(blueprint.cardHeightMm),
        layoutFields: Value(_snapshot(fields)),
        updatedAt: Value(DateTime.now()),
      ));
      await (_db.update(_db.projects)
            ..where((row) => row.id.equals(blueprint.projectId)))
          .write(ProjectsCompanion(
        updatedAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ));
    });
  }

  Future<Blueprint> duplicate(String blueprintId, {String? projectId, String? name}) async {
    final source = await getById(blueprintId);
    if (source == null) {
      throw StateError('Blueprint não encontrado');
    }
    final fields = await fieldsOf(blueprintId);
    final copy = await create(
      projectId: projectId ?? source.projectId,
      name: name ?? '${source.name} (cópia)',
      widthMm: source.cardWidthMm,
      heightMm: source.cardHeightMm,
    );
    final remapped = <FieldDefinition>[];
    for (final field in fields) {
      remapped.add(field.copyWith(id: newId(), blueprintId: copy.id));
    }
    await saveLayout(blueprint: copy, fields: remapped);
    return (await getById(copy.id))!;
  }

  Future<void> rename(String id, String name) {
    return (_db.update(_db.blueprints)..where((row) => row.id.equals(id))).write(
      BlueprintsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.blueprints)..where((row) => row.id.equals(id))).write(
      BlueprintsCompanion(isDeleted: const Value(true), updatedAt: Value(DateTime.now())),
    );
  }

  Future<int> incompatibleValueCount(String fieldId, String newType) async {
    final values = await (_db.select(_db.fieldValues)
          ..where((row) => row.fieldDefinitionId.equals(fieldId)))
        .get();
    return values.where((value) {
      if (newType == 'texto' || newType == 'icone') {
        return (value.imagePath ?? '').isNotEmpty && (value.testValue ?? '').isEmpty;
      }
      return (value.testValue ?? '').isNotEmpty && (value.imagePath ?? '').isEmpty;
    }).length;
  }

  String _snapshot(List<FieldDefinition> fields) {
    return jsonEncode(fields
        .map((field) => {
              'id': field.id,
              'type': field.type,
              'x_pctg': field.xPctg,
              'y_pctg': field.yPctg,
              'w_pctg': field.wPctg,
              'h_pctg': field.hPctg,
              'style_config': FieldStyleConfig.fromJson(field.styleConfig).toJson(),
              'sort_order': field.sortOrder,
            })
        .toList());
  }
}

class CollectionRepository {
  CollectionRepository(this._db);
  final AppDatabase _db;

  Stream<List<Collection>> watchByProject(String projectId) {
    return (_db.select(_db.collections)
          ..where((row) =>
              row.projectId.equals(projectId) & row.isDeleted.equals(false))
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .watch();
  }

  Future<Collection?> getById(String id) {
    return (_db.select(_db.collections)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Collection> create({
    required String projectId,
    required String blueprintId,
    required String name,
    String category = 'default',
  }) async {
    final companion = CollectionsCompanion.insert(
      id: newId(),
      projectId: projectId,
      blueprintId: blueprintId,
      name: name,
      category: Value(category),
      updatedAt: DateTime.now(),
    );
    await _db.into(_db.collections).insert(companion);
    return (await getById(companion.id.value))!;
  }

  Future<void> update(String id, {required String name, required String category}) {
    return (_db.update(_db.collections)..where((row) => row.id.equals(id))).write(
      CollectionsCompanion(
        name: Value(name),
        category: Value(category),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.collections)..where((row) => row.id.equals(id))).write(
      CollectionsCompanion(isDeleted: const Value(true), updatedAt: Value(DateTime.now())),
    );
  }
}

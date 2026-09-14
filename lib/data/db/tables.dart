import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get username => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Blueprints extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get name => text()();
  RealColumn get cardWidthMm => real()();
  RealColumn get cardHeightMm => real()();
  TextColumn get layoutFields => text().withDefault(const Constant('[]'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get blueprintId => text().references(Blueprints, #id)();
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('default'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GameCard')
class GameCards extends Table {
  @override
  String get tableName => 'cards';

  TextColumn get id => text()();
  TextColumn get collectionId => text().references(Collections, #id)();
  TextColumn get blueprintId => text().references(Blueprints, #id)();
  IntColumn get sortOrder => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FieldDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get blueprintId => text().references(Blueprints, #id)();
  TextColumn get type => text()();
  RealColumn get xPctg => real()();
  RealColumn get yPctg => real()();
  RealColumn get wPctg => real()();
  RealColumn get hPctg => real()();
  TextColumn get styleConfig => text().withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FieldValues extends Table {
  TextColumn get id => text()();
  TextColumn get cardId => text().references(GameCards, #id)();
  TextColumn get fieldDefinitionId => text().references(FieldDefinitions, #id)();
  TextColumn get imagePath => text().nullable()();
  TextColumn get testValue => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ExportJobs extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get format => text()();
  TextColumn get status => text()();
  TextColumn get outputPath => text().nullable()();
  TextColumn get exportConfig => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ajuste de schema pedido pela tela de histórico (Fase 4.12).
class ChangeLogs extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get snapshotJson => text()();
  TextColumn get summary => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

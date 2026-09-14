import 'package:cartas/data/db/app_database.dart';
import 'package:cartas/data/repositories/content_repositories.dart';
import 'package:cartas/data/seed/seed_data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed cria projeto, blueprint e cartas', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SeedData.ensure(db);

    final projects = ProjectRepository(db);
    final list = await projects.watchAll().first;
    expect(list, isNotEmpty);
    expect(list.first.name, 'Círculo de Bruma');

    final blueprints = BlueprintRepository(db);
    final models = await blueprints.watchByProject(list.first.id).first;
    expect(models, isNotEmpty);
    final fields = await blueprints.fieldsOf(models.first.id);
    expect(fields.length, greaterThanOrEqualTo(5));
  });
}

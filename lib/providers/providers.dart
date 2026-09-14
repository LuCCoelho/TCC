import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/app_database.dart';
import '../data/repositories/card_repositories.dart';
import '../data/repositories/content_repositories.dart';
import '../data/sync/sync_repository.dart';
import '../domain/sync_state.dart';
import '../domain/enums.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider deve ser sobrescrito no main');
});

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider deve ser sobrescrito no main');
});

final userRepositoryProvider = Provider((ref) => UserRepository(ref.watch(databaseProvider)));
final projectRepositoryProvider = Provider((ref) => ProjectRepository(ref.watch(databaseProvider)));
final blueprintRepositoryProvider = Provider((ref) => BlueprintRepository(ref.watch(databaseProvider)));
final collectionRepositoryProvider = Provider((ref) => CollectionRepository(ref.watch(databaseProvider)));
final cardRepositoryProvider = Provider((ref) => CardRepository(ref.watch(databaseProvider)));
final exportRepositoryProvider = Provider((ref) => ExportJobRepository(ref.watch(databaseProvider)));
final changeLogRepositoryProvider = Provider((ref) => ChangeLogRepository(ref.watch(databaseProvider)));

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final repo = LocalSyncRepository(ref.watch(projectRepositoryProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final syncStateProvider = StreamProvider<SyncState>((ref) {
  return ref.watch(syncRepositoryProvider).watch();
});

final currentUserProvider = FutureProvider((ref) {
  return ref.watch(userRepositoryProvider).current();
});

final projectsProvider = StreamProvider((ref) {
  return ref.watch(projectRepositoryProvider).watchAll();
});

final blueprintsProvider = StreamProvider.family((ref, String projectId) {
  return ref.watch(blueprintRepositoryProvider).watchByProject(projectId);
});

final allBlueprintsProvider = StreamProvider((ref) {
  return ref.watch(blueprintRepositoryProvider).watchAll();
});

final collectionsProvider = StreamProvider.family((ref, String projectId) {
  return ref.watch(collectionRepositoryProvider).watchByProject(projectId);
});

final blueprintFieldsProvider = StreamProvider.family((ref, String blueprintId) {
  return ref.watch(blueprintRepositoryProvider).watchFields(blueprintId);
});

final collectionCardsProvider = StreamProvider.family((ref, String collectionId) {
  return ref.watch(cardRepositoryProvider).watchByCollection(collectionId);
});

final exportJobsProvider = StreamProvider.family((ref, String projectId) {
  return ref.watch(exportRepositoryProvider).watchByProject(projectId);
});

final changeLogsProvider = StreamProvider.family((ref, String projectId) {
  return ref.watch(changeLogRepositoryProvider).watchByProject(projectId);
});

final onboardingDoneProvider = StateProvider<bool>((ref) {
  return ref.watch(prefsProvider).getBool('onboarding_complete') ?? false;
});

SyncPhase projectSyncPhase(DateTime updatedAt, DateTime? syncedAt, SyncState global) {
  if (global.offlineMode || !global.isOnline) return SyncPhase.offline;
  if (syncedAt == null || updatedAt.isAfter(syncedAt)) return SyncPhase.pending;
  return SyncPhase.synced;
}

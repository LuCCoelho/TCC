import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/enums.dart';
import '../../domain/sync_state.dart';
import '../repositories/content_repositories.dart';

/// Abstração de sincronização. A implementação concreta (Firebase, REST, etc.)
/// pode substituir [LocalSyncRepository] sem mudar as telas.
abstract class SyncRepository {
  Stream<SyncState> watch();
  SyncState get current;
  Future<void> syncNow();
  Future<void> setOfflineMode(bool enabled);
}

class LocalSyncRepository implements SyncRepository {
  LocalSyncRepository(this._projects) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((item) => item != ConnectivityResult.none);
      _emit(_current.copyWith(isOnline: online, phase: _derivePhase(online: online)));
    });
    unawaited(_primeConnectivity());
  }

  final ProjectRepository _projects;
  final _controller = StreamController<SyncState>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  SyncState _current = const SyncState(phase: SyncPhase.pending);

  @override
  SyncState get current => _current;

  @override
  Stream<SyncState> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  Future<void> _primeConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final online = results.any((item) => item != ConnectivityResult.none);
    final pending = await _projects.pendingCount();
    _emit(_current.copyWith(
      isOnline: online,
      pendingCount: pending,
      phase: _derivePhase(online: online, pending: pending),
    ));
  }

  SyncPhase _derivePhase({bool? online, int? pending}) {
    final isOnline = online ?? _current.isOnline;
    final pendingCount = pending ?? _current.pendingCount;
    if (_current.offlineMode || !isOnline) return SyncPhase.offline;
    if (_current.phase == SyncPhase.syncing) return SyncPhase.syncing;
    if (_current.phase == SyncPhase.error) return SyncPhase.error;
    if (pendingCount > 0) return SyncPhase.pending;
    return SyncPhase.synced;
  }

  void _emit(SyncState next) {
    _current = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  @override
  Future<void> setOfflineMode(bool enabled) async {
    final pending = await _projects.pendingCount();
    _emit(_current.copyWith(
      offlineMode: enabled,
      pendingCount: pending,
      phase: enabled
          ? SyncPhase.offline
          : _derivePhase(online: _current.isOnline, pending: pending),
      message: enabled ? 'Modo offline ativado. Os dados locais continuam disponíveis.' : null,
      clearMessage: !enabled,
    ));
  }

  @override
  Future<void> syncNow() async {
    final pending = await _projects.pendingCount();
    if (_current.offlineMode) {
      _emit(_current.copyWith(
        phase: SyncPhase.offline,
        pendingCount: pending,
        message: 'Sincronização pausada: o modo offline está ativo.',
        lastAttempt: DateTime.now(),
      ));
      return;
    }
    if (!_current.isOnline) {
      _emit(_current.copyWith(
        phase: SyncPhase.offline,
        pendingCount: pending,
        message: 'Sem conexão. Exibindo dados locais.',
        lastAttempt: DateTime.now(),
      ));
      return;
    }

    _emit(_current.copyWith(
      phase: SyncPhase.syncing,
      message: 'Enviando alterações pendentes…',
      lastAttempt: DateTime.now(),
    ));

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _projects.markAllSynced();
      _emit(_current.copyWith(
        phase: SyncPhase.synced,
        pendingCount: 0,
        message: 'Tudo sincronizado.',
        lastAttempt: DateTime.now(),
      ));
    } catch (error) {
      _emit(_current.copyWith(
        phase: SyncPhase.error,
        pendingCount: pending,
        message: 'Falha ao sincronizar: $error',
        lastAttempt: DateTime.now(),
      ));
    }
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _controller.close();
  }
}

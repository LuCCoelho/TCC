import 'enums.dart';

class SyncState {
  const SyncState({
    required this.phase,
    this.message,
    this.lastAttempt,
    this.offlineMode = false,
    this.isOnline = true,
    this.pendingCount = 0,
  });

  final SyncPhase phase;
  final String? message;
  final DateTime? lastAttempt;
  final bool offlineMode;
  final bool isOnline;
  final int pendingCount;

  SyncState copyWith({
    SyncPhase? phase,
    String? message,
    bool clearMessage = false,
    DateTime? lastAttempt,
    bool? offlineMode,
    bool? isOnline,
    int? pendingCount,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      message: clearMessage ? null : (message ?? this.message),
      lastAttempt: lastAttempt ?? this.lastAttempt,
      offlineMode: offlineMode ?? this.offlineMode,
      isOnline: isOnline ?? this.isOnline,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

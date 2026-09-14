import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../domain/enums.dart';
import '../domain/sync_state.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.state, this.compact = false});

  final SyncState state;
  final bool compact;

  Color get _color => switch (state.phase) {
        SyncPhase.synced => AppColors.success,
        SyncPhase.pending => AppColors.warning,
        SyncPhase.syncing => AppColors.gold,
        SyncPhase.offline => AppColors.mist,
        SyncPhase.error => AppColors.danger,
      };

  IconData get _icon => switch (state.phase) {
        SyncPhase.synced => Icons.cloud_done_outlined,
        SyncPhase.pending => Icons.cloud_queue_outlined,
        SyncPhase.syncing => Icons.sync,
        SyncPhase.offline => Icons.cloud_off_outlined,
        SyncPhase.error => Icons.cloud_off,
      };

  @override
  Widget build(BuildContext context) {
    final label = compact ? state.phase.label : (state.message ?? state.phase.label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 16, color: _color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _color),
            ),
          ),
        ],
      ),
    );
  }
}

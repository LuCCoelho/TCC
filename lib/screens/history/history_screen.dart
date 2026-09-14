import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(changeLogsProvider(projectId));
    final format = DateFormat("d/MM HH:mm", 'pt_BR');
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'Nenhuma alteração registrada',
              message:
                  'Salvar blueprints, editar em lote e importar CSV geram entradas neste log. O rollback restaura o snapshot gravado.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.hairline),
                ),
                tileColor: AppColors.inkElevated,
                title: Text(item.summary),
                subtitle: Text('${item.action} · ${format.format(item.createdAt)}'),
                trailing: TextButton(
                  onPressed: () => _rollback(context, ref, item),
                  child: const Text('Rollback'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _rollback(BuildContext context, WidgetRef ref, ChangeLog log) async {
    final ok = await confirmAction(
      context,
      title: 'Restaurar snapshot?',
      message: 'O rollback aplica o estado gravado nesta entrada. Alterações posteriores no mesmo alvo podem ser perdidas.',
      confirmLabel: 'Restaurar',
      destructive: true,
    );
    if (!ok) return;

    if (log.entityType == 'blueprint') {
      final repo = ref.read(blueprintRepositoryProvider);
      final blueprint = await repo.getById(log.entityId);
      if (blueprint == null) return;
      try {
        final raw = jsonDecode(log.snapshotJson);
        if (raw is List) {
          final fields = raw.map((item) {
            final map = item as Map<String, dynamic>;
            return FieldDefinition(
              id: map['id'] as String,
              blueprintId: blueprint.id,
              type: map['type'] as String? ?? 'texto',
              xPctg: (map['x_pctg'] as num?)?.toDouble() ?? 0,
              yPctg: (map['y_pctg'] as num?)?.toDouble() ?? 0,
              wPctg: (map['w_pctg'] as num?)?.toDouble() ?? 20,
              hPctg: (map['h_pctg'] as num?)?.toDouble() ?? 10,
              styleConfig: jsonEncode(map['style_config'] ?? {}),
              sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
            );
          }).toList();
          await repo.saveLayout(blueprint: blueprint, fields: fields);
        }
      } catch (_) {
        // snapshot antigo pode ser só o JSON do layout_fields em formato livre
      }
    } else if (log.entityType == 'batch') {
      final cardRepo = ref.read(cardRepositoryProvider);
      for (final line in log.snapshotJson.split('\n')) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|');
        if (parts.length < 5) continue;
        await cardRepo.upsertValue(
          cardId: parts[1],
          fieldDefinitionId: parts[2],
          testValue: parts[3].isEmpty ? null : parts[3],
          imagePath: parts[4].isEmpty ? null : parts[4],
        );
      }
    }

    await ref.read(changeLogRepositoryProvider).append(
          projectId: projectId,
          entityType: log.entityType,
          entityId: log.entityId,
          action: 'rollback',
          snapshotJson: log.snapshotJson,
          summary: 'Rollback de "${log.summary}"',
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Snapshot restaurado.')));
    }
  }
}

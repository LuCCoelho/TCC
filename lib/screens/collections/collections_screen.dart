import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

const kCategories = {
  'default': ('Padrão', AppColors.primary),
  'nevoa': ('Névoa', Color(0xFF7F9BB8)),
  'fogo': ('Fogo', AppColors.danger),
  'floresta': ('Floresta', AppColors.success),
  'maré': ('Maré', Color(0xFF5B8CDE)),
};

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider(projectId));
    final blueprints = ref.watch(blueprintsProvider(projectId));
    return Scaffold(
      appBar: AppBar(title: const Text('Coleções')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, blueprints.asData?.value ?? []),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Nova coleção'),
      ),
      body: collections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.folder_copy_outlined,
              title: 'Nenhuma coleção',
              message: 'Pastas agrupam cartas que compartilham o mesmo blueprint.',
              actionLabel: 'Criar coleção',
              onAction: () => _edit(context, ref, blueprints.asData?.value ?? []),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final category = kCategories[item.category] ?? kCategories['default']!;
              return ListTile(
                onTap: () => context.push('/project/$projectId/collection/${item.id}'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.hairline),
                ),
                tileColor: AppColors.inkElevated,
                leading: CircleAvatar(backgroundColor: category.$2.withValues(alpha: 0.3), child: Icon(Icons.folder, color: category.$2)),
                title: Text(item.name),
                subtitle: Text(category.$1),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _edit(context, ref, blueprints.asData?.value ?? [], existing: item);
                    } else if (value == 'delete') {
                      final ok = await confirmAction(
                        context,
                        title: 'Excluir coleção?',
                        message: 'As cartas ficam ocultas (exclusão suave).',
                        confirmLabel: 'Excluir',
                        destructive: true,
                      );
                      if (ok) await ref.read(collectionRepositoryProvider).softDelete(item.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Renomear')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    List<Blueprint> blueprints, {
    Collection? existing,
  }) async {
    if (blueprints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crie um blueprint no projeto antes de abrir uma coleção.')),
      );
      return;
    }
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) => _CollectionDialog(blueprints: blueprints, existing: existing),
    );
    if (result == null) return;
    final repo = ref.read(collectionRepositoryProvider);
    if (existing == null) {
      final created = await repo.create(
        projectId: projectId,
        blueprintId: result.$3,
        name: result.$1,
        category: result.$2,
      );
      if (context.mounted) context.push('/project/$projectId/collection/${created.id}');
    } else {
      await repo.update(existing.id, name: result.$1, category: result.$2);
    }
  }
}

class _CollectionDialog extends StatefulWidget {
  const _CollectionDialog({required this.blueprints, this.existing});
  final List<Blueprint> blueprints;
  final Collection? existing;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _category = widget.existing?.category ?? 'default';
  late String _blueprintId = widget.existing?.blueprintId ?? widget.blueprints.first.id;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nova coleção' : 'Editar coleção'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: [
              for (final entry in kCategories.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value.$1)),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'default'),
            decoration: const InputDecoration(labelText: 'Categoria'),
          ),
          if (widget.existing == null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _blueprintId,
              items: [
                for (final item in widget.blueprints)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() => _blueprintId = value ?? _blueprintId),
              decoration: const InputDecoration(labelText: 'Blueprint'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name, _category, _blueprintId));
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

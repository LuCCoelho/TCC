import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../domain/enums.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/sync_status_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final sync = ref.watch(syncStateProvider);
    final dateFormat = DateFormat("d 'de' MMM", 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Naipe'),
        actions: [
          sync.when(
            data: (state) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SyncStatusBadge(state: state, compact: true),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => const Icon(Icons.error_outline, color: AppColors.danger),
          ),
          IconButton(
            tooltip: 'Galeria de blueprints',
            onPressed: () => context.push('/gallery'),
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          IconButton(
            tooltip: 'Conta e sincronização',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo projeto'),
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro ao carregar projetos: $error')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.style_outlined,
              title: 'Nenhuma mesa montada',
              message: 'Crie um projeto para desenhar blueprints, coleções e cartas. O primeiro passo cabe neste botão.',
              actionLabel: 'Criar projeto',
              onAction: () => _newProject(context, ref),
            );
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () => ref.read(syncRepositoryProvider).syncNow(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                childAspectRatio: 1.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final project = items[index];
                final global = sync.asData?.value;
                final phase = global == null
                    ? SyncPhase.pending
                    : projectSyncPhase(project.updatedAt, project.syncedAt, global);
                return _ProjectCard(
                  project: project,
                  phase: phase,
                  updatedLabel: dateFormat.format(project.updatedAt),
                  onOpen: () => context.push('/project/${project.id}'),
                  onLongPress: () => _projectActions(context, ref, project),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _newProject(BuildContext context, WidgetRef ref) async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null || !context.mounted) return;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _ProjectFormDialog(),
    );
    if (result == null) return;
    final project = await ref.read(projectRepositoryProvider).create(
          userId: user.id,
          name: result.$1,
          description: result.$2,
        );
    if (context.mounted) context.push('/project/${project.id}');
  }

  Future<void> _projectActions(BuildContext context, WidgetRef ref, Project project) async {
    final host = context;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renomear'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await showDialog<(String, String)>(
                  context: host,
                  builder: (context) => _ProjectFormDialog(
                    initialName: project.name,
                    initialDescription: project.description,
                  ),
                );
                if (result != null) {
                  await ref.read(projectRepositoryProvider).rename(
                        project.id,
                        name: result.$1,
                        description: result.$2,
                      );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Excluir'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await confirmAction(
                  host,
                  title: 'Excluir projeto?',
                  message: 'O projeto "${project.name}" sai da lista, mas permanece no dispositivo (exclusão suave) para a sincronização.',
                  confirmLabel: 'Excluir',
                  destructive: true,
                );
                if (ok) {
                  await ref.read(projectRepositoryProvider).softDelete(project.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.phase,
    required this.updatedLabel,
    required this.onOpen,
    required this.onLongPress,
  });

  final Project project;
  final SyncPhase phase;
  final String updatedLabel;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inkElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.style, color: AppColors.gold),
                  const Spacer(),
                  _MiniSync(phase: phase),
                ],
              ),
              const Spacer(),
              Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                project.description.isEmpty ? 'Sem descrição' : project.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: 12),
              Text(
                'Atualizado $updatedLabel',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.mist),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSync extends StatelessWidget {
  const _MiniSync({required this.phase});
  final SyncPhase phase;

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      SyncPhase.synced => AppColors.success,
      SyncPhase.pending => AppColors.warning,
      SyncPhase.syncing => AppColors.gold,
      SyncPhase.offline => AppColors.mist,
      SyncPhase.error => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        phase == SyncPhase.offline ? 'não sincronizado' : phase.label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({this.initialName = '', this.initialDescription = ''});

  final String initialName;
  final String initialDescription;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _description = TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName.isEmpty ? 'Novo projeto' : 'Editar projeto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name, _description.text.trim()));
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

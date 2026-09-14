import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class ProjectHubScreen extends ConsumerWidget {
  const ProjectHubScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final blueprints = ref.watch(blueprintsProvider(projectId));
    final collections = ref.watch(collectionsProvider(projectId));

    return projects.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (items) {
        final project = items.where((item) => item.id == projectId).firstOrNull;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.help_outline,
              title: 'Projeto não encontrado',
              message: 'Ele pode ter sido excluído.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                tooltip: 'Histórico',
                onPressed: () => context.push('/project/$projectId/history'),
                icon: const Icon(Icons.history),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                project.description.isEmpty ? 'Sem descrição ainda.' : project.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: 20),
              _HubTile(
                icon: Icons.dashboard_customize_outlined,
                title: 'Blueprints',
                subtitle: blueprints.maybeWhen(
                  data: (items) => items.isEmpty
                      ? 'Nenhum modelo ainda — crie o molde da carta'
                      : '${items.length} modelo(s)',
                  orElse: () => 'Leiaute mestre das cartas',
                ),
                onTap: () => _openBlueprints(context, ref, blueprints.asData?.value ?? []),
              ),
              _HubTile(
                icon: Icons.folder_copy_outlined,
                title: 'Coleções',
                subtitle: collections.maybeWhen(
                  data: (items) => items.isEmpty ? 'Organize as cartas em pastas' : '${items.length} coleção(ões)',
                  orElse: () => 'Pastas de cartas',
                ),
                onTap: () => context.push('/project/$projectId/collections'),
              ),
              _HubTile(
                icon: Icons.ios_share_outlined,
                title: 'Exportação',
                subtitle: 'PDF, Tabletop Simulator, JSON e XML',
                onTap: () => context.push('/project/$projectId/export'),
              ),
              _HubTile(
                icon: Icons.photo_library_outlined,
                title: 'Galeria de blueprints',
                subtitle: 'Buscar, duplicar e gerenciar modelos',
                onTap: () => context.push('/gallery'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBlueprints(BuildContext context, WidgetRef ref, List<Blueprint> items) async {
    if (items.isEmpty) {
      context.push('/project/$projectId/blueprint/new');
      return;
    }
    if (items.length == 1) {
      context.push('/project/$projectId/blueprint/${items.first.id}');
      return;
    }
    final host = context;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              ListTile(
                title: Text(item.name),
                subtitle: Text('${item.cardWidthMm.toStringAsFixed(0)} × ${item.cardHeightMm.toStringAsFixed(0)} mm'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  host.push('/project/$projectId/blueprint/${item.id}');
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Novo blueprint'),
              onTap: () {
                Navigator.pop(sheetContext);
                host.push('/project/$projectId/blueprint/new');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline),
        ),
        tileColor: AppColors.inkElevated,
        leading: CircleAvatar(
          backgroundColor: AppColors.inkSoft,
          child: Icon(icon, color: AppColors.gold),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

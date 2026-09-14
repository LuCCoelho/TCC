import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class BlueprintGalleryScreen extends ConsumerStatefulWidget {
  const BlueprintGalleryScreen({super.key});

  @override
  ConsumerState<BlueprintGalleryScreen> createState() => _BlueprintGalleryScreenState();
}

class _BlueprintGalleryScreenState extends ConsumerState<BlueprintGalleryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final blueprints = ref.watch(allBlueprintsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Galeria de blueprints')),
      body: blueprints.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          final filtered = items
              .where((item) => item.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nome',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Nenhum blueprint',
                        message: 'Crie um modelo dentro de um projeto para vê-lo aqui.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.hairline),
                            ),
                            tileColor: AppColors.inkElevated,
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.cardWidthMm.toStringAsFixed(0)} × ${item.cardHeightMm.toStringAsFixed(0)} mm',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'open') {
                                  context.push('/project/${item.projectId}/blueprint/${item.id}');
                                } else if (value == 'duplicate') {
                                  await ref.read(blueprintRepositoryProvider).duplicate(item.id);
                                } else if (value == 'delete') {
                                  final ok = await confirmAction(
                                    context,
                                    title: 'Excluir blueprint?',
                                    message: 'O modelo sai da galeria (exclusão suave).',
                                    confirmLabel: 'Excluir',
                                    destructive: true,
                                  );
                                  if (ok) {
                                    await ref.read(blueprintRepositoryProvider).softDelete(item.id);
                                  }
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'open', child: Text('Abrir editor')),
                                PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                                PopupMenuItem(value: 'delete', child: Text('Excluir')),
                              ],
                            ),
                            onTap: () => context.push('/project/${item.projectId}/blueprint/${item.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

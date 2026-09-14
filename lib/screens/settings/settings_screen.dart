import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/sync_status_badge.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _username = TextEditingController();
  late final _email = TextEditingController();
  var _loaded = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncStateProvider);
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Conta e sincronização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          user.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (profile) {
              if (profile != null && !_loaded) {
                _username.text = profile.username;
                _email.text = profile.email;
                _loaded = true;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Perfil local', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  TextField(controller: _username, decoration: const InputDecoration(labelText: 'Nome de usuário')),
                  const SizedBox(height: 8),
                  TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail')),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      await ref.read(userRepositoryProvider).updateProfile(
                            username: _username.text.trim(),
                            email: _email.text.trim(),
                          );
                      ref.invalidate(currentUserProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Perfil atualizado neste aparelho.')),
                        );
                      }
                    },
                    child: const Text('Salvar perfil'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text('Sincronização', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          sync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (state) {
              final format = DateFormat("d/MM HH:mm", 'pt_BR');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SyncStatusBadge(state: state),
                  const SizedBox(height: 8),
                  Text(
                    state.lastAttempt == null
                        ? 'Nenhuma tentativa ainda.'
                        : 'Última tentativa: ${format.format(state.lastAttempt!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mist),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Modo offline'),
                    subtitle: const Text('Pausa o envio para a nuvem. Os dados locais continuam editáveis.'),
                    value: state.offlineMode,
                    onChanged: (value) => ref.read(syncRepositoryProvider).setOfflineMode(value),
                  ),
                  FilledButton.tonal(
                    onPressed: () => ref.read(syncRepositoryProvider).syncNow(),
                    child: const Text('Forçar sincronização'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text('Conflitos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          projects.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('$error'),
            data: (items) {
              final pending = items
                  .where((item) => item.syncedAt == null || item.updatedAt.isAfter(item.syncedAt!))
                  .toList();
              if (pending.isEmpty) {
                return const Text('Nenhum conflito. Tudo que está pendente pode ser enviado na próxima sincronização.');
              }
              return Column(
                children: [
                  const Text(
                    'Itens locais mais recentes que a última sincronização. Sem backend concreto, o Naipe mantém a cópia local como vencedora.',
                  ),
                  const SizedBox(height: 8),
                  for (final item in pending)
                    ListTile(
                      title: Text(item.name),
                      subtitle: Text('Atualizado em ${item.updatedAt}'),
                      trailing: const Text('Local vence'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

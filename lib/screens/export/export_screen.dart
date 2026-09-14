import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/export/export_service.dart';
import '../../domain/enums.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, required this.projectId, this.collectionId});

  final String projectId;
  final String? collectionId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _format = ExportFormat.pdf;
  String? _collectionId;
  double _bleed = 3;
  int _dpi = 300;
  int _start = 1;
  int _end = 999;
  double _progress = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _collectionId = widget.collectionId;
  }

  Future<void> _startExport(List<Collection> collections) async {
    final collection = collections.where((item) => item.id == _collectionId).firstOrNull ??
        (collections.isNotEmpty ? collections.first : null);
    if (collection == null) return;
    setState(() {
      _running = true;
      _progress = 0;
    });
    final jobs = ref.read(exportRepositoryProvider);
    final config = ExportConfig(
      bleedMm: _bleed,
      dpi: _dpi,
      startIndex: (_start - 1).clamp(0, 9999),
      endIndex: _end,
      collectionId: collection.id,
    );
    final job = await jobs.create(
      projectId: widget.projectId,
      format: _format,
      exportConfig: config.encode(),
    );
    await jobs.updateStatus(job.id, status: ExportJobStatus.processing);
    try {
      final service = ExportService(
        blueprints: ref.read(blueprintRepositoryProvider),
        cards: ref.read(cardRepositoryProvider),
        collections: ref.read(collectionRepositoryProvider),
      );
      final path = await service.exportCollection(
        collection: collection,
        format: _format,
        config: config,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      await jobs.updateStatus(job.id, status: ExportJobStatus.completed, outputPath: path);
    } catch (error) {
      await jobs.updateStatus(job.id, status: ExportJobStatus.failed, outputPath: '$error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha na exportação: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider(widget.projectId));
    final jobs = ref.watch(exportJobsProvider(widget.projectId));
    return Scaffold(
      appBar: AppBar(title: const Text('Exportação')),
      body: collections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.ios_share_outlined,
              title: 'Nada para exportar',
              message: 'Crie uma coleção com cartas antes de gerar PDF ou metadados.',
            );
          }
          _collectionId ??= items.first.id;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Tipo de saída', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final format in ExportFormat.values)
                    ChoiceChip(
                      label: Text(format.label),
                      selected: _format == format,
                      onSelected: (_) => setState(() => _format = format),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _collectionId,
                items: [
                  for (final item in items) DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => setState(() => _collectionId = value),
                decoration: const InputDecoration(labelText: 'Coleção'),
              ),
              const SizedBox(height: 12),
              Text('Sangria (${_bleed.toStringAsFixed(0)} mm)'),
              Slider(
                min: 0,
                max: 6,
                divisions: 6,
                value: _bleed,
                onChanged: (value) => setState(() => _bleed = value),
              ),
              Text('DPI: $_dpi'),
              Slider(
                min: 150,
                max: 600,
                divisions: 3,
                value: _dpi.toDouble(),
                onChanged: (value) => setState(() => _dpi = value.round()),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_start',
                      decoration: const InputDecoration(labelText: 'Da carta nº'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _start = int.tryParse(value) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_end',
                      decoration: const InputDecoration(labelText: 'Até'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _end = int.tryParse(value) ?? 999,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_running) LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _running ? null : () => _startExport(items),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar exportação'),
              ),
              const SizedBox(height: 24),
              Text('Jobs do projeto', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              jobs.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('$error'),
                data: (list) {
                  if (list.isEmpty) {
                    return const Text('Nenhuma exportação ainda.');
                  }
                  return Column(
                    children: [
                      for (final job in list) _JobTile(job: job),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});
  final ExportJob job;

  @override
  Widget build(BuildContext context) {
    final status = ExportJobStatus.parse(job.status);
    final color = switch (status) {
      ExportJobStatus.completed => AppColors.success,
      ExportJobStatus.failed => AppColors.danger,
      ExportJobStatus.processing => AppColors.gold,
      ExportJobStatus.pending => AppColors.mist,
    };
    return Card(
      child: ListTile(
        title: Text(ExportFormat.parse(job.format).label),
        subtitle: Text('${status.label}\n${job.outputPath ?? '—'}'),
        isThreeLine: true,
        trailing: status == ExportJobStatus.completed && (job.outputPath ?? '').isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () async {
                  final path = job.outputPath!;
                  if (job.format == ExportFormat.pdf.name) {
                    await Printing.sharePdf(bytes: await _readBytes(path), filename: path.split('/').last);
                  } else {
                    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
                  }
                },
              )
            : Icon(Icons.circle, size: 12, color: color),
      ),
    );
  }

  Future<dynamic> _readBytes(String path) async {
    return await XFile(path).readAsBytes();
  }
}

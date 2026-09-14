import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../domain/enums.dart';
import '../../domain/field_style.dart';
import '../../providers/providers.dart';
import '../../widgets/image_picker_helper.dart';

class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key, required this.projectId, required this.collectionId});

  final String projectId;
  final String collectionId;

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  int _step = 0;
  List<List<dynamic>> _rows = [];
  List<String> _headers = [];
  Map<int, String?> _mapping = {};
  bool _createNew = true;
  bool _busy = false;
  int _progress = 0;
  int _total = 0;
  int _ignored = 0;
  String? _error;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null && !kIsWeb) {
      content = await File(file.path!).readAsString();
    } else {
      setState(() => _error = 'Não foi possível ler o arquivo.');
      return;
    }
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    final parsed = const CsvToListConverter(eol: '\n').convert(content);
    if (parsed.isEmpty) {
      setState(() => _error = 'O CSV está vazio.');
      return;
    }
    setState(() {
      _headers = parsed.first.map((cell) => '$cell').toList();
      _rows = parsed.skip(1).toList();
      _mapping = {for (var i = 0; i < _headers.length; i++) i: null};
      _step = 1;
      _error = null;
    });
  }

  Future<void> _autoMap(List<FieldDefinition> fields) async {
    final labels = {
      for (final field in fields) FieldStyleConfig.fromJson(field.styleConfig).label.toLowerCase(): field.id,
    };
    setState(() {
      for (var i = 0; i < _headers.length; i++) {
        final header = _headers[i].toLowerCase().trim();
        _mapping[i] = labels[header] ?? labels[header.replaceAll('_', ' ')];
      }
    });
  }

  Future<void> _run(Collection collection, List<FieldDefinition> fields) async {
    setState(() {
      _busy = true;
      _step = 3;
      _progress = 0;
      _total = _rows.length;
      _ignored = 0;
    });
    final repo = ref.read(cardRepositoryProvider);
    var sort = (await repo.listByCollection(collection.id)).length;
    const chunk = 40;
    for (var offset = 0; offset < _rows.length; offset += chunk) {
      final slice = _rows.skip(offset).take(chunk);
      for (final row in slice) {
        if (row.every((cell) => '$cell'.trim().isEmpty)) {
          _ignored++;
          continue;
        }
        final payload = <String, ({String? text, String? image})>{};
        for (final field in fields) {
          payload[field.id] = (text: null, image: null);
        }
        var mapped = 0;
        for (var i = 0; i < _headers.length; i++) {
          final fieldId = _mapping[i];
          if (fieldId == null) continue;
          final field = fields.where((item) => item.id == fieldId).firstOrNull;
          if (field == null) continue;
          final raw = i < row.length ? '${row[i]}'.trim() : '';
          if (raw.isEmpty) continue;
          mapped++;
          final type = FieldType.parse(field.type);
          if (type == FieldType.imagem) {
            payload[fieldId] = (
              text: null,
              image: ImagePickerHelper.isRemote(raw) || raw.isNotEmpty ? raw : null,
            );
          } else {
            payload[fieldId] = (text: raw, image: null);
          }
        }
        if (mapped == 0) {
          _ignored++;
          continue;
        }
        await repo.insertImported(
          collectionId: collection.id,
          blueprintId: collection.blueprintId,
          sortOrder: sort++,
          fieldPayload: payload,
        );
        _progress++;
        if (mounted) setState(() {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await ref.read(changeLogRepositoryProvider).append(
          projectId: widget.projectId,
          entityType: 'collection',
          entityId: collection.id,
          action: 'csv_import',
          snapshotJson: '{"created":$_progress,"ignored":$_ignored}',
          summary: 'Importação CSV: $_progress carta(s), $_ignored ignorada(s)',
        );
    if (mounted) {
      setState(() {
        _busy = false;
        _step = 4;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider(widget.projectId));
    return collections.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (items) {
        final collection = items.where((item) => item.id == widget.collectionId).firstOrNull;
        if (collection == null) {
          return Scaffold(appBar: AppBar(title: const Text('CSV')), body: const Center(child: Text('Coleção ausente')));
        }
        final fields = ref.watch(blueprintFieldsProvider(collection.blueprintId)).asData?.value ?? [];
        return Scaffold(
          appBar: AppBar(title: const Text('Importar CSV')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Stepper(step: _step),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              if (_step == 0) ...[
                const Text('Selecione um arquivo CSV. A primeira linha deve conter os nomes das colunas.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Escolher arquivo'),
                ),
              ],
              if (_step == 1) ...[
                Text('${_rows.length} linha(s), ${_headers.length} coluna(s). Prévia:'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [for (final header in _headers) DataColumn(label: Text(header))],
                    rows: [
                      for (final row in _rows.take(5))
                        DataRow(
                          cells: [
                            for (var i = 0; i < _headers.length; i++)
                              DataCell(Text(i < row.length ? '${row[i]}' : '')),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    _autoMap(fields);
                    setState(() => _step = 2);
                  },
                  child: const Text('Mapear colunas'),
                ),
              ],
              if (_step == 2) ...[
                const Text('Associe cada coluna da planilha a um campo do blueprint. Colunas sem mapeamento são ignoradas.'),
                const SizedBox(height: 12),
                for (var i = 0; i < _headers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _mapping[i],
                      decoration: InputDecoration(labelText: _headers[i]),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Ignorar coluna')),
                        for (final field in fields)
                          DropdownMenuItem(
                            value: field.id,
                            child: Text(FieldStyleConfig.fromJson(field.styleConfig).label),
                          ),
                      ],
                      onChanged: (value) => setState(() => _mapping[i] = value),
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Criar cartas novas'),
                  subtitle: const Text('Desative para apenas revisar o mapeamento. Atualização por chave virá em uma versão futura; esta importação cria linhas novas.'),
                  value: _createNew,
                  onChanged: (value) => setState(() => _createNew = value),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run(collection, fields),
                  child: Text('Importar ${_rows.length} linha(s)'),
                ),
              ],
              if (_step == 3) ...[
                LinearProgressIndicator(value: _total == 0 ? null : _progress / _total),
                const SizedBox(height: 12),
                Text('Processando $_progress de $_total…'),
              ],
              if (_step == 4) ...[
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
                const SizedBox(height: 12),
                Text('$_progress carta(s) criada(s). $_ignored linha(s) ignorada(s).'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/project/${widget.projectId}/collection/${widget.collectionId}'),
                  child: const Text('Voltar à coleção'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Arquivo', 'Prévia', 'Mapeamento', 'Progresso', 'Resultado'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          CircleAvatar(
            radius: 12,
            backgroundColor: i <= step ? AppColors.gold : AppColors.hairline,
            foregroundColor: AppColors.ink,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          if (i < labels.length - 1) const Expanded(child: Divider()),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/content_repositories.dart';
import '../../domain/enums.dart';
import '../../domain/field_style.dart';
import '../../providers/providers.dart';
import '../../widgets/card_face.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/field_renderer.dart';
import '../../widgets/image_picker_helper.dart';

class CollectionCardsScreen extends ConsumerStatefulWidget {
  const CollectionCardsScreen({
    super.key,
    required this.projectId,
    required this.collectionId,
  });

  final String projectId;
  final String collectionId;

  @override
  ConsumerState<CollectionCardsScreen> createState() => _CollectionCardsScreenState();
}

class _CollectionCardsScreenState extends ConsumerState<CollectionCardsScreen> {
  bool _grid = true;
  final _selected = <String>{};
  bool _batchMode = false;

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionsProvider(widget.projectId));

    return collectionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (collections) {
        final collection =
            collections.where((item) => item.id == widget.collectionId).firstOrNull;
        if (collection == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Coleção não encontrada',
              message: 'Ela pode ter sido excluída.',
            ),
          );
        }
        final cards = ref.watch(collectionCardsProvider(widget.collectionId));
        final fields = ref.watch(blueprintFieldsProvider(collection.blueprintId));
        return Scaffold(
          appBar: AppBar(
            title: Text(collection.name),
            actions: [
              IconButton(
                tooltip: _grid ? 'Visão em tabela' : 'Visão em grade',
                onPressed: () => setState(() => _grid = !_grid),
                icon: Icon(_grid ? Icons.table_rows_outlined : Icons.grid_view_outlined),
              ),
              IconButton(
                tooltip: 'Importar CSV',
                onPressed: () => context.push(
                  '/project/${widget.projectId}/collection/${widget.collectionId}/import',
                ),
                icon: const Icon(Icons.upload_file_outlined),
              ),
              IconButton(
                tooltip: 'Exportar',
                onPressed: () => context.push(
                  '/project/${widget.projectId}/export?collectionId=${widget.collectionId}',
                ),
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final card = await ref.read(cardRepositoryProvider).createEmpty(
                    collectionId: collection.id,
                    blueprintId: collection.blueprintId,
                  );
              if (context.mounted) {
                context.push(
                  '/project/${widget.projectId}/collection/${widget.collectionId}/card/${card.id}',
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Nova carta'),
          ),
          body: cards.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (rows) {
              if (rows.isEmpty) {
                return EmptyState(
                  icon: Icons.style_outlined,
                  title: 'Coleção vazia',
                  message: 'Crie uma carta à mão ou importe um CSV para preencher o set.',
                  actionLabel: 'Nova carta',
                  onAction: () async {
                    final card = await ref.read(cardRepositoryProvider).createEmpty(
                          collectionId: collection.id,
                          blueprintId: collection.blueprintId,
                        );
                    if (context.mounted) {
                      context.push(
                        '/project/${widget.projectId}/collection/${widget.collectionId}/card/${card.id}',
                      );
                    }
                  },
                );
              }
              final defs = fields.asData?.value ?? [];
              return Column(
                children: [
                  if (_batchMode || _selected.isNotEmpty)
                    _BatchBar(
                      selectedCount: _selected.length,
                      fields: defs,
                      onCancel: () => setState(() {
                        _selected.clear();
                        _batchMode = false;
                      }),
                      onApply: (field, text, image) => _applyBatch(collection, rows, field, text, image),
                    ),
                  Expanded(
                    child: _grid
                        ? _GridView(
                            projectId: widget.projectId,
                            collection: collection,
                            rows: rows,
                            fields: defs,
                            selected: _selected,
                            onToggle: _toggle,
                            onOpen: (cardId) => context.push(
                              '/project/${widget.projectId}/collection/${widget.collectionId}/card/$cardId',
                            ),
                            onMenu: (row) => _cardMenu(collection, row),
                          )
                        : _TableView(
                            rows: rows,
                            fields: defs,
                            selected: _selected,
                            onToggle: _toggle,
                            onOpen: (cardId) => context.push(
                              '/project/${widget.projectId}/collection/${widget.collectionId}/card/$cardId',
                            ),
                            onEdit: (row, field, text, image) async {
                              await ref.read(cardRepositoryProvider).upsertValue(
                                    cardId: row.card.id,
                                    fieldDefinitionId: field.id,
                                    testValue: text,
                                    imagePath: image,
                                  );
                            },
                            onReorder: (oldIndex, newIndex) async {
                              var target = newIndex;
                              if (target > oldIndex) target--;
                              final ids = rows.map((row) => row.card.id).toList();
                              final item = ids.removeAt(oldIndex);
                              ids.insert(target, item);
                              await ref.read(cardRepositoryProvider).reorder(collection.id, ids);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      _batchMode = _selected.isNotEmpty;
    });
  }

  Future<void> _applyBatch(
    Collection collection,
    List<CardWithValues> rows,
    FieldDefinition field,
    String? text,
    String? image,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Aplicar edição em lote?',
      message:
          'O valor será copiado para ${_selected.length} carta(s) no campo "${FieldStyleConfig.fromJson(field.styleConfig).label}". Esta ação é difícil de desfazer.',
      confirmLabel: 'Aplicar',
      destructive: true,
    );
    if (!ok) return;
    final ids = _selected.toList();
    final snapshot = await ref.read(cardRepositoryProvider).snapshotValues(ids);
    await ref.read(changeLogRepositoryProvider).append(
          projectId: widget.projectId,
          entityType: 'batch',
          entityId: collection.id,
          action: 'batch_edit',
          snapshotJson: snapshot.values
              .map((value) => '${value.id}|${value.cardId}|${value.fieldDefinitionId}|${value.testValue ?? ''}|${value.imagePath ?? ''}')
              .join('\n'),
          summary: 'Edição em lote em ${ids.length} carta(s)',
        );
    await ref.read(cardRepositoryProvider).batchApply(
          cardIds: ids,
          fieldDefinitionId: field.id,
          testValue: text,
          imagePath: image,
        );
    if (mounted) {
      setState(() {
        _selected.clear();
        _batchMode = false;
      });
    }
  }

  Future<void> _cardMenu(Collection collection, CardWithValues row) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editor individual'),
              onTap: () {
                Navigator.pop(context);
                this.context.push(
                  '/project/${widget.projectId}/collection/${widget.collectionId}/card/${row.card.id}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Preview'),
              onTap: () {
                Navigator.pop(context);
                this.context.push(
                  '/project/${widget.projectId}/collection/${widget.collectionId}/preview/${row.card.id}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicar'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(cardRepositoryProvider).duplicate(row.card.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Excluir'),
              onTap: () async {
                Navigator.pop(context);
                final ok = await confirmAction(
                  this.context,
                  title: 'Excluir carta?',
                  message: 'A carta sai da coleção (exclusão suave).',
                  confirmLabel: 'Excluir',
                  destructive: true,
                );
                if (ok) await ref.read(cardRepositoryProvider).softDelete(row.card.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchBar extends StatefulWidget {
  const _BatchBar({
    required this.selectedCount,
    required this.fields,
    required this.onCancel,
    required this.onApply,
  });

  final int selectedCount;
  final List<FieldDefinition> fields;
  final VoidCallback onCancel;
  final void Function(FieldDefinition field, String? text, String? image) onApply;

  @override
  State<_BatchBar> createState() => _BatchBarState();
}

class _BatchBarState extends State<_BatchBar> {
  FieldDefinition? _field;
  final _text = TextEditingController();
  String? _image;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inkSoft,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('${widget.selectedCount} selecionada(s)', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
              ],
            ),
            DropdownButtonFormField<FieldDefinition>(
              initialValue: _field,
              hint: const Text('Coluna a editar'),
              items: [
                for (final field in widget.fields)
                  DropdownMenuItem(
                    value: field,
                    child: Text(FieldStyleConfig.fromJson(field.styleConfig).label),
                  ),
              ],
              onChanged: (value) => setState(() => _field = value),
            ),
            if (_field != null) ...[
              const SizedBox(height: 8),
              if (FieldType.parse(_field!.type) == FieldType.imagem)
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await ImagePickerHelper.pickAndStore();
                    if (path != null) setState(() => _image = path);
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_image == null ? 'Escolher imagem' : 'Imagem selecionada'),
                )
              else if (FieldType.parse(_field!.type) == FieldType.icone)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in kIconCatalog.entries)
                      IconButton(
                        onPressed: () => _text.text = entry.key,
                        icon: Icon(entry.value),
                      ),
                  ],
                )
              else
                TextField(
                  controller: _text,
                  decoration: const InputDecoration(labelText: 'Valor a aplicar'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => widget.onApply(_field!, _text.text, _image),
                child: const Text('Aplicar às selecionadas'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({
    required this.projectId,
    required this.collection,
    required this.rows,
    required this.fields,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
    required this.onMenu,
  });

  final String projectId;
  final Collection collection;
  final List<CardWithValues> rows;
  final List<FieldDefinition> fields;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpen;
  final ValueChanged<CardWithValues> onMenu;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final isOn = selected.contains(row.card.id);
        return GestureDetector(
          onTap: () => onOpen(row.card.id),
          onLongPress: () => onToggle(row.card.id),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isOn ? AppColors.gold : AppColors.hairline, width: isOn ? 2 : 1),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: CardFace(
                    widthMm: 63,
                    heightMm: 88,
                    fields: fields,
                    values: row.values,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    onPressed: () => onMenu(row),
                    icon: const Icon(Icons.more_vert, size: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({
    required this.rows,
    required this.fields,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
    required this.onReorder,
  });

  final List<CardWithValues> rows;
  final List<FieldDefinition> fields;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpen;
  final void Function(CardWithValues row, FieldDefinition field, String? text, String? image) onEdit;
  final ReorderCallback onReorder;

  static const _checkboxWidth = 48.0;
  static const _handleWidth = 40.0;

  List<FieldDefinition> get _columns => fields.take(4).toList();

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: rows.length,
      onReorder: onReorder,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: _TableRowShell(
          checkboxWidth: _checkboxWidth,
          handleWidth: _handleWidth,
          checkbox: const SizedBox.shrink(),
          handle: const SizedBox.shrink(),
          cells: [
            for (final field in columns)
              Text(
                FieldStyleConfig.fromJson(field.styleConfig).label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.muted),
              ),
          ],
        ),
      ),
      itemBuilder: (context, index) {
        final row = rows[index];
        final selectedRow = selected.contains(row.card.id);
        return Material(
          key: ValueKey(row.card.id),
          color: selectedRow ? AppColors.primarySoft : Colors.transparent,
          child: InkWell(
            onTap: () => onOpen(row.card.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _TableRowShell(
                checkboxWidth: _checkboxWidth,
                handleWidth: _handleWidth,
                checkbox: Checkbox(
                  value: selectedRow,
                  onChanged: (_) => onToggle(row.card.id),
                ),
                handle: const Icon(Icons.drag_handle, color: AppColors.muted),
                cells: [
                  for (final field in columns)
                    _InlineCell(
                      field: field,
                      value: row.values[field.id],
                      onCommit: (text, image) => onEdit(row, field, text, image),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TableRowShell extends StatelessWidget {
  const _TableRowShell({
    required this.checkboxWidth,
    required this.handleWidth,
    required this.checkbox,
    required this.handle,
    required this.cells,
  });

  final double checkboxWidth;
  final double handleWidth;
  final Widget checkbox;
  final Widget handle;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: checkboxWidth, child: Center(child: checkbox)),
        for (final cell in cells)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: cell,
            ),
          ),
        SizedBox(width: handleWidth, child: Center(child: handle)),
      ],
    );
  }
}

class _InlineCell extends StatelessWidget {
  const _InlineCell({required this.field, required this.value, required this.onCommit});

  final FieldDefinition field;
  final FieldValue? value;
  final void Function(String? text, String? image) onCommit;

  @override
  Widget build(BuildContext context) {
    final type = FieldType.parse(field.type);
    if (type == FieldType.imagem) {
      return Center(
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () async {
            final path = await ImagePickerHelper.pickAndStore(source: ImageSource.gallery);
            if (path != null) onCommit(value?.testValue, path);
          },
          child: Text(
            (value?.imagePath ?? '').isEmpty ? 'Imagem' : 'Local',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (type == FieldType.icone) {
      return Center(
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          onSelected: (name) => onCommit(name, value?.imagePath),
          itemBuilder: (context) => [
            for (final entry in kIconCatalog.entries)
              PopupMenuItem(value: entry.key, child: Icon(entry.value)),
          ],
          child: Icon(iconForName(value?.testValue ?? '') ?? Icons.star_border, size: 18),
        ),
      );
    }
    return TextFormField(
      key: ValueKey('${field.id}-${value?.updatedAt}'),
      initialValue: value?.testValue ?? '',
      textAlign: TextAlign.center,
      maxLines: 1,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
      ),
      onFieldSubmitted: (text) => onCommit(text, value?.imagePath),
    );
  }
}

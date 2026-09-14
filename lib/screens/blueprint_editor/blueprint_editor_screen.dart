import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ids.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../domain/enums.dart';
import '../../domain/field_style.dart';
import '../../providers/providers.dart';
import '../../widgets/card_canvas_scaler.dart';
import '../../widgets/card_face.dart';
import '../../widgets/empty_state.dart';

class BlueprintEditorScreen extends ConsumerStatefulWidget {
  const BlueprintEditorScreen({super.key, required this.projectId, this.blueprintId});

  final String projectId;
  final String? blueprintId;

  @override
  ConsumerState<BlueprintEditorScreen> createState() => _BlueprintEditorScreenState();
}

class _DraftField {
  _DraftField({
    required this.id,
    required this.type,
    required this.xPctg,
    required this.yPctg,
    required this.wPctg,
    required this.hPctg,
    required this.sortOrder,
    required this.style,
  });

  factory _DraftField.fromDefinition(FieldDefinition field) {
    return _DraftField(
      id: field.id,
      type: FieldType.parse(field.type),
      xPctg: field.xPctg,
      yPctg: field.yPctg,
      wPctg: field.wPctg,
      hPctg: field.hPctg,
      sortOrder: field.sortOrder,
      style: FieldStyleConfig.fromJson(field.styleConfig),
    );
  }

  String id;
  FieldType type;
  double xPctg;
  double yPctg;
  double wPctg;
  double hPctg;
  int sortOrder;
  FieldStyleConfig style;

  FieldDefinition toDefinition(String blueprintId) {
    return FieldDefinition(
      id: id,
      blueprintId: blueprintId,
      type: type.name,
      xPctg: xPctg,
      yPctg: yPctg,
      wPctg: wPctg,
      hPctg: hPctg,
      styleConfig: style.encode(),
      sortOrder: sortOrder,
    );
  }
}

class _BlueprintEditorScreenState extends ConsumerState<BlueprintEditorScreen> {
  final _name = TextEditingController();
  double _widthMm = 63;
  double _heightMm = 88;
  final _fields = <_DraftField>[];
  String? _selectedId;
  String? _loadedId;
  bool _dirty = false;
  bool _ready = false;

  static const _presets = <(String, double, double)>[
    ('TCG / Poker', 63, 88),
    ('Mini', 44, 68),
    ('Tarô', 70, 120),
    ('Quadrado', 70, 70),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_ready) return;
    final id = widget.blueprintId;
    if (id == null) {
      setState(() {
        _name.text = 'Novo blueprint';
        _ready = true;
      });
      return;
    }
    final repo = ref.read(blueprintRepositoryProvider);
    final blueprint = await repo.getById(id);
    final fields = await repo.fieldsOf(id);
    if (!mounted || blueprint == null) return;
    setState(() {
      _loadedId = blueprint.id;
      _name.text = blueprint.name;
      _widthMm = blueprint.cardWidthMm;
      _heightMm = blueprint.cardHeightMm;
      _fields
        ..clear()
        ..addAll(fields.map(_DraftField.fromDefinition));
      _ready = true;
    });
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirmAction(
      context,
      title: 'Descartar alterações?',
      message: 'Há mudanças não salvas neste blueprint.',
      confirmLabel: 'Descartar',
      destructive: true,
    );
  }

  Future<void> _save() async {
    final repo = ref.read(blueprintRepositoryProvider);
    var blueprintId = _loadedId;
    if (blueprintId == null) {
      final created = await repo.create(
        projectId: widget.projectId,
        name: _name.text.trim().isEmpty ? 'Blueprint' : _name.text.trim(),
        widthMm: _widthMm,
        heightMm: _heightMm,
      );
      blueprintId = created.id;
      _loadedId = created.id;
    }
    final blueprint = (await repo.getById(blueprintId))!;
    final fields = [
      for (var i = 0; i < _fields.length; i++)
        _fields[i]
          ..sortOrder = i,
    ].map((field) => field.toDefinition(blueprintId!)).toList();
    await repo.saveLayout(
      blueprint: blueprint.copyWith(name: _name.text.trim(), cardWidthMm: _widthMm, cardHeightMm: _heightMm),
      fields: fields,
    );
    await ref.read(changeLogRepositoryProvider).append(
          projectId: widget.projectId,
          entityType: 'blueprint',
          entityId: blueprintId,
          action: 'save',
          snapshotJson: blueprint.layoutFields,
          summary: 'Blueprint "${_name.text.trim()}" salvo',
        );
    if (mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blueprint salvo')));
      if (widget.blueprintId == null) {
        context.replace('/project/${widget.projectId}/blueprint/$blueprintId');
      }
    }
  }

  void _addField(FieldType type) {
    setState(() {
      _fields.add(_DraftField(
        id: newId(),
        type: type,
        xPctg: 10 + (_fields.length * 3) % 20,
        yPctg: 10 + (_fields.length * 5) % 30,
        wPctg: type == FieldType.imagem ? 40 : 30,
        hPctg: type == FieldType.imagem ? 28 : 12,
        sortOrder: _fields.length,
        style: FieldStyleConfig(label: '${type.label} ${_fields.length + 1}'),
      ));
      _selectedId = _fields.last.id;
      _dirty = true;
    });
  }

  _DraftField? get _selected =>
      _fields.where((field) => field.id == _selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      _bootstrap();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _name,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: 'Nome do blueprint',
            ),
            onChanged: (_) => _markDirty(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: [
            TextButton(onPressed: _save, child: const Text('Salvar')),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final canvas = _CanvasPane(
              widthMm: _widthMm,
              heightMm: _heightMm,
              fields: _fields,
              selectedId: _selectedId,
              onSelect: (id) => setState(() => _selectedId = id),
              onChanged: (field) {
                setState(() {
                  final index = _fields.indexWhere((item) => item.id == field.id);
                  if (index >= 0) _fields[index] = field;
                  _dirty = true;
                });
              },
            );
            final panel = _EditorPanel(
              widthMm: _widthMm,
              heightMm: _heightMm,
              onSizeChanged: (w, h) {
                setState(() {
                  _widthMm = w;
                  _heightMm = h;
                  _dirty = true;
                });
              },
              presets: _presets,
              fields: _fields,
              selected: _selected,
              onSelect: (id) => setState(() => _selectedId = id),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  var target = newIndex;
                  if (target > oldIndex) target--;
                  final item = _fields.removeAt(oldIndex);
                  _fields.insert(target, item);
                  for (var i = 0; i < _fields.length; i++) {
                    _fields[i].sortOrder = i;
                  }
                  _dirty = true;
                });
              },
              onAdd: _addField,
              onDuplicate: (field) {
                setState(() {
                  _fields.add(_DraftField(
                    id: newId(),
                    type: field.type,
                    xPctg: (field.xPctg + 5).clamp(0, 90),
                    yPctg: (field.yPctg + 5).clamp(0, 90),
                    wPctg: field.wPctg,
                    hPctg: field.hPctg,
                    sortOrder: _fields.length,
                    style: field.style.copyWith(label: '${field.style.label} cópia'),
                  ));
                  _selectedId = _fields.last.id;
                  _dirty = true;
                });
              },
              onDelete: (field) {
                setState(() {
                  _fields.removeWhere((item) => item.id == field.id);
                  if (_selectedId == field.id) _selectedId = null;
                  _dirty = true;
                });
              },
              onTypeChanged: (field, type) async {
                final count = await ref
                    .read(blueprintRepositoryProvider)
                    .incompatibleValueCount(field.id, type.name);
                if (!context.mounted) return;
                if (count > 0) {
                  final ok = await confirmAction(
                    context,
                    title: 'Alterar tipo do campo?',
                    message:
                        '$count carta(s) já têm valores que podem ficar incompatíveis com ${type.label.toLowerCase()}.',
                    confirmLabel: 'Alterar mesmo assim',
                    destructive: true,
                  );
                  if (!ok) return;
                }
                setState(() {
                  field.type = type;
                  _dirty = true;
                });
              },
              onStyleChanged: (field) => _markDirty(),
            );

            if (wide) {
              return Row(
                children: [
                  Expanded(child: canvas),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 340, child: panel),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: canvas),
                SizedBox(height: 280, child: panel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CanvasPane extends StatelessWidget {
  const _CanvasPane({
    required this.widthMm,
    required this.heightMm,
    required this.fields,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
  });

  final double widthMm;
  final double heightMm;
  final List<_DraftField> fields;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<_DraftField> onChanged;

  @override
  Widget build(BuildContext context) {
    final defs = fields.map((field) => field.toDefinition('draft')).toList();
    return ColoredBox(
      color: AppColors.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = CardCanvasScaler.fit(
                Size(constraints.maxWidth, constraints.maxHeight),
                widthMm,
                heightMm,
              );
              return GestureDetector(
                onTap: () => onSelect(''),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    children: [
                      CardFace(
                        widthMm: widthMm,
                        heightMm: heightMm,
                        fields: defs,
                        selectedFieldId: selectedId,
                        onTapField: (field) => onSelect(field.id),
                        maxSize: size,
                      ),
                      for (final field in fields)
                        _FieldHandle(
                          field: field,
                          canvas: size,
                          selected: field.id == selectedId,
                          onSelect: () => onSelect(field.id),
                          onChanged: onChanged,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FieldHandle extends StatelessWidget {
  const _FieldHandle({
    required this.field,
    required this.canvas,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
  });

  final _DraftField field;
  final Size canvas;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<_DraftField> onChanged;

  @override
  Widget build(BuildContext context) {
    final rect = CardCanvasScaler.fieldRect(
      canvasSize: canvas,
      xPctg: field.xPctg,
      yPctg: field.yPctg,
      wPctg: field.wPctg,
      hPctg: field.hPctg,
    );
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: onSelect,
        onPanUpdate: (details) {
          field.xPctg = (field.xPctg + details.delta.dx / canvas.width * 100).clamp(0, 100 - field.wPctg);
          field.yPctg = (field.yPctg + details.delta.dy / canvas.height * 100).clamp(0, 100 - field.hPctg);
          onChanged(field);
        },
        child: selected
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  const SizedBox.expand(),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        field.wPctg = (field.wPctg + details.delta.dx / canvas.width * 100).clamp(8, 100 - field.xPctg);
                        field.hPctg = (field.hPctg + details.delta.dy / canvas.height * 100).clamp(6, 100 - field.yPctg);
                        onChanged(field);
                      },
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.widthMm,
    required this.heightMm,
    required this.onSizeChanged,
    required this.presets,
    required this.fields,
    required this.selected,
    required this.onSelect,
    required this.onReorder,
    required this.onAdd,
    required this.onDuplicate,
    required this.onDelete,
    required this.onTypeChanged,
    required this.onStyleChanged,
  });

  final double widthMm;
  final double heightMm;
  final void Function(double width, double height) onSizeChanged;
  final List<(String, double, double)> presets;
  final List<_DraftField> fields;
  final _DraftField? selected;
  final ValueChanged<String> onSelect;
  final ReorderCallback onReorder;
  final ValueChanged<FieldType> onAdd;
  final ValueChanged<_DraftField> onDuplicate;
  final ValueChanged<_DraftField> onDelete;
  final void Function(_DraftField field, FieldType type) onTypeChanged;
  final ValueChanged<_DraftField> onStyleChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inkElevated,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dimensões físicas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in presets)
                ChoiceChip(
                  label: Text(preset.$1),
                  selected: widthMm == preset.$2 && heightMm == preset.$3,
                  onSelected: (_) => onSizeChanged(preset.$2, preset.$3),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('w-$widthMm'),
                  initialValue: widthMm.toStringAsFixed(0),
                  decoration: const InputDecoration(labelText: 'Largura mm'),
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (value) {
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed != null && parsed > 0) onSizeChanged(parsed, heightMm);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey('h-$heightMm'),
                  initialValue: heightMm.toStringAsFixed(0),
                  decoration: const InputDecoration(labelText: 'Altura mm'),
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (value) {
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed != null && parsed > 0) onSizeChanged(widthMm, parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Campos', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              PopupMenuButton<FieldType>(
                tooltip: 'Adicionar campo',
                onSelected: onAdd,
                itemBuilder: (context) => [
                  for (final type in FieldType.values)
                    PopupMenuItem(value: type, child: Text(type.label)),
                ],
                child: const Icon(Icons.add_box_outlined, color: AppColors.gold),
              ),
            ],
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fields.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final field = fields[index];
              return ListTile(
                key: ValueKey(field.id),
                dense: true,
                selected: selected?.id == field.id,
                onTap: () => onSelect(field.id),
                title: Text(field.style.label),
                subtitle: Text(field.type.label),
                trailing: const Icon(Icons.drag_handle),
              );
            },
          ),
          if (selected != null) ...[
            const Divider(),
            Text('Campo selecionado', style: Theme.of(context).textTheme.titleMedium),
            TextFormField(
              key: ValueKey('label-${selected!.id}'),
              initialValue: selected!.style.label,
              decoration: const InputDecoration(labelText: 'Rótulo'),
              onChanged: (value) {
                selected!.style = selected!.style.copyWith(label: value);
                onStyleChanged(selected!);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<FieldType>(
              initialValue: selected!.type,
              items: [
                for (final type in FieldType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (type) {
                if (type != null) onTypeChanged(selected!, type);
              },
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selected!.style.alignment,
              items: const [
                DropdownMenuItem(value: 'left', child: Text('Esquerda')),
                DropdownMenuItem(value: 'center', child: Text('Centro')),
                DropdownMenuItem(value: 'right', child: Text('Direita')),
              ],
              onChanged: (value) {
                if (value == null) return;
                selected!.style = selected!.style.copyWith(alignment: value);
                onStyleChanged(selected!);
              },
              decoration: const InputDecoration(labelText: 'Alinhamento'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('color-${selected!.id}'),
              initialValue: selected!.style.color,
              decoration: const InputDecoration(labelText: 'Cor (#hex)'),
              onChanged: (value) {
                selected!.style = selected!.style.copyWith(color: value);
                onStyleChanged(selected!);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Negrito'),
              value: selected!.style.fontWeight == 'bold',
              onChanged: (value) {
                selected!.style = selected!.style.copyWith(fontWeight: value ? 'bold' : 'regular');
                onStyleChanged(selected!);
              },
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => onDuplicate(selected!),
                  icon: const Icon(Icons.copy),
                  label: const Text('Duplicar'),
                ),
                TextButton.icon(
                  onPressed: () => onDelete(selected!),
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  label: const Text('Remover'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

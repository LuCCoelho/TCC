import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../domain/enums.dart';
import '../../domain/field_style.dart';
import '../../providers/providers.dart';
import '../../widgets/card_face.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/field_renderer.dart';
import '../../widgets/image_picker_helper.dart';

class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen({
    super.key,
    required this.projectId,
    required this.collectionId,
    required this.cardId,
  });

  final String projectId;
  final String collectionId;
  final String cardId;

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  String? _selectedFieldId;
  Timer? _debounce;
  String? _permissionMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _save(String fieldId, {String? text, String? image}) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await ref.read(cardRepositoryProvider).upsertValue(
            cardId: widget.cardId,
            fieldDefinitionId: fieldId,
            testValue: text,
            imagePath: image,
          );
    });
  }

  Future<void> _pickImage(FieldDefinition field, FieldValue? current, ImageSource source) async {
    final permission = source == ImageSource.camera ? Permission.camera : Permission.photos;
    final status = await permission.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _permissionMessage = source == ImageSource.camera
            ? 'Permissão da câmera negada. Você ainda pode colar um caminho ou usar a galeria.'
            : 'Permissão da galeria negada. A carta continua editável offline.';
      });
      return;
    }
    try {
      final path = await ImagePickerHelper.pickAndStore(source: source);
      if (path != null) {
        await ref.read(cardRepositoryProvider).upsertValue(
              cardId: widget.cardId,
              fieldDefinitionId: field.id,
              testValue: current?.testValue,
              imagePath: path,
            );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível usar a imagem: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(collectionCardsProvider(widget.collectionId));
    return cards.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (rows) {
        final index = rows.indexWhere((row) => row.card.id == widget.cardId);
        if (index < 0) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.style_outlined,
              title: 'Carta não encontrada',
              message: 'Ela pode ter sido excluída.',
            ),
          );
        }
        final row = rows[index];
        final blueprintId = row.card.blueprintId;
        final fields = ref.watch(blueprintFieldsProvider(blueprintId)).asData?.value ?? [];
        final collections = ref.watch(collectionsProvider(widget.projectId)).asData?.value ?? [];
        final collection = collections.where((item) => item.id == widget.collectionId).firstOrNull;
        return FutureBuilder<Blueprint?>(
          future: ref.read(blueprintRepositoryProvider).getById(blueprintId),
          builder: (context, snapshot) {
            final blueprint = snapshot.data;
            final selected = fields.where((field) => field.id == _selectedFieldId).firstOrNull;
            return Scaffold(
              appBar: AppBar(
                title: Text(collection?.name ?? 'Carta'),
                actions: [
                  IconButton(
                    tooltip: 'Preview',
                    onPressed: () => context.push(
                      '/project/${widget.projectId}/collection/${widget.collectionId}/preview/${widget.cardId}',
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (_permissionMessage != null)
                    MaterialBanner(
                      content: Text(_permissionMessage!),
                      actions: [
                        TextButton(onPressed: () => setState(() => _permissionMessage = null), child: const Text('Ok')),
                      ],
                    ),
                  Expanded(
                    child: Center(
                      child: blueprint == null
                          ? const CircularProgressIndicator()
                          : CardFace(
                              widthMm: blueprint.cardWidthMm,
                              heightMm: blueprint.cardHeightMm,
                              fields: fields,
                              values: row.values,
                              selectedFieldId: _selectedFieldId,
                              onTapField: (field) => setState(() => _selectedFieldId = field.id),
                            ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: index == 0
                                ? null
                                : () => context.replace(
                                      '/project/${widget.projectId}/collection/${widget.collectionId}/card/${rows[index - 1].card.id}',
                                    ),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              'Carta ${index + 1} de ${rows.length}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            onPressed: index >= rows.length - 1
                                ? null
                                : () => context.replace(
                                      '/project/${widget.projectId}/collection/${widget.collectionId}/card/${rows[index + 1].card.id}',
                                    ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selected != null)
                    _FieldEditorSheet(
                      field: selected,
                      value: row.values[selected.id],
                      onText: (text) => _save(selected.id, text: text, image: row.values[selected.id]?.imagePath),
                      onPickCamera: () => _pickImage(selected, row.values[selected.id], ImageSource.camera),
                      onPickGallery: () => _pickImage(selected, row.values[selected.id], ImageSource.gallery),
                      onIcon: (name) => _save(selected.id, text: name, image: row.values[selected.id]?.imagePath),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FieldEditorSheet extends StatelessWidget {
  const _FieldEditorSheet({
    required this.field,
    required this.value,
    required this.onText,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onIcon,
  });

  final FieldDefinition field;
  final FieldValue? value;
  final ValueChanged<String> onText;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final ValueChanged<String> onIcon;

  @override
  Widget build(BuildContext context) {
    final style = FieldStyleConfig.fromJson(field.styleConfig);
    final type = FieldType.parse(field.type);
    return Material(
      color: AppColors.inkElevated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(style.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (type == FieldType.texto)
              TextFormField(
                key: ValueKey('${field.id}-${value?.updatedAt}'),
                initialValue: value?.testValue ?? '',
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Conteúdo da carta'),
                onChanged: onText,
              )
            else if (type == FieldType.imagem)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeria'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Câmera'),
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in kIconCatalog.entries)
                    IconButton.filledTonal(
                      onPressed: () => onIcon(entry.key),
                      icon: Icon(entry.value),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

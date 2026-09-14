import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/card_canvas_scaler.dart';
import '../../widgets/card_face.dart';
import '../../widgets/empty_state.dart';

class CardPreviewScreen extends ConsumerStatefulWidget {
  const CardPreviewScreen({
    super.key,
    required this.projectId,
    required this.collectionId,
    required this.cardId,
  });

  final String projectId;
  final String collectionId;
  final String cardId;

  @override
  ConsumerState<CardPreviewScreen> createState() => _CardPreviewScreenState();
}

class _CardPreviewScreenState extends ConsumerState<CardPreviewScreen> {
  bool _printMode = false;
  final _boundary = GlobalKey();
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _shareImage() async {
    final boundary = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'carta-preview.png'));
    await file.writeAsBytes(bytes.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Prévia da carta'));
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(collectionCardsProvider(widget.collectionId));
    return cards.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (rows) {
        final computed = rows.indexWhere((row) => row.card.id == widget.cardId);
        final initial = computed < 0 ? 0 : computed;
        _pageController ??= PageController(initialPage: initial);
        if (rows.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.visibility_off_outlined,
              title: 'Nada para pré-visualizar',
              message: 'Crie cartas nesta coleção primeiro.',
            ),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFF2A261C),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Preview na mesa'),
            actions: [
              IconButton(
                tooltip: _printMode ? 'Modo mesa' : 'Modo impressão',
                onPressed: () => setState(() => _printMode = !_printMode),
                icon: Icon(_printMode ? Icons.table_bar_outlined : Icons.crop_free),
              ),
              IconButton(
                tooltip: 'Compartilhar imagem',
                onPressed: _shareImage,
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Esta prévia é uma aproximação da impressão. Sangria e marcas de corte aparecem no modo impressão.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mist),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController!,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return FutureBuilder<Blueprint?>(
                      future: ref.read(blueprintRepositoryProvider).getById(row.card.blueprintId),
                      builder: (context, snapshot) {
                        final blueprint = snapshot.data;
                        if (blueprint == null) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final fields =
                            ref.watch(blueprintFieldsProvider(blueprint.id)).asData?.value ?? [];
                        final real = CardCanvasScaler.physicalPx(
                          blueprint.cardWidthMm,
                          blueprint.cardHeightMm,
                        );
                        return InteractiveViewer(
                          minScale: 0.6,
                          maxScale: 4,
                          child: Center(
                            child: RepaintBoundary(
                              key: index ==
                                      (_pageController?.hasClients == true
                                          ? _pageController!.page?.round()
                                          : initial)
                                  ? _boundary
                                  : null,
                              child: CardFace(
                                widthMm: blueprint.cardWidthMm,
                                heightMm: blueprint.cardHeightMm,
                                fields: fields,
                                values: row.values,
                                printMode: _printMode,
                                maxSize: real,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.tonal(
                    onPressed: () {
                      final page = _pageController?.hasClients == true
                          ? _pageController!.page?.round() ?? initial
                          : initial;
                      context.push(
                        '/project/${widget.projectId}/collection/${widget.collectionId}/card/${rows[page].card.id}',
                      );
                    },
                    child: const Text('Abrir no editor'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

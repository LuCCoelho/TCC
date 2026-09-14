import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      icon: Icons.auto_stories,
      title: 'Monte o seu naipe',
      body:
          'Crie projetos de cartas no estilo TCG, trabalhe offline e sincronize quando quiser. Tudo começa na mesa — os dados ficam no aparelho primeiro.',
    ),
    (
      icon: Icons.dashboard_customize_outlined,
      title: 'Blueprints, o modelo mestre',
      body:
          'Desenhe o leiaute uma vez: zonas de texto, arte e ícones sobre um canvas proporcional ao tamanho físico da carta. Reuse o mesmo molde em milhares de cartas.',
    ),
    (
      icon: Icons.table_rows_outlined,
      title: 'Importação em CSV',
      body:
          'Preencha coleções inteiras a partir de uma planilha. Mapeie colunas para os campos do blueprint e gere dezenas de cartas de uma vez.',
    ),
    (
      icon: Icons.print_outlined,
      title: 'Resultado profissional',
      body:
          'Exporte PDF com sangria, metadados JSON/XML ou um pacote para Tabletop Simulator. O preview na mesa existe para você checar a legibilidade antes.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish(WidgetRef ref) async {
    await ref.read(prefsProvider).setBool('onboarding_complete', true);
    ref.read(onboardingDoneProvider.notifier).state = true;
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _finish(ref),
                      child: const Text('Pular'),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (index) => setState(() => _page = index),
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                color: AppColors.inkElevated,
                                border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                              ),
                              child: Icon(page.icon, size: 48, color: AppColors.gold),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.body,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.mist,
                                    fontSize: 16,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? AppColors.gold : AppColors.hairline,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (_page == _pages.length - 1) {
                          _finish(ref);
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Text(_page == _pages.length - 1 ? 'Começar a criar' : 'Continuar'),
                    ),
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

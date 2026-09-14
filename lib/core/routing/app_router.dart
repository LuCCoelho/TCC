import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../screens/blueprint_editor/blueprint_editor_screen.dart';
import '../../screens/blueprint_gallery/blueprint_gallery_screen.dart';
import '../../screens/card_editor/card_editor_screen.dart';
import '../../screens/card_preview/card_preview_screen.dart';
import '../../screens/collection_cards/collection_cards_screen.dart';
import '../../screens/collections/collections_screen.dart';
import '../../screens/csv_import/csv_import_screen.dart';
import '../../screens/export/export_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/project/project_hub_screen.dart';
import '../../screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ref.watch(onboardingDoneProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!onboardingDone && loc != '/onboarding') return '/onboarding';
      if (onboardingDone && loc == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'gallery',
            builder: (context, state) => const BlueprintGalleryScreen(),
          ),
          GoRoute(
            path: 'project/:projectId',
            builder: (context, state) => ProjectHubScreen(
              projectId: state.pathParameters['projectId']!,
            ),
            routes: [
              GoRoute(
                path: 'blueprint/new',
                builder: (context, state) => BlueprintEditorScreen(
                  projectId: state.pathParameters['projectId']!,
                ),
              ),
              GoRoute(
                path: 'blueprint/:blueprintId',
                builder: (context, state) => BlueprintEditorScreen(
                  projectId: state.pathParameters['projectId']!,
                  blueprintId: state.pathParameters['blueprintId'],
                ),
              ),
              GoRoute(
                path: 'collections',
                builder: (context, state) => CollectionsScreen(
                  projectId: state.pathParameters['projectId']!,
                ),
              ),
              GoRoute(
                path: 'collection/:collectionId',
                builder: (context, state) => CollectionCardsScreen(
                  projectId: state.pathParameters['projectId']!,
                  collectionId: state.pathParameters['collectionId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'card/:cardId',
                    builder: (context, state) => CardEditorScreen(
                      projectId: state.pathParameters['projectId']!,
                      collectionId: state.pathParameters['collectionId']!,
                      cardId: state.pathParameters['cardId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'preview/:cardId',
                    builder: (context, state) => CardPreviewScreen(
                      projectId: state.pathParameters['projectId']!,
                      collectionId: state.pathParameters['collectionId']!,
                      cardId: state.pathParameters['cardId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'import',
                    builder: (context, state) => CsvImportScreen(
                      projectId: state.pathParameters['projectId']!,
                      collectionId: state.pathParameters['collectionId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'export',
                builder: (context, state) => ExportScreen(
                  projectId: state.pathParameters['projectId']!,
                  collectionId: state.uri.queryParameters['collectionId'],
                ),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => HistoryScreen(
                  projectId: state.pathParameters['projectId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Rota não encontrada: ${state.uri}')),
    ),
  );
});

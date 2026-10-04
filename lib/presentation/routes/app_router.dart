import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/journal_detail_screen.dart';
import '../../presentation/screens/history_screen.dart';
import '../../presentation/screens/favorites_screen.dart';
import '../../presentation/screens/settings_screen.dart';

/// Корневой навигатор. Нужен, чтобы показать диалог об обновлении из
/// виджета, стоящего выше Navigator (см. `update_prompt.dart`).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'journal/:issn',
          name: 'journal-detail',
          builder: (context, state) {
            final issn = state.pathParameters['issn']!;
            return JournalDetailScreen(issn: issn);
          },
        ),
        GoRoute(
          path: 'history',
          name: 'history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: 'favorites',
          name: 'favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
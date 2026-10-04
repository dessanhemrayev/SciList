import 'package:go_router/go_router.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/journal_detail_screen.dart';
import '../../presentation/screens/history_screen.dart';
import '../../presentation/screens/favorites_screen.dart';

final GoRouter appRouter = GoRouter(
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
      ],
    ),
  ],
);
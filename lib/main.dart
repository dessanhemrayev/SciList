import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/providers/journal_provider.dart';
import 'presentation/providers/history_provider.dart';
import 'presentation/providers/favorites_provider.dart';
import 'presentation/providers/push_provider.dart';
import 'presentation/providers/update_provider.dart';
import 'presentation/widgets/update/update_prompt.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru_RU', null);
  await initializeDateFormatting('en_US', null);

  final prefs = await SharedPreferences.getInstance();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => JournalProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => UpdateProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => PushProvider(prefs),
        ),
      ],
      child: const SciListApp(),
    ),
  );
}

class SciListApp extends StatelessWidget {
  const SciListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SciList',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        return UpdatePrompt(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.3),
              ),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
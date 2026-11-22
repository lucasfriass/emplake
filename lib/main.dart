import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_settings_provider.dart';
import 'screens/game_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Na web, aguarda a restauração da sessão antes de decidir a rota inicial
  await FirebaseAuth.instance.authStateChanges().first;

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const EmplakeApp(),
    ),
  );
}

class EmplakeApp extends ConsumerStatefulWidget {
  const EmplakeApp({super.key});

  @override
  ConsumerState<EmplakeApp> createState() => _EmplakeAppState();
}

class _EmplakeAppState extends ConsumerState<EmplakeApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final savedRoute = ref.read(appSettingsProvider.notifier).getLastRoute();
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    _router = GoRouter(
      initialLocation: isLoggedIn ? savedRoute : '/login',
      redirect: (context, state) {
        final loggedIn = FirebaseAuth.instance.currentUser != null;
        final loggingIn = state.matchedLocation == '/login';

        if (!loggedIn && !loggingIn) return '/login';
        if (loggedIn && loggingIn) return savedRoute;
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainShell(
              currentLocation: state.matchedLocation,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/game',
              builder: (context, state) => const GameScreen(),
            ),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    final lightScheme = ColorScheme.fromSeed(
      seedColor: settings.seedColor,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: settings.seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Emplake',
      locale: settings.locale,
      supportedLocales: const [
        Locale('pt'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FirebaseUILocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: lightScheme.surfaceContainer,
        fontFamily: GoogleFonts.getFont(settings.fontFamily).fontFamily,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.surfaceContainer,
        fontFamily: GoogleFonts.getFont(settings.fontFamily).fontFamily,
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: child!,
        );
      },
      routerConfig: _router,
    );
  }
}
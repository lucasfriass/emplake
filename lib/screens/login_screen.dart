import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  // TODO: Substitua pelo seu Client ID Web do Google (o mesmo do web/index.html)
  static const String googleClientId =
      '975098654659-v416mi22ljlc48uf2gdvoi3npoiqo8l8.apps.googleusercontent.com';

  // TODO: Coloque o nome completo dos integrantes da dupla
  static const String groupMembers = 'Lucas Frias Vieira & Caroline Ito';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      body: SignInScreen(
        providers: [
          EmailAuthProvider(),
          GoogleProvider(clientId: googleClientId),
        ],
        actions: [
          AuthStateChangeAction<SignedIn>((context, state) {
            context.go('/game');
          }),
          AuthStateChangeAction<UserCreated>((context, state) {
            context.go('/game');
          }),
        ],
        headerBuilder: (context, constraints, shrinkOffset) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calculate_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          );
        },
        subtitleBuilder: (context, action) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nomes dos integrantes do grupo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.developedBy(groupMembers),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Seletor de idioma com bandeirinhas
                Row(
                  children: [
                    Text('${l10n.selectLanguage}: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🇧🇷 Português'),
                      selected: settings.locale.languageCode == 'pt',
                      onSelected: (_) => notifier.setLocale(const Locale('pt')),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🇺🇸 English'),
                      selected: settings.locale.languageCode == 'en',
                      onSelected: (_) => notifier.setLocale(const Locale('en')),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
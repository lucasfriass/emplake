import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/neumorphic.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../providers/game_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<String> availableFonts = [
    'Roboto',
    'EB Garamond',
    'Open Sans',
    'JetBrains Mono',
  ];

  static const List<Color> seedPalette = [
    Color(0xFF1E56A0), // Azul Padrão
    Color(0xFF0077B6), // Oceano
    Color(0xFF2D6A4F), // Floresta
    Color(0xFFE76F51), // Pôr do Sol
    Color(0xFF7209B7), // Roxo
    Color(0xFFD62828), // Carmesim
    Color(0xFF3D405B), // Ardósia
  ];

  /// Seção em um painel neumórfico com título.
  Widget _section(BuildContext context, String? title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: NeuBox(
        radius: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      l10n.settingsTitle,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  NeuButton(
                    minSize: const Size(0, 44),
                    onPressed: () async {
                      ref.invalidate(currentPlateProvider);
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) context.go('/login');
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.logout, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.logoutButton),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Idioma
            _section(
              context,
              l10n.selectLanguage,
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  NeuButton(
                    selected: settings.locale.languageCode == 'pt',
                    onPressed: () => notifier.setLocale(const Locale('pt')),
                    child: const Text('🇧🇷 Português'),
                  ),
                  NeuButton(
                    selected: settings.locale.languageCode == 'en',
                    onPressed: () => notifier.setLocale(const Locale('en')),
                    child: const Text('🇺🇸 English'),
                  ),
                ],
              ),
            ),

            // (a) Claro / Escuro
            _section(
              context,
              null,
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.darkModeLabel),
                  secondary: Icon(
                    settings.themeMode == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                  ),
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (isDark) {
                    notifier.setThemeMode(
                      isDark ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
              ),
            ),

            // (b) Tamanho da fonte
            _section(
              context,
              '${l10n.fontSizeLabel}: ${(settings.fontScale * 100).round()}%',
              Slider(
                value: settings.fontScale,
                min: 0.85,
                max: 1.35,
                divisions: 10,
                label: '${(settings.fontScale * 100).round()}%',
                onChanged: notifier.setFontScale,
              ),
            ),

            // (c) Tipo da fonte
            _section(
              context,
              l10n.fontFamilyLabel,
              DropdownButtonFormField<String>(
                initialValue: availableFonts.contains(settings.fontFamily)
                    ? settings.fontFamily
                    : 'Roboto',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.font_download_outlined),
                ),
                items: availableFonts
                    .map(
                      (font) => DropdownMenuItem(
                        value: font,
                        child: Text(font),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) notifier.setFontFamily(val);
                },
              ),
            ),

            // (d) Temas prontos
            _section(
              context,
              l10n.presetThemesLabel,
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  NeuButton(
                    onPressed: () {
                      notifier.setThemeMode(ThemeMode.system);
                      notifier.setSeedColor(const Color(0xFF1E56A0));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.brightness_auto, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.themeDefault),
                      ],
                    ),
                  ),
                  _presetButton(
                    l10n.themeOcean,
                    const Color(0xFF0077B6),
                    ThemeMode.light,
                    notifier,
                  ),
                  _presetButton(
                    l10n.themeForest,
                    const Color(0xFF2D6A4F),
                    ThemeMode.dark,
                    notifier,
                  ),
                  _presetButton(
                    l10n.themeSunset,
                    const Color(0xFFE76F51),
                    ThemeMode.light,
                    notifier,
                  ),
                ],
              ),
            ),

            // (d) Cor semente
            _section(
              context,
              l10n.themeColorLabel,
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: seedPalette.map((color) {
                  final isSelected =
                      settings.seedColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => notifier.setSeedColor(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: NeuStyle.raised(
                          context,
                          distance: isSelected ? 1 : 3,
                          blur: isSelected ? 2 : 7,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetButton(
    String label,
    Color color,
    ThemeMode mode,
    AppSettingsNotifier notifier,
  ) {
    return NeuButton(
      onPressed: () {
        notifier.setThemeMode(mode);
        notifier.setSeedColor(color);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 9, backgroundColor: color),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

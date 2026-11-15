import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.settingsTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.logoutButton),
                ),
              ],
            ),
            const Divider(height: 32),

            // (a) Claro / Escuro / Sistema
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.darkModeLabel),
              secondary: Icon(
                settings.themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (isDark) {
                notifier.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
              },
            ),
            const SizedBox(height: 16),

            // (b) Tamanho da Fonte
            Text(
              '${l10n.fontSizeLabel}: ${(settings.fontScale * 100).round()}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: settings.fontScale,
              min: 0.85,
              max: 1.35,
              divisions: 10,
              label: '${(settings.fontScale * 100).round()}%',
              onChanged: notifier.setFontScale,
            ),
            const SizedBox(height: 16),

            // (c) Tipo da Fonte
            Text(
              l10n.fontFamilyLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 24),

            // (d) Temas Prontos
            Text(
              l10n.presetThemesLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.brightness_auto, size: 18),
                  label: Text(l10n.themeDefault),
                  onPressed: () {
                    notifier.setThemeMode(ThemeMode.system);
                    notifier.setSeedColor(const Color(0xFF1E56A0));
                  },
                ),
                ActionChip(
                  avatar: const CircleAvatar(backgroundColor: Color(0xFF0077B6)),
                  label: Text(l10n.themeOcean),
                  onPressed: () {
                    notifier.setThemeMode(ThemeMode.light);
                    notifier.setSeedColor(const Color(0xFF0077B6));
                  },
                ),
                ActionChip(
                  avatar: const CircleAvatar(backgroundColor: Color(0xFF2D6A4F)),
                  label: Text(l10n.themeForest),
                  onPressed: () {
                    notifier.setThemeMode(ThemeMode.dark);
                    notifier.setSeedColor(const Color(0xFF2D6A4F));
                  },
                ),
                ActionChip(
                  avatar: const CircleAvatar(backgroundColor: Color(0xFFE76F51)),
                  label: Text(l10n.themeSunset),
                  onPressed: () {
                    notifier.setThemeMode(ThemeMode.light);
                    notifier.setSeedColor(const Color(0xFFE76F51));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // (d) Cor Semente Livre
            Text(
              l10n.themeColorLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: seedPalette.map((color) {
                final isSelected =
                    settings.seedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => notifier.setSeedColor(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
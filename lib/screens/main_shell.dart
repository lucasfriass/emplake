import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  final String currentLocation;

  const MainShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  int _locationToIndex(String location) {
    if (location.startsWith('/settings')) return 1;
    return 0;
  }

  void _showHelpDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.helpTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.helpBody,
            style: const TextStyle(height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = _locationToIndex(currentLocation);

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: 60,
        backgroundColor: Colors.transparent,
        color: colorScheme.primary,
        buttonBackgroundColor: colorScheme.secondary,
        animationDuration: const Duration(milliseconds: 300),
        items: [
          Icon(Icons.sports_esports, size: 28, color: colorScheme.onPrimary),
          Icon(Icons.settings, size: 28, color: colorScheme.onPrimary),
          Icon(Icons.help_outline, size: 28, color: colorScheme.onPrimary),
        ],
        onTap: (index) {
          if (index == 0) {
            ref.read(appSettingsProvider.notifier).saveLastRoute('/game');
            context.go('/game');
          } else if (index == 1) {
            ref.read(appSettingsProvider.notifier).saveLastRoute('/settings');
            context.go('/settings');
          } else if (index == 2) {
            _showHelpDialog(context, l10n);
          }
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../core/math_engine.dart';
import '../core/neumorphic.dart';
import '../l10n/app_localizations.dart';
import '../providers/game_provider.dart';

/// Histórico dos números resolvidos e da solução montada pelo usuário.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<SolvedEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(firestoreServiceProvider).fetchHistory();
  }

  void _reload() {
    setState(() {
      _future = ref.read(firestoreServiceProvider).fetchHistory();
    });
  }

  String _levelLabel(String? level, AppLocalizations l10n) {
    switch (level) {
      case 'easy':
        return l10n.levelEasy;
      case 'intermediate':
        return l10n.levelIntermediate;
      case 'advanced':
        return l10n.levelAdvanced;
      case 'hard':
        return l10n.levelHard;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<SolvedEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpinKitWave(color: scheme.primary, size: 48),
                const SizedBox(height: 16),
                Text(l10n.loadingData),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text(l10n.errorLoadingData),
                const SizedBox(height: 16),
                NeuButton(
                  onPressed: _reload,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh),
                      const SizedBox(width: 8),
                      Text(l10n.retryButton),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final entries = snapshot.data ?? const <SolvedEntry>[];
        final localeName = Localizations.localeOf(context).toString();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.historyTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      l10n.solvedCount(entries.length),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: Text(l10n.historyEmpty)),
                  ),
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _entryCard(context, e, l10n, localeName),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _entryCard(
    BuildContext context,
    SolvedEntry e,
    AppLocalizations l10n,
    String localeName,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final meta = <String>[
      if (e.level != null) _levelLabel(e.level, l10n),
      if (e.points != null) l10n.historyPoints(e.points!),
      if (e.solvedAt != null)
        DateFormat.yMd(localeName).add_Hm().format(e.solvedAt!),
    ].where((t) => t.isNotEmpty).join(' · ');

    return NeuBox(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                e.plate,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  meta,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (e.expression == null)
            Text(
              l10n.historyNoSolution,
              style: TextStyle(color: scheme.outline),
            )
          else
            SizedBox(
              width: double.infinity,
              child: NeuBox(
                pressed: true,
                radius: 14,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    MathEngine.toLatex(e.expression!),
                    textStyle: Theme.of(context).textTheme.titleLarge,
                    onErrorFallback: (_) => Text(
                      e.expression!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

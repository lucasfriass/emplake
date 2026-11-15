import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../core/math_engine.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../providers/game_provider.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late Future<UserProgressData> _progressFuture;

  // 5 slots ao redor dos 4 dígitos: [S0] D0 [S1] D1 [S2] D2 [S3] D3 [S4]
  // Por padrão, o '=' já começa no slot central (índice 2)
  List<String> _slots = ['', '', '=', '', ''];
  int _selectedSlot = 1;
  bool _isAnimatingReset = false;

  @override
  void initState() {
    super.initState();
    _progressFuture = ref.read(firestoreServiceProvider).fetchUserProgress();
  }

  void _reloadProgress() {
    setState(() {
      _progressFuture = ref.read(firestoreServiceProvider).fetchUserProgress();
    });
  }

  void _playClickSound() {
    if (ref.read(appSettingsProvider).isSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Monta a expressão matemática completa juntando slots e dígitos da placa
  String _buildRawExpression(String plate) {
    final buf = StringBuffer();
    for (int i = 0; i < 4; i++) {
      buf.write(_slots[i]);
      buf.write(plate[i]);
    }
    buf.write(_slots[4]);
    return buf.toString();
  }

  /// Anima os operadores voltando para a bandeja e reseta os slots
  Future<void> _animateOperatorsBack({bool keepEquals = true}) async {
    setState(() => _isAnimatingReset = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _slots = ['', '', keepEquals ? '=' : '', '', ''];
      _selectedSlot = 1;
      _isAnimatingReset = false;
    });
  }

  void _insertOperator(String op) {
    _playClickSound();
    setState(() {
      // Garante apenas um '=' na equação
      if (op == '=') {
        for (int i = 0; i < _slots.length; i++) {
          _slots[i] = _slots[i].replaceAll('=', '');
        }
      }
      _slots[_selectedSlot] = '${_slots[_selectedSlot]}$op';
    });
  }

  void _backspaceSlot() {
    _playClickSound();
    setState(() {
      final current = _slots[_selectedSlot];
      if (current.isNotEmpty) {
        if (current.endsWith('**')) {
          _slots[_selectedSlot] = current.substring(0, current.length - 2);
        } else {
          _slots[_selectedSlot] = current.substring(0, current.length - 1);
        }
      }
    });
  }

  int _pointsForDifficulty(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy:
        return 10;
      case DifficultyLevel.intermediate:
        return 20;
      case DifficultyLevel.advanced:
        return 30;
      case DifficultyLevel.hard:
        return 50;
    }
  }

  Future<void> _verifyEquation(
    String plate,
    DifficultyLevel level,
    List<String> solvedNumbers,
    AppLocalizations l10n,
  ) async {
    _playClickSound();
    final raw = _buildRawExpression(plate);
    final result = MathEngine.evaluateEquation(raw, level);

    // Animação obrigatória dos operadores voltando aos botões após verificar
    await _animateOperatorsBack();
    if (!mounted) return;

    if (result.isValid) {
      final pts = _pointsForDifficulty(level);
      final service = ref.read(firestoreServiceProvider);
      await service.recordSolvedNumber(plate, pts);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.successMessage(pts)),
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Sorteia novo número ainda não resolvido
      final updatedSolved = [...solvedNumbers, plate];
      ref
          .read(currentPlateProvider.notifier)
          .setPlate(service.generateUnsolvedPlate(updatedSolved));
      _reloadProgress();
    } else {
      String errorMsg;
      switch (result.error) {
        case MathEvalError.nonIntegerDivision:
          errorMsg = l10n.errorNonIntegerDivision;
          break;
        case MathEvalError.operatorNotAllowed:
          errorMsg = l10n.errorOperatorNotAllowed;
          break;
        case MathEvalError.notEqual:
          final lStr = result.leftValue?.toStringAsFixed(2) ?? '?';
          final rStr = result.rightValue?.toStringAsFixed(2) ?? '?';
          errorMsg = l10n.errorNotEqual(lStr, rStr);
          break;
        default:
          errorMsg = l10n.errorInvalidSyntax;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _skipPlate(List<String> solvedNumbers) {
    _playClickSound();
    final service = ref.read(firestoreServiceProvider);
    final next = service.generateUnsolvedPlate(solvedNumbers);
    ref.read(currentPlateProvider.notifier).setPlate(next);
    _animateOperatorsBack();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final difficulty = ref.watch(difficultyProvider);
    final isSoundOn = ref.watch(appSettingsProvider).isSoundEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<UserProgressData>(
      future: _progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indicador de progressão diferente do padrão (flutter_spinkit)
                SpinKitWave(
                  color: colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(l10n.loadingData),
              ],
            ),
          );
        }

        final progress = snapshot.data ??
            const UserProgressData(score: 0, solvedNumbers: []);

        // Garante inicialização da placa com um número ainda não resolvido
        var currentPlate = ref.watch(currentPlateProvider);
        if (currentPlate == null) {
          currentPlate = ref
              .read(firestoreServiceProvider)
              .generateUnsolvedPlate(progress.solvedNumbers);
          Future.microtask(() {
            if (mounted) {
              ref.read(currentPlateProvider.notifier).setPlate(currentPlate);
            }
          });
        }

        final rawExpression = _buildRawExpression(currentPlate);
        final latexExpression = MathEngine.toLatex(rawExpression);
        final allowedOps = MathEngine.allowedOperators(difficulty);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho: Pontuação, Resolvidos e Botão de Som Opcional
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 12,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.stars_rounded, size: 18),
                            label: Text(l10n.scoreLabel(progress.score)),
                          ),
                          Chip(
                            avatar:
                                const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(
                              l10n.solvedCount(progress.solvedNumbers.length),
                            ),
                          ),
                        ],
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          ref.read(appSettingsProvider.notifier).toggleSound();
                        },
                        icon: Icon(
                          isSoundOn ? Icons.volume_up : Icons.volume_off,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Seletor dos 4 Níveis de Dificuldade
                  SegmentedButton<DifficultyLevel>(
                    segments: [
                      ButtonSegment(
                        value: DifficultyLevel.easy,
                        label: Text(l10n.levelEasy),
                      ),
                      ButtonSegment(
                        value: DifficultyLevel.intermediate,
                        label: Text(l10n.levelIntermediate),
                      ),
                      ButtonSegment(
                        value: DifficultyLevel.advanced,
                        label: Text(l10n.levelAdvanced),
                      ),
                      ButtonSegment(
                        value: DifficultyLevel.hard,
                        label: Text(l10n.levelHard),
                      ),
                    ],
                    selected: {difficulty},
                    onSelectionChanged: (selection) {
                      _playClickSound();
                      ref
                          .read(difficultyProvider.notifier)
                          .setDifficulty(selection.first);
                      _animateOperatorsBack();
                    },
                  ),
                  const SizedBox(height: 24),

                  // PLACA INTERATIVA EXCLUSIVA (Design Automotivo com Slots Clicáveis)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colorScheme.primary,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Faixa superior estilo placa Mercosul / Emplake
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.plateHeader,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Linha interativa: [Slot0] D0 [Slot1] D1 [Slot2] D2 [Slot3] D3 [Slot4]
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int i = 0; i < 4; i++) ...[
                                _buildSlotButton(i, colorScheme),
                                _buildDigitTile(currentPlate[i], colorScheme),
                              ],
                              _buildSlotButton(4, colorScheme),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Expressão bruta construída
                        Text(
                          rawExpression,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),

                        // Renderizador LaTeX Obrigatório logo abaixo da fórmula
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                latexExpression,
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: colorScheme.primary),
                                onErrorFallback: (_) => Text(
                                  rawExpression,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Teclado de Operadores Permitidos no Nível
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...allowedOps.map(
                            (op) => ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(52, 48),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: () => _insertOperator(op),
                              child: Text(
                                op,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Botão Apagar do slot selecionado
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(56, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: _backspaceSlot,
                            child: const Icon(Icons.backspace_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botões de Ação: Verificar, Limpar e Pular
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _verifyEquation(
                            currentPlate!,
                            difficulty,
                            progress.solvedNumbers,
                            l10n,
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: Text(l10n.checkButton),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            _playClickSound();
                            _animateOperatorsBack();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.clearButton),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _skipPlate(progress.solvedNumbers),
                          icon: const Icon(Icons.skip_next),
                          label: Text(l10n.skipButton),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDigitTile(String digit, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildSlotButton(int index, ColorScheme colorScheme) {
    final isSelected = _selectedSlot == index;
    final content = _slots[index];

    return GestureDetector(
      onTap: () {
        _playClickSound();
        setState(() => _selectedSlot = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.secondaryContainer
              : colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colorScheme.secondary : colorScheme.outline,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Center(
          // Animação de retorno dos operadores aos botões
          child: AnimatedScale(
            scale: _isAnimatingReset ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInBack,
            child: AnimatedSlide(
              offset: _isAnimatingReset ? const Offset(0, 1.5) : Offset.zero,
              duration: const Duration(milliseconds: 300),
              child: Text(
                content.isEmpty ? '·' : content,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: content.isEmpty
                      ? colorScheme.outline
                      : colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
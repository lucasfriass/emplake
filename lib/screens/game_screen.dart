import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../core/math_engine.dart';
import '../core/neumorphic.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../providers/game_provider.dart';

/// Tipo de feedback visual mostrado na placa após verificar a equação.
enum _Feedback { none, success, error }

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

  // Animação de feedback (acerto: pulso verde + confete; erro: tremor vermelho)
  late final AnimationController _fbController;
  _Feedback _fb = _Feedback.none;

  @override
  void initState() {
    super.initState();
    _fbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressFuture = ref.read(firestoreServiceProvider).fetchUserProgress();
  }

  @override
  void dispose() {
    _fbController.dispose();
    super.dispose();
  }

  void _playFeedback(_Feedback feedback) {
    _fb = feedback;
    _fbController.forward(from: 0);
  }

  void _reloadProgress() {
    setState(() {
      _progressFuture = ref.read(firestoreServiceProvider).fetchUserProgress();
    });
  }

  void _playClickSound() {
    if (ref.read(appSettingsProvider).isSoundEnabled) {
      ref.read(soundServiceProvider).playClick();
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
    final raw = _buildRawExpression(plate);
    final result = MathEngine.evaluateEquation(raw, level);

    // Feedback diferente para acerto e erro (animação + som opcional)
    _playFeedback(result.isValid ? _Feedback.success : _Feedback.error);
    if (ref.read(appSettingsProvider).isSoundEnabled) {
      final sound = ref.read(soundServiceProvider);
      result.isValid ? sound.playSuccess() : sound.playError();
    }

    // Animação obrigatória dos operadores voltando aos botões após verificar
    await _animateOperatorsBack();
    if (!mounted) return;

    if (result.isValid) {
      final pts = _pointsForDifficulty(level);
      final service = ref.read(firestoreServiceProvider);
      try {
        await service.recordSolvedNumber(plate, pts);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSavingProgress),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

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

  void _skipPlate(String currentPlate, List<String> solvedNumbers) {
    _playClickSound();
    final service = ref.read(firestoreServiceProvider);
    // Evita sortear o mesmo número que está sendo pulado
    final next = service.generateUnsolvedPlate([...solvedNumbers, currentPlate]);
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

        if (snapshot.hasError && !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 48, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(l10n.errorLoadingData),
                const SizedBox(height: 16),
                NeuButton(
                  onPressed: _reloadProgress,
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

        final progress = snapshot.data ??
            const UserProgressData(score: 0, solvedNumbers: []);

        // Garante uma placa ainda não resolvida por este usuário
        var currentPlate = ref.watch(currentPlateProvider);
        if (currentPlate == null ||
            progress.solvedNumbers.contains(currentPlate)) {
          currentPlate = ref
              .read(firestoreServiceProvider)
              .generateUnsolvedPlate(progress.solvedNumbers);
          final fresh = currentPlate;
          Future.microtask(() {
            if (mounted) {
              ref.read(currentPlateProvider.notifier).setPlate(fresh);
            }
          });
        }
        final plate = currentPlate;

        final rawExpression = _buildRawExpression(plate);
        final latexExpression = MathEngine.toLatex(rawExpression);
        final allowedOps = MathEngine.allowedOperators(difficulty);

        final levels = <(DifficultyLevel, String)>[
          (DifficultyLevel.easy, l10n.levelEasy),
          (DifficultyLevel.intermediate, l10n.levelIntermediate),
          (DifficultyLevel.advanced, l10n.levelAdvanced),
          (DifficultyLevel.hard, l10n.levelHard),
        ];

        // Conteúdo da placa (fica fora do AnimatedBuilder para não reconstruir)
        final plateContent = Column(
          children: [
            // Faixa superior estilo placa Mercosul / Emplake
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    Color.lerp(colorScheme.primary, Colors.black, 0.25)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 18),

            // Linha interativa: [Slot0] D0 [Slot1] D1 [Slot2] D2 [Slot3] D3 [Slot4]
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 4; i++) ...[
                    _buildSlotButton(i, colorScheme),
                    _buildDigitTile(plate[i], colorScheme),
                  ],
                  _buildSlotButton(4, colorScheme),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Expressão bruta construída
            Text(
              rawExpression,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Renderizador LaTeX obrigatório logo abaixo da fórmula
            SizedBox(
              width: double.infinity,
              child: NeuBox(
                pressed: true,
                radius: 14,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho: pontuação, resolvidos e botão de som opcional
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            _buildStatPill(
                              Icons.stars_rounded,
                              l10n.scoreLabel(progress.score),
                              colorScheme,
                            ),
                            _buildStatPill(
                              Icons.check_circle_outline,
                              l10n.solvedCount(progress.solvedNumbers.length),
                              colorScheme,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      NeuButton(
                        minSize: const Size(48, 48),
                        radius: 24,
                        padding: const EdgeInsets.all(10),
                        tooltip: isSoundOn
                            ? l10n.soundOnTooltip
                            : l10n.soundOffTooltip,
                        onPressed: () {
                          ref.read(appSettingsProvider.notifier).toggleSound();
                          // Feedback imediato ao ligar o som
                          if (ref.read(appSettingsProvider).isSoundEnabled) {
                            ref.read(soundServiceProvider).playClick();
                          }
                        },
                        child: Icon(
                          isSoundOn ? Icons.volume_up : Icons.volume_off,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Seletor dos 4 níveis de dificuldade
                  Row(
                    children: [
                      for (final (level, label) in levels)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: NeuButton(
                              selected: difficulty == level,
                              radius: 14,
                              minSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 10,
                              ),
                              onPressed: () {
                                _playClickSound();
                                ref
                                    .read(difficultyProvider.notifier)
                                    .setDifficulty(level);
                                _animateOperatorsBack();
                              },
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(label),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Placa interativa com animação de acerto/erro
                  AnimatedBuilder(
                    animation: _fbController,
                    child: plateContent,
                    builder: (context, child) {
                      final t = _fbController.value;
                      final pulse = math.sin(t * math.pi).clamp(0.0, 1.0);
                      double dx = 0;
                      double scale = 1;
                      Color? accent;
                      IconData? icon;

                      switch (_fb) {
                        case _Feedback.success:
                          scale = 1 + 0.06 * pulse;
                          accent = Colors.green.shade600;
                          icon = Icons.check_circle_rounded;
                          break;
                        case _Feedback.error:
                          dx = math.sin(t * math.pi * 8) * 12 * (1 - t);
                          accent = colorScheme.error;
                          icon = Icons.cancel_rounded;
                          break;
                        case _Feedback.none:
                          break;
                      }

                      final active = accent != null && t > 0 && t < 1;

                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Transform.scale(
                          scale: scale,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              NeuBox(
                                radius: 26,
                                depth: 8,
                                padding: const EdgeInsets.all(18),
                                borderColor: active ? accent : null,
                                extraShadows: active
                                    ? [
                                        BoxShadow(
                                          color: accent
                                              .withValues(alpha: 0.55 * pulse),
                                          blurRadius: 32,
                                          spreadRadius: 4,
                                        ),
                                      ]
                                    : const [],
                                child: child!,
                              ),
                              if (_fb == _Feedback.success)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _BurstPainter(t),
                                    ),
                                  ),
                                ),
                              if (active)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Opacity(
                                        opacity: pulse.toDouble(),
                                        child: Transform.scale(
                                          scale: 0.6 + 0.6 * pulse,
                                          child: Icon(
                                            icon,
                                            size: 96,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Teclado de operadores permitidos no nível
                  NeuBox(
                    radius: 24,
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 14,
                      children: [
                        ...allowedOps.map(
                          (op) => NeuButton(
                            minSize: const Size(52, 48),
                            onPressed: () => _insertOperator(op),
                            child: Text(
                              op,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        // Apagar do slot selecionado
                        NeuButton(
                          minSize: const Size(56, 48),
                          onPressed: _backspaceSlot,
                          child: const Icon(Icons.backspace_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Ações: Verificar, Limpar e Pular
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: NeuButton(
                          filled: true,
                          minSize: const Size(0, 56),
                          onPressed: () => _verifyEquation(
                            plate,
                            difficulty,
                            progress.solvedNumbers,
                            l10n,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle),
                                const SizedBox(width: 8),
                                Text(l10n.checkButton),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: NeuButton(
                          minSize: const Size(0, 56),
                          onPressed: () {
                            _playClickSound();
                            _animateOperatorsBack();
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh),
                                const SizedBox(width: 6),
                                Text(l10n.clearButton),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: NeuButton(
                          minSize: const Size(0, 56),
                          onPressed: () =>
                              _skipPlate(plate, progress.solvedNumbers),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.skip_next),
                                const SizedBox(width: 6),
                                Text(l10n.skipButton),
                              ],
                            ),
                          ),
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

  Widget _buildStatPill(IconData icon, String text, ColorScheme colorScheme) {
    return NeuBox(
      radius: 14,
      depth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDigitTile(String digit, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: NeuBox(
        radius: 12,
        depth: 4,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: colorScheme.primary,
          ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: NeuBox(
          radius: 12,
          depth: 3,
          pressed: isSelected,
          borderColor: isSelected ? colorScheme.primary : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 52),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              // Animação de retorno dos operadores aos botões
              child: AnimatedScale(
                scale: _isAnimatingReset ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInBack,
                child: AnimatedSlide(
                  offset:
                      _isAnimatingReset ? const Offset(0, 1.5) : Offset.zero,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    content.isEmpty ? '·' : content,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: content.isEmpty
                          ? colorScheme.outline
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confete simples que se espalha a partir do centro da placa ao acertar.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  static const List<Color> _colors = [
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF29B6F6),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOut.transform(t);
    const count = 20;
    for (int i = 0; i < count; i++) {
      final angle = i * 2 * math.pi / count;
      final reach = size.width * 0.5 + (i.isEven ? 50 : 15);
      final dist = 30 + eased * reach;
      final pos = center +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.7);
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: 1 - t);
      canvas.drawCircle(pos, (i.isEven ? 6.0 : 4.0) * (1 - t) + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.t != t;
}

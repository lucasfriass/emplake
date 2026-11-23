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
    with TickerProviderStateMixin {
  late Future<UserProgressData> _progressFuture;

  // 5 slots ao redor dos 4 dígitos: [S0] D0 [S1] D1 [S2] D2 [S3] D3 [S4]
  // Por padrão, o '=' já começa no slot central (índice 2)
  // Cada espaço é uma lista de operadores (cada um um "token"), na ordem em
  // que aparecem. Assim dá para escrever √ antes ou depois de outro operador.
  List<List<String>> _slots = [[], [], ['='], [], []];
  int _selectedSlot = 1;
  bool _isAnimatingReset = false;

  // Arrastar operador: true enquanto um operador está sendo arrastado.
  // Os espaços vazios se alargam para servir de alvo e o espaço sob o dedo
  // abre uma lacuna maior, empurrando dígitos e operadores vizinhos.
  bool _draggingOperator = false;
  // Posição de soltura do operador arrastado: espaço (0 a 4) e índice dentro
  // dele (0 = antes do primeiro operador do espaço). Calculada pela posição do
  // ponteiro, então vale para os dois lados de cada dígito e de cada operador.
  int? _hoverSlot;
  int _hoverIndex = 0;
  String? _hoverOp;
  // Uma chave por dígito e uma por operador colocado, para medir onde estão
  final List<GlobalKey> _digitKeys = List.generate(4, (_) => GlobalKey());
  final Map<String, GlobalKey> _tokenKeys = {};

  /// Descobre qual espaço fica mais perto do ponteiro: conta quantos dígitos
  /// estão à esquerda dele (0 = antes do primeiro, 4 = depois do último).
  int _slotForPointer(Offset global) {
    int slot = 0;
    for (int i = 0; i < 4; i++) {
      final box = _digitKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final centerX = box.localToGlobal(box.size.center(Offset.zero)).dx;
      if (global.dx > centerX) slot = i + 1;
    }
    return slot;
  }

  /// Dentro do espaço [slot], descobre em que posição o ponteiro cai: conta
  /// quantos operadores já colocados estão à esquerda dele.
  int _indexForPointer(int slot, double dx) {
    int index = 0;
    for (int t = 0; t < _slots[slot].length; t++) {
      final box = _tokenKeys['$slot-$t']?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final centerX = box.localToGlobal(box.size.center(Offset.zero)).dx;
      if (dx > centerX) index = t + 1;
    }
    return index;
  }

  // Após verificar, a expressão fica parada. Se acertou, fica bloqueada
  // (só dá para Limpar ou Pular); se errou, o usuário pode continuar editando.
  bool _locked = false;
  GameResultBanner? _banner;

  // Animação de feedback (acerto: pulso verde + confete; erro: tremor vermelho)
  late final AnimationController _fbController;

  // Tremidinha dos operadores colocados enquanto algo é arrastado (como os
  // ícones do celular no modo de reorganizar)
  late final AnimationController _wiggle;
  _Feedback _fb = _Feedback.none;

  late final GameSession _session;

  @override
  void initState() {
    super.initState();
    // Restaura a rodada em andamento (ao voltar de outra página)
    _session = ref.read(gameSessionProvider);
    _slots = _session.slots.map((l) => List<String>.of(l)).toList();
    _selectedSlot = _session.selectedSlot;
    _banner = _session.banner;
    _locked = _session.locked && _session.banner != null;
    _fbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _progressFuture = ref.read(firestoreServiceProvider).fetchUserProgress();
  }

  /// Começa/termina o modo de arrasto: liga/desliga a tremidinha.
  void _setDragging(bool on) {
    if (!mounted) return;
    setState(() {
      _draggingOperator = on;
      if (!on) {
        _hoverSlot = null;
        _hoverOp = null;
      }
    });
    if (on) {
      _wiggle.repeat(reverse: true);
    } else {
      _wiggle.stop();
      _wiggle.value = 0;
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    // Guarda a rodada para restaurar quando o usuário voltar ao jogo
    _session.slots = _slots.map((l) => List<String>.of(l)).toList();
    _session.selectedSlot = _selectedSlot;
    _session.locked = _locked;
    _session.banner = _banner;
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
      buf.writeAll(_slots[i]);
      buf.write(plate[i]);
    }
    buf.writeAll(_slots[4]);
    return buf.toString();
  }

  /// Anima os operadores voltando para a bandeja e reseta os slots
  Future<void> _animateOperatorsBack({bool keepEquals = true}) async {
    setState(() => _isAnimatingReset = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _slots = [[], [], keepEquals ? ['='] : [], [], []];
      _selectedSlot = 1;
      _isAnimatingReset = false;
      _locked = false;
      _banner = null;
      _fb = _Feedback.none;
    });
  }

  /// Toque num operador do teclado: entra no fim do espaço selecionado.
  void _insertOperator(String op) {
    _placeToken(op, _selectedSlot, _slots[_selectedSlot].length);
  }

  /// Coloca [op] no espaço [slot], na posição [index] (0 = antes de todos).
  /// Se [fromSlot]/[fromIndex] vierem preenchidos, é uma mudança de lugar: o
  /// operador é tirado da origem antes de entrar no destino.
  void _placeToken(
    String op,
    int slot,
    int index, {
    int? fromSlot,
    int? fromIndex,
  }) {
    if (_locked) return;
    var target = index;
    if (fromSlot != null && fromIndex != null) {
      // Soltou exatamente onde já estava: nada a fazer
      if (fromSlot == slot && (index == fromIndex || index == fromIndex + 1)) {
        return;
      }
      _slots[fromSlot].removeAt(fromIndex);
      // Tirar da frente, no mesmo espaço, desloca o destino uma casa
      if (fromSlot == slot && fromIndex < index) target--;
    }
    _playClickSound();
    setState(() {
      _banner = null;
      _fb = _Feedback.none;
      // Garante apenas um '=' na equação
      if (op == '=') {
        for (int i = 0; i < _slots.length; i++) {
          if (i == slot) {
            // '=' removidos antes do ponto de entrada deslocam o destino
            final cut = math.min(math.max(target, 0), _slots[i].length);
            target -= _slots[i].sublist(0, cut).where((t) => t == '=').length;
          }
          _slots[i].removeWhere((t) => t == '=');
        }
      }
      final at = math.min(math.max(target, 0), _slots[slot].length);
      _slots[slot].insert(at, op);
    });
  }

  void _backspaceSlot() {
    if (_locked) return;
    _playClickSound();
    setState(() {
      _banner = null;
      _fb = _Feedback.none;
      // Apaga o último operador do espaço selecionado
      if (_slots[_selectedSlot].isNotEmpty) {
        _slots[_selectedSlot].removeLast();
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

  /// Formata o valor de um lado da igualdade (inteiro sem casas decimais).
  String _fmt(double? v) {
    if (v == null) return '?';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  Future<void> _verifyEquation(
    String plate,
    DifficultyLevel level,
    AppLocalizations l10n,
  ) async {
    if (_locked) return;
    final raw = _buildRawExpression(plate);
    final result = MathEngine.evaluateEquation(raw, level);

    // Feedback diferente para acerto e erro (animação + som opcional)
    setState(() => _playFeedback(
        result.isValid ? _Feedback.success : _Feedback.error));
    if (ref.read(appSettingsProvider).isSoundEnabled) {
      final sound = ref.read(soundServiceProvider);
      result.isValid ? sound.playSuccess() : sound.playError();
    }

    if (result.isValid) {
      // Congela a expressão: só dá para Limpar ou Pular a partir daqui
      setState(() => _locked = true);

      final pts = _pointsForDifficulty(level);
      final service = ref.read(firestoreServiceProvider);
      try {
        await service.recordSolvedNumber(
          plate,
          pts,
          expression: raw,
          level: level.name,
        );
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _locked = false;
          _fb = _Feedback.none;
          _banner = GameResultBanner(
            success: false,
            message: l10n.errorSavingProgress,
            hint: l10n.retryHint,
          );
        });
        return;
      }
      if (!mounted) return;

      setState(() {
        _banner = GameResultBanner(
          success: true,
          message: l10n.successMessage(pts),
          detail: '${_fmt(result.leftValue)} = ${_fmt(result.rightValue)}',
          hint: l10n.solvedHint,
        );
      });
      // Atualiza a pontuação; a placa resolvida continua na tela até o usuário
      // clicar em Limpar ou Pular.
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
          errorMsg = l10n.errorNotEqual(
            _fmt(result.leftValue),
            _fmt(result.rightValue),
          );
          break;
        default:
          errorMsg = l10n.errorInvalidSyntax;
      }

      // Não limpa os operadores: o usuário continua de onde parou
      setState(() {
        _banner = GameResultBanner(
          success: false,
          message: errorMsg,
          hint: l10n.retryHint,
        );
      });
    }
  }

  /// Limpar: se a placa já foi resolvida, parte para um novo número.
  void _clearAction(String plate, List<String> solvedNumbers) {
    if (_locked) {
      _skipPlate(plate, solvedNumbers);
    } else {
      _playClickSound();
      _animateOperatorsBack();
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
            (!_locked && progress.solvedNumbers.contains(currentPlate))) {
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
            // A linha inteira é o alvo: soltar em qualquer ponto vale para o
            // espaço mais próximo (esquerda ou direita de qualquer dígito).
            DragTarget<_DragOp>(
              onWillAcceptWithDetails: (_) => !_locked,
              onMove: (details) {
                // details.offset é o canto da imagem arrastada; usa o centro
                final pointer = details.offset + const Offset(24, 24);
                final slot = _slotForPointer(pointer);
                final index = _indexForPointer(slot, pointer.dx);
                if (slot != _hoverSlot ||
                    index != _hoverIndex ||
                    details.data.text != _hoverOp) {
                  setState(() {
                    _hoverSlot = slot;
                    _hoverIndex = index;
                    _hoverOp = details.data.text;
                  });
                }
              },
              onLeave: (_) => setState(() {
                _hoverSlot = null;
                _hoverOp = null;
              }),
              onAcceptWithDetails: (details) {
                final pointer = details.offset + const Offset(24, 24);
                final slot = _hoverSlot ?? _slotForPointer(pointer);
                final index = _hoverSlot == null
                    ? _indexForPointer(slot, pointer.dx)
                    : _hoverIndex;
                setState(() {
                  _selectedSlot = slot;
                  _hoverSlot = null;
                  _hoverOp = null;
                });
                _placeToken(
                  details.data.text,
                  slot,
                  index,
                  fromSlot: details.data.fromSlot,
                  fromIndex: details.data.fromIndex,
                );
              },
              builder: (context, candidate, rejected) => Padding(
                // Folga em volta para facilitar soltar perto da linha
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 4; i++) ...[
                        _buildSlotButton(i, colorScheme),
                        _buildDigitTile(plate[i], colorScheme, _digitKeys[i]),
                      ],
                      _buildSlotButton(4, colorScheme),
                    ],
                  ),
                ),
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
                                borderColor: active
                                    ? accent
                                    : (_banner == null
                                        ? null
                                        : (_banner!.success
                                            ? Colors.green.shade600
                                            : colorScheme.error)),
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
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _banner == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: _buildBanner(_banner!, colorScheme),
                          ),
                  ),
                  const SizedBox(height: 28),

                  // Teclado de operadores permitidos no nível
                  Opacity(
                    opacity: _locked ? 0.4 : 1,
                    child: IgnorePointer(
                      ignoring: _locked,
                      // Operadores (retângulo grande) + Apagar (retângulo ao lado)
                      child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: NeuBox(
                            radius: 24,
                            padding: const EdgeInsets.all(14),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 12,
                              children: [
                                ...allowedOps.map(
                                  (op) => Draggable<_DragOp>(
                                    // Dado levado até o espaço (DragTarget)
                                    data: _DragOp(op),
                                    // Imagem que acompanha o dedo/mouse
                                    feedback: Material(
                                      type: MaterialType.transparency,
                                      child: NeuBox(
                                        radius: 14,
                                        depth: 8,
                                        borderColor: colorScheme.primary,
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          op,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // O botão original fica esmaecido no lugar
                                    childWhenDragging: Opacity(
                                      opacity: 0.35,
                                      child: NeuButton(
                                        minSize: const Size(48, 48),
                                        onPressed: null,
                                        child: Text(
                                          op,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                    ),
                                    onDragStarted: () {
                                      _playClickSound();
                                      _setDragging(true);
                                    },
                                    // Chamado ao soltar (dentro ou fora de um espaço)
                                    onDragEnd: (_) => _setDragging(false),
                                    // O toque simples continua inserindo no espaço selecionado
                                    child: NeuButton(
                                      minSize: const Size(48, 48),
                                      onPressed: () => _insertOperator(op),
                                      child: Text(
                                        op,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 84,
                          child: NeuButton(
                            radius: 24,
                            minSize: const Size(84, 0),
                            padding: const EdgeInsets.all(8),
                            onPressed: _backspaceSlot,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.backspace_outlined, size: 26),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(l10n.eraseButton),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          onPressed: _locked
                              ? null
                              : () => _verifyEquation(plate, difficulty, l10n),
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
                          onPressed: () =>
                              _clearAction(plate, progress.solvedNumbers),
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

  Widget _buildBanner(GameResultBanner b, ColorScheme colorScheme) {
    final bg = b.success ? Colors.green.shade700 : colorScheme.error;
    final fg = b.success ? Colors.white : colorScheme.onError;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            b.success ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: fg,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.message,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (b.detail != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    b.detail!,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  b.hint,
                  style: TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildDigitTile(String digit, ColorScheme colorScheme, Key key) {
    return Padding(
      key: key,
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

  /// Um operador já colocado: pode ser arrastado para outro lugar.
  Widget _buildToken(int slot, int t, ColorScheme colorScheme) {
    final text = _slots[slot][t];
    const style = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
    return Draggable<_DragOp>(
      key: _tokenKeys.putIfAbsent('$slot-$t', () => GlobalKey()),
      maxSimultaneousDrags: _locked ? 0 : 1,
      data: _DragOp(text, fromSlot: slot, fromIndex: t),
      // O operador "levantado": maior e com sombra, acompanhando o dedo
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.scale(
          scale: 1.15,
          child: NeuBox(
            radius: 14,
            depth: 10,
            borderColor: colorScheme.primary,
            padding: const EdgeInsets.all(12),
            child: Text(
              text,
              style: style.copyWith(fontSize: 24, color: colorScheme.primary),
            ),
          ),
        ),
      ),
      // O lugar de origem se fecha suavemente (largura vai a zero), como os
      // ícones vizinhos ocupando o espaço de quem foi levantado
      childWhenDragging: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (context, v, _) => ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Opacity(opacity: v, child: Text(text, style: style)),
          ),
        ),
      ),
      onDragStarted: () {
        _playClickSound();
        _setDragging(true);
      },
      onDragEnd: (_) => _setDragging(false),
      // Enquanto algo é arrastado, os operadores colocados "tremem" de leve
      child: AnimatedBuilder(
        animation: _wiggle,
        builder: (context, child) => Transform.rotate(
          angle: _draggingOperator
              ? (t.isEven ? 1 : -1) * (_wiggle.value - 0.5) * 0.12
              : 0,
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            text,
            style: style.copyWith(color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotButton(int index, ColorScheme colorScheme) {
    final isSelected = _selectedSlot == index;
    final tokens = _slots[index];
    final hovered = _hoverSlot == index;
    // Largura mínima: normal 28; durante o arrasto 40; sob o operador 56.
    final minWidth = hovered ? 56.0 : (_draggingOperator ? 40.0 : 28.0);

    // Operadores do espaço. Entre eles (e nas pontas) há uma "lacuna" cuja
    // largura é animada: a do ponto de soltura abre e as outras fecham, então
    // tudo desliza suavemente para dar lugar ao operador arrastado.
    final ghostWidth = (_hoverOp?.length ?? 1) * 13.0 + 4;
    Widget gap(int t) {
      final open = hovered && _hoverIndex == t;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: open ? ghostWidth : 0,
        // Altura fixa: dentro de uma Row a altura é ilimitada e o OverflowBox
        // sem altura própria ficaria com tamanho infinito
        height: 30,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: ghostWidth,
            minWidth: ghostWidth,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: open ? 1 : 0,
              child: Text(
                _hoverOp ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final children = <Widget>[];
    for (int t = 0; t <= tokens.length; t++) {
      children.add(gap(t));
      if (t < tokens.length) children.add(_buildToken(index, t, colorScheme));
    }
    if (tokens.isEmpty && !hovered) {
      children.add(
        Text(
          '·',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colorScheme.outline,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_locked) return;
        _playClickSound();
        setState(() => _selectedSlot = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: NeuBox(
          radius: 12,
          depth: 3,
          pressed: isSelected || hovered,
          borderColor: (isSelected || hovered) ? colorScheme.primary : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: BoxConstraints(minWidth: minWidth, minHeight: 52),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: children,
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

/// Dado levado no arrasto: o texto do operador e, se já estava na expressão,
/// de onde veio (espaço e posição). Sem origem = veio do teclado de operadores.
class _DragOp {
  const _DragOp(this.text, {this.fromSlot, this.fromIndex});

  final String text;
  final int? fromSlot;
  final int? fromIndex;
}
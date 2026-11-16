// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Emplake';

  @override
  String get plateHeader => 'BRASIL • EMPLAKE';

  @override
  String developedBy(String names) {
    return 'Desenvolvido por: $names';
  }

  @override
  String get selectLanguage => 'Idioma';

  @override
  String get navGame => 'Jogar';

  @override
  String get navSettings => 'Configurações';

  @override
  String get navHelp => 'Ajuda';

  @override
  String get levelEasy => 'Fácil';

  @override
  String get levelIntermediate => 'Intermediário';

  @override
  String get levelAdvanced => 'Avançado';

  @override
  String get levelHard => 'Difícil';

  @override
  String scoreLabel(int score) {
    return 'Pontuação: $score';
  }

  @override
  String solvedCount(int count) {
    return 'Resolvidos: $count';
  }

  @override
  String get checkButton => 'Verificar';

  @override
  String get clearButton => 'Limpar';

  @override
  String get skipButton => 'Pular';

  @override
  String get logoutButton => 'Sair';

  @override
  String successMessage(int points) {
    return 'Parabéns! Igualdade válida! +$points pts';
  }

  @override
  String errorNotEqual(String left, String right) {
    return 'Os dois lados não são iguais ($left ≠ $right).';
  }

  @override
  String get errorNonIntegerDivision =>
      'Neste nível não é permitida divisão não inteira!';

  @override
  String get errorInvalidSyntax =>
      'Expressão matemática inválida ou parênteses desbalanceados.';

  @override
  String get errorOperatorNotAllowed => 'Operador não permitido neste nível.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get darkModeLabel => 'Modo Escuro';

  @override
  String get fontSizeLabel => 'Tamanho da Fonte';

  @override
  String get fontFamilyLabel => 'Tipo da Fonte';

  @override
  String get themeColorLabel => 'Cor Semente do Tema';

  @override
  String get presetThemesLabel => 'Temas Prontos';

  @override
  String get themeDefault => 'Padrão do Sistema';

  @override
  String get themeOcean => 'Oceano';

  @override
  String get themeForest => 'Floresta';

  @override
  String get themeSunset => 'Pôr do Sol';

  @override
  String get helpTitle => 'Como Jogar Emplake';

  @override
  String get helpBody =>
      'Insira operadores matemáticos entre os 4 dígitos da placa para formar uma equação verdadeira.\n\nRegras por Nível:\n• Fácil: Todos os operadores (+, -, *, /, √, ∛, !, ^, |x|, piso ⌊x⌋, teto ⌈x⌉) e aceita divisão decimal.\n• Intermediário: Sem piso/teto. Apenas divisões inteiras.\n• Avançado: Sem raiz cúbica e potência. Apenas divisões inteiras.\n• Difícil: Apenas +, -, *, /, ( ), e módulo |x|. Apenas divisões inteiras.';

  @override
  String get closeButton => 'Fechar';

  @override
  String get loadingData => 'Sincronizando progresso na nuvem...';

  @override
  String get errorLoadingData => 'Não foi possível carregar seu progresso.';

  @override
  String get errorSavingProgress =>
      'Não foi possível salvar seu progresso. Tente novamente.';

  @override
  String get retryButton => 'Tentar novamente';

  @override
  String get soundOnTooltip => 'Desligar som';

  @override
  String get soundOffTooltip => 'Ligar som';
}

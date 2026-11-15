import 'dart:math' as math;

enum DifficultyLevel { easy, intermediate, advanced, hard }

enum MathEvalError {
  invalidSyntax,
  nonIntegerDivision,
  operatorNotAllowed,
  notEqual,
}

class MathEvalResult {
  final bool isValid;
  final MathEvalError? error;
  final double? leftValue;
  final double? rightValue;

  const MathEvalResult({
    required this.isValid,
    this.error,
    this.leftValue,
    this.rightValue,
  });
}

class MathEngine {
  /// Retorna os operadores permitidos em cada nível
  static List<String> allowedOperators(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy:
        return ['+', '-', '*', '/', '(', ')', '√', '∛', '!', '**', '|', '⌊', '⌋', '⌈', '⌉', '='];
      case DifficultyLevel.intermediate:
        return ['+', '-', '*', '/', '(', ')', '√', '∛', '!', '**', '|', '='];
      case DifficultyLevel.advanced:
        return ['+', '-', '*', '/', '(', ')', '√', '!', '|', '='];
      case DifficultyLevel.hard:
        return ['+', '-', '*', '/', '(', ')', '|', '='];
    }
  }

  /// Converte a expressão construída pelo usuário para sintaxe LaTeX
  static String toLatex(String raw) {
    if (raw.trim().isEmpty) return '';
    String s = raw;

    // 1. Potências simples: a**b ou (expr)**(expr) -> ^{...}
    s = s.replaceAllMapped(
      RegExp(r'\*\*\(([^()]+)\)'),
      (m) => '^{${m.group(1)}}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\*\*(\d+(\.\d+)?)'),
      (m) => '^{${m.group(1)}}',
    );
    s = s.replaceAll('**', '^');

    // 2. Raiz quadrada e cúbica com parênteses ou número único
    s = s.replaceAllMapped(RegExp(r'√\(([^()]+)\)'), (m) => '\\sqrt{${m.group(1)}}');
    s = s.replaceAllMapped(RegExp(r'√(\d+)'), (m) => '\\sqrt{${m.group(1)}}');
    s = s.replaceAll('√', '\\sqrt{}');

    s = s.replaceAllMapped(RegExp(r'∛\(([^()]+)\)'), (m) => '\\sqrt[3]{${m.group(1)}}');
    s = s.replaceAllMapped(RegExp(r'∛(\d+)'), (m) => '\\sqrt[3]{${m.group(1)}}');
    s = s.replaceAll('∛', '\\sqrt[3]{}');

    // 3. Piso e Teto
    s = s.replaceAll('⌊', '\\lfloor ');
    s = s.replaceAll('⌋', ' \\rfloor');
    s = s.replaceAll('⌈', '\\lceil ');
    s = s.replaceAll('⌉', ' \\rceil');

    // 4. Multiplicação visual elegante
    s = s.replaceAll('*', ' \\cdot ');

    return s;
  }

  /// Avalia a igualdade completa (ex: "√(8 + 1) = 3**1")
  static MathEvalResult evaluateEquation(String expression, DifficultyLevel level) {
    final parts = expression.split('=');
    if (parts.length != 2) {
      return const MathEvalResult(isValid: false, error: MathEvalError.invalidSyntax);
    }

    final leftExpr = parts[0].trim();
    final rightExpr = parts[1].trim();
    if (leftExpr.isEmpty || rightExpr.isEmpty) {
      return const MathEvalResult(isValid: false, error: MathEvalError.invalidSyntax);
    }

    try {
      final allowDecimalDiv = (level == DifficultyLevel.easy);
      final leftVal = _evaluateSide(leftExpr, level, allowDecimalDiv);
      final rightVal = _evaluateSide(rightExpr, level, allowDecimalDiv);

      if (leftVal.isNaN || leftVal.isInfinite || rightVal.isNaN || rightVal.isInfinite) {
        return const MathEvalResult(isValid: false, error: MathEvalError.invalidSyntax);
      }

      if ((leftVal - rightVal).abs() < 1e-9) {
        return MathEvalResult(isValid: true, leftValue: leftVal, rightValue: rightVal);
      } else {
        return MathEvalResult(
          isValid: false,
          error: MathEvalError.notEqual,
          leftValue: leftVal,
          rightValue: rightVal,
        );
      }
    } on _NonIntegerDivisionException {
      return const MathEvalResult(isValid: false, error: MathEvalError.nonIntegerDivision);
    } on _OperatorNotAllowedException {
      return const MathEvalResult(isValid: false, error: MathEvalError.operatorNotAllowed);
    } catch (_) {
      return const MathEvalResult(isValid: false, error: MathEvalError.invalidSyntax);
    }
  }

  static double _evaluateSide(String expr, DifficultyLevel level, bool allowDecimalDiv) {
    final allowed = allowedOperators(level);
    final tokens = _tokenize(expr, allowed);
    final parser = _RecursiveParser(tokens, allowDecimalDiv);
    final result = parser.parseExpression();
    if (!parser.isAtEnd) {
      throw const FormatException('Unexpected token');
    }
    return result;
  }

  static List<String> _tokenize(String expr, List<String> allowed) {
    final List<String> tokens = [];
    int i = 0;
    bool openAbs = false;

    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ') {
        i++;
        continue;
      }

      // Números (dígitos)
      if (_isDigit(ch)) {
        final start = i;
        while (i < expr.length && (_isDigit(expr[i]) || expr[i] == '.')) {
          i++;
        }
        tokens.add(expr.substring(start, i));
        continue;
      }

      // Potência **
      if (ch == '*' && i + 1 < expr.length && expr[i + 1] == '*') {
        if (!allowed.contains('**')) throw _OperatorNotAllowedException();
        tokens.add('**');
        i += 2;
        continue;
      }

      // Módulo |x| alternando abertura e fechamento
      if (ch == '|') {
        if (!allowed.contains('|')) throw _OperatorNotAllowedException();
        tokens.add(openAbs ? '|_close' : '|_open');
        openAbs = !openAbs;
        i++;
        continue;
      }

      // Operadores de 1 caractere
      if (!allowed.contains(ch)) {
        throw _OperatorNotAllowedException();
      }
      tokens.add(ch);
      i++;
    }

    if (openAbs) throw const FormatException('Unclosed |');
    return tokens;
  }

  static bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
}

class _NonIntegerDivisionException implements Exception {}
class _OperatorNotAllowedException implements Exception {}

class _RecursiveParser {
  final List<String> tokens;
  final bool allowDecimalDiv;
  int pos = 0;

  _RecursiveParser(this.tokens, this.allowDecimalDiv);

  bool get isAtEnd => pos >= tokens.length;
  String get peek => tokens[pos];
  String consume() => tokens[pos++];

  // Soma e Subtração
  double parseExpression() {
    double val = parseTerm();
    while (!isAtEnd && (peek == '+' || peek == '-')) {
      final op = consume();
      final right = parseTerm();
      val = (op == '+') ? val + right : val - right;
    }
    return val;
  }

  // Multiplicação e Divisão
  double parseTerm() {
    double val = parsePower();
    while (!isAtEnd && (peek == '*' || peek == '/')) {
      final op = consume();
      final right = parsePower();
      if (op == '*') {
        val *= right;
      } else {
        if (right.abs() < 1e-12) throw const FormatException('Div by zero');
        final res = val / right;
        if (!allowDecimalDiv && (res - res.roundToDouble()).abs() > 1e-9) {
          throw _NonIntegerDivisionException();
        }
        val = res;
      }
    }
    return val;
  }

  // Potência (**) associativa à direita
  double parsePower() {
    double base = parseUnary();
    if (!isAtEnd && peek == '**') {
      consume();
      final exp = parsePower();
      return math.pow(base, exp).toDouble();
    }
    return base;
  }

  // Operadores unários prefixos (+, -, √, ∛) e pós-fixos (!)
  double parseUnary() {
    if (!isAtEnd) {
      if (peek == '+') {
        consume();
        return parseUnary();
      }
      if (peek == '-') {
        consume();
        return -parseUnary();
      }
      if (peek == '√') {
        consume();
        final v = parseUnary();
        if (v < 0) throw const FormatException('Negative sqrt');
        return math.sqrt(v);
      }
      if (peek == '∛') {
        consume();
        final v = parseUnary();
        return v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();
      }
    }

    double val = parsePrimary();

    // Fatorial pós-fixo (!)
    while (!isAtEnd && peek == '!') {
      consume();
      if (val < 0 || val > 20 || (val - val.roundToDouble()).abs() > 1e-9) {
        throw const FormatException('Invalid factorial');
      }
      val = _factorial(val.round()).toDouble();
    }
    return val;
  }

  // Primários: Números, ( ), | |, ⌊ ⌋, ⌈ ⌉
  double parsePrimary() {
    if (isAtEnd) throw const FormatException('Unexpected end');
    final tok = consume();

    if (tok == '(') {
      final v = parseExpression();
      if (isAtEnd || consume() != ')') throw const FormatException('Missing )');
      return v;
    }
    if (tok == '|_open') {
      final v = parseExpression();
      if (isAtEnd || consume() != '|_close') throw const FormatException('Missing |');
      return v.abs();
    }
    if (tok == '⌊') {
      final v = parseExpression();
      if (isAtEnd || consume() != '⌋') throw const FormatException('Missing ⌋');
      return v.floorToDouble();
    }
    if (tok == '⌈') {
      final v = parseExpression();
      if (isAtEnd || consume() != '⌉') throw const FormatException('Missing ⌉');
      return v.ceilToDouble();
    }

    return double.parse(tok);
  }

  int _factorial(int n) {
    int res = 1;
    for (int i = 2; i <= n; i++) {
      res *= i;
    }
    return res;
  }
}
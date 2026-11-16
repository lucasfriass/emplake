import 'package:emplake/core/math_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('igualdade válida no nível difícil', () {
    // 8 + 1 = 9 -> placa 8109 com "+" e "=" nos slots
    final r = MathEngine.evaluateEquation('8+1=9', DifficultyLevel.hard);
    expect(r.isValid, isTrue);
  });

  test('divisão não inteira só é aceita no nível fácil', () {
    final easy = MathEngine.evaluateEquation('5/2=2.5', DifficultyLevel.easy);
    expect(easy.error, isNot(MathEvalError.nonIntegerDivision));
    final hard = MathEngine.evaluateEquation('5/2=2', DifficultyLevel.hard);
    expect(hard.error, MathEvalError.nonIntegerDivision);
  });

  test('operador não permitido no nível', () {
    final r = MathEngine.evaluateEquation('4**2=16', DifficultyLevel.advanced);
    expect(r.error, MathEvalError.operatorNotAllowed);
  });
}

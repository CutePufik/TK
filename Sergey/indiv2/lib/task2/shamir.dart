import 'dart:math';
import '../common/finite_field.dart';
import '../common/polynomial.dart';

/// Доля секрета
class Share {
  final int x; // точка вычисления
  final int y; // значение доли

  Share(this.x, this.y);

  @override
  String toString() => '($x, $y)';
}

/// Схема разделения секрета Шамира
class ShamirSecretSharing {
  final FiniteField field;
  final int threshold; // минимальное количество долей для восстановления (t+1)
  final int numShares; // общее количество долей (n)

  ShamirSecretSharing({
    required this.field,
    required this.threshold,
    required this.numShares,
  }) {
    if (threshold < 1) {
      throw ArgumentError('threshold должен быть >= 1');
    }
    if (threshold > numShares) {
      throw ArgumentError('threshold должен быть <= numShares');
    }
    if (numShares >= field.p) {
      throw ArgumentError('numShares должен быть < размера поля');
    }
  }

  /// Разделение секрета на доли
  /// secret - секретное значение
  /// Возвращает список из numShares долей
  List<Share> share(int secret, {Random? random}) {
    random ??= Random();

    // Создаем случайный многочлен степени threshold-1
    // f(x) = secret + a1*x + a2*x^2 + ... + a_{t-1}*x^{t-1}
    List<int> coeffs = [field.mod(secret)];
    for (int i = 1; i < threshold; i++) {
      coeffs.add(random.nextInt(field.p));
    }

    Polynomial f = Polynomial(field, coeffs);

    // Вычисляем доли: (i, f(i)) для i = 1, 2, ..., numShares
    List<Share> shares = [];
    for (int i = 1; i <= numShares; i++) {
      shares.add(Share(i, f.evaluate(i)));
    }

    return shares;
  }

  /// Восстановление секрета из долей с помощью интерполяции Лагранжа
  /// Требуется минимум threshold долей
  int reconstruct(List<Share> shares) {
    if (shares.length < threshold) {
      throw ArgumentError(
        'Недостаточно долей. Требуется минимум $threshold, получено ${shares.length}',
      );
    }

    // Используем первые threshold долей
    List<Share> usedShares = shares.take(threshold).toList();

    // Интерполяция Лагранжа в точке x = 0
    int secret = 0;
    for (int i = 0; i < usedShares.length; i++) {
      int xi = usedShares[i].x;
      int yi = usedShares[i].y;

      // Вычисляем коэффициент Лагранжа L_i(0)
      int numerator = 1;
      int denominator = 1;
      for (int j = 0; j < usedShares.length; j++) {
        if (i != j) {
          int xj = usedShares[j].x;
          numerator = field.mul(numerator, field.neg(xj)); // 0 - xj = -xj
          denominator = field.mul(denominator, field.sub(xi, xj));
        }
      }

      int lagrangeCoeff = field.div(numerator, denominator);
      secret = field.add(secret, field.mul(yi, lagrangeCoeff));
    }

    return secret;
  }

  /// Вычисление коэффициентов Лагранжа в точке 0 для заданных x-координат
  List<int> lagrangeCoefficientsAtZero(List<int> xCoords) {
    List<int> coeffs = [];
    for (int i = 0; i < xCoords.length; i++) {
      int xi = xCoords[i];
      int numerator = 1;
      int denominator = 1;
      for (int j = 0; j < xCoords.length; j++) {
        if (i != j) {
          int xj = xCoords[j];
          numerator = field.mul(numerator, field.neg(xj));
          denominator = field.mul(denominator, field.sub(xi, xj));
        }
      }
      coeffs.add(field.div(numerator, denominator));
    }
    return coeffs;
  }
}
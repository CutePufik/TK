import '../models/polynomial.dart';

/// Арифметические операции над многочленами в GF(p)
class PolynomialArithmetic {
  final int p;

  PolynomialArithmetic(this.p);

  int _mod(int x) => ((x % p) + p) % p;

  /// Сложение многочленов
  Polynomial add(Polynomial a, Polynomial b) {
    final maxLen = a.coeffs.length > b.coeffs.length
        ? a.coeffs.length
        : b.coeffs.length;

    final result = List<int>.filled(maxLen, 0);
    for (int i = 0; i < maxLen; i++) {
      result[i] = _mod(a[i] + b[i]);
    }

    return Polynomial(result, p);
  }

  /// Вычитание многочленов
  Polynomial subtract(Polynomial a, Polynomial b) {
    final maxLen = a.coeffs.length > b.coeffs.length
        ? a.coeffs.length
        : b.coeffs.length;

    final result = List<int>.filled(maxLen, 0);
    for (int i = 0; i < maxLen; i++) {
      result[i] = _mod(a[i] - b[i]);
    }

    return Polynomial(result, p);
  }

  /// Умножение многочленов
  Polynomial multiply(Polynomial a, Polynomial b) {
    if (a.isZero || b.isZero) return Polynomial.zero(p);

    final resultLen = a.degree + b.degree + 1;
    final result = List<int>.filled(resultLen, 0);

    for (int i = 0; i <= a.degree; i++) {
      for (int j = 0; j <= b.degree; j++) {
        result[i + j] = _mod(result[i + j] + a[i] * b[j]);
      }
    }

    return Polynomial(result, p);
  }

  /// Деление с остатком: a = b * q + r
  /// Возвращает (частное, остаток)
  (Polynomial, Polynomial) divMod(Polynomial a, Polynomial b) {
    if (b.isZero) {
      throw ArgumentError('Division by zero polynomial');
    }

    if (a.degree < b.degree) {
      return (Polynomial.zero(p), a);
    }

    List<int> remainder = List<int>.from(a.coeffs);
    List<int> quotient = List<int>.filled(a.degree - b.degree + 1, 0);

    final bLeadInv = _modInverse(b.leadingCoeff);

    for (int i = a.degree; i >= b.degree; i--) {
      if (remainder.length <= i) continue;

      final coeff = _mod(remainder[i] * bLeadInv);
      quotient[i - b.degree] = coeff;

      for (int j = 0; j <= b.degree; j++) {
        final idx = i - b.degree + j;
        if (idx < remainder.length) {
          remainder[idx] = _mod(remainder[idx] - coeff * b[j]);
        }
      }
    }

    return (Polynomial(quotient, p), Polynomial(remainder, p));
  }

  /// Целочисленное деление
  Polynomial div(Polynomial a, Polynomial b) => divMod(a, b).$1;

  /// Остаток от деления
  Polynomial mod(Polynomial a, Polynomial b) => divMod(a, b).$2;

  /// НОД многочленов (алгоритм Евклида)
  Polynomial gcd(Polynomial a, Polynomial b) {
    while (!b.isZero) {
      final r = mod(a, b);
      a = b;
      b = r;
    }
    // Нормализация: делаем старший коэффициент = 1
    if (!a.isZero && a.leadingCoeff != 1) {
      final inv = _modInverse(a.leadingCoeff);
      return a.scalarMult(inv);
    }
    return a;
  }

  int _modInverse(int a) {
    a = _mod(a);
    for (int x = 1; x < p; x++) {
      if (_mod(a * x) == 1) return x;
    }
    return 1;
  }
}
import '../models/polynomial.dart';
import '../operations/polynomial_arithmetic.dart';

/// Факторизация многочленов над GF(p)
class Factorization {
  final int p;
  final PolynomialArithmetic _arith;

  Factorization(this.p) : _arith = PolynomialArithmetic(p);

  /// Факторизация x^n - 1 над GF(p)
  List<Polynomial> factorizeXnMinus1(int n) {
    // x^n - 1 = x^n + (p-1) в GF(p)
    final coeffs = List<int>.filled(n + 1, 0);
    coeffs[n] = 1;
    coeffs[0] = p - 1; // -1 mod p

    var poly = Polynomial(coeffs, p);
    return _factorize(poly);
  }

  /// Факторизация многочлена на неприводимые множители
  List<Polynomial> _factorize(Polynomial poly) {
    final factors = <Polynomial>[];

    // Проверяем корни (линейные множители)
    for (int a = 0; a < p; a++) {
      while (poly.evaluate(a) == 0 && !poly.isOne) {
        // (x - a) = (x + (p-a))
        final factor = Polynomial([(p - a) % p, 1], p);
        factors.add(factor);
        poly = _arith.div(poly, factor);
      }
    }

    // Факторизация оставшейся части через Berlekamp или перебор
    if (!poly.isOne) {
      factors.addAll(_factorizeSquareFree(poly));
    }

    return factors;
  }

  /// Факторизация бесквадратного многочлена
  List<Polynomial> _factorizeSquareFree(Polynomial poly) {
    if (poly.degree <= 1) {
      return poly.isOne ? [] : [poly];
    }

    // Для небольших степеней используем перебор делителей
    for (int d = 2; d <= poly.degree ~/ 2; d++) {
      final divisor = _findIrreducibleDivisor(poly, d);
      if (divisor != null) {
        final quotient = _arith.div(poly, divisor);
        return [divisor, ..._factorizeSquareFree(quotient)];
      }
    }

    // Если делителей не найдено, многочлен неприводим
    return [poly];
  }

  /// Поиск неприводимого делителя степени d
  Polynomial? _findIrreducibleDivisor(Polynomial poly, int d) {
    // Перебор всех мононических многочленов степени d
    final numPolys = _pow(p, d);

    for (int i = 0; i < numPolys; i++) {
      final coeffs = _intToCoeffs(i, d);
      coeffs.add(1); // Мононический (старший коэфф. = 1)

      final candidate = Polynomial(coeffs, p);

      // Проверяем, что candidate делит poly
      final (_, remainder) = _arith.divMod(poly, candidate);
      if (remainder.isZero) {
        // Проверяем неприводимость
        if (_isIrreducible(candidate)) {
          return candidate;
        }
      }
    }

    return null;
  }

  /// Проверка неприводимости многочлена
  bool _isIrreducible(Polynomial poly) {
    if (poly.degree <= 1) return true;

    // Проверяем отсутствие корней
    for (int a = 0; a < p; a++) {
      if (poly.evaluate(a) == 0) return false;
    }

    // Проверяем делимость на все многочлены меньших степеней
    for (int d = 2; d <= poly.degree ~/ 2; d++) {
      final numPolys = _pow(p, d);
      for (int i = 0; i < numPolys; i++) {
        final coeffs = _intToCoeffs(i, d);
        coeffs.add(1);

        final divisor = Polynomial(coeffs, p);
        final (_, remainder) = _arith.divMod(poly, divisor);
        if (remainder.isZero) return false;
      }
    }

    return true;
  }

  List<int> _intToCoeffs(int n, int length) {
    final result = <int>[];
    for (int i = 0; i < length; i++) {
      result.add(n % p);
      n ~/= p;
    }
    return result;
  }

  int _pow(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}
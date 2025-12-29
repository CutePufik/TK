import 'finite_field.dart';

/// Класс многочлена над конечным полем
class Polynomial {
  final FiniteField field;
  final List<int> coefficients; // coefficients[i] = коэффициент при x^i

  Polynomial(this.field, List<int> coeffs)
      : coefficients = _normalize(field, coeffs);

  /// Нормализация: убираем ведущие нули и приводим к полю
  static List<int> _normalize(FiniteField field, List<int> coeffs) {
    List<int> normalized = coeffs.map((c) => field.mod(c)).toList();
    while (normalized.length > 1 && normalized.last == 0) {
      normalized.removeLast();
    }
    if (normalized.isEmpty) {
      normalized.add(0);
    }
    return normalized;
  }

  /// Нулевой многочлен
  factory Polynomial.zero(FiniteField field) => Polynomial(field, [0]);

  /// Константный многочлен
  factory Polynomial.constant(FiniteField field, int c) =>
      Polynomial(field, [c]);

  /// Многочлен x
  factory Polynomial.x(FiniteField field) => Polynomial(field, [0, 1]);

  /// Многочлен x^n
  factory Polynomial.monomial(FiniteField field, int degree, [int coeff = 1]) {
    List<int> coeffs = List.filled(degree + 1, 0);
    coeffs[degree] = coeff;
    return Polynomial(field, coeffs);
  }

  /// Степень многочлена
  int get degree {
    if (coefficients.length == 1 && coefficients[0] == 0) {
      return -1; // Нулевой многочлен
    }
    return coefficients.length - 1;
  }

  /// Является ли нулевым
  bool get isZero => degree == -1;

  /// Ведущий коэффициент
  int get leadingCoefficient => coefficients.last;

  /// Получить коэффициент при x^i
  int operator [](int i) {
    if (i < 0 || i >= coefficients.length) return 0;
    return coefficients[i];
  }

  /// Вычислить значение многочлена в точке
  int evaluate(int x) {
    int result = 0;
    int xPow = 1;
    for (int i = 0; i < coefficients.length; i++) {
      result = field.add(result, field.mul(coefficients[i], xPow));
      xPow = field.mul(xPow, x);
    }
    return result;
  }

  /// Сложение многочленов
  Polynomial operator +(Polynomial other) {
    int maxLen =
        coefficients.length > other.coefficients.length
            ? coefficients.length
            : other.coefficients.length;
    List<int> result = List.filled(maxLen, 0);
    for (int i = 0; i < maxLen; i++) {
      result[i] = field.add(this[i], other[i]);
    }
    return Polynomial(field, result);
  }

  /// Вычитание многочленов
  Polynomial operator -(Polynomial other) {
    int maxLen =
        coefficients.length > other.coefficients.length
            ? coefficients.length
            : other.coefficients.length;
    List<int> result = List.filled(maxLen, 0);
    for (int i = 0; i < maxLen; i++) {
      result[i] = field.sub(this[i], other[i]);
    }
    return Polynomial(field, result);
  }

  /// Умножение многочленов
  Polynomial operator *(Polynomial other) {
    if (isZero || other.isZero) return Polynomial.zero(field);
    List<int> result = List.filled(degree + other.degree + 1, 0);
    for (int i = 0; i <= degree; i++) {
      for (int j = 0; j <= other.degree; j++) {
        result[i + j] = field.add(
          result[i + j],
          field.mul(coefficients[i], other.coefficients[j]),
        );
      }
    }
    return Polynomial(field, result);
  }

  /// Умножение на скаляр
  Polynomial scalarMul(int scalar) {
    return Polynomial(
      field,
      coefficients.map((c) => field.mul(c, scalar)).toList(),
    );
  }

  /// Деление с остатком: возвращает (частное, остаток)
  (Polynomial, Polynomial) divMod(Polynomial divisor) {
    if (divisor.isZero) {
      throw ArgumentError('Деление на нулевой многочлен');
    }

    Polynomial remainder = Polynomial(field, List.from(coefficients));
    List<int> quotientCoeffs = List.filled(
      degree >= divisor.degree ? degree - divisor.degree + 1 : 1,
      0,
    );

    int divisorLeadInv = field.inverse(divisor.leadingCoefficient);

    while (!remainder.isZero && remainder.degree >= divisor.degree) {
      int coeff = field.mul(remainder.leadingCoefficient, divisorLeadInv);
      int expDiff = remainder.degree - divisor.degree;

      if (expDiff < quotientCoeffs.length) {
        quotientCoeffs[expDiff] = coeff;
      }

      Polynomial term = Polynomial.monomial(field, expDiff, coeff);
      remainder = remainder - (term * divisor);
    }

    return (Polynomial(field, quotientCoeffs), remainder);
  }

  /// Деление
  Polynomial operator /(Polynomial other) => divMod(other).$1;

  /// Остаток от деления
  Polynomial operator %(Polynomial other) => divMod(other).$2;

  /// Проверка делимости
  bool isDivisibleBy(Polynomial other) => (this % other).isZero;

  @override
  String toString() {
    if (isZero) return '0';
    List<String> terms = [];
    for (int i = coefficients.length - 1; i >= 0; i--) {
      if (coefficients[i] != 0) {
        String term;
        if (i == 0) {
          term = '${coefficients[i]}';
        } else if (i == 1) {
          term =
              coefficients[i] == 1 ? 'x' : '${coefficients[i]}x';
        } else {
          term =
              coefficients[i] == 1 ? 'x^$i' : '${coefficients[i]}x^$i';
        }
        terms.add(term);
      }
    }
    return terms.isEmpty ? '0' : terms.join(' + ');
  }

  @override
  bool operator ==(Object other) {
    if (other is! Polynomial) return false;
    if (coefficients.length != other.coefficients.length) return false;
    for (int i = 0; i < coefficients.length; i++) {
      if (coefficients[i] != other.coefficients[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => coefficients.hashCode;
}
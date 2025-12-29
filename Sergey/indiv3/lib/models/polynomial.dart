/// Многочлен над конечным полем GF(p)
class Polynomial {
  /// Коэффициенты: coeffs[i] = коэффициент при x^i
  final List<int> coeffs;

  /// Характеристика поля
  final int p;

  Polynomial(List<int> coefficients, this.p)
      : coeffs = _normalize(coefficients, p);

  /// Создать нулевой многочлен
  Polynomial.zero(this.p) : coeffs = [0];

  /// Создать единичный многочлен
  Polynomial.one(this.p) : coeffs = [1];

  /// Создать моном x^degree
  Polynomial.monomial(int degree, this.p, [int coeff = 1])
      : coeffs = List.filled(degree + 1, 0) {
    (coeffs)[degree] = _mod(coeff, p);
  }

  /// Нормализация: приведение по модулю и удаление ведущих нулей
  static List<int> _normalize(List<int> c, int p) {
    final result = c.map((x) => _mod(x, p)).toList();
    while (result.length > 1 && result.last == 0) {
      result.removeLast();
    }
    return result;
  }

  static int _mod(int x, int p) => ((x % p) + p) % p;

  /// Степень многочлена (-1 для нулевого)
  int get degree => isZero ? -1 : coeffs.length - 1;

  /// Проверка на нулевой многочлен
  bool get isZero => coeffs.length == 1 && coeffs[0] == 0;

  /// Проверка на единичный многочлен
  bool get isOne => coeffs.length == 1 && coeffs[0] == 1;

  /// Старший коэффициент
  int get leadingCoeff => coeffs.last;

  /// Получить коэффициент при x^i
  int operator [](int i) => (i >= 0 && i < coeffs.length) ? coeffs[i] : 0;

  /// Вычисление значения многочлена в точке
  int evaluate(int x) {
    int result = 0;
    int power = 1;
    for (int c in coeffs) {
      result = _mod(result + c * power, p);
      power = _mod(power * x, p);
    }
    return result;
  }

  /// Возвратный (реципрокный) многочлен: x^deg * P(1/x)
  Polynomial get reciprocal {
    if (isZero) return Polynomial.zero(p);

    final reversed = coeffs.reversed.toList();
    final result = Polynomial(reversed, p);

    // Нормализация: делаем старший коэффициент равным 1
    if (!result.isZero && result.leadingCoeff != 1) {
      final inv = _modInverse(result.leadingCoeff, p);
      return result.scalarMult(inv);
    }
    return result;
  }

  /// Умножение на скаляр
  Polynomial scalarMult(int scalar) {
    return Polynomial(coeffs.map((c) => c * scalar).toList(), p);
  }

  /// Обратный элемент по модулю
  static int _modInverse(int a, int m) {
    a = _mod(a, m);
    for (int x = 1; x < m; x++) {
      if (_mod(a * x, m) == 1) return x;
    }
    return 1;
  }

  @override
  bool operator ==(Object other) {
    if (other is! Polynomial) return false;
    if (p != other.p || coeffs.length != other.coeffs.length) return false;
    for (int i = 0; i < coeffs.length; i++) {
      if (coeffs[i] != other.coeffs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(coeffs, p);

  /// Форматированный вывод многочлена
  @override
  String toString() {
    if (isZero) return '0';

    final terms = <String>[];
    for (int i = coeffs.length - 1; i >= 0; i--) {
      if (coeffs[i] == 0) continue;

      String term;
      if (i == 0) {
        term = '${coeffs[i]}';
      } else if (i == 1) {
        term = coeffs[i] == 1 ? 'x' : '${coeffs[i]}x';
      } else {
        term = coeffs[i] == 1 ? 'x^$i' : '${coeffs[i]}x^$i';
      }
      terms.add(term);
    }

    return terms.isEmpty ? '0' : terms.join(' + ');
  }

  /// Краткое представление для отладки
  String toShortString() => 'P(${coeffs.join(",")})';
}

import 'gf2_vector.dart';

/// Полином над GF(2) в кольце R = F2[X]/(X^n - 1)
class GF2Polynomial {
  final GF2Vector coefficients;

  GF2Polynomial(this.coefficients);

  /// Создание из списка коэффициентов
  factory GF2Polynomial.fromList(List<int> coeffs) {
    return GF2Polynomial(GF2Vector(coeffs));
  }

  factory GF2Polynomial.random(int n) {
    return GF2Polynomial(GF2Vector.random(n));
  }

  /// Создание разреженного полинома
  factory GF2Polynomial.sparse(int n, int weight) {
    return GF2Polynomial(GF2Vector.sparse(n, weight));
  }

  int get degree => coefficients.length - 1;
  int get n => coefficients.length;

  int operator [](int index) => coefficients[index];

  /// Сложение полиномов
  GF2Polynomial operator +(GF2Polynomial other) {
    assert(n == other.n);
    return GF2Polynomial(coefficients + other.coefficients);
  }

  /// Умножение полиномов в кольце R = F2[X]/(X^n - 1)
  /// Это циклическая свёртка
  GF2Polynomial operator *(GF2Polynomial other) {
    assert(n == other.n);
    final result = List<int>.filled(n, 0);
    
    for (int i = 0; i < n; i++) {
      if (coefficients[i] == 1) {
        for (int j = 0; j < n; j++) {
          if (other.coefficients[j] == 1) {
            final k = (i + j) % n;
            result[k] ^= 1;
          }
        }
      }
    }
    
    return GF2Polynomial.fromList(result);
  }

  /// Умножение вектора на циркулянтную матрицу rot(this)
  /// Эквивалентно w * rot(s), где w - вектор, s - полином
  GF2Vector multiplyByVector(GF2Vector w) {
    assert(n == w.length);
    final result = List<int>.filled(n, 0);
    
    // w * rot(s) = sum_i w[i] * (i-й сдвиг s)
    for (int i = 0; i < n; i++) {
      if (w[i] == 1) {
        for (int j = 0; j < n; j++) {
          // i-й сдвиг вправо: позиция j идёт в позицию (i+j) mod n
          final k = (i + j) % n;
          result[k] ^= coefficients[j];
        }
      }
    }
    
    return GF2Vector(result);
  }

  /// Получить коэффициенты как вектор
  GF2Vector toVector() => GF2Vector(coefficients.toList());

  int get weight => coefficients.weight;

  @override
  String toString() => 'Poly(${coefficients.toShortString()})';
}

/// Циркулянтная матрица, построенная из полинома
class CirculantMatrix {
  final GF2Polynomial polynomial;

  CirculantMatrix(this.polynomial);

  int get n => polynomial.n;

  /// Получить i-ю строку матрицы (циклический сдвиг на i позиций)
  GF2Vector getRow(int i) {
    final data = List<int>.filled(n, 0);
    for (int j = 0; j < n; j++) {
      // При сдвиге вправо на i: коэффициент j становится на позицию (j+i) mod n
      // Или наоборот: позиция j получает коэффициент (j-i) mod n
      final srcIdx = (j - i + n) % n;
      data[j] = polynomial[srcIdx];
    }
    return GF2Vector(data);
  }

  /// Умножение вектора на матрицу: v * M
  GF2Vector multiplyVector(GF2Vector v) {
    return polynomial.multiplyByVector(v);
  }

  @override
  String toString() {
    final buffer = StringBuffer('CirculantMatrix:\n');
    for (int i = 0; i < n; i++) {
      buffer.writeln('  ${getRow(i)}');
    }
    return buffer.toString();
  }
}
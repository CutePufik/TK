import '../models/polynomial.dart';
import '../models/gf_matrix.dart';
import '../models/cyclic_code.dart';
import '../operations/polynomial_arithmetic.dart';

/// Построение порождающих и проверочных матриц
class MatrixBuilder {
  final int p;
  final PolynomialArithmetic _arith;

  MatrixBuilder(this.p) : _arith = PolynomialArithmetic(p);

  /// Классическая порождающая матрица (сдвиги g(x))
  GFMatrix buildGeneratorMatrix(CyclicCode code) {
    final n = code.n;
    final k = code.k;
    final g = code.generator;

    final data = <List<int>>[];

    for (int i = 0; i < k; i++) {
      final row = List<int>.filled(n, 0);

      // x^i * g(x)
      for (int j = 0; j <= g.degree; j++) {
        row[i + j] = g[j];
      }

      data.add(row);
    }

    return GFMatrix(data, p);
  }

  /// Классическая проверочная матрица (сдвиги h*(x))
  GFMatrix buildCheckMatrix(CyclicCode code) {
    final n = code.n;
    final r = code.redundancy;
    final hRecip = code.check.reciprocal;

    final data = <List<int>>[];

    for (int i = 0; i < r; i++) {
      final row = List<int>.filled(n, 0);

      // x^i * h*(x)
      for (int j = 0; j <= hRecip.degree; j++) {
        row[i + j] = hRecip[j];
      }

      data.add(row);
    }

    return GFMatrix(data, p);
  }

  /// Систематическая порождающая матрица [P | I_k]
  /// Информационные символы в последних k позициях
  GFMatrix buildSystematicGenerator(CyclicCode code) {
    final n = code.n;
    final k = code.k;
    final r = n - k; // избыточность
    final g = code.generator;

    final data = <List<int>>[];

    for (int i = 0; i < k; i++) {
      final row = List<int>.filled(n, 0);

      // Информационная позиция: x^{r+i}
      final infPoly = Polynomial.monomial(r + i, p);

      // Остаток от деления на g(x)
      final remainder = _arith.mod(infPoly, g);

      // c(x) = x^{r+i} - remainder(x) mod g(x)
      // Единица в позиции r+i (единичная матрица справа)
      row[r + i] = 1;
      
      // Проверочные символы слева (отрицание остатка)
      for (int j = 0; j <= remainder.degree; j++) {
        row[j] = _mod(-remainder[j]);
      }

      data.add(row);
    }

    return GFMatrix(data, p);
  }

  /// Систематическая проверочная матрица из систематической порождающей
  /// Если G = [P | I_k], то H = [I_r | -P^T]
  GFMatrix buildSystematicCheck(GFMatrix systematicG, int k, int n) {
    final r = n - k;

    // G = [P | I_k], извлекаем P (первые r столбцов, k строк)
    final P = systematicG.subMatrix(0, 0, k, r);

    // -P^T размера r × k
    final negPT = P.transpose.negate;

    // I_r размера r × r
    final I = GFMatrix.identity(r, p);

    // H = [I_r | -P^T]
    return I.horizontalConcat(negPT);
  }

  int _mod(int x) => ((x % p) + p) % p;
}
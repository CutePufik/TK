import 'package:indiv3/algorithms/code_relations.dart';
import 'package:indiv3/algorithms/factorization.dart';
import 'package:indiv3/algorithms/matrix_builder.dart';
import 'package:indiv3/models/cyclic_code.dart';
import 'package:indiv3/models/polynomial.dart';
import 'package:indiv3/operations/polynomial_arithmetic.dart';

void main() {
  // Параметры задания
  const int n = 17;
  const int p = 2;

  print('=' * 70);
  print('ЦИКЛИЧЕСКИЕ КОДЫ: n = $n, p = $p (поле GF($p))');
  print('=' * 70);

  // 1. Факторизация x^n - 1
  print('\n--- 1. ФАКТОРИЗАЦИЯ x^$n - 1 над GF($p) ---\n');

  final factorization = Factorization(p);
  final factors = factorization.factorizeXnMinus1(n);

  print('Неприводимые множители:');
  for (int i = 0; i < factors.length; i++) {
    print('  f${i + 1}(x) = ${factors[i]}');
  }

  final numCodes = 1 << factors.length; 
  print('\nКоличество циклических кодов: 2^${factors.length} = $numCodes');

  // 2-3. Построение всех кодов
  print('\n--- 2-3. ПОРОЖДАЮЩИЕ И ПРОВЕРОЧНЫЕ МНОГОЧЛЕНЫ (РАЗМЕРНОСТИ) ---\n');

  final arith = PolynomialArithmetic(p);
  final codes = <CyclicCode>[];

  // x^n - 1
  final xnMinus1Coeffs = List<int>.filled(n + 1, 0);
  xnMinus1Coeffs[n] = 1;
  xnMinus1Coeffs[0] = (p - 1) % p;
  final xnMinus1 = Polynomial(xnMinus1Coeffs, p);

  for (int mask = 0; mask < numCodes; mask++) {
    var g = Polynomial.one(p);
    final indices = <int>[];

    for (int i = 0; i < factors.length; i++) {
      if ((mask >> i) & 1 == 1) {
        g = arith.multiply(g, factors[i]);
        indices.add(i + 1);
      }
    }

    final h = arith.div(xnMinus1, g);

    codes.add(CyclicCode(
      id: mask,
      factorIndices: indices,
      generator: g,
      check: h,
      n: n,
      p: p,
    ));
  }

  // Выводим первые 6 кодов
  print('Первые 6 кодов:');
  for (int i = 0; i < 6 && i < codes.length; i++) {
    final c = codes[i];
    print('\nКод #${c.id} [n=$n, k=${c.k}] - множители: ${c.factorIndices}');
    print('  g(x) = ${c.generator}');
    print('  h(x) = ${c.check}');
  }

  // 4. Взаимоотношения между кодами
  print('\n--- 4. ВЗАИМООТНОШЕНИЯ МЕЖДУ КОДАМИ ---\n');

  final relations = CodeRelations(codes);

  print(
      '${'Код'.padRight(6)} | ${'k'.padRight(3)} | ${'Dual'.padRight(6)} | ${'Recip'.padRight(6)} | ${'Annul'.padRight(6)}');
  print(List.filled(40, '-').join());

  for (final code in codes) {
    final rel = relations.getRelations(code);
    final dualStr = rel['dual'] != null ? '#${rel['dual']}' : 'N/A';
    final recipStr =
        rel['reciprocal'] != null ? '#${rel['reciprocal']}' : 'N/A';
    final annulStr = rel['annulator'] != null ? '#${rel['annulator']}' : 'N/A';

    print(
        '#${code.id.toString().padRight(4)} | ${code.k.toString().padRight(3)} | '
        '${dualStr.padRight(6)} | ${recipStr.padRight(6)} | ${annulStr.padRight(6)}');
  }

  // 5-6. Матрицы для двух нетривиальных кодов
  print('\n--- 5-6. ПОРОЖДАЮЩИЕ И ПРОВЕРОЧНЫЕ МАТРИЦЫ ---\n');

  final builder = MatrixBuilder(p);
  final nonTrivialCodes = codes.where((c) => c.isNonTrivial).take(2).toList();

  for (final code in nonTrivialCodes) {
    print('=' * 60);
    print('КОД #${code.id} [n=${code.n}, k=${code.k}, r=${code.redundancy}]');
    print('g(x) = ${code.generator}');
    print('h(x) = ${code.check}');
    print('=' * 60);

    // 5. Классические матрицы
    print('\n5. КЛАССИЧЕСКАЯ ПОРОЖДАЮЩАЯ МАТРИЦА G (сдвиги g(x)):');
    final G = builder.buildGeneratorMatrix(code);
    print(G.toCompactString(maxRows: 9));

    print('5. КЛАССИЧЕСКАЯ ПРОВЕРОЧНАЯ МАТРИЦА H (сдвиги h*(x)):');
    final H = builder.buildCheckMatrix(code);
    print(H.toCompactString(maxRows: 9));

    // Проверка G * H^T = 0
    final product = G.multiply(H.transpose);
    print('Проверка G * H^T = 0: ${product.isZero ? "✓ УСПЕХ" : "✗ ОШИБКА"}');

    // 6. Систематические матрицы
    print('\n6. СИСТЕМАТИЧЕСКАЯ ПОРОЖДАЮЩАЯ МАТРИЦА G_sys:');
    final Gsys = builder.buildSystematicGenerator(code);
    print(Gsys.toCompactString(maxRows: 9));

    // Проверка структуры [P | I_k]
    final rightPart = Gsys.subMatrix(0, code.redundancy, code.k, code.k);
    print(
        'Проверка правого блока (I_k): ${rightPart.isIdentity ? "✓ УСПЕХ" : "✗ ОШИБКА"}');

    print('\n6. СИСТЕМАТИЧЕСКАЯ ПРОВЕРОЧНАЯ МАТРИЦА H_sys:');
    final Hsys = builder.buildSystematicCheck(Gsys, code.k, code.n);
    print(Hsys.toCompactString(maxRows: 9));

    // Проверка ортогональности
    final productSys = Gsys.multiply(Hsys.transpose);
    print(
        'Проверка G_sys * H_sys^T = 0: ${productSys.isZero ? "✓ УСПЕХ" : "✗ ОШИБКА"}');

    print('');
  }

  print('=' * 70);
  print('ВЫПОЛНЕНИЕ ЗАВЕРШЕНО');
  print('=' * 70);
}

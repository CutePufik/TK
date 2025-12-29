import 'polynomial.dart';

/// Циклический код над GF(p)
class CyclicCode {
  final int id;
  final List<int> factorIndices; // Индексы множителей в g(x)
  final Polynomial generator; // g(x) - порождающий многочлен
  final Polynomial check; // h(x) - проверочный многочлен
  final int n; // Длина кода
  final int k; // Размерность кода
  final int p; // Характеристика поля

  CyclicCode({
    required this.id,
    required this.factorIndices,
    required this.generator,
    required this.check,
    required this.n,
    required this.p,
  }) : k = n - generator.degree;

  /// Кодовое расстояние (нижняя граница по BCH не вычисляется)
  int get redundancy => n - k;

  /// Проверка на тривиальный код
  bool get isTrivial => k == 0 || k == n;

  /// Проверка на нетривиальный код
  bool get isNonTrivial => !isTrivial;

  @override
  String toString() {
    return 'Code #$id [n=$n, k=$k, r=$redundancy] factors: $factorIndices';
  }
}
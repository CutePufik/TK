import 'dart:math';
import '../common/finite_field.dart';
import '../common/polynomial.dart';

/// Кодер Рида-Соломона
class ReedSolomonEncoder {
  final FiniteField field;
  final int n; // длина кода
  final int k; // размерность (длина сообщения)
  final List<int> evaluationPoints; // точки вычисления (α1, ..., αn)

  ReedSolomonEncoder({
    required this.field,
    required this.n,
    required this.k,
    List<int>? points,
  }) : evaluationPoints = points ?? _generatePoints(field, n) {
    if (n > field.p) {
      throw ArgumentError('n должно быть <= q (размер поля)');
    }
    if (k >= n) {
      throw ArgumentError('k должно быть < n');
    }
    if (evaluationPoints.length != n) {
      throw ArgumentError('Количество точек должно равняться n');
    }
    // Проверка на уникальность точек
    if (evaluationPoints.toSet().length != n) {
      throw ArgumentError('Точки вычисления должны быть различными');
    }
  }

  /// Генерация n различных точек из поля
  static List<int> _generatePoints(FiniteField field, int n) {
    // Используем 1, 2, 3, ..., n (или примитивные степени)
    List<int> points = [];
    for (int i = 1; i <= n && points.length < n; i++) {
      points.add(field.mod(i));
    }
    return points;
  }

  /// Максимальное количество исправляемых ошибок
  int get maxErrors => (n - k) ~/ 2;

  /// Минимальное расстояние кода
  int get minDistance => n - k + 1;

  /// Кодирование сообщения
  /// message - список из k элементов поля (коэффициенты многочлена)
  List<int> encode(List<int> message) {
    if (message.length != k) {
      throw ArgumentError('Длина сообщения должна быть $k');
    }

    // Создаем многочлен f(x) = m0 + m1*x + ... + m_{k-1}*x^{k-1}
    Polynomial f = Polynomial(field, message);

    // Вычисляем кодовое слово c = (f(α1), ..., f(αn))
    List<int> codeword = evaluationPoints.map((alpha) => f.evaluate(alpha)).toList();

    return codeword;
  }

  /// Генерация случайного вектора ошибки веса t
  List<int> generateErrorVector(int t, {Random? random}) {
    random ??= Random();
    
    if (t < 0 || t > maxErrors) {
      throw ArgumentError('t должно быть в диапазоне [0, $maxErrors]');
    }

    List<int> error = List.filled(n, 0);
    
    // Выбираем t случайных позиций
    List<int> positions = List.generate(n, (i) => i);
    positions.shuffle(random);
    List<int> errorPositions = positions.take(t).toList();

    // Генерируем ненулевые значения ошибок
    for (int pos in errorPositions) {
      int errorValue = random.nextInt(field.p - 1) + 1; // Ненулевое значение
      error[pos] = errorValue;
    }

    return error;
  }

  /// Добавление ошибки к кодовому слову
  List<int> addError(List<int> codeword, List<int> error) {
    if (codeword.length != n || error.length != n) {
      throw ArgumentError('Длины должны быть $n');
    }
    return List.generate(n, (i) => field.add(codeword[i], error[i]));
  }

  /// Вес Хэмминга вектора
  int hammingWeight(List<int> vector) {
    return vector.where((x) => x != 0).length;
  }
}
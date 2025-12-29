import '../math/gf2_vector.dart';

/// Код Рида-Маллера первого порядка RM(1, m)
/// n = 2^m, k = m + 1, d = 2^(m-1)
class ReedMullerCode {
  final int m;
  late final int n;
  late final int k;
  late final int minDistance;
  late final List<GF2Vector> generatorMatrix;

  ReedMullerCode(this.m) {
    n = 1 << m; // 2^m
    k = m + 1;
    minDistance = 1 << (m - 1); // 2^(m-1)
    generatorMatrix = _buildGeneratorMatrix();
  }

  /// Построение порождающей матрицы RM(1,m)
  /// Первая строка - все единицы
  /// Остальные m строк - булевы переменные x_0, x_1, ..., x_{m-1}
  List<GF2Vector> _buildGeneratorMatrix() {
    final matrix = <GF2Vector>[];

    // Первая строка - все единицы (константа 1)
    matrix.add(GF2Vector(List<int>.filled(n, 1)));

    // Строки для булевых переменных x_i
    for (int i = 0; i < m; i++) {
      final row = List<int>.filled(n, 0);
      for (int j = 0; j < n; j++) {
        // j-й столбец соответствует двоичному представлению j
        // i-я переменная - это i-й бит числа j
        row[j] = (j >> i) & 1;
      }
      matrix.add(GF2Vector(row));
    }

    return matrix;
  }

  /// Кодирование сообщения μ (вектор из k бит)
  GF2Vector encode(GF2Vector message) {
    assert(message.length == k, 'Сообщение должно иметь длину k=$k');

    final codeword = List<int>.filled(n, 0);
    for (int i = 0; i < k; i++) {
      if (message[i] == 1) {
        for (int j = 0; j < n; j++) {
          codeword[j] ^= generatorMatrix[i][j];
        }
      }
    }
    return GF2Vector(codeword);
  }

  /// Декодирование методом быстрого преобразования Уолша-Адамара
  /// Возвращает (декодированное сообщение, успех)
  (GF2Vector?, bool) decode(GF2Vector received) {
    assert(received.length == n);

    // Преобразуем {0,1} в {1,-1}: 0 -> 1, 1 -> -1
    final signal = List<int>.generate(n, (i) => received[i] == 0 ? 1 : -1);

    // Быстрое преобразование Уолша-Адамара
    final walsh = _fastWalshHadamard(signal);

    // Находим максимальный по модулю коэффициент
    int maxAbs = 0;
    int maxIdx = 0;
    int maxSign = 1;

    for (int i = 0; i < n; i++) {
      final absVal = walsh[i].abs();
      if (absVal > maxAbs) {
        maxAbs = absVal;
        maxIdx = i;
        maxSign = walsh[i] >= 0 ? 1 : -1;
      }
    }

    // Восстанавливаем сообщение
    // Если коэффициент положительный, первый бит = 0, иначе = 1
    final message = List<int>.filled(k, 0);
    message[0] = maxSign > 0 ? 0 : 1;

    // Остальные биты - двоичное представление maxIdx
    for (int i = 0; i < m; i++) {
      message[i + 1] = (maxIdx >> i) & 1;
    }

    // Проверяем правильность декодирования
    final decoded = encode(GF2Vector(message));
    final success = decoded == received ||
        _hammingDistance(decoded, received) <= (minDistance - 1) ~/ 2;

    return (GF2Vector(message), success);
  }

  /// Проверка, является ли вектор кодовым словом
  bool isCodeword(GF2Vector v) {
    if (v.length != n) return false;

    // Попробуем декодировать и проверить
    final (message, _) = decode(v);
    if (message == null) return false;

    final encoded = encode(message);
    return encoded == v;
  }

  /// Попытка найти сообщение, если вектор является кодовым словом
  GF2Vector? findMessage(GF2Vector v) {
    if (v.length != n) return null;

    final (message, _) = decode(v);
    if (message == null) return null;

    final encoded = encode(message);
    if (encoded == v) return message;
    return null;
  }

  /// Быстрое преобразование Уолша-Адамара
  List<int> _fastWalshHadamard(List<int> signal) {
    final result = List<int>.from(signal);
    int h = 1;

    while (h < n) {
      for (int i = 0; i < n; i += h * 2) {
        for (int j = i; j < i + h; j++) {
          final x = result[j];
          final y = result[j + h];
          result[j] = x + y;
          result[j + h] = x - y;
        }
      }
      h *= 2;
    }

    return result;
  }

  /// Расстояние Хэмминга между векторами
  int _hammingDistance(GF2Vector a, GF2Vector b) {
    return (a + b).weight;
  }

  /// Вывод порождающей матрицы
  void printGeneratorMatrix() {
    print('Порождающая матрица RM(1,$m):');
    for (int i = 0; i < k; i++) {
      print('  G[$i]: ${generatorMatrix[i]}');
    }
  }
}
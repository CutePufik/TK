import 'dart:math';

/// Вектор над полем GF(2) (бинарный вектор)
class GF2Vector {
  final List<int> _data;

  /// Создание вектора из списка битов
  GF2Vector(List<int> data) : _data = List<int>.from(data);

  /// Создание нулевого вектора заданной длины
  GF2Vector.zero(int length) : _data = List<int>.filled(length, 0);

  /// Создание случайного вектора
  factory GF2Vector.random(int length, {Random? rng}) {
    final random = rng ?? Random();
    return GF2Vector(List.generate(length, (_) => random.nextInt(2)));
  }

  /// Создание разреженного вектора с заданным весом Хэмминга
  factory GF2Vector.sparse(int length, int weight, {Random? rng}) {
    final random = rng ?? Random();
    final positions = <int>{};
    
    while (positions.length < weight) {
      positions.add(random.nextInt(length));
    }
    
    final data = List<int>.filled(length, 0);
    for (final pos in positions) {
      data[pos] = 1;
    }
    return GF2Vector(data);
  }

  /// Создание вектора с единицами в указанных позициях
  factory GF2Vector.fromPositions(int length, List<int> positions) {
    final data = List<int>.filled(length, 0);
    for (final pos in positions) {
      if (pos >= 0 && pos < length) {
        data[pos] = 1;
      }
    }
    return GF2Vector(data);
  }

  int get length => _data.length;

  int operator [](int index) => _data[index];

  void operator []=(int index, int value) {
    _data[index] = value & 1;
  }

  /// Вес Хэмминга (количество единиц)
  int get weight => _data.where((x) => x == 1).length;

  /// Сложение векторов (XOR)
  GF2Vector operator +(GF2Vector other) {
    assert(length == other.length, 'Длины векторов должны совпадать');
    return GF2Vector(List.generate(length, (i) => _data[i] ^ other._data[i]));
  }

  /// Скалярное произведение над GF(2)
  int dot(GF2Vector other) {
    assert(length == other.length);
    int result = 0;
    for (int i = 0; i < length; i++) {
      result ^= _data[i] & other._data[i];
    }
    return result;
  }

  /// Получить копию данных
  List<int> toList() => List<int>.from(_data);

  /// Получить позиции единиц
  List<int> get onePositions {
    final positions = <int>[];
    for (int i = 0; i < length; i++) {
      if (_data[i] == 1) positions.add(i);
    }
    return positions;
  }

  @override
  bool operator ==(Object other) {
    if (other is! GF2Vector) return false;
    if (length != other.length) return false;
    for (int i = 0; i < length; i++) {
      if (_data[i] != other._data[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _data.hashCode;

  @override
  String toString() => _data.join('');

  String toShortString([int maxLen = 20]) {
    if (length <= maxLen) return toString();
    return '${_data.sublist(0, maxLen).join('')}...';
  }
}
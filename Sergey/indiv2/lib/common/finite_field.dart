/// Класс для работы с конечным полем Fp (простое поле)
class FiniteField {
  final int p; // характеристика поля (простое число)

  FiniteField(this.p) {
    if (!_isPrime(p)) {
      throw ArgumentError('p должно быть простым числом');
    }
  }

  /// Проверка на простоту
  bool _isPrime(int n) {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    for (int i = 3; i * i <= n; i += 2) {
      if (n % i == 0) return false;
    }
    return true;
  }

  /// Приведение к элементу поля [0, p-1]
  int mod(int a) {
    int result = a % p;
    return result >= 0 ? result : result + p;
  }

  /// Сложение в поле
  int add(int a, int b) => mod(a + b);

  /// Вычитание в поле
  int sub(int a, int b) => mod(a - b);

  /// Умножение в поле
  int mul(int a, int b) => mod(a * b);

  /// Возведение в степень (быстрое)
  int pow(int base, int exp) {
    if (exp < 0) {
      // Отрицательная степень = обратный элемент в положительной степени
      return pow(inverse(base), -exp);
    }
    int result = 1;
    base = mod(base);
    while (exp > 0) {
      if (exp % 2 == 1) {
        result = mul(result, base);
      }
      exp ~/= 2;
      base = mul(base, base);
    }
    return result;
  }

  /// Мультипликативный обратный элемент (расширенный алгоритм Евклида)
  int inverse(int a) {
    a = mod(a);
    if (a == 0) {
      throw ArgumentError('Нельзя найти обратный к нулю');
    }
    return pow(a, p - 2); // По малой теореме Ферма
  }

  /// Деление в поле
  int div(int a, int b) => mul(a, inverse(b));

  /// Отрицание
  int neg(int a) => mod(-a);

  /// Получить все ненулевые элементы поля
  List<int> getNonZeroElements() {
    return List.generate(p - 1, (i) => i + 1);
  }

  /// Найти примитивный элемент поля
  int getPrimitiveElement() {
    for (int g = 2; g < p; g++) {
      Set<int> generated = {};
      int current = 1;
      for (int i = 0; i < p - 1; i++) {
        generated.add(current);
        current = mul(current, g);
      }
      if (generated.length == p - 1) {
        return g;
      }
    }
    throw StateError('Примитивный элемент не найден');
  }

  /// Получить степени примитивного элемента (α^0, α^1, ..., α^(p-2))
  List<int> getPrimitivePowers() {
    int alpha = getPrimitiveElement();
    List<int> powers = [];
    int current = 1;
    for (int i = 0; i < p - 1; i++) {
      powers.add(current);
      current = mul(current, alpha);
    }
    return powers;
  }

  @override
  String toString() => 'F_$p';
}
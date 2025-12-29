library;

class HammingSyndromeEmbedding {
  static const int n = 7;

  static const int r = 3;

  /// Вычисление синдрома контейнера
  ///
  /// Синдром вычисляется как H * x^T, где H - проверочная матрица,
  /// x - вектор контейнера
  static int computeSyndrome(List<int> x) {
    if (x.length != n) {
      throw ArgumentError('Длина контейнера должна быть равна $n');
    }

    int syndrome = 0;
    // Пробегаем каждый бит контейнера; если бит = 1, XOR-им его позицию
    // с аккумулятором синдрома. В результате получаем H * x^T в компактном виде.
    for (int i = 1; i <= n; i++) {
      if (x[i - 1] == 1) {
        syndrome ^= i;
      }
    }
    return syndrome;
  }

  /// Конвертация бинарного вектора в десятичное число
  static int binaryVectorToNumber(List<int> v) {
    int num = 0;
    // Сдвигаем накопитель влево и добавляем следующий бит,
    // т.е. строим число из двоичного вектора (MSB -> LSB)
    for (int i = 0; i < v.length; i++) {
      num = (num << 1) | v[i];
    }
    return num;
  }

  /// Конвертация десятичного числа в бинарный вектор
  static List<int> numberToBinaryVector(int num, int length) {
    List<int> result = List.filled(length, 0);
    // Заполняем результат побитов с конца (младшие биты числа -> конец вектора)
    for (int i = length - 1; i >= 0; i--) {
      result[i] = num & 1;
      num >>= 1;
    }
    return result;
  }

  /// Алгоритм вложения сообщения в контейнер
  static List<int> embedMessage(List<int> x, List<int> m) {
    if (x.length != n) {
      throw ArgumentError('Длина контейнера должна быть равна $n');
    }
    if (m.length != r) {
      throw ArgumentError('Длина сообщения должна быть равна $r');
    }

    // Клонируем контейнер, чтобы не менять оригинал
    List<int> result = List.from(x);

    // Текущий синдром контейнера
    int currentSyndrome = computeSyndrome(x);

    // Целевой синдром, который представляет r-битовое сообщение m
    int targetSyndrome = binaryVectorToNumber(m);

    // Если уже совпадает — ничего не делаем
    if (currentSyndrome == targetSyndrome) {
      return result;
    }

    // Разница синдромов указывает на позицию бита, который нужно перевернуть
    int syndromeDiff = targetSyndrome ^ currentSyndrome;

    // Если разница в допустимом диапазоне — переворачиваем соответствующий бит
    if (syndromeDiff == 0) {
      return result;
    } else if (syndromeDiff > 0 && syndromeDiff <= n) {
      result[syndromeDiff - 1] ^= 1;
    }

    return result;
  }

  /// Алгоритм извлечения сообщения из стегоконтейнера
  static List<int> extractMessage(List<int> x) {
    if (x.length != n) {
      throw ArgumentError('Длина контейнера должна быть равна $n');
    }

    // Вычисляем синдром контейнера и преобразуем число в r-битный вектор
    int syndrome = computeSyndrome(x);

    return numberToBinaryVector(syndrome, r);
  }

  /// Вычисление расстояния Хэмминга между двумя векторами
  static int hammingDistance(List<int> v1, List<int> v2) {
    if (v1.length != v2.length) {
      throw ArgumentError('Векторы должны быть одинаковой длины');
    }

    // Считаем количество позиций с отличающимися битами
    int distance = 0;
    for (int i = 0; i < v1.length; i++) {
      if (v1[i] != v2[i]) {
        distance++;
      }
    }
    return distance;
  }

  /// Проверка корректности вложения
  ///
  /// Проверяет, что:
  /// 1. Извлеченное сообщение совпадает с оригинальным
  /// 2. Расстояние Хэмминга между контейнерами <= 1
  ///
  /// Параметры:
  ///   - [original]: исходный контейнер
  ///   - [modified]: модифицированный контейнер
  ///   - [message]: исходное сообщение
  ///
  /// Возвращает: true если вложение корректно
  static bool verifyEmbedding(
    List<int> original,
    List<int> modified,
    List<int> message,
  ) {
    // Проверяем, что контейнеры отличаются не более чем в одном бите
    int distance = hammingDistance(original, modified);
    if (distance > 1) {
      return false;
    }

    // Извлекаем сообщение из модифицированного контейнера
    List<int> extracted = extractMessage(modified);
    if (extracted.length != message.length) {
      return false;
    }

    // Сравниваем побитно
    for (int i = 0; i < message.length; i++) {
      if (extracted[i] != message[i]) {
        return false;
      }
    }

    return true;
  }
}

library;

import 'dart:io';
import 'dart:math';

class NISTTests {
  static Future<void> exportBitsForNIST(
    List<int> bits,
    String outputPath,
  ) async {
    final file = File(outputPath);
    final buffer = StringBuffer();

    // Записываем биты как текст '0' и '1' подряд — формат, понятный для некоторых тестовых утилит
    for (int bit in bits) {
      buffer.write(bit);
    }

    await file.writeAsString(buffer.toString());
    print('✓ Экспортировано ${bits.length} битов в файл $outputPath');
    print('  Файл готов для тестирования с NIST STS');
  }

  /// Экспорт битовой последовательности в бинарном формате для NIST STS
  ///
  /// Создает файл с битами в бинарном формате (8 битов на байт),
  /// который можно использовать с NIST Statistical Test Suite
  ///
  /// Параметры:
  ///   - [bits]: последовательность битов для тестирования
  ///   - [outputPath]: путь к выходному файлу
  static Future<void> exportBitsForNISTBinary(
    List<int> bits,
    String outputPath,
  ) async {
    final file = File(outputPath);
    final bytes = <int>[];

    // Упаковываем биты в байты (8 битов на байт)
    // Проходим по потокам по 8 бит и собираем байт; если последовательность не делится на 8 —
    // дополняем в конце нулями для выравнивания
    for (int i = 0; i < bits.length; i += 8) {
      int byte = 0;
      for (int j = 0; j < 8 && i + j < bits.length; j++) {
        byte = (byte << 1) | bits[i + j];
      }
      if (i + 8 > bits.length) {
        int shift = 8 - (bits.length - i);
        byte <<= shift; // сдвигаем в младшие биты остаток
      }
      bytes.add(byte);
    }

    await file.writeAsBytes(bytes);
    print(
        '✓ Экспортировано ${bits.length} битов (${bytes.length} байт) в файл $outputPath');
    print('  Файл готов для тестирования с NIST STS (binary mode)');
  }

  /// Базовый тест частоты (Frequency Test)
  ///
  /// Проверяет, что количество 0 и 1 примерно одинаково.
  /// Реализация упрощенной версии NIST Frequency Test.
  ///
  /// Параметры:
  ///   - [bits]: последовательность битов для тестирования
  ///
  /// Возвращает: p-value теста (> 0.01 означает прохождение)
  static double frequencyTest(List<int> bits) {
    if (bits.isEmpty) return 0.0;

    int n = bits.length;
    int sum = 0;

    // Преобразование: 1 -> +1, 0 -> -1; затем стандартизованная статистика sObs
    for (int bit in bits) {
      sum += (bit == 1) ? 1 : -1;
    }

    double sObs = sum.abs() / sqrt(n);
    // p-value по доп. функции ошибок — чем больше, тем ближе к случайности
    double pValue = _erfc(sObs / sqrt(2));

    return pValue;
  }

  /// Тест серий (Runs Test)
  ///
  /// Проверяет количество последовательных серий одинаковых битов.
  /// Реализация упрощенной версии NIST Runs Test.
  ///
  /// Параметры:
  ///   - [bits]: последовательность битов для тестирования
  ///
  /// Возвращает: p-value теста (> 0.01 означает прохождение)
  static double runsTest(List<int> bits) {
    if (bits.length < 2) return 0.0;

    int n = bits.length;
    int ones = bits.where((b) => b == 1).length;
    double pi = ones / n;

    // Короткая предварительная проверка на равновесие единиц/нулей
    if ((pi - 0.5).abs() >= 2 / sqrt(n)) {
      return 0.0; // Не проходит предварительный тест
    }

    // Подсчитываем количество переходов (серий)
    int runs = 1;
    for (int i = 1; i < n; i++) {
      if (bits[i] != bits[i - 1]) {
        runs++;
      }
    }

    // Стандартизируем отклонение числа серий и вычисляем p-value
    double numerator = (runs - 2 * n * pi * (1 - pi)).abs();
    double denominator = 2 * sqrt(2 * n) * pi * (1 - pi);

    if (denominator == 0) return 0.0;

    double pValue = _erfc(numerator / denominator);

    return pValue;
  }

  /// Тест самой длинной серии единиц (Longest Run Test)
  ///
  /// Проверяет длину самых длинных последовательностей единиц.
  /// Упрощенная версия NIST Longest Run Test.
  ///
  /// Параметры:
  ///   - [bits]: последовательность битов для тестирования
  ///
  /// Возвращает: p-value теста (> 0.01 означает прохождение)
  static double longestRunTest(List<int> bits) {
    if (bits.isEmpty) return 0.0;

    int maxRun = 0;
    int currentRun = 0;

    for (int bit in bits) {
      if (bit == 1) {
        currentRun++;
        if (currentRun > maxRun) {
          maxRun = currentRun;
        }
      } else {
        currentRun = 0;
      }
    }

    // Оценочное ожидаемое значение самой длинной серии (~log2(N))
    double expectedMax = log(bits.length) / log(2);
    double deviation = (maxRun - expectedMax).abs();

    // Простая экспоненциальная оценка p-value на основе отклонения
    double pValue = exp(-deviation / expectedMax);

    return pValue.clamp(0.0, 1.0);
  }

  /// Комплексный тест псевдослучайности
  ///
  /// Применяет несколько статистических тестов и выводит результаты
  ///
  /// Параметры:
  ///   - [bits]: последовательность битов для тестирования
  ///   - [label]: метка для идентификации теста
  static void comprehensiveTest(List<int> bits, String label) {
    print('\n=== Статистическое тестирование: $label ===');
    print('Длина последовательности: ${bits.length} бит');

    int ones = bits.where((b) => b == 1).length;
    int zeros = bits.length - ones;
    double ratio = ones / bits.length;

    print('\nБазовая статистика:');
    print('  Единиц: $ones (${(ratio * 100).toStringAsFixed(2)}%)');
    print('  Нулей: $zeros (${((1 - ratio) * 100).toStringAsFixed(2)}%)');
    print(
        '  Отклонение от 50%: ${((ratio - 0.5).abs() * 100).toStringAsFixed(2)}%');

    print('\nСтатистические тесты (p-value):');

    double freqPValue = frequencyTest(bits);
    print(
        '  Frequency Test: ${freqPValue.toStringAsFixed(6)} ${_testStatus(freqPValue)}');

    double runsPValue = runsTest(bits);
    print(
        '  Runs Test: ${runsPValue.toStringAsFixed(6)} ${_testStatus(runsPValue)}');

    double longestPValue = longestRunTest(bits);
    print(
        '  Longest Run Test: ${longestPValue.toStringAsFixed(6)} ${_testStatus(longestPValue)}');

    int passed = 0;
    if (freqPValue >= 0.01) passed++;
    if (runsPValue >= 0.01) passed++;
    if (longestPValue >= 0.01) passed++;

    print('\nРезультат: $passed/3 тестов пройдено');
    if (passed == 3) {
      print('✓ Последовательность проходит базовые тесты псевдослучайности');
    } else {
      print('⚠ Последовательность не проходит все тесты');
    }
  }

  /// Вспомогательная функция: дополнительная функция ошибок (complementary error function)
  static double _erfc(double x) {
    return 1.0 - _erf(x);
  }

  /// Вспомогательная функция: функция ошибок (error function)
  static double _erf(double x) {
    // Приближение функции ошибок
    const double a1 = 0.254829592;
    const double a2 = -0.284496736;
    const double a3 = 1.421413741;
    const double a4 = -1.453152027;
    const double a5 = 1.061405429;
    const double p = 0.3275911;

    int sign = (x >= 0) ? 1 : -1;
    x = x.abs();

    double t = 1.0 / (1.0 + p * x);
    double y = 1.0 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x);

    return sign * y;
  }

  /// Статус теста на основе p-value
  static String _testStatus(double pValue) {
    if (pValue >= 0.01) {
      return '✓ PASS';
    } else {
      return '✗ FAIL';
    }
  }
}

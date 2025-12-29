library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Результат анализа изображения
class AnalysisResult {
  final int totalBits;
  final int zeroCount;
  final int oneCount;
  final double zeroPercentage;
  final double onePercentage;
  final double deviation;
  final double chiSquare;
  final bool hasAnomaly;
  final Map<String, int> channelZeros;
  final Map<String, int> channelOnes;

  AnalysisResult({
    required this.totalBits,
    required this.zeroCount,
    required this.oneCount,
    required this.zeroPercentage,
    required this.onePercentage,
    required this.deviation,
    required this.chiSquare,
    required this.hasAnomaly,
    required this.channelZeros,
    required this.channelOnes,
  });

  @override
  String toString() {
    return '''
=== Результаты стегано-анализа ===
Всего битов: $totalBits
Нулей: $zeroCount (${zeroPercentage.toStringAsFixed(2)}%)
Единиц: $oneCount (${onePercentage.toStringAsFixed(2)}%)
Отношение 0/1: ${(zeroCount / oneCount).toStringAsFixed(3)}
Отклонение от 50%: ${deviation.toStringAsFixed(2)}%
Хи-квадрат: ${chiSquare.toStringAsFixed(4)}

Анализ по каналам:
  R: ${channelZeros['R']} нулей, ${channelOnes['R']} единиц
  G: ${channelZeros['G']} нулей, ${channelOnes['G']} единиц
  B: ${channelZeros['B']} нулей, ${channelOnes['B']} единиц

Статус: ${hasAnomaly ? "⚠ ОБНАРУЖЕНА АНОМАЛИЯ" : "✓ Распределение нормальное"}
''';
  }
}

/// Класс для стегано-анализа изображений
class Steganalysis {
  static const double anomalyThreshold = 5.0;

  /// Анализ распределения младших битов в изображении
  ///
  /// Проводит статистический анализ LSB для выявления:
  /// - Отклонения от равномерного распределения 0/1
  /// - Аномалий в отдельных цветовых каналах
  /// - Хи-квадрат статистики
  ///
  /// Параметры:
  ///   - [imagePath]: путь к изображению для анализа
  ///
  /// Возвращает: результат анализа
  static Future<AnalysisResult> analyzeLSBDistribution(String imagePath) async {
    File imageFile = File(imagePath);
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Не удалось декодировать изображение');
    }

    img.Image image = decodedImage;

    // Счётчики для общей статистики и по каналам
    int zeroCount = 0;
    int oneCount = 0;
    int totalBits = 0;

    Map<String, int> channelZeros = {'R': 0, 'G': 0, 'B': 0};
    Map<String, int> channelOnes = {'R': 0, 'G': 0, 'B': 0};

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        img.Pixel pixel = image.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Для каждого канала извлекаем LSB и обновляем соответствующие счётчики
        if ((r & 1) == 0) {
          zeroCount++;
          channelZeros['R'] = channelZeros['R']! + 1;
        } else {
          oneCount++;
          channelOnes['R'] = channelOnes['R']! + 1;
        }

        if ((g & 1) == 0) {
          zeroCount++;
          channelZeros['G'] = channelZeros['G']! + 1;
        } else {
          oneCount++;
          channelOnes['G'] = channelOnes['G']! + 1;
        }

        if ((b & 1) == 0) {
          zeroCount++;
          channelZeros['B'] = channelZeros['B']! + 1;
        } else {
          oneCount++;
          channelOnes['B'] = channelOnes['B']! + 1;
        }

        // Увеличиваем общий счётчик бит (3 бита на пиксель)
        totalBits += 3;
      }
    }

    // Вычисляем процентное соотношение и простую хи-квадрат статистику
    double zeroPercentage = (zeroCount / totalBits) * 100;
    double onePercentage = (oneCount / totalBits) * 100;

    double deviation = (zeroPercentage - 50).abs();

    double expected = totalBits / 2;
    double chiSquare = pow((zeroCount - expected), 2) / expected +
        pow((oneCount - expected), 2) / expected;

    // Флаг аномалии — если отклонение от 50% больше порога
    bool hasAnomaly = deviation > anomalyThreshold;

    return AnalysisResult(
      totalBits: totalBits,
      zeroCount: zeroCount,
      oneCount: oneCount,
      zeroPercentage: zeroPercentage,
      onePercentage: onePercentage,
      deviation: deviation,
      chiSquare: chiSquare,
      hasAnomaly: hasAnomaly,
      channelZeros: channelZeros,
      channelOnes: channelOnes,
    );
  }

  static void printAnalysisResult(AnalysisResult result) {
    print(result.toString());
  }

  /// Сравнительный анализ двух изображений
  ///
  /// Сравнивает распределение LSB в исходном и стегоизображении
  ///
  /// Параметры:
  ///   - [originalPath]: путь к исходному изображению
  ///   - [stegoPath]: путь к стегоизображению
  static Future<void> compareImages(
    String originalPath,
    String stegoPath,
  ) async {
    print('\n=== Сравнительный анализ изображений ===\n');

    print('Исходное изображение:');
    AnalysisResult originalResult = await analyzeLSBDistribution(originalPath);
    printAnalysisResult(originalResult);

    print('\nСтегоизображение:');
    AnalysisResult stegoResult = await analyzeLSBDistribution(stegoPath);
    printAnalysisResult(stegoResult);

    print('\n=== Сравнение ===');
    // Сравниваем основные метрики между исходным и стего-изображением
    double deviationDiff =
        (stegoResult.deviation - originalResult.deviation).abs();
    double chiSquareDiff =
        (stegoResult.chiSquare - originalResult.chiSquare).abs();

    print('Разница в отклонении: ${deviationDiff.toStringAsFixed(2)}%');
    print('Разница в хи-квадрат: ${chiSquareDiff.toStringAsFixed(4)}');

    // Простое правило принятия: если отличия малы — изменений нет
    if (deviationDiff < 1.0 && chiSquareDiff < 1.0) {
      print('✓ Изменения незначительны - стеганография успешна');
    } else {
      print('⚠ Обнаружены заметные изменения в распределении');
    }
  }

  /// Анализ локальных областей изображения
  ///
  /// Разбивает изображение на блоки и анализирует каждый блок отдельно
  /// для выявления локальных аномалий
  ///
  /// Параметры:
  ///   - [imagePath]: путь к изображению
  ///   - [blockSize]: размер блока для анализа
  static Future<void> analyzeLocalRegions(
    String imagePath,
    int blockSize,
  ) async {
    File imageFile = File(imagePath);
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Не удалось декодировать изображение');
    }

    img.Image image = decodedImage;

    print(
        '\n=== Анализ локальных областей (блоки ${blockSize}x$blockSize) ===\n');

    int anomalyCount = 0;
    int totalBlocks = 0;

    // Проходим по блокам изображения размером blockSize x blockSize
    for (int by = 0; by < image.height; by += blockSize) {
      for (int bx = 0; bx < image.width; bx += blockSize) {
        int zeros = 0;
        int bits = 0;

        for (int y = by; y < min(by + blockSize, image.height); y++) {
          for (int x = bx; x < min(bx + blockSize, image.width); x++) {
            img.Pixel pixel = image.getPixel(x, y);
            int r = pixel.r.toInt();
            int g = pixel.g.toInt();
            int b = pixel.b.toInt();

            // Считаем нули в LSB внутри блока
            zeros += _countZerosInLSB(r, g, b);
            bits += 3;
          }
        }

        totalBlocks++;
        double zeroPercent = (zeros / bits) * 100;
        double blockDeviation = (zeroPercent - 50).abs();

        // Сообщаем о локальных аномалиях, если отклонение блока больше порога
        if (blockDeviation > anomalyThreshold) {
          anomalyCount++;
          print(
              'Блок ($bx, $by): отклонение ${blockDeviation.toStringAsFixed(2)}%');
        }
      }
    }

    print('\nВсего блоков: $totalBlocks');
    print('Блоков с аномалиями: $anomalyCount');
    print(
        'Процент аномальных блоков: ${(anomalyCount / totalBlocks * 100).toStringAsFixed(2)}%');
  }

  static int _countZerosInLSB(int r, int g, int b) {
    int count = 0;
    if ((r & 1) == 0) count++;
    if ((g & 1) == 0) count++;
    if ((b & 1) == 0) count++;
    return count;
  }
}

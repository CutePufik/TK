library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Класс для вложения с использованием секретного ключа
class KeyBasedEmbedding {
  static const int n = 7;

  static const int r = 3;

  /// Генерация зерна (Seed) для ГПСЧ из секретного ключа

  static List<int> generateSeed(String key) {
    // Кодируем строку ключа в байты и вычисляем SHA-256
    // Возвращаем байтовый массив — удобный источник энтропии для PRNG
    var bytes = utf8.encode(key);
    var digest = sha256.convert(bytes);
    return digest.bytes;
  }

  /// Генерация псевдослучайной последовательности уникальных индексов
  static List<int> generateRandomIndices(
    int totalPixels,
    int count,
    List<int> seed,
  ) {
    if (count > totalPixels) {
      throw ArgumentError('Невозможно сгенерировать $count уникальных индексов '
          'из $totalPixels доступных позиций');
    }

    // Инициализируем детерминированный PRNG из seed
    // (для криптостойкости рекомендую заменить на CSPRNG внешний)
    Random random = Random(_seedToInt(seed));
    Set<int> indices = {};

    // Генерируем уникальные индексы до достижения требуемого количества
    while (indices.length < count) {
      int index = random.nextInt(totalPixels);
      indices.add(index);
    }

    // Возвращаем список индексов в порядке генерации (без сортировки)
    return indices.toList();
  }

  /// Конвертация seed в целое число для Random
  static int _seedToInt(List<int> seed) {
    int result = 0;
    for (int i = 0; i < min(seed.length, 8); i++) {
      result = (result << 8) | seed[i];
    }
    return result;
  }

  /// Извлечение LSB битов только из выбранных (псевдослучайных) индексов
  ///

  static List<int> extractLSBBitsFromIndices(
    img.Image image,
    List<int> indices,
  ) {
    List<int> bits = [];
    int width = image.width;

    for (int index in indices) {
      int x = index % width;
      int y = index ~/ width;

      if (y < image.height) {
        img.Pixel pixel = image.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Извлекаем младшие биты из выбранных каналов в порядке R,G,B
        bits.add(r & 1);
        bits.add(g & 1);
        bits.add(b & 1);
      }
    }

    return bits;
  }

  /// Установка LSB битов только в выбранные (псевдослучайные) индексы
  ///

  static img.Image setLSBBitsToIndices(
    img.Image image,
    List<int> bits,
    List<int> indices,
  ) {
    img.Image result = image.clone();
    int bitIndex = 0;
    int width = result.width;

    for (int pixelIndex in indices) {
      if (bitIndex >= bits.length) break;

      int x = pixelIndex % width;
      int y = pixelIndex ~/ width;

      if (y < result.height) {
        img.Pixel pixel = result.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Для каждого канала очищаем LSB и записываем следующий бит из потока (если есть)
        if (bitIndex < bits.length) {
          r = (r & 0xFE) | bits[bitIndex++];
        }
        if (bitIndex < bits.length) {
          g = (g & 0xFE) | bits[bitIndex++];
        }
        if (bitIndex < bits.length) {
          b = (b & 0xFE) | bits[bitIndex++];
        }

        // Сохраняем изменённый пиксель обратно
        result.setPixelRgb(x, y, r, g, b);
      }
    }

    return result;
  }

  /// Вычисление максимальной длины сообщения при использовании ключа
  ///
  /// Параметры:
  ///   - [totalPixels]: общее количество пикселей
  ///   - [key]: секретный ключ
  ///   - [messageLength]: предполагаемая длина сообщения в битах
  ///
  /// Возвращает: максимальное количество битов сообщения
  static int calculateMaxMessageLengthWithKey(
    int totalPixels,
    String key,
    int messageLength,
  ) {
    // Корректный расчёт вместимости при использовании ключа
    // totalLSBBits = totalPixels * 3 (R,G,B)
    // Полное число доступных LSB: 3 канала на пиксель
    int totalLSBBits = totalPixels * 3;

    // Количество контейнерных n-битных блоков
    int totalBlocks = totalLSBBits ~/ n;
    int availableBlocks = totalBlocks;

    // Оценка размера заголовка (сколько r-битных блоков потребуется для хранения числа блоков)
    int bitsNeededForCount =
        (availableBlocks - 1) > 0 ? (availableBlocks - 1).bitLength : 1;
    int headerBlocksNeeded = (bitsNeededForCount + r - 1) ~/ r;

    // Максимальное количество бит сообщения — оставшиеся блоки * r
    int maxMessageBits = (availableBlocks - headerBlocksNeeded) * r;
    if (maxMessageBits < 0) maxMessageBits = 0;
    return maxMessageBits;
  }
}

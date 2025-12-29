library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'syndrome_embedding.dart';

class ImageSteganography {
  static const int n = 7;

  static const int r = 3;

  /// Извлечение младших битов (LSB) из всех пикселей изображения

  static List<int> extractLSBBits(img.Image image) {
    // Собираем все младшие биты (LSB) из каждого пикселя
    // Формат: для каждого пикселя добавляем LSB R, затем LSB G, затем LSB B
    List<int> bits = [];

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        // Получаем пиксель и каналы
        img.Pixel pixel = image.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Извлекаем младший бит каждого канала и добавляем в поток
        bits.add(r & 1); // LSB красного
        bits.add(g & 1); // LSB зелёного
        bits.add(b & 1); // LSB синего
      }
    }

    // Возвращаем последовательность бит LSB для дальнейшего разбиения на блоки
    return bits;
  }

  /// Установка младших битов (LSB) в пиксели изображения

  static img.Image setLSBBits(img.Image image, List<int> bits) {
    // Записываем битовый поток обратно в младшие биты пикселей
    // Клонируем изображение, чтобы не менять оригинал
    img.Image result = image.clone();
    int bitIndex = 0;

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        // Если биты закончились, завершаем запись
        if (bitIndex >= bits.length) break;

        img.Pixel pixel = result.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Для каждого канала сначала очищаем LSB (AND с 0xFE), затем вставляем новый бит (OR)
        if (bitIndex < bits.length) {
          r = (r & 0xFE) | bits[bitIndex++]; // записываем LSB для красного
        }
        if (bitIndex < bits.length) {
          g = (g & 0xFE) | bits[bitIndex++]; // записываем LSB для зелёного
        }
        if (bitIndex < bits.length) {
          b = (b & 0xFE) | bits[bitIndex++]; // записываем LSB для синего
        }

        // Устанавливаем обновлённый пиксель
        result.setPixelRgb(x, y, r, g, b);
      }
    }

    // Возвращаем изображение со вставленными LSB битами
    return result;
  }

  /// Кодирование сообщения в изображение с использованием LSB и синдромного вложения
  static Future<void> encodeMessageInImage(
    String inputImagePath,
    String outputImagePath,
    List<int> messageBits,
  ) async {
    File imageFile = File(inputImagePath);
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Не удалось декодировать изображение');
    }

    img.Image image = decodedImage;

    // 1) Извлекаем поток LSB битов из изображения
    List<int> lsbBits = extractLSBBits(image);

    // 2) Разбиваем поток LSB на контейнерные блоки длиной n (7 бит)
    // Каждый блок x будет использоваться для встраивания r бит (через синдром)
    List<List<int>> xBlocks = [];
    for (int i = 0; i < lsbBits.length; i += n) {
      int end = i + n <= lsbBits.length ? i + n : lsbBits.length;
      xBlocks.add(lsbBits.sublist(i, end));

      // Если последний блок короче n, дополняем нулями
      if (xBlocks.last.length < n) {
        xBlocks.last.addAll(List.filled(n - xBlocks.last.length, 0));
      }
    }

    // 3) Разбиваем сообщение на блоки длиной r (3 бита).
    // Каждый такой блок будет записан как синдром в одном контейнерном блоке.
    List<List<int>> mBlocks = [];
    for (int i = 0; i < messageBits.length; i += r) {
      int end = i + r <= messageBits.length ? i + r : messageBits.length;
      mBlocks.add(messageBits.sublist(i, end));

      // Дополняем последний блок нулями, если нужно
      if (mBlocks.last.length < r) {
        mBlocks.last.addAll(List.filled(r - mBlocks.last.length, 0));
      }
    }

    int numMessageBlocks = mBlocks.length;
    int availableBlocks = xBlocks.length;

    // Сколько бит нужно, чтобы представить число блоков (0..availableBlocks-1)
    int bitsNeededForCount =
        (availableBlocks - 1) > 0 ? (availableBlocks - 1).bitLength : 1;
    int headerBlocksNeeded = (bitsNeededForCount + r - 1) ~/
        r; // сколько блоков по r бит потребуется

    // 4) Формируем заголовок: кодируем число блоков сообщения в несколько r-битных блоков
    //    Это нужно, чтобы декодер знал, сколько блоков читать при извлечении.
    List<int> headerBits =
        _numberToBits(numMessageBlocks, headerBlocksNeeded * r);

    // Разбиваем заголовок на r-битные куски и вставляем в начало mBlocks
    List<List<int>> headerBlocks = [];
    for (int i = 0; i < headerBlocksNeeded; i++) {
      int start = i * r;
      headerBlocks.add(headerBits.sublist(start, start + r));
    }
    mBlocks.insertAll(0, headerBlocks);

    int requiredBlocks = mBlocks.length;
    if (requiredBlocks > availableBlocks) {
      throw Exception('Сообщение слишком длинное для данного изображения. '
          'Требуется $requiredBlocks блоков, доступно $availableBlocks блоков. '
          'Максимальная длина сообщения: ${(availableBlocks - headerBlocksNeeded) * r} бит.');
    }

    // 5) Потоковое вложение: для каждого r-битного блока mBlocks применяем
    //    алгоритм синдромного вложения к соответствующему контейнерному xBlocks[i]
    //    Это гарантирует, что новый контейнерный блок x̃ имеет синдром = m и
    //    отличается от оригинала не более чем в одном бите.
    List<List<int>> encodedBlocks = [];
    for (int i = 0; i < mBlocks.length; i++) {
      List<int> encodedBlock =
          HammingSyndromeEmbedding.embedMessage(xBlocks[i], mBlocks[i]);
      encodedBlocks.add(encodedBlock);
    }

    encodedBlocks.addAll(xBlocks.sublist(mBlocks.length));

    // 6) Собираем все изменённые блоки и оставшиеся неизменённые блоки
    //    в один поток бит для записи обратно в LSB
    List<int> allBits = [];
    for (var block in encodedBlocks) {
      allBits.addAll(block);
    }

    // 7) Записываем полученные биты обратно в младшие биты пикселей и сохраняем
    img.Image encodedImage = setLSBBits(image, allBits);

    List<int> encodedImageBytes = img.encodePng(encodedImage);
    await File(outputImagePath).writeAsBytes(encodedImageBytes);

    print('✓ Сообщение успешно встроено в изображение');
    print('  Длина сообщения: ${messageBits.length} бит');
    print('  Использовано блоков: ${mBlocks.length} из $availableBlocks');
  }

  /// Декодирование сообщения из стегоизображения

  static Future<List<int>> decodeMessageFromImage(String imagePath) async {
    // Загружаем изображение
    File imageFile = File(imagePath);
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Не удалось декодировать изображение');
    }

    img.Image image = decodedImage;

    // 1) Извлекаем поток LSB битов из изображения
    List<int> lsbBits = extractLSBBits(image);

    // 2) Разбиваем поток на контейнерные блоки длиной n
    List<List<int>> xBlocks = [];
    for (int i = 0; i < lsbBits.length; i += n) {
      int end = i + n <= lsbBits.length ? i + n : lsbBits.length;
      xBlocks.add(lsbBits.sublist(i, end));

      if (xBlocks.last.length < n) {
        xBlocks.last.addAll(List.filled(n - xBlocks.last.length, 0));
      }
    }

    int availableBlocks = xBlocks.length;
    int bitsNeededForCount =
        (availableBlocks - 1) > 0 ? (availableBlocks - 1).bitLength : 1;
    int headerBlocksNeeded = (bitsNeededForCount + r - 1) ~/ r;

    // 3) Читаем заголовок: первые headerBlocksNeeded блоков содержат число
    //    блоков сообщения (headerBits), каждый из этих блоков представлен
    //    как синдром H*x^T (функция extractMessage возвращает r бит)
    List<int> headerBits = [];
    for (int i = 0; i < headerBlocksNeeded; i++) {
      if (i < xBlocks.length) {
        headerBits.addAll(HammingSyndromeEmbedding.extractMessage(xBlocks[i]));
      }
    }
    int numMessageBlocks = _bitsToNumber(headerBits);

    List<int> messageBits = [];

    // 4) Читаем сами блоки сообщения: для каждого контейнерного блока
    //    вычисляем синдром (extractMessage) и добавляем r бит в поток сообщения
    for (int idx = headerBlocksNeeded;
        idx < headerBlocksNeeded + numMessageBlocks;
        idx++) {
      if (idx < xBlocks.length) {
        List<int> messageBlock =
            HammingSyndromeEmbedding.extractMessage(xBlocks[idx]);
        messageBits.addAll(messageBlock);
      }
    }

    return messageBits;
  }

  static List<int> _numberToBits(int number, int bitLength) {
    List<int> bits = List.filled(bitLength, 0);
    for (int i = bitLength - 1; i >= 0; i--) {
      bits[i] = number & 1;
      number >>= 1;
    }
    return bits;
  }

  static int _bitsToNumber(List<int> bits) {
    int number = 0;
    for (int i = 0; i < bits.length; i++) {
      number = (number << 1) | bits[i];
    }
    return number;
  }

  /// Конвертация строки в биты
  ///
  /// Каждый символ кодируется в 8 битов (ASCII/UTF-8)
  static List<int> stringToBits(String text) {
    List<int> bits = [];
    for (int i = 0; i < text.length; i++) {
      int charCode = text.codeUnitAt(i);
      for (int j = 7; j >= 0; j--) {
        bits.add((charCode >> j) & 1);
      }
    }
    return bits;
  }

  /// Конвертация битов в строку
  ///
  /// Каждые 8 битов преобразуются в символ
  static String bitsToString(List<int> bits) {
    StringBuffer result = StringBuffer();
    for (int i = 0; i < bits.length; i += 8) {
      if (i + 8 <= bits.length) {
        int charCode = 0;
        for (int j = 0; j < 8; j++) {
          charCode = (charCode << 1) | bits[i + j];
        }
        if (charCode != 0) {
          result.writeCharCode(charCode);
        }
      }
    }
    return result.toString();
  }

  /// Вычисление максимальной длины сообщения для изображения
  static Future<int> calculateMaxMessageLength(String imagePath) async {
    File imageFile = File(imagePath);
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Не удалось декодировать изображение');
    }

    img.Image image = decodedImage;

    int totalLSBBits = image.width * image.height * 3;

    int totalBlocks = totalLSBBits ~/ n;

    int availableBlocks = totalBlocks;

    int bitsNeededForCount =
        (availableBlocks - 1) > 0 ? (availableBlocks - 1).bitLength : 1;
    int headerBlocksNeeded = (bitsNeededForCount + r - 1) ~/ r;

    int maxMessageBits = (availableBlocks - headerBlocksNeeded) * r;
    if (maxMessageBits < 0) maxMessageBits = 0;

    return maxMessageBits;
  }
}

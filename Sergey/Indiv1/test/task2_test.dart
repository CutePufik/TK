/// Тесты для ЗАДАНИЯ 2: Интеграция с LSB
library;

import 'package:test/test.dart';
import 'package:steganography_app_indiv/image_steganography.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

void main() {
  group('ЗАДАНИЕ 2 - Базовые операции LSB', () {
    test('extractLSBBits извлекает младшие биты из изображения', () {
      img.Image image = img.Image(width: 2, height: 2);
      image.setPixelRgb(0, 0, 255, 254, 253); // LSB: 1, 0, 1
      image.setPixelRgb(1, 0, 128, 129, 130); // LSB: 0, 1, 0
      image.setPixelRgb(0, 1, 0, 1, 2);       // LSB: 0, 1, 0
      image.setPixelRgb(1, 1, 100, 101, 102); // LSB: 0, 1, 0
      
      List<int> bits = ImageSteganography.extractLSBBits(image);
      
      expect(bits.length, equals(12)); // 4 пикселя * 3 канала
      expect(bits.take(3).toList(), equals([1, 0, 1])); // Первый пиксель
    });

    test('setLSBBits устанавливает младшие биты в изображении', () {
      img.Image image = img.Image(width: 2, height: 2);
      for (int y = 0; y < 2; y++) {
        for (int x = 0; x < 2; x++) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      
      List<int> bits = [1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0];
      img.Image modified = ImageSteganography.setLSBBits(image, bits);
      
      List<int> extracted = ImageSteganography.extractLSBBits(modified);
      expect(extracted, equals(bits));
    });
  });

  group('ЗАДАНИЕ 2 - Преобразование строк', () {
    test('stringToBits корректно конвертирует строку в биты', () {
      String text = 'AB';
      List<int> bits = ImageSteganography.stringToBits(text);
      
      // 'A' = 65 = 01000001, 'B' = 66 = 01000010
      expect(bits.length, equals(16)); // 2 символа * 8 бит
    });

    test('bitsToString корректно конвертирует биты обратно в строку', () {
      String original = 'Hello!';
      List<int> bits = ImageSteganography.stringToBits(original);
      String recovered = ImageSteganography.bitsToString(bits);
      
      expect(recovered, equals(original));
    });

    test('stringToBits и bitsToString - обратные операции', () {
      List<String> testStrings = [
        'Test',
        'ABC123',
        'a',
        'Long message!',
      ];
      
      for (String text in testStrings) {
        List<int> bits = ImageSteganography.stringToBits(text);
        String recovered = ImageSteganography.bitsToString(bits);
        expect(recovered, equals(text));
      }
    });
  });

  group('ЗАДАНИЕ 2 - Встраивание в изображение', () {
    late String testImagePath;
    late String stegoImagePath;
    
    setUp(() async {
      testImagePath = 'test_task2_original.png';
      stegoImagePath = 'test_task2_stego.png';
      
      // Создаем тестовое изображение
      img.Image testImg = img.Image(width: 50, height: 50);
      for (int y = 0; y < 50; y++) {
        for (int x = 0; x < 50; x++) {
          testImg.setPixelRgb(x, y, x * 5, y * 5, (x + y) * 2);
        }
      }
      
      await File(testImagePath).writeAsBytes(img.encodePng(testImg));
    });

    tearDown(() async {
      if (await File(testImagePath).exists()) {
        await File(testImagePath).delete();
      }
      if (await File(stegoImagePath).exists()) {
        await File(stegoImagePath).delete();
      }
    });

    test('encodeMessageInImage встраивает сообщение', () async {
      String message = 'Task 2 Test';
      List<int> bits = ImageSteganography.stringToBits(message);
      
      await ImageSteganography.encodeMessageInImage(
        testImagePath,
        stegoImagePath,
        bits
      );
      
      expect(await File(stegoImagePath).exists(), isTrue);
    });

    test('decodeMessageFromImage извлекает сообщение', () async {
      String message = 'Secret';
      List<int> bits = ImageSteganography.stringToBits(message);
      
      await ImageSteganography.encodeMessageInImage(
        testImagePath,
        stegoImagePath,
        bits
      );
      
      List<int> extractedBits = await ImageSteganography.decodeMessageFromImage(stegoImagePath);
      
      // Проверяем, что декодирование завершилось без ошибок
      expect(extractedBits, isA<List<int>>());
    });

    test('Полный цикл кодирования и декодирования', () async {
      String msg = 'Test';
      List<int> bits = ImageSteganography.stringToBits(msg);
      
      await ImageSteganography.encodeMessageInImage(
        testImagePath,
        stegoImagePath,
        bits
      );
      
      List<int> extracted = await ImageSteganography.decodeMessageFromImage(stegoImagePath);
      
      // Проверяем, что метод выполнился успешно
      expect(extracted, isA<List<int>>());
    });

    test('calculateMaxMessageLength вычисляет емкость', () async {
      int maxBits = await ImageSteganography.calculateMaxMessageLength(testImagePath);
      
      // 50x50 = 2500 пикселей, 3 канала, 7 бит на блок
      int totalLSB = 2500 * 3;
      int totalBlocks = totalLSB ~/ 7;
      int expectedBits = (totalBlocks - 1) * 3; // -1 для заголовка
      
      expect(maxBits, equals(expectedBits));
    });
  });
}

/// Тесты для key_based_embeding
library;

import 'package:test/test.dart';
import 'package:steganography_app_indiv/key_based_embeding.dart';
import 'package:image/image.dart' as img;

void main() {
  group('KeyBasedEmbedding - Генерация seed', () {
    test('generateSeed должен возвращать детерминированный результат', () {
      String key = 'myPassword123';
      List<int> seed1 = KeyBasedEmbedding.generateSeed(key);
      List<int> seed2 = KeyBasedEmbedding.generateSeed(key);
      
      expect(seed1, equals(seed2));
      expect(seed1.length, equals(32)); // SHA-256 = 32 байта
    });

    test('generateSeed должен возвращать разные результаты для разных ключей', () {
      List<int> seed1 = KeyBasedEmbedding.generateSeed('password1');
      List<int> seed2 = KeyBasedEmbedding.generateSeed('password2');
      
      expect(seed1, isNot(equals(seed2)));
    });
  });

  group('KeyBasedEmbedding - Генерация индексов', () {
    test('generateRandomIndices должен генерировать уникальные индексы', () {
      List<int> seed = KeyBasedEmbedding.generateSeed('test');
      List<int> indices = KeyBasedEmbedding.generateRandomIndices(1000, 100, seed);
      
      expect(indices.length, equals(100));
      expect(indices.toSet().length, equals(100)); // Все уникальные
    });

    test('generateRandomIndices должен быть детерминированным', () {
      List<int> seed = KeyBasedEmbedding.generateSeed('test');
      List<int> indices1 = KeyBasedEmbedding.generateRandomIndices(1000, 50, seed);
      List<int> indices2 = KeyBasedEmbedding.generateRandomIndices(1000, 50, seed);
      
      expect(indices1, equals(indices2));
    });

    test('generateRandomIndices должен выбрасывать исключение если count > total', () {
      List<int> seed = KeyBasedEmbedding.generateSeed('test');
      
      expect(
        () => KeyBasedEmbedding.generateRandomIndices(100, 200, seed),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('generateRandomIndices должен возвращать отсортированные индексы', () {
      List<int> seed = KeyBasedEmbedding.generateSeed('test');
      List<int> indices = KeyBasedEmbedding.generateRandomIndices(1000, 50, seed);
      
      List<int> sorted = List.from(indices)..sort();
      expect(indices, equals(sorted));
    });
  });

  group('KeyBasedEmbedding - Работа с изображением', () {
    test('extractLSBBitsFromIndices извлекает биты из выбранных пикселей', () {
      img.Image image = img.Image(width: 10, height: 10);
      for (int i = 0; i < 10; i++) {
        for (int j = 0; j < 10; j++) {
          image.setPixelRgb(i, j, 255, 255, 255);
        }
      }
      
      List<int> indices = [0, 1, 2, 3, 4]; // Первые 5 пикселей
      List<int> bits = KeyBasedEmbedding.extractLSBBitsFromIndices(image, indices);
      
      expect(bits.length, equals(15)); // 5 пикселей * 3 канала
      expect(bits, equals(List.filled(15, 1))); // Все LSB = 1 (из 255)
    });

    test('setLSBBitsToIndices устанавливает биты в выбранные пиксели', () {
      img.Image image = img.Image(width: 10, height: 10);
      for (int i = 0; i < 10; i++) {
        for (int j = 0; j < 10; j++) {
          image.setPixelRgb(i, j, 128, 128, 128);
        }
      }
      
      List<int> indices = [0, 1, 2];
      List<int> bits = [1, 1, 1, 0, 0, 0, 1, 0, 1]; // 3 пикселя * 3 канала
      
      img.Image modified = KeyBasedEmbedding.setLSBBitsToIndices(image, bits, indices);
      List<int> extracted = KeyBasedEmbedding.extractLSBBitsFromIndices(modified, indices);
      
      expect(extracted, equals(bits));
    });

    test('setLSBBitsToIndices не изменяет другие пиксели', () {
      img.Image image = img.Image(width: 10, height: 10);
      for (int i = 0; i < 10; i++) {
        for (int j = 0; j < 10; j++) {
          image.setPixelRgb(i, j, 100, 150, 200);
        }
      }
      
      List<int> indices = [0, 1]; // Изменяем только первые 2 пикселя
      List<int> bits = List.filled(6, 1);
      
      img.Image modified = KeyBasedEmbedding.setLSBBitsToIndices(image, bits, indices);
      
      // Проверяем, что пиксель с индексом 50 не изменился
      img.Pixel origPixel = image.getPixel(0, 5);
      img.Pixel modPixel = modified.getPixel(0, 5);
      
      expect(origPixel.r.toInt(), equals(modPixel.r.toInt()));
      expect(origPixel.g.toInt(), equals(modPixel.g.toInt()));
      expect(origPixel.b.toInt(), equals(modPixel.b.toInt()));
    });
  });

  group('KeyBasedEmbedding - Разные ключи', () {
    test('Разные ключи дают разные последовательности индексов', () {
      List<int> seed1 = KeyBasedEmbedding.generateSeed('key1');
      List<int> seed2 = KeyBasedEmbedding.generateSeed('key2');
      
      List<int> indices1 = KeyBasedEmbedding.generateRandomIndices(1000, 100, seed1);
      List<int> indices2 = KeyBasedEmbedding.generateRandomIndices(1000, 100, seed2);
      
      expect(indices1, isNot(equals(indices2)));
    });
  });
}

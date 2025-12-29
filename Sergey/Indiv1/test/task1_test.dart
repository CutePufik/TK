/// Тесты для алгоритма синдромного вложения на основе кодов Хэмминга
library;

import 'package:test/test.dart';
import 'package:steganography_app_indiv/syndrome_embedding.dart';
import 'dart:math';

void main() {
  group('HammingSyndromeEmbedding - Базовые функции', () {
    test('computeSyndrome должен корректно вычислять синдром', () {
      // Тестовые случаи с известными синдромами
      List<int> x1 = [0, 0, 0, 0, 0, 0, 0];
      expect(HammingSyndromeEmbedding.computeSyndrome(x1), equals(0));
      
      List<int> x2 = [1, 0, 0, 0, 0, 0, 0];
      expect(HammingSyndromeEmbedding.computeSyndrome(x2), equals(1));
      
      List<int> x3 = [0, 1, 0, 0, 0, 0, 0];
      expect(HammingSyndromeEmbedding.computeSyndrome(x3), equals(2));
      
      List<int> x4 = [1, 1, 0, 0, 0, 0, 0];
      expect(HammingSyndromeEmbedding.computeSyndrome(x4), equals(3));
    });

    test('computeSyndrome должен выбрасывать исключение для неверной длины', () {
      expect(
        () => HammingSyndromeEmbedding.computeSyndrome([1, 0, 1]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('binaryVectorToNumber должен корректно конвертировать', () {
      expect(HammingSyndromeEmbedding.binaryVectorToNumber([0, 0, 0]), equals(0));
      expect(HammingSyndromeEmbedding.binaryVectorToNumber([0, 0, 1]), equals(1));
      expect(HammingSyndromeEmbedding.binaryVectorToNumber([0, 1, 0]), equals(2));
      expect(HammingSyndromeEmbedding.binaryVectorToNumber([1, 1, 1]), equals(7));
    });

    test('numberToBinaryVector должен корректно конвертировать', () {
      expect(
        HammingSyndromeEmbedding.numberToBinaryVector(0, 3),
        equals([0, 0, 0]),
      );
      expect(
        HammingSyndromeEmbedding.numberToBinaryVector(1, 3),
        equals([0, 0, 1]),
      );
      expect(
        HammingSyndromeEmbedding.numberToBinaryVector(7, 3),
        equals([1, 1, 1]),
      );
    });

    test('numberToBinaryVector и binaryVectorToNumber - обратные операции', () {
      for (int i = 0; i < 8; i++) {
        List<int> vector = HammingSyndromeEmbedding.numberToBinaryVector(i, 3);
        int result = HammingSyndromeEmbedding.binaryVectorToNumber(vector);
        expect(result, equals(i));
      }
    });
  });

  group('HammingSyndromeEmbedding - Вложение и извлечение', () {
    test('embedMessage должен корректно встраивать сообщение', () {
      List<int> x = [0, 0, 0, 0, 0, 0, 0];
      List<int> m = [1, 0, 1]; // синдром = 5
      
      List<int> modified = HammingSyndromeEmbedding.embedMessage(x, m);
      int syndrome = HammingSyndromeEmbedding.computeSyndrome(modified);
      int targetSyndrome = HammingSyndromeEmbedding.binaryVectorToNumber(m);
      
      expect(syndrome, equals(targetSyndrome));
    });

    test('embedMessage должен изменять не более 1 бита', () {
      Random random = Random(42);
      
      for (int i = 0; i < 100; i++) {
        List<int> x = List.generate(7, (_) => random.nextInt(2));
        List<int> m = List.generate(3, (_) => random.nextInt(2));
        
        List<int> modified = HammingSyndromeEmbedding.embedMessage(x, m);
        int distance = HammingSyndromeEmbedding.hammingDistance(x, modified);
        
        expect(distance, lessThanOrEqualTo(1));
      }
    });

    test('extractMessage должен корректно извлекать сообщение', () {
      List<int> x = [1, 0, 1, 0, 1, 0, 1];
      List<int> extracted = HammingSyndromeEmbedding.extractMessage(x);
      
      int syndrome = HammingSyndromeEmbedding.computeSyndrome(x);
      int extractedNumber = HammingSyndromeEmbedding.binaryVectorToNumber(extracted);
      
      expect(extractedNumber, equals(syndrome));
    });

    test('Полный цикл вложения и извлечения должен восстанавливать сообщение', () {
      Random random = Random(42);
      
      for (int i = 0; i < 100; i++) {
        List<int> x = List.generate(7, (_) => random.nextInt(2));
        List<int> m = List.generate(3, (_) => random.nextInt(2));
        
        List<int> modified = HammingSyndromeEmbedding.embedMessage(x, m);
        List<int> extracted = HammingSyndromeEmbedding.extractMessage(modified);
        
        expect(extracted, equals(m));
      }
    });

    test('embedMessage должен выбрасывать исключение для неверной длины контейнера', () {
      expect(
        () => HammingSyndromeEmbedding.embedMessage([1, 0, 1], [1, 0, 1]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('embedMessage должен выбрасывать исключение для неверной длины сообщения', () {
      expect(
        () => HammingSyndromeEmbedding.embedMessage(
          [1, 0, 1, 0, 1, 0, 1],
          [1, 0],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('HammingSyndromeEmbedding - Расстояние Хэмминга', () {
    test('hammingDistance должен корректно вычислять расстояние', () {
      expect(
        HammingSyndromeEmbedding.hammingDistance([0, 0, 0], [0, 0, 0]),
        equals(0),
      );
      expect(
        HammingSyndromeEmbedding.hammingDistance([0, 0, 0], [1, 0, 0]),
        equals(1),
      );
      expect(
        HammingSyndromeEmbedding.hammingDistance([0, 0, 0], [1, 1, 1]),
        equals(3),
      );
    });

    test('hammingDistance должен быть симметричным', () {
      List<int> v1 = [1, 0, 1, 0, 1, 0, 1];
      List<int> v2 = [0, 1, 0, 1, 0, 1, 0];
      
      expect(
        HammingSyndromeEmbedding.hammingDistance(v1, v2),
        equals(HammingSyndromeEmbedding.hammingDistance(v2, v1)),
      );
    });

    test('hammingDistance должен выбрасывать исключение для разных длин', () {
      expect(
        () => HammingSyndromeEmbedding.hammingDistance([1, 0], [1, 0, 1]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('HammingSyndromeEmbedding - Верификация', () {
    test('verifyEmbedding должен подтверждать корректное вложение', () {
      Random random = Random(42);
      
      for (int i = 0; i < 50; i++) {
        List<int> x = List.generate(7, (_) => random.nextInt(2));
        List<int> m = List.generate(3, (_) => random.nextInt(2));
        
        List<int> modified = HammingSyndromeEmbedding.embedMessage(x, m);
        bool isValid = HammingSyndromeEmbedding.verifyEmbedding(x, modified, m);
        
        expect(isValid, isTrue);
      }
    });

    test('verifyEmbedding должен отклонять неверное вложение', () {
      List<int> x = [0, 0, 0, 0, 0, 0, 0];
      List<int> m = [1, 0, 1];
      List<int> wrong = [1, 1, 0, 0, 0, 0, 0]; // Изменено 2 бита
      
      bool isValid = HammingSyndromeEmbedding.verifyEmbedding(x, wrong, m);
      
      expect(isValid, isFalse);
    });
  });

  group('HammingSyndromeEmbedding - Граничные случаи', () {
    test('Вложение в пустой контейнер', () {
      List<int> x = [0, 0, 0, 0, 0, 0, 0];
      
      for (int i = 0; i < 8; i++) {
        List<int> m = HammingSyndromeEmbedding.numberToBinaryVector(i, 3);
        List<int> modified = HammingSyndromeEmbedding.embedMessage(x, m);
        List<int> extracted = HammingSyndromeEmbedding.extractMessage(modified);
        
        expect(extracted, equals(m));
      }
    });

    test('Вложение в полный контейнер', () {
      List<int> x = [1, 1, 1, 1, 1, 1, 1];
      
      for (int i = 0; i < 8; i++) {
        List<int> m = HammingSyndromeEmbedding.numberToBinaryVector(i, 3);
        List<int> modified = HammingSyndromeEmbedding.embedMessage(x, m);
        List<int> extracted = HammingSyndromeEmbedding.extractMessage(modified);
        
        expect(extracted, equals(m));
      }
    });

    test('Все возможные комбинации сообщений', () {
      List<int> x = [1, 0, 1, 0, 1, 0, 1];
      
      for (int i = 0; i < 8; i++) {
        List<int> m = HammingSyndromeEmbedding.numberToBinaryVector(i, 3);
        List<int> modified = HammingSyndromeEmbedding.embedMessage(x, m);
        List<int> extracted = HammingSyndromeEmbedding.extractMessage(modified);
        
        expect(extracted, equals(m));
        expect(
          HammingSyndromeEmbedding.hammingDistance(x, modified),
          lessThanOrEqualTo(1),
        );
      }
    });
  });
}

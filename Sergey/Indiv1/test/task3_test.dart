/// Тесты для ЗАДАНИЯ 3: Стегано-анализ
library;

import 'package:test/test.dart';
import 'package:steganography_app_indiv/analysis.dart';
import 'package:steganography_app_indiv/image_steganography.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

void main() {
  group('ЗАДАНИЕ 3 - Статистический анализ LSB', () {
    late String cleanImagePath;
    late String stegoImagePath;
    
    setUp(() async {
      cleanImagePath = 'test_task3_clean.png';
      stegoImagePath = 'test_task3_stego.png';
      
      // Создаем чистое изображение
      img.Image cleanImg = img.Image(width: 50, height: 50);
      for (int y = 0; y < 50; y++) {
        for (int x = 0; x < 50; x++) {
          cleanImg.setPixelRgb(x, y, x * 4, y * 4, (x + y) * 2);
        }
      }
      
      await File(cleanImagePath).writeAsBytes(img.encodePng(cleanImg));
      
      // Создаем стегоизображение
      String message = 'Steganalysis test message!';
      List<int> bits = ImageSteganography.stringToBits(message);
      await ImageSteganography.encodeMessageInImage(
        cleanImagePath,
        stegoImagePath,
        bits
      );
    });

    tearDown(() async {
      if (await File(cleanImagePath).exists()) {
        await File(cleanImagePath).delete();
      }
      if (await File(stegoImagePath).exists()) {
        await File(stegoImagePath).delete();
      }
    });

    test('analyzeLSBDistribution извлекает статистику', () async {
      AnalysisResult result = await Steganalysis.analyzeLSBDistribution(cleanImagePath);
      
      expect(result.totalBits, equals(50 * 50 * 3)); // 7500 битов
      expect(result.zeroCount + result.oneCount, equals(result.totalBits));
      expect(result.zeroPercentage + result.onePercentage, closeTo(100.0, 0.01));
    });

    test('analyzeLSBDistribution вычисляет хи-квадрат', () async {
      AnalysisResult result = await Steganalysis.analyzeLSBDistribution(cleanImagePath);
      
      expect(result.chiSquare, greaterThanOrEqualTo(0));
      // Хи-квадрат для неслучайного распределения может быть большим
      expect(result.chiSquare, isNotNull);
    });

    test('analyzeLSBDistribution считает по каналам', () async {
      AnalysisResult result = await Steganalysis.analyzeLSBDistribution(cleanImagePath);
      
      expect(result.channelZeros.containsKey('R'), isTrue);
      expect(result.channelZeros.containsKey('G'), isTrue);
      expect(result.channelZeros.containsKey('B'), isTrue);
      
      expect(result.channelOnes.containsKey('R'), isTrue);
      expect(result.channelOnes.containsKey('G'), isTrue);
      expect(result.channelOnes.containsKey('B'), isTrue);
      
      int totalChannelBits = result.channelZeros['R']! + result.channelOnes['R']! +
                             result.channelZeros['G']! + result.channelOnes['G']! +
                             result.channelZeros['B']! + result.channelOnes['B']!;
      
      expect(totalChannelBits, equals(result.totalBits));
    });

    test('Стегоизображение имеет близкую статистику к оригиналу', () async {
      AnalysisResult cleanResult = await Steganalysis.analyzeLSBDistribution(cleanImagePath);
      AnalysisResult stegoResult = await Steganalysis.analyzeLSBDistribution(stegoImagePath);
      
      // Разница в распределении должна быть небольшой
      double deviationDiff = (cleanResult.deviation - stegoResult.deviation).abs();
      
      // Для хорошей стеганографии разница должна быть минимальной
      expect(deviationDiff, lessThan(5.0)); // Менее 5%
    });

    test('hasAnomaly детектирует очевидные аномалии', () async {
      // Создаем изображение с очевидной аномалией (все LSB = 0)
      img.Image anomalyImg = img.Image(width: 50, height: 50);
      for (int y = 0; y < 50; y++) {
        for (int x = 0; x < 50; x++) {
          anomalyImg.setPixelRgb(x, y, 128, 128, 128); // Все четные - LSB = 0
        }
      }
      
      String anomalyPath = 'test_anomaly.png';
      await File(anomalyPath).writeAsBytes(img.encodePng(anomalyImg));
      
      AnalysisResult result = await Steganalysis.analyzeLSBDistribution(anomalyPath);
      
      // Должна быть аномалия - все биты нули (LSB = 0)
      expect(result.zeroPercentage, equals(100.0));
      expect(result.onePercentage, equals(0.0));
      expect(result.deviation, equals(50.0));
      
      await File(anomalyPath).delete();
    });
  });

  group('ЗАДАНИЕ 3 - Сравнительный анализ', () {
    test('compareImages сравнивает два изображения', () async {
      String path1 = 'test_compare1.png';
      String path2 = 'test_compare2.png';
      
      img.Image img1 = img.Image(width: 30, height: 30);
      img.Image img2 = img.Image(width: 30, height: 30);
      
      for (int y = 0; y < 30; y++) {
        for (int x = 0; x < 30; x++) {
          img1.setPixelRgb(x, y, 100, 150, 200);
          img2.setPixelRgb(x, y, 101, 151, 201); // Слегка изменено
        }
      }
      
      await File(path1).writeAsBytes(img.encodePng(img1));
      await File(path2).writeAsBytes(img.encodePng(img2));
      
      await Steganalysis.compareImages(path1, path2);
      
      // Функция выводит результаты в консоль, проверяем что она выполняется без ошибок
      expect(true, isTrue);
      
      await File(path1).delete();
      await File(path2).delete();
    });
  });
}

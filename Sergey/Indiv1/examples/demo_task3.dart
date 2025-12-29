library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:steganography_app_indiv/analysis.dart';
import 'package:steganography_app_indiv/nist_tests.dart';
import 'package:steganography_app_indiv/image_steganography.dart';

void main() async {
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║              ЗАДАНИЕ 3: Стегано-анализ                        ║');
  print('║    Статистический анализ распределения LSB битов              ║');
  print('╚═══════════════════════════════════════════════════════════════╝\n');

  print('┌─────────────────────────────────────────────────────────────┐');
  print('│ 3.1. Подготовка тестовых изображений                       │');
  print('└─────────────────────────────────────────────────────────────┘');


  img.Image cleanImage = img.Image(width: 100, height: 100);
  final rng = Random(12345); // фиксированный семпл для воспроизводимости
  for (int y = 0; y < 100; y++) {
    for (int x = 0; x < 100; x++) {
      int r = rng.nextInt(256);
      int g = rng.nextInt(256);
      int b = rng.nextInt(256);
      cleanImage.setPixelRgb(x, y, r, g, b);
    }
  }

  String cleanPath = 'test_clean.png';
  await File(cleanPath).writeAsBytes(img.encodePng(cleanImage));
  print('✓ Создано чистое изображение: $cleanPath');

  // Запускаем NIST-подобные тесты для LSB чистого изображения
  List<int> cleanBits = ImageSteganography.extractLSBBits(cleanImage);
  NISTTests.comprehensiveTest(cleanBits, 'Clean Image LSBs');

  // Создаем стегоизображение
  String message = 'Test message for steganalysis!';
  List<int> bits = ImageSteganography.stringToBits(message);

  String stegoPath = 'test_stego.png';
  await ImageSteganography.encodeMessageInImage(cleanPath, stegoPath, bits);
  print('✓ Создано стегоизображение: $stegoPath');
  print('  Встроено: "$message"');

  // Запускаем NIST-подобные тесты для LSB стегоизображения
  Uint8List stegoBytes = await File(stegoPath).readAsBytes();
  img.Image? stegoImg = img.decodeImage(stegoBytes);
  if (stegoImg != null) {
    List<int> stegoBits = ImageSteganography.extractLSBBits(stegoImg);
    NISTTests.comprehensiveTest(stegoBits, 'Stego Image LSBs');
  }

  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 3.2. Анализ чистого изображения                            │');
  print('└─────────────────────────────────────────────────────────────┘');

  AnalysisResult cleanResult =
      await Steganalysis.analyzeLSBDistribution(cleanPath);
  print('Всего битов: ${cleanResult.totalBits}');
  print(
      'Нулей: ${cleanResult.zeroCount} (${cleanResult.zeroPercentage.toStringAsFixed(2)}%)');
  print(
      'Единиц: ${cleanResult.oneCount} (${cleanResult.onePercentage.toStringAsFixed(2)}%)');
  print('Отклонение от 50%: ${cleanResult.deviation.toStringAsFixed(2)}%');
  print('Хи-квадрат: ${cleanResult.chiSquare.toStringAsFixed(4)}');
  print('\nСтатус: ${cleanResult.hasAnomaly ? "⚠ АНОМАЛИЯ" : "✓ Норма"}');

  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 3.3. Анализ стегоизображения                               │');
  print('└─────────────────────────────────────────────────────────────┘');

  AnalysisResult stegoResult =
      await Steganalysis.analyzeLSBDistribution(stegoPath);
  print('Всего битов: ${stegoResult.totalBits}');
  print(
      'Нулей: ${stegoResult.zeroCount} (${stegoResult.zeroPercentage.toStringAsFixed(2)}%)');
  print(
      'Единиц: ${stegoResult.oneCount} (${stegoResult.onePercentage.toStringAsFixed(2)}%)');
  print('Отклонение от 50%: ${stegoResult.deviation.toStringAsFixed(2)}%');
  print('Хи-квадрат: ${stegoResult.chiSquare.toStringAsFixed(4)}');
  print('\nСтатус: ${stegoResult.hasAnomaly ? "⚠ АНОМАЛИЯ" : "✓ Норма"}');

  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 3.4. Сравнительный анализ                                  │');
  print('└─────────────────────────────────────────────────────────────┘');

  double deviationDiff = (stegoResult.deviation - cleanResult.deviation).abs();
  double chiSquareDiff = (stegoResult.chiSquare - cleanResult.chiSquare).abs();

  print('Разница в отклонении: ${deviationDiff.toStringAsFixed(2)}%');
  print('Разница в хи-квадрат: ${chiSquareDiff.toStringAsFixed(4)}');

  print('\nАнализ по каналам (стегоизображение):');
  print(
      '  R: ${stegoResult.channelZeros['R']} нулей, ${stegoResult.channelOnes['R']} единиц');
  print(
      '  G: ${stegoResult.channelZeros['G']} нулей, ${stegoResult.channelOnes['G']} единиц');
  print(
      '  B: ${stegoResult.channelZeros['B']} нулей, ${stegoResult.channelOnes['B']} единиц');

  print('\n${'═' * 65}');
  if (deviationDiff < 1.0 && chiSquareDiff < 1.0) {
    print('✓ ЗАДАНИЕ 3 ВЫПОЛНЕНО УСПЕШНО!');
  } else {
    print('⚠ Обнаружены заметные изменения в распределении');
  }
  print('═' * 65);
}

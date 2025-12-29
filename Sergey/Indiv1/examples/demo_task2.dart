/// ЗАДАНИЕ 2: Интеграция с медиа-контейнером (LSB)
/// 
/// Демонстрация встраивания в изображение PNG
library;

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:steganography_app_indiv/image_steganography.dart';

void main() async {
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║    ЗАДАНИЕ 2: Интеграция с LSB (Least Significant Bit)       ║');
  print('║              Работа с изображениями PNG                       ║');
  print('╚═══════════════════════════════════════════════════════════════╝\n');

   print('┌─────────────────────────────────────────────────────────────┐');
  print('│ 2.1. Создание тестового изображения                        │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  // Создаем тестовое изображение 100x100
  img.Image testImage = img.Image(width: 100, height: 100);
  
  // Заполняем случайными цветами
  for (int y = 0; y < testImage.height; y++) {
    for (int x = 0; x < testImage.width; x++) {
      int r = (x * 255) ~/ testImage.width;
      int g = (y * 255) ~/ testImage.height;
      int b = ((x + y) * 255) ~/ (testImage.width + testImage.height);
      testImage.setPixelRgb(x, y, r, g, b);
    }
  }
  
  String originalPath = 'test_image_original.png';
  await File(originalPath).writeAsBytes(img.encodePng(testImage));
  print('✓ Создано изображение: $originalPath (100x100 пикселей)');
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 2.2. Формирование контейнера (извлечение LSB)              │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  List<int> lsbBits = ImageSteganography.extractLSBBits(testImage);
  print('Извлечено LSB битов: ${lsbBits.length}');
  print('  - Пикселей: ${testImage.width} × ${testImage.height} = ${testImage.width * testImage.height}');
  print('  - Каналов на пиксель: 3 (R, G, B)');
  print('  - Всего LSB битов: ${testImage.width * testImage.height * 3}');
  
  // Статистика LSB
  int zeros = lsbBits.where((b) => b == 0).length;
  int ones = lsbBits.length - zeros;
  print('\nСтатистика LSB:');
  print('  - Нулей: $zeros (${(zeros / lsbBits.length * 100).toStringAsFixed(1)}%)');
  print('  - Единиц: $ones (${(ones / lsbBits.length * 100).toStringAsFixed(1)}%)');
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 2.3. Потоковое вложение (встраивание сообщения)            │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  String secretMessage = 'Task2 Demo!';
  List<int> messageBits = ImageSteganography.stringToBits(secretMessage);
  
  print('Сообщение для встраивания: "$secretMessage"');
  print('Длина в битах: ${messageBits.length} бит (${messageBits.length ~/ 8} байт)');
  
  // Вычисляем емкость
  int maxBits = await ImageSteganography.calculateMaxMessageLength(originalPath);
  print('\nЕмкость контейнера: $maxBits бит (${maxBits ~/ 8} байт)');
  print('Использовано: ${(messageBits.length / maxBits * 100).toStringAsFixed(2)}%');
  
  // Встраиваем сообщение
  String stegoPath = 'test_image_stego.png';
  await ImageSteganography.encodeMessageInImage(
    originalPath,
    stegoPath,
    messageBits
  );
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 2.4. Извлечение скрытого сообщения                         │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  List<int> extractedBits = await ImageSteganography.decodeMessageFromImage(stegoPath);
  String extractedMessage = ImageSteganography.bitsToString(extractedBits);
  
  print('Извлеченное сообщение: "$extractedMessage"');
  print('Длина: ${extractedBits.length} бит');
  
  print('\n${'═' * 65}');
  if (extractedMessage == secretMessage) {
    print('✓ ЗАДАНИЕ 2 ВЫПОЛНЕНО УСПЕШНО!');
  } else {
    print('✗ ОШИБКА: сообщения не совпадают');
  }
  print('═' * 65);
  
}

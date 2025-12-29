library;

import 'package:steganography_app_indiv/key_based_embeding.dart';

void main() {
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║   ЗАДАНИЕ 4: Секретный ключ и псевдослучайный выбор         ║');
  print('║              (Опционально +2 балла)                           ║');
  print('╚═══════════════════════════════════════════════════════════════╝\n');

  demonstrateTask4();
}

void demonstrateTask4() {
  String secretKey = 'MySecretPassword123';
  
  print('┌─────────────────────────────────────────────────────────────┐');
  print('│ 4.1. Генерация зерна (Seed) из ключа                       │');
  print('└─────────────────────────────────────────────────────────────┘');
  print('Секретный ключ K: "$secretKey"');
  
  // Шаг 1: формируем детерминированный seed из ключа через SHA-256
  // Это позволяет при одинаковом ключе получать ту же псевдослучайную последовательность
  List<int> seed = KeyBasedEmbedding.generateSeed(secretKey);
  String seedHex = seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  
  print('\nSeed = SHA-256(K):');
  print('  $seedHex');
  print('  (${seed.length} байт)');
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 4.2. Генерация псевдослучайных индексов                    │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  int totalPixels = 10000;
  int requiredPixels = 100;
  
  print('Параметры:');
  print('  - Всего пикселей в контейнере: $totalPixels');
  print('  - Требуется индексов для вложения: $requiredPixels');
  
  // Шаг 2: генерируем l уникальных псевдослучайных индексов пикселей для вложения
  // Индексы детерминированы seed и подходят для выборочного LSB-встраивания
  List<int> indices = KeyBasedEmbedding.generateRandomIndices(
    totalPixels,
    requiredPixels,
    seed
  );
  
  print('\nПсевдослучайные индексы I = {i₁, i₂, ..., iₗ}:');
  print('  Первые 20: ${indices.take(20).join(', ')}...');
  print('  Диапазон: [${indices.first}, ${indices.last}]');
  print('  Всего: ${indices.length} индексов');
  
  // Проверка уникальности сгенерированных индексов (ожидаем true)
  bool allUnique = indices.toSet().length == indices.length;
  print('\n✓ Все индексы уникальны: $allUnique');
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 4.3. Проверка детерминированности                          │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  // Генерируем еще раз с тем же ключом — проверяем детерминированность
  List<int> indices2 = KeyBasedEmbedding.generateRandomIndices(
    totalPixels,
    requiredPixels,
    seed
  );
  
  bool deterministic = true;
  for (int i = 0; i < indices.length; i++) {
    if (indices[i] != indices2[i]) {
      deterministic = false;
      break;
    }
  }
  
  print('Один ключ → одна последовательность:');
  print('  ✓ Детерминированность: $deterministic');
  
  // Проверка: другой ключ должен давать другую последовательность
  List<int> seed2 = KeyBasedEmbedding.generateSeed('DifferentKey456');
  List<int> indices3 = KeyBasedEmbedding.generateRandomIndices(
    totalPixels,
    requiredPixels,
    seed2
  );
  
  bool different = false;
  for (int i = 0; i < indices.length; i++) {
    if (indices[i] != indices3[i]) {
      different = true;
      break;
    }
  }
  
  print('  ✓ Разные ключи → разные последовательности: $different');
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 4.4. Тестирование псевдослучайности                         │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  // Шаг 4: генерируем большую выборку индексов для упрощённого теста псевдослучайности
  List<int> testIndices = KeyBasedEmbedding.generateRandomIndices(
    100000,
    10000,
    seed
  );
  
  // Преобразуем индексы в биты (младший бит индекса) — используем как сырой источник битов
  List<int> bits = testIndices.map((i) => i & 1).toList();
  
  print('Сгенерировано ${bits.length} битов для тестирования\n');
  
  // Простая оценка баланса 0/1
  int ones = bits.where((b) => b == 1).length;
  int zeros = bits.length - ones;
  double ratio = ones / bits.length;
  
  print('Базовая статистика:');
  print('  Единиц: $ones (${(ratio * 100).toStringAsFixed(2)}%)');
  print('  Нулей: $zeros (${((1 - ratio) * 100).toStringAsFixed(2)}%)');
  print('  Отклонение от 50%: ${((ratio - 0.5).abs() * 100).toStringAsFixed(2)}%');
  


  
  print('\n${'═' * 65}');
  // Итоговое сообщение: все проверки успешны => задача выполнена
  if (deterministic && different) {
    print('✓ ЗАДАНИЕ 4 ВЫПОЛНЕНО УСПЕШНО!');

  } else {
    print('⚠ Некоторые проверки не пройдены');
  }
  print('═' * 65);

}

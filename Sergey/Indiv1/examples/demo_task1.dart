library;

import 'package:steganography_app_indiv/syndrome_embedding.dart';
import 'dart:math';

void main() {
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║         ЗАДАНИЕ 1: Алгоритм синдромного вложения              ║');
  print('║              Коды Хэмминга (7,4,3)                            ║');
  print('╚═══════════════════════════════════════════════════════════════╝\n');

  Random random = Random(42); 

  List<int> x = List.generate(7, (_) => random.nextInt(2));
  List<int> m = List.generate(3, (_) => random.nextInt(2));

  print('┌─────────────────────────────────────────────────────────────┐');
  print('│ 1.1. Алгоритм ВЛОЖЕНИЯ (embedMessage)                       │');
  print('└─────────────────────────────────────────────────────────────┘');
  print('Исходный контейнер x (n=7 бит):');
  print('  x = $x');
  print('\nСообщение для вложения m (r=3 бит):');
  print('  m = $m');
  
  int originalSyndrome = HammingSyndromeEmbedding.computeSyndrome(x);
  print('\nИсходный синдром H·x^T = $originalSyndrome');
  
  List<int> xModified = HammingSyndromeEmbedding.embedMessage(x, m);
  int newSyndrome = HammingSyndromeEmbedding.computeSyndrome(xModified);
  int targetSyndrome = HammingSyndromeEmbedding.binaryVectorToNumber(m);
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
    print('│ Результат вложения:                                         │');
    print('└─────────────────────────────────────────────────────────────┘');
  print('Модифицированный контейнер x̃:');
  print('  x̃ = $xModified');
  print('\nНовый синдром H·x̃^T = $newSyndrome');
  print('Требуемый синдром (m) = $targetSyndrome');
  print('✓ Синдромы совпадают: ${newSyndrome == targetSyndrome}');
  
  int distance = HammingSyndromeEmbedding.hammingDistance(x, xModified);
  print('\nРасстояние Хэмминга d(x, x̃) = $distance');
  print('✓ Условие d(x, x̃) ≤ 1 выполнено: ${distance <= 1}');
  
  print('\n┌─────────────────────────────────────────────────────────────┐');
  print('│ 1.2. Алгоритм ИЗВЛЕЧЕНИЯ (extractMessage)                  │');
  print('└─────────────────────────────────────────────────────────────┘');
  
  // Извлечение сообщения
  List<int> mExtracted = HammingSyndromeEmbedding.extractMessage(xModified);
  print('Извлеченное сообщение m\':');
  print('  m\' = $mExtracted');
  print('\nСравнение:');
  print('  Исходное:     m  = $m');
  print('  Извлеченное:  m\' = $mExtracted');
  
  bool success = true;
  for (int i = 0; i < m.length; i++) {
    if (m[i] != mExtracted[i]) {
      success = false;
      break;
    }
  }
  
  print('\n${'═' * 65}');
  if (success && distance <= 1) {
    print('✓ ЗАДАНИЕ 1 ВЫПОЛНЕНО УСПЕШНО!');
    print('  - Сообщение извлечено корректно');
    print('  - Количество изменений минимально (d ≤ 1)');
  } else {
    print('✗ ОШИБКА в алгоритме');
  }
  print('═' * 65);
  
}


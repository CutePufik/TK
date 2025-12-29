import 'dart:io';
import 'dart:math';
import 'package:indiv4/crypto/attack.dart';
import 'package:indiv4/crypto/hqc_vulnerable.dart';
import 'package:indiv4/math/gf2_vector.dart';
import 'package:indiv4/math/reed_muller.dart';

void main() {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║     АТАКА НА УЯЗВИМУЮ ВЕРСИЮ HQC (без ошибки e)             ║');
  print('╠══════════════════════════════════════════════════════════════╣');
  print('║  Индивидуальное задание 4                                   ║');
  print('║  c2 = μG + wS  (вместо c2 = μG + wS + e)                    ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');

  while (true) {
    print('\n═══════════════════════════════════════════════════════════════');
    print('МЕНЮ:');
    print('  1. Демонстрация успешной атаки (уязвимая версия)');
    print('  2. Демонстрация неудачной атаки (версия с ошибкой e)');
    print('  3. Массовое тестирование атаки');
    print('  4. Информация о параметрах');
    print('  5. Интерактивный режим');
    print('  6. Выход');
    print('═══════════════════════════════════════════════════════════════');
    stdout.write('Выберите действие (1-6): ');

    final choice = stdin.readLineSync()?.trim();

    switch (choice) {
      case '1':
        demonstrateSuccessfulAttack();
        break;
      case '2':
        demonstrateFailedAttack();
        break;
      case '3':
        massTest();
        break;
      case '4':
        showInfo();
        break;
      case '5':
        interactiveMode();
        break;
      case '6':
        print('\nВыход из программы. До свидания!');
        return;
      default:
        print('\nНеверный выбор. Попробуйте снова.');
    }
  }
}

void demonstrateSuccessfulAttack() {
  print('\n${'─' * 60}');
  print('ДЕМОНСТРАЦИЯ УСПЕШНОЙ АТАКИ НА УЯЗВИМУЮ ВЕРСИЮ HQC');
  print('─' * 60);

  final rng = Random(42);
  const m = 4;
  const noiseWeight = 3;

  final hqc = VulnerableHQC(m: m, noiseWeight: noiseWeight);
  final code = hqc.code;

  print('\nПараметры:');
  print('   m = $m');
  print('   n = ${code.n} (длина блока)');
  print('   k = ${code.k} (размерность сообщения)');
  print('   Вес шума w = $noiseWeight');
  print('   Минимальное расстояние кода = ${code.minDistance}');

  print('\nГенерация открытого ключа...');
  final publicKey = hqc.generatePublicKey(rng: rng);
  print('   Полином s (первые 16 бит): ${publicKey.s.toVector()}');

  final message = GF2Vector.random(code.k, rng: rng);
  print('\nИсходное сообщение μ: $message');

  final encodedMessage = code.encode(message);
  print('   Кодовое слово μG: $encodedMessage');

  print('\nШифрование (БЕЗ ошибки e)...');
  final ciphertext = hqc.encrypt(message, publicKey, rng: rng);
  print('   Шифртекст c2: ${ciphertext.c2}');

  print('\nПРОВЕДЕНИЕ АТАКИ...');
  final attack = HQCAttack(
    publicKey: publicKey,
    code: code,
    maxNoiseWeight: noiseWeight,
  );

  print('   Всего кандидатов для перебора: ${attack.countCandidates()}');

  final result = attack.attack(ciphertext);

  print('\nРЕЗУЛЬТАТ АТАКИ:');
  print(result);

  if (result.success) {
    print('\nСообщение успешно восстановлено!');
    print('   Оригинал:      $message');
    print('   Восстановлено: ${result.recoveredMessage}');
    print('   Совпадение:    ${message == result.recoveredMessage ? "ДА ✓" : "НЕТ ✗"}');
  }
}

void demonstrateFailedAttack() {
  print('\n${'─' * 60}');
  print('ДЕМОНСТРАЦИЯ: АТАКА НЕ РАБОТАЕТ С ОШИБКОЙ e');
  print('─' * 60);

  final rng = Random(42);

  const m = 4;
  const noiseWeight = 3;
  const errorWeight = 5;

  final hqc = VulnerableHQC(m: m, noiseWeight: noiseWeight);
  final code = hqc.code;

  print('\nПараметры:');
  print('   m = $m, n = ${code.n}, k = ${code.k}');
  print('   Вес шума w = $noiseWeight');
  print('   Вес ошибки e = $errorWeight');

  final publicKey = hqc.generatePublicKey(rng: rng);
  final message = GF2Vector.random(code.k, rng: rng);

  print('\nИсходное сообщение: $message');

  print('\nШифрование (С ошибкой e)...');
  print('   c2 = μG + wS + e');
  final ciphertext = hqc.encryptWithError(
    message,
    publicKey,
    errorWeight: errorWeight,
    rng: rng,
  );
  print('   Шифртекст c2: ${ciphertext.c2}');

  print('\nПопытка атаки...');
  final attack = HQCAttack(
    publicKey: publicKey,
    code: code,
    maxNoiseWeight: noiseWeight,
  );
  final result = attack.attack(ciphertext);

  print('\nРЕЗУЛЬТАТ АТАКИ:');

  if (!result.success) {
    print('   Атака НЕ УДАЛАСЬ (как и ожидалось)');
    print('   Причина: добавленная ошибка e искажает кодовое слово');
    print('   Для любого кандидата w: c2 - wS = μG + e ≠ μG');
    print('   Вектор μG + e не является кодовым словом RM(1,$m)');
  } else {
    print('   Атака случайно "удалась", но сообщение неверное:');
    print('   Оригинал:      $message');
    print('   Восстановлено: ${result.recoveredMessage}');
    print('   Совпадение:    ${message == result.recoveredMessage}');
  }

  print('\nВЫВОД:');
  print('   В оригинальной версии HQC (с ошибкой e) атака полного');
  print('   перебора w НЕ РАБОТАЕТ, так как c2 - wS = μG + e,');
  print('   где e ≠ 0, и результат не является кодовым словом.');
}

void massTest() {
  print('\n${'─' * 60}');
  print('МАССОВОЕ ТЕСТИРОВАНИЕ АТАКИ');
  print('─' * 60);

  stdout.write('Количество тестов (по умолчанию 100): ');
  final input = stdin.readLineSync()?.trim();
  final numTests = int.tryParse(input ?? '') ?? 100;

  final rng = Random();
  const m = 4;
  const noiseWeight = 3;

  final hqc = VulnerableHQC(m: m, noiseWeight: noiseWeight);
  final code = hqc.code;

  int successCount = 0;
  int exactMatchCount = 0;
  int totalAttempts = 0;
  final stopwatch = Stopwatch()..start();

  print('\n🔄 Запуск $numTests тестов...\n');

  for (int i = 0; i < numTests; i++) {
    final publicKey = hqc.generatePublicKey(rng: rng);
    final message = GF2Vector.random(code.k, rng: rng);
    final ciphertext = hqc.encrypt(message, publicKey, rng: rng);

    final attack = HQCAttack(
      publicKey: publicKey,
      code: code,
      maxNoiseWeight: noiseWeight,
    );
    final result = attack.attack(ciphertext);

    if (result.success) {
      successCount++;
      if (result.recoveredMessage == message) {
        exactMatchCount++;
      }
    }
    totalAttempts += result.attempts;

    if ((i + 1) % 10 == 0) {
      stdout.write('\r   Выполнено: ${i + 1}/$numTests');
    }
  }

  stopwatch.stop();

  print('\n\nРЕЗУЛЬТАТЫ:');
  print('   Успешных атак (найдено сообщение): $successCount/$numTests (${(successCount / numTests * 100).toStringAsFixed(1)}%)');
  print('   Точное совпадение с оригиналом:    $exactMatchCount/$numTests (${(exactMatchCount / numTests * 100).toStringAsFixed(1)}%)');
  print('   Среднее число попыток: ${(totalAttempts / numTests).toStringAsFixed(1)}');
  print('   Общее время: ${stopwatch.elapsedMilliseconds} мс');
  print('   Среднее время на атаку: ${(stopwatch.elapsedMilliseconds / numTests).toStringAsFixed(2)} мс');
}

void showInfo() {
  print('\n${'─' * 60}');
  print('ИНФОРМАЦИЯ О ПАРАМЕТРАХ И АЛГОРИТМЕ');
  print('─' * 60);

  const m = 4;
  final code = ReedMullerCode(m);

  print('\nКОД РИДА-МАЛЛЕРА RM(1, $m):');
  print('   Длина блока n = 2^$m = ${code.n}');
  print('   Размерность k = $m + 1 = ${code.k}');
  print('   Минимальное расстояние d = 2^${m - 1} = ${code.minDistance}');
  print('   Исправляющая способность: ${(code.minDistance - 1) ~/ 2} ошибок');

  print('\nПОРОЖДАЮЩАЯ МАТРИЦА:');
  code.printGeneratorMatrix();

  print('\nУЯЗВИМАЯ СХЕМА:');
  print('   Открытый ключ: (G, s)');
  print('   Шифрование:    c2 = μG + wS');
  print('   где w - разреженный вектор веса 3');
  print('   S = rot(s) - циркулянтная матрица');

  print('\nАТАКА:');
  print('   1. Перебираем все возможные w веса ≤ 3');
  print('   2. Для каждого w вычисляем candidate = c2 + wS');
  print('   3. Проверяем, является ли candidate кодовым словом');
  print('   4. Если да - декодируем и получаем μ');

  print('\nСЛОЖНОСТЬ:');
  print('   Число кандидатов: C(16,0) + C(16,1) + C(16,2) + C(16,3)');
  print('                   = 1 + 16 + 120 + 560 = 697');
  print('   Это мгновенно на современных компьютерах!');

  print('\nЗАЩИТА В ОРИГИНАЛЬНОМ HQC:');
  print('   c2 = μG + wS + e');
  print('   Ошибка e делает c2 - wS = μG + e ≠ кодовому слову');
  print('   Атака перебором w не работает!');
}

void interactiveMode() {
  print('\n${'─' * 60}');
  print('ИНТЕРАКТИВНЫЙ РЕЖИМ');
  print('─' * 60);

  stdout.write('\nВведите сообщение (5 бит, например 10110): ');
  final msgInput = stdin.readLineSync()?.trim() ?? '';

  // Валидация ввода: только 0 и 1
  final filtered = msgInput.replaceAll(RegExp(r'[^01]'), '');
  
  if (filtered.isEmpty) {
    print('\n❌ Ошибка: введите двоичное число (только символы 0 и 1)');
    print('   Пример: 10110');
    return;
  }

  if (filtered != msgInput) {
    print('\n⚠️  Предупреждение: некорректные символы удалены');
    print('   Исходный ввод: "$msgInput"');
    print('   После фильтрации: "$filtered"');
  }

  // Преобразование в биты
  final msgBits = filtered.split('').map((c) => int.parse(c)).toList();
  
  // Дополнение до 5 бит или обрезка
  while (msgBits.length < 5) {
    msgBits.add(0);
  }
  if (msgBits.length > 5) {
    print('   Обрезано до 5 бит');
    msgBits.removeRange(5, msgBits.length);
  }

  final message = GF2Vector(msgBits);

  print('\nВаше сообщение: $message');

  final rng = Random();
  const m = 4;
  const noiseWeight = 3;

  final hqc = VulnerableHQC(m: m, noiseWeight: noiseWeight);
  final code = hqc.code;
  final publicKey = hqc.generatePublicKey(rng: rng);

  print('\nШифрование...');
  final ciphertext = hqc.encrypt(message, publicKey, rng: rng);
  print('   c2 = ${ciphertext.c2}');

  print('\n🔓 Атака...');
  final attack = HQCAttack(
    publicKey: publicKey,
    code: code,
    maxNoiseWeight: noiseWeight,
  );
  final result = attack.attack(ciphertext);

  print('\nРЕЗУЛЬТАТ:');
  print(result);

  if (result.success) {
    print('\n   Исходное сообщение:      $message');
    print('   Восстановленное:         ${result.recoveredMessage}');
    print('   Совпадение:              ${message == result.recoveredMessage ? "ДА ✓" : "НЕТ ✗"}');
  }
}
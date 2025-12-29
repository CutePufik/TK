import 'dart:io';
import 'dart:math';
import 'package:indiv2/common/finite_field.dart';
import 'package:indiv2/common/polynomial.dart';
import 'package:indiv2/task1/reed_solomon.dart';
import 'package:indiv2/task1/berlekamp_massey_decoder.dart';
import 'package:indiv2/task2/mpc.dart';

void main() {
  print('╔════════════════════════════════════════════════════════════════════╗');
  print('║     КОДЫ РИДА-СОЛОМОНА И МНОГОСТОРОННИЕ ВЫЧИСЛЕНИЯ (MPC)           ║');
  print('║                  Индивидуальное задание 2                          ║');
  print('╠════════════════════════════════════════════════════════════════════╣');
  print('║  Реализованный декодер:                                             ║');
  print('║    • Декодер Берлекэмпа-Мэсси                                      ║');
  print('╚════════════════════════════════════════════════════════════════════╝\n');

    while (true) {
    print('\n┌─────────────────────────────────────┐');
    print('│         ГЛАВНОЕ МЕНЮ                │');
    print('├─────────────────────────────────────┤');
    print('│ 1. Демонстрация РС-кодов (Задание 1)│');
    print('│ 2. Демонстрация MPC (Задание 2)     │');
    print('│ 3. Интерактивный тест РС-кода       │');
    print('│ 4. Интерактивный тест MPC           │');
    print('│ 5. Полный тест корректности         │');
    print('│ 0. Выход                            │');
    print('└─────────────────────────────────────┘');
    stdout.write('Ваш выбор: ');

    String? input = stdin.readLineSync();
    switch (input) {
      case '1':
        demonstrateReedSolomon();
        break;
      case '2':
        demonstrateMPC();
        break;
      case '3':
        interactiveRS();
        break;
      case '4':
        interactiveMPC();
        break;
      case '5':
        runFullCorrectnessTest();
        break;
      case '0':
        print('Выход...');
        return;
      default:
        print('Неверный выбор');
    }
  }
}

/// Демонстрация работы кодов Рида-Соломона (Задание 1)
void demonstrateReedSolomon() {
  print('\n${'═' * 70}');
  print('  ЗАДАНИЕ 1: КОДЫ РИДА-СОЛОМОНА');
  print('═' * 70);

  int p = 17;
  FiniteField field = FiniteField(p);
  print('\n[1] Конечное поле: $field');
  print('    Примитивный элемент: ${field.getPrimitiveElement()}');

  // Параметры кода
  int n = 10; // длина кода
  int k = 4; // размерность
  int t = (n - k) ~/ 2;

  print('\n[2] Параметры кода Рида-Соломона:');
  print('    n (длина кода)           = $n');
  print('    k (размерность)          = $k');
  print('    d (мин. расстояние)      = ${n - k + 1}');
  print('    t (макс. ошибок)         = $t');

  // Создаем кодер
  ReedSolomonEncoder encoder = ReedSolomonEncoder(field: field, n: n, k: k);
  print('\n[3] Точки вычисления α_i: ${encoder.evaluationPoints}');

  // Сообщение
  List<int> message = [3, 7, 1, 5];
  Polynomial msgPoly = Polynomial(field, message);

  print('\n${'─' * 70}');
  print('  (a) АЛГОРИТМ КОДИРОВАНИЯ');
  print('─' * 70);
  print('  Исходное сообщение m = $message');
  print('  Многочлен f(x) = $msgPoly');

  // Кодирование
  List<int> codeword = encoder.encode(message);
  print('  Кодовое слово c = (f(α₁),...,f(αₙ)) = $codeword');

  print('\n${'─' * 70}');
  print('  (b) ГЕНЕРАЦИЯ ВЕКТОРА ОШИБКИ');
  print('─' * 70);
  print('  Параметр t = $t (0 < t ≤ ⌊(n-k)/2⌋ = ${(n - k) ~/ 2})');

  Random random = Random(42);
  List<int> error = encoder.generateErrorVector(t, random: random);
  print('  Вектор ошибки e = $error');
  print('  Вес Хэмминга wt(e) = ${encoder.hammingWeight(error)}');

  List<int> received = encoder.addError(codeword, error);
  print('  Принятое слово z = c + e = $received');

  // Декодирование всеми декодерами
  print('\n${'─' * 70}');
  print('  ДЕКОДИРОВАНИЕ');
  print('─' * 70);
  // Декодер Берлекэмпа-Мэсси 
  print('\n  ▸ Декодер Берлекэмпа-Мэсси:');
  BerlekampMasseyDecoder bmDecoder = BerlekampMasseyDecoder(encoder);
  DecodingResult bmResult = bmDecoder.decode(received);
  _printDecodingResult(bmResult, message);
}

void _printDecodingResult(DecodingResult result, List<int> original) {
  if (result.success) {
    print('    Статус: ✓ УСПЕХ');
    print('    Восстановленное сообщение: ${result.message}');
    print('    Многочлен: ${result.polynomial}');
    print('    Позиции ошибок: ${result.errorPositions}');
    bool correct = _listEquals(result.message!, original);
    print('    Проверка: ${correct ? "✓ ВЕРНО" : "✗ НЕВЕРНО"}');
  } else {
    print('    Статус: ✗ ОШИБКА');
    print('    Причина: ${result.errorMessage}');
  }
}

/// Сравнение всех декодеров на множестве тестов
void compareAllDecoders() {
  print('\n${'═' * 70}');
  print('  СРАВНЕНИЕ ВСЕХ ДЕКОДЕРОВ');
  print('═' * 70);

  int p = 23;
  FiniteField field = FiniteField(p);
  int n = 12;
  int k = 4;

  ReedSolomonEncoder encoder = ReedSolomonEncoder(field: field, n: n, k: k);
  BerlekampMasseyDecoder bmDecoder = BerlekampMasseyDecoder(encoder);

  print('\nПараметры: F_$p, n=$n, k=$k, t=${encoder.maxErrors}');
  print('\n${'─' * 70}');
  print('  Тест  │ Ошибок │ Берл-Мэсси');
  print('─' * 70);

  Random random = Random(12345);
  int numTests = 10;
  int bmSuccess = 0;

  for (int test = 1; test <= numTests; test++) {
    // Случайное сообщение
    List<int> message = List.generate(k, (_) => random.nextInt(p));
    List<int> codeword = encoder.encode(message);

    // Случайное количество ошибок
    int numErrors = random.nextInt(encoder.maxErrors + 1);
    List<int> error = encoder.generateErrorVector(numErrors, random: random);
    List<int> received = encoder.addError(codeword, error);

    // Декодирование BM
    var bm = bmDecoder.decode(received);
    bool bmOk = bm.success && _listEquals(bm.message!, message);
    if (bmOk) bmSuccess++;

    print('  ${test.toString().padLeft(5)} │ ${numErrors.toString().padLeft(6)} │ '
      '${bmOk ? "✓ OK     " : "✗ FAIL   "}');
  }

  print('─' * 70);
  print('  ИТОГО │        │ $bmSuccess/$numTests');
  print('═' * 70);
}

/// Демонстрация MPC протокола (Задание 2)
void demonstrateMPC() {
  print('\n${'═' * 70}');
  print('  ЗАДАНИЕ 2: MPC ПРОТОКОЛ');
  print('═' * 70);

  int p = 23;
  int n = 7;
  int t = 2;

  print('\n[1] Параметры протокола:');
  print('    Поле: F_$p');
  print('    Участников: n = $n');
  print('    Порог Шамира: t + 1 = ${t + 1}');
  print('    Макс. нечестных: t = $t');
  print('    Условие 2t < n: ${2 * t} < $n ${2 * t < n ? "✓" : "✗"}');

  FiniteField field = FiniteField(p);

  List<int> secrets = [5, 8, 3, 12, 7, 9, 2];
  List<int> weights = [1, 2, 1, 3, 1, 2, 1];

  print('\n[2] Секреты участников:');
  for (int i = 0; i < n; i++) {
    print('    s_${i + 1} = ${secrets[i]}');
  }

  print('\n[3] Веса λ:');
  for (int i = 0; i < n; i++) {
    print('    λ_${i + 1} = ${weights[i]}');
  }

  int expected = 0;
  for (int i = 0; i < n; i++) {
    expected = field.add(expected, field.mul(weights[i], secrets[i]));
  }
  print('\n[4] Ожидаемый результат: Σλ_j·s_j = $expected');

  MPCSimulator simulator = MPCSimulator(
    field: field,
    n: n,
    t: t,
    secrets: secrets,
    weights: weights,
  );

  Random random = Random(123);
  MPCResult result = simulator.runProtocol(numCorrupted: t, random: random);

  print('\n${'═' * 70}');
  print('  ИТОГОВЫЙ РЕЗУЛЬТАТ');
  print('═' * 70);
  print('  Вычисленное значение: ${result.computedValue}');
  print('  Ожидаемое значение: $expected');
  print('  Статус: ${result.success ? "✓ УСПЕХ" : "✗ ОШИБКА"}');
  print('  Нечестные участники: ${result.corruptedIds}');
}

/// Интерактивное тестирование РС-кода
void interactiveRS() {
  print('\n${'─' * 50}');
  print('  ИНТЕРАКТИВНЫЙ ТЕСТ РС-КОДА');
  print('${'─' * 50}\n');

  stdout.write('Размер поля p (простое, например 17): ');
  int p = int.tryParse(stdin.readLineSync() ?? '') ?? 17;

  FiniteField field;
  try {
    field = FiniteField(p);
  } catch (e) {
    print('Ошибка: $e');
    return;
  }

  stdout.write('Длина кода n (n <= $p): ');
  int n = int.tryParse(stdin.readLineSync() ?? '') ?? 10;

  stdout.write('Размерность k (k < n): ');
  int k = int.tryParse(stdin.readLineSync() ?? '') ?? 4;

  ReedSolomonEncoder encoder;
  try {
    encoder = ReedSolomonEncoder(field: field, n: n, k: k);
  } catch (e) {
    print('Ошибка: $e');
    return;
  }

  print('Макс. ошибок: ${encoder.maxErrors}');

  stdout.write('Введите $k элементов сообщения через пробел: ');
  List<int> message;
  try {
    message =
        (stdin.readLineSync() ?? '')
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s.trim()))
            .toList();
    if (message.length != k) throw Exception('Нужно $k элементов');
  } catch (e) {
    print('Ошибка: $e');
    return;
  }

  List<int> codeword = encoder.encode(message);
  print('Кодовое слово: $codeword');

  stdout.write('Количество ошибок t (0-${encoder.maxErrors}): ');
  int t = int.tryParse(stdin.readLineSync() ?? '') ?? 0;

  List<int> error = encoder.generateErrorVector(t);
  print('Вектор ошибки: $error');

  List<int> received = encoder.addError(codeword, error);
  print('Принятое слово: $received');

  print('\nВыберите декодер:');
  // Используем единственный декодер — Берлекэмпа-Мэсси
  DecodingResult result = BerlekampMasseyDecoder(encoder).decode(received);

  _printDecodingResult(result, message);
}

/// Интерактивное тестирование MPC
void interactiveMPC() {
  print('\n${'─' * 50}');
  print('  ИНТЕРАКТИВНЫЙ ТЕСТ MPC');
  print('${'─' * 50}\n');

  stdout.write('Размер поля p (простое, например 23): ');
  int p = int.tryParse(stdin.readLineSync() ?? '') ?? 23;

  FiniteField field;
  try {
    field = FiniteField(p);
  } catch (e) {
    print('Ошибка: $e');
    return;
  }

  stdout.write('Количество участников n: ');
  int n = int.tryParse(stdin.readLineSync() ?? '') ?? 5;

  stdout.write('Порог t (2t < n): ');
  int t = int.tryParse(stdin.readLineSync() ?? '') ?? 1;

  if (2 * t >= n) {
    print('Ошибка: требуется 2t < n');
    return;
  }

  stdout.write('Введите $n секретов через пробел: ');
  List<int> secrets;
  try {
    secrets =
        (stdin.readLineSync() ?? '')
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s.trim()))
            .toList();
    if (secrets.length != n) throw Exception('Нужно $n секретов');
  } catch (e) {
    print('Ошибка: $e');
    return;
  }

  stdout.write('Введите $n весов λ через пробел: ');
  List<int> weights;
  try {
    weights =
        (stdin.readLineSync() ?? '')
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s.trim()))
            .toList();
    if (weights.length != n) throw Exception('Нужно $n весов');
  } catch (e) {
    print('Ошибка: $e');
    return;
  }

  stdout.write('Количество нечестных (макс $t): ');
  int numCorrupted = int.tryParse(stdin.readLineSync() ?? '') ?? t;

  MPCSimulator simulator = MPCSimulator(
    field: field,
    n: n,
    t: t,
    secrets: secrets,
    weights: weights,
  );

  MPCResult result = simulator.runProtocol(numCorrupted: numCorrupted);

  int expected = 0;
  for (int i = 0; i < n; i++) {
    expected = field.add(expected, field.mul(weights[i], secrets[i]));
  }

  print('\n${'═' * 40}');
  print('РЕЗУЛЬТАТ: ${result.success ? "✓ УСПЕХ" : "✗ ОШИБКА"}');
  print('Вычислено: ${result.computedValue}, Ожидалось: $expected');
  print('Нечестные: ${result.corruptedIds}');
}

/// Полный тест корректности всех компонентов
void runFullCorrectnessTest() {
  print('\n${'═' * 70}');
  print('  ПОЛНЫЙ ТЕСТ КОРРЕКТНОСТИ');
  print('═' * 70);

  Random random = Random(999);
  int passed = 0;
  int total = 0;

  // Тест 1: Кодирование и декодирование без ошибок
  print('\n[Тест 1] Кодирование/декодирование без ошибок...');
  for (int p in [7, 11, 13, 17, 23]) {
    FiniteField field = FiniteField(p);
    for (int n = 4; n <= p - 1 && n <= 10; n++) {
      for (int k = 2; k < n - 1; k++) {
        ReedSolomonEncoder encoder = ReedSolomonEncoder(
          field: field,
          n: n,
          k: k,
        );

        List<int> message = List.generate(k, (_) => random.nextInt(p));
        List<int> codeword = encoder.encode(message);

        var bm = BerlekampMasseyDecoder(encoder).decode(codeword);

        total++;
        if (bm.success && _listEquals(bm.message!, message)) passed++;
      }
    }
  }
  print('   Без ошибок: $passed/$total');

  // Тест 2: С ошибками
  print('\n[Тест 2] Декодирование с ошибками...');
  int errPassed = 0;
  int errTotal = 0;

  FiniteField field = FiniteField(17);
  ReedSolomonEncoder encoder = ReedSolomonEncoder(field: field, n: 10, k: 4);

  for (int trial = 0; trial < 50; trial++) {
    List<int> message = List.generate(4, (_) => random.nextInt(17));
    List<int> codeword = encoder.encode(message);

    int numErrors = random.nextInt(encoder.maxErrors + 1);
    List<int> error = encoder.generateErrorVector(numErrors, random: random);
    List<int> received = encoder.addError(codeword, error);

    var bm = BerlekampMasseyDecoder(encoder).decode(received);

    errTotal++;
    if (bm.success && _listEquals(bm.message!, message)) errPassed++;
  }
  print('   С ошибками: $errPassed/$errTotal');

  // Тест 3: MPC
  print('\n[Тест 3] MPC протокол...');
  int mpcPassed = 0;
  int mpcTotal = 10;

  for (int trial = 0; trial < mpcTotal; trial++) {
    int p = 23;
    int n = 7;
    int t = 2;

    FiniteField mpcField = FiniteField(p);
    List<int> secrets = List.generate(n, (_) => random.nextInt(p));
    List<int> weights = List.generate(n, (_) => random.nextInt(p));

    MPCSimulator sim = MPCSimulator(
      field: mpcField,
      n: n,
      t: t,
      secrets: secrets,
      weights: weights,
    );

    MPCResult result = sim.runProtocol(numCorrupted: t, random: random);

    int expected = 0;
    for (int i = 0; i < n; i++) {
      expected = mpcField.add(expected, mpcField.mul(weights[i], secrets[i]));
    }

    if (result.success && result.computedValue == expected) {
      mpcPassed++;
    }
  }
  print('   MPC: $mpcPassed/$mpcTotal');

  print('\n${'═' * 70}');
  print(
    '  ОБЩИЙ РЕЗУЛЬТАТ: ${passed + errPassed + mpcPassed}/${total + errTotal + mpcTotal}',
  );
  print('═' * 70);
}
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
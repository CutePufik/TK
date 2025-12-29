import 'dart:math';
import '../common/finite_field.dart';
import 'shamir.dart';
import '../task1/reed_solomon.dart';
import '../task1/berlekamp_massey_decoder.dart';

/// Участник MPC протокола
class Participant {
  final int id; // ID участника (1, 2, ..., n)
  final int secret; // Приватный секрет
  List<Share> receivedShares = []; // Полученные доли от других участников
  int? localResult; // Результат локальных вычислений
  bool isCorrupted = false; // Флаг нечестного участника

  Participant({required this.id, required this.secret});

  @override
  String toString() => 'Participant($id, secret=$secret)';
}

/// Результат MPC вычислений
class MPCResult {
  final int computedValue; // Вычисленное значение
  final List<int> corruptedIds; // ID нечестных участников
  final bool success;

  MPCResult({
    required this.computedValue,
    required this.corruptedIds,
    required this.success,
  });
}

/// Симулятор MPC протокола для вычисления линейной комбинации секретов
class MPCSimulator {
  final FiniteField field;
  final int n; // Количество участников
  final int t; // Порог схемы Шамира (threshold - 1)
  final List<int> weights; // Веса λ1, ..., λn
  final List<Participant> participants;
  final ShamirSecretSharing shamir;

  MPCSimulator({
    required this.field,
    required this.n,
    required this.t,
    required List<int> secrets,
    required this.weights,
  })  : participants = List.generate(
          n,
          (i) => Participant(id: i + 1, secret: secrets[i]),
        ),
        shamir = ShamirSecretSharing(
          field: field,
          threshold: t + 1,
          numShares: n,
        ) {
    if (secrets.length != n) {
      throw ArgumentError('Количество секретов должно быть $n');
    }
    if (weights.length != n) {
      throw ArgumentError('Количество весов должно быть $n');
    }
    if (2 * t >= n) {
      throw ArgumentError('Должно выполняться 2t < n для исправления t ошибок');
    }
  }

  /// Этап 1: Разделение секретов
  /// Каждый участник делит свой секрет на n долей и раздает их
  void shareSecrets({Random? random}) {
    random ??= Random();

    print('\n=== ЭТАП 1: РАЗДЕЛЕНИЕ СЕКРЕТОВ ===');

    for (var participant in participants) {
      // Участник делит свой секрет
      List<Share> shares = shamir.share(participant.secret, random: random);
      print(
        'Участник ${participant.id} делит секрет ${participant.secret}: $shares',
      );

      // Раздает доли другим участникам
      for (int i = 0; i < n; i++) {
        participants[i].receivedShares.add(shares[i]);
      }
    }

    print('\nПолученные доли каждым участником:');
    for (var p in participants) {
      print('  Участник ${p.id}: ${p.receivedShares}');
    }
  }

  /// Этап 2: Локальные вычисления
  /// Каждый участник вычисляет линейную комбинацию своих долей
  void computeLocally() {
    print('\n=== ЭТАП 2: ЛОКАЛЬНЫЕ ВЫЧИСЛЕНИЯ ===');
    print('Вычисляем: Σ λ_j * share_j');

    for (var participant in participants) {
      int result = 0;
      for (int j = 0; j < n; j++) {
        // λ_j * доля от участника j
        int term = field.mul(weights[j], participant.receivedShares[j].y);
        result = field.add(result, term);
      }
      participant.localResult = result;
      print(
        '  Участник ${participant.id}: локальный результат = $result',
      );
    }
  }

  /// Этап 3: Симуляция атаки
  /// Искажаем результаты t случайных участников
  List<int> simulateAttack(int numCorrupted, {Random? random}) {
    random ??= Random();

    print('\n=== ЭТАП 3: СИМУЛЯЦИЯ АТАКИ ===');

    if (numCorrupted > t) {
      print('ПРЕДУПРЕЖДЕНИЕ: Количество искаженных > t, восстановление может быть невозможно');
    }

    // Выбираем случайных участников для атаки
    List<int> indices = List.generate(n, (i) => i);
    indices.shuffle(random);
    List<int> corruptedIndices = indices.take(numCorrupted).toList();

    for (int idx in corruptedIndices) {
      var participant = participants[idx];
      int originalValue = participant.localResult!;
      
      // Генерируем случайное искажение (отличное от оригинала)
      int corrupted;
      do {
        corrupted = random.nextInt(field.p);
      } while (corrupted == originalValue);

      participant.localResult = corrupted;
      participant.isCorrupted = true;

      print(
        '  Участник ${participant.id}: искажен $originalValue -> $corrupted',
      );
    }

    return corruptedIndices.map((i) => participants[i].id).toList();
  }

  /// Этап 4: Восстановление результата с использованием декодера РС
  MPCResult reconstruct() {
    print('\n=== ЭТАП 4: ВОССТАНОВЛЕНИЕ С ДЕКОДИРОВАНИЕМ ===');

    // Собираем результаты всех участников
    // Это эквивалентно вычислению значений многочлена в точках 1, 2, ..., n
    // где многочлен f(x) такой, что f(0) = Σ λ_j * s_j

    // Для применения декодера РС:
    // - Сообщение длины k соответствует коэффициентам многочлена степени k-1
    // - Кодовое слово длины n = количество участников
    // - k = n - 2t (чтобы исправить t ошибок)

    int k = n - 2 * t;
    print('Параметры кода РС: n=$n, k=$k, t=$t');

    // Создаем кодер РС с точками вычисления 1, 2, ..., n
    List<int> evaluationPoints = List.generate(n, (i) => i + 1);
    ReedSolomonEncoder rsEncoder = ReedSolomonEncoder(
      field: field,
      n: n,
      k: k,
      points: evaluationPoints,
    );

    // Собираем "принятое слово" из результатов участников
    List<int> received = participants.map((p) => p.localResult!).toList();
    print('Принятый вектор: $received');

    // Декодируем (используем единственный декодер — Берлекэмпа-Мэсси)
    BerlekampMasseyDecoder decoder = BerlekampMasseyDecoder(rsEncoder);
    DecodingResult result = decoder.decode(received);

    if (!result.success) {
      print('Ошибка декодирования: ${result.errorMessage}');
      return MPCResult(computedValue: 0, corruptedIds: [], success: false);
    }

    print('Декодирование успешно!');
    print('Восстановленный многочлен: ${result.polynomial}');
    print('Позиции ошибок: ${result.errorPositions}');

    // Значение линейной комбинации = f(0) = свободный член многочлена
    int computedValue = result.polynomial!.evaluate(0);
    print('Вычисленное значение f(0) = $computedValue');

    // Идентификация нечестных участников
    List<int> corruptedIds =
        result.errorPositions!.map((pos) => pos + 1).toList();
    print('Идентифицированные нечестные участники: $corruptedIds');

    // Проверка правильности
    int expectedValue = 0;
    for (int j = 0; j < n; j++) {
      expectedValue = field.add(
        expectedValue,
        field.mul(weights[j], participants[j].secret),
      );
    }
    print('\nПроверка: ожидаемое значение Σλ_j*s_j = $expectedValue');

    return MPCResult(
      computedValue: computedValue,
      corruptedIds: corruptedIds,
      success: computedValue == expectedValue,
    );
  }

  /// Запуск полного протокола
  MPCResult runProtocol({int? numCorrupted, Random? random}) {
    numCorrupted ??= t;

    shareSecrets(random: random);
    computeLocally();
    simulateAttack(numCorrupted, random: random);
    return reconstruct();
  }
}
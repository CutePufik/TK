import 'package:indiv4/math/reed_muller.dart';

import '../math/gf2_vector.dart';
import 'hqc_vulnerable.dart';

/// Результат атаки
class AttackResult {
  final bool success;
  final GF2Vector? recoveredMessage;
  final GF2Vector? usedNoise;
  final int attempts;
  final Duration duration;

  AttackResult({
    required this.success,
    this.recoveredMessage,
    this.usedNoise,
    required this.attempts,
    required this.duration,
  });

  @override
  String toString() {
    if (success) {
      return 'Атака УСПЕШНА!\n'
          '  Восстановленное сообщение: $recoveredMessage\n'
          '  Использованный шум w: $usedNoise (вес: ${usedNoise?.weight})\n'
          '  Попыток: $attempts\n'
          '  Время: ${duration.inMilliseconds} мс';
    } else {
      return 'Атака НЕ УДАЛАСЬ\n'
          '  Попыток: $attempts\n'
          '  Время: ${duration.inMilliseconds} мс';
    }
  }
}

/// Класс для проведения атаки на уязвимую версию HQC
class HQCAttack {
  final VulnerableHQCPublicKey publicKey;
  final ReedMullerCode code;
  final int n;
  final int maxNoiseWeight;

  HQCAttack({
    required this.publicKey,
    required this.code,
    this.maxNoiseWeight = 3,
  }) : n = code.n;

  /// Генератор всех комбинаций позиций заданного размера
  Iterable<List<int>> _combinations(int n, int r) sync* {
    if (r == 0) {
      yield [];
      return;
    }
    if (r > n) return;

    final indices = List<int>.generate(r, (i) => i);
    yield List.from(indices);

    while (true) {
      int i = r - 1;
      while (i >= 0 && indices[i] == i + n - r) {
        i--;
      }
      if (i < 0) break;

      indices[i]++;
      for (int j = i + 1; j < r; j++) {
        indices[j] = indices[j - 1] + 1;
      }
      yield List.from(indices);
    }
  }

  /// Основная атака: перебор всех возможных w и проверка
  AttackResult attack(VulnerableHQCCiphertext ciphertext) {
    final stopwatch = Stopwatch()..start();
    int attempts = 0;

    //перебираем от maxNoiseWeight до 0
    for (int weight = maxNoiseWeight; weight >= 0; weight--) {
      for (final positions in _combinations(n, weight)) {
        attempts++;

        final w = GF2Vector.fromPositions(n, positions);
        final wS = publicKey.s.multiplyByVector(w);
        final candidate = ciphertext.c2 + wS;

        final message = code.findMessage(candidate);
        if (message != null) {
          stopwatch.stop();
          return AttackResult(
            success: true,
            recoveredMessage: message,
            usedNoise: w,
            attempts: attempts,
            duration: stopwatch.elapsed,
          );
        }
      }
    }

    stopwatch.stop();
    return AttackResult(
      success: false,
      attempts: attempts,
      duration: stopwatch.elapsed,
    );
  }

  /// Подсчёт количества кандидатов для перебора
  int countCandidates() {
    int total = 0;
    for (int w = 0; w <= maxNoiseWeight; w++) {
      total += _binomial(n, w);
    }
    return total;
  }

  int _binomial(int n, int k) {
    if (k > n) return 0;
    if (k == 0 || k == n) return 1;
    int result = 1;
    for (int i = 0; i < k; i++) {
      result = result * (n - i) ~/ (i + 1);
    }
    return result;
  }
}
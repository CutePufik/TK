import '../models/cyclic_code.dart';

/// Анализ взаимоотношений между кодами
class CodeRelations {
  final List<CyclicCode> codes;

  CodeRelations(this.codes);

  /// Найти двойственный код (Dual)
  /// Порождающий многочлен двойственного кода = h*(x)
  int? findDualCode(CyclicCode code) {
    final hReciprocal = code.check.reciprocal;

    for (final other in codes) {
      if (other.generator == hReciprocal) {
        return other.id;
      }
    }
    return null;
  }

  /// Найти возвратный код (Reciprocal)
  /// Порождающий многочлен возвратного кода = g*(x)
  int? findReciprocalCode(CyclicCode code) {
    final gReciprocal = code.generator.reciprocal;

    for (final other in codes) {
      if (other.generator == gReciprocal) {
        return other.id;
      }
    }
    return null;
  }

  /// Найти аннуляторный код (Annulator)
  /// Порождающий многочлен аннуляторного кода = h(x)
  int? findAnnulatorCode(CyclicCode code) {
    for (final other in codes) {
      if (other.generator == code.check) {
        return other.id;
      }
    }
    return null;
  }

  /// Получить все взаимоотношения для кода
  Map<String, int?> getRelations(CyclicCode code) {
    return {
      'dual': findDualCode(code),
      'reciprocal': findReciprocalCode(code),
      'annulator': findAnnulatorCode(code),
    };
  }
}
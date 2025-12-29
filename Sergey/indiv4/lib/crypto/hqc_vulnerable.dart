import 'dart:math';
import 'package:indiv4/math/reed_muller.dart';

import '../math/gf2_vector.dart';
import '../math/gf2_polynomial.dart';

/// Открытый ключ уязвимой версии HQC
class VulnerableHQCPublicKey {
  final List<GF2Vector> generatorMatrix; // Порождающая матрица кода RM(1,m)
  final GF2Polynomial s; // Полином s (публичный)

  VulnerableHQCPublicKey({
    required this.generatorMatrix,
    required this.s,
  });
}

/// Шифртекст уязвимой версии HQC (только c2, без c1 для простоты)
class VulnerableHQCCiphertext {
  final GF2Vector c2;

  VulnerableHQCCiphertext(this.c2);
}

/// Уязвимая версия HQC без ошибки e
/// c2 = μG + wS (вместо c2 = μG + wS + e)
class VulnerableHQC {
  final int m;
  final int noiseWeight; // Вес w
  late final ReedMullerCode code;
  late final int n;

  VulnerableHQC({this.m = 4, this.noiseWeight = 3}) {
    code = ReedMullerCode(m);
    n = code.n;
  }

  /// Генерация ключей
  VulnerableHQCPublicKey generatePublicKey({Random? rng}) {
    final random = rng ?? Random();
    
    // Генерируем случайный полином s
    final s = GF2Polynomial(GF2Vector.random(n, rng: random));

    return VulnerableHQCPublicKey(
      generatorMatrix: code.generatorMatrix,
      s: s,
    );
  }

  /// Шифрование сообщения μ
  VulnerableHQCCiphertext encrypt(
    GF2Vector message,
    VulnerableHQCPublicKey publicKey, {
    Random? rng,
  }) {
    assert(message.length == code.k);

    // 1. Кодируем сообщение: μG
    final encodedMessage = code.encode(message);

    // 2. Генерируем разреженный вектор шума w
    final w = GF2Vector.sparse(n, noiseWeight, rng: rng);

    // 3. Вычисляем wS (w умножить на циркулянтную матрицу S)
    final wS = publicKey.s.multiplyByVector(w);

    // 4. c2 = μG + wS (БЕЗ ошибки e - это уязвимость!)
    final c2 = encodedMessage + wS;

    return VulnerableHQCCiphertext(c2);
  }

  /// Шифрование с ошибкой (оригинальная версия HQC)
  VulnerableHQCCiphertext encryptWithError(
    GF2Vector message,
    VulnerableHQCPublicKey publicKey, {
    int errorWeight = 5,
    Random? rng,
  }) {
    assert(message.length == code.k);

    final encodedMessage = code.encode(message);
    final w = GF2Vector.sparse(n, noiseWeight, rng: rng);
    final wS = publicKey.s.multiplyByVector(w);
    
    // Добавляем ошибку e
    final e = GF2Vector.sparse(n, errorWeight, rng: rng);
    
    // c2 = μG + wS + e
    final c2 = encodedMessage + wS + e;

    return VulnerableHQCCiphertext(c2);
  }
}
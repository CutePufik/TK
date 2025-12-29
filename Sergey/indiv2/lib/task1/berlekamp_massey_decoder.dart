import '../common/finite_field.dart';
import '../common/polynomial.dart';
import 'reed_solomon.dart';

/// Результат декодирования
class DecodingResult {
  final bool success;
  final List<int>? message;
  final Polynomial? polynomial;
  final List<int>? errorPositions;
  final String? errorMessage;

  DecodingResult.success(this.message, this.polynomial, this.errorPositions)
      : success = true,
        errorMessage = null;

  DecodingResult.failure(this.errorMessage)
      : success = false,
        message = null,
        polynomial = null,
        errorPositions = null;
}

/// Декодер Берлекэмпа–Мэсси для обобщённых RS-кодов
class BerlekampMasseyDecoder {
  final ReedSolomonEncoder encoder;
  FiniteField get field => encoder.field;
  int get n => encoder.n;
  int get k => encoder.k;
  List<int> get points => encoder.evaluationPoints;

  // A'(α_i) и веса w_i = 1 / A'(α_i)
  late final List<int> _aPrimes;
  late final List<int> _weights;

  BerlekampMasseyDecoder(this.encoder) {
    _precomputeLagrangeWeights();
  }

  /// Предварительно считаем A'(α_i) = ∏_{j≠i} (α_i - α_j) и w_i = 1 / A'(α_i)
  void _precomputeLagrangeWeights() {
    _aPrimes = List.filled(n, 0);
    _weights = List.filled(n, 0);

    for (int i = 0; i < n; i++) {
      int xi = points[i];
      int prod = 1;
      for (int j = 0; j < n; j++) {
        if (j == i) continue;
        int xj = points[j];
        prod = field.mul(prod, field.sub(xi, xj)); // (xi - xj)
      }
      _aPrimes[i] = prod;               // A'(xi)
      _weights[i] = field.inverse(prod); // w_i = 1 / A'(xi)
    }
  }

  /// Синдромы S_ℓ = Σ r_i * w_i * α_i^ℓ, ℓ = 0..(2t-1)
  List<int> _computeSyndromes(List<int> received, int t) {
    int needed = 2 * t;
    if (needed <= 0) return <int>[];
    if (needed > n - k) needed = n - k;

    List<int> syndromes = List.filled(needed, 0);

    for (int ell = 0; ell < needed; ell++) {
      int s = 0;
      for (int i = 0; i < n; i++) {
        int xi = points[i];
        // r_i * w_i * xi^ell
        int term = field.mul(received[i], _weights[i]); // r_i / A'(xi)
        if (ell != 0) {
          term = field.mul(term, field.pow(xi, ell));
        }
        s = field.add(s, term);
      }
      syndromes[ell] = s;
    }

    return syndromes;
  }

  /// Алгоритм Берлекэмпа–Мэсси: находим локатор ошибок Λ(x)
  Polynomial _berlekampMassey(List<int> syndromes) {
    int nSyn = syndromes.length;

    List<int> C = [1]; // текущий connection polynomial C(x)
    List<int> B = [1]; // предыдущее C
    int L = 0;
    int m = 1;
    int b = 1; // последний ненулевой дискрепанс

    for (int n = 0; n < nSyn; n++) {
      // d = S_n + Σ_{i=1..L} C[i] * S_{n-i}
      int d = syndromes[n];
      for (int i = 1; i <= L && i < C.length; i++) {
        d = field.add(d, field.mul(C[i], syndromes[n - i]));
      }

      if (d == 0) {
        m++;
      } else {
        List<int> T = List.from(C);
        int coef = field.div(d, b);

        int newLen = (C.length > B.length + m) ? C.length : (B.length + m);
        List<int> newC = List.filled(newLen, 0);
        for (int i = 0; i < C.length; i++) newC[i] = C[i];
        for (int i = 0; i < B.length; i++) {
          int idx = i + m;
          newC[idx] = field.sub(newC[idx], field.mul(coef, B[i]));
        }
        C = newC;

        if (2 * L <= n) {
          B = T;
          b = d;
          L = n + 1 - L;
          m = 1;
        } else {
          m++;
        }
      }
    }

    return Polynomial(field, C);
  }

  /// Поиск позиций ошибок: Λ(α_i^{-1}) = 0
  List<int> _chienSearch(Polynomial lambda) {
    List<int> errorPositions = [];
    for (int i = 0; i < n; i++) {
      int alphaInv = field.inverse(points[i]);
      if (lambda.evaluate(alphaInv) == 0) {
        errorPositions.add(i);
      }
    }
    return errorPositions;
  }

  /// Формальная производная многочлена
  Polynomial _derivative(Polynomial p) {
    if (p.degree <= 0) return Polynomial.zero(field);
    List<int> derivCoeffs = [];
    for (int i = 1; i < p.coefficients.length; i++) {
      derivCoeffs.add(field.mul(i % field.p, p.coefficients[i]));
    }
    return Polynomial(field, derivCoeffs);
  }

  /// Алгоритм Форни:
  /// сначала получаем "взвешенные" ошибки s_i = e_i * w_i,
  /// затем восстанавливаем e_i = s_i / w_i.
  List<int> _forney(
    List<int> syndromes,
    Polynomial lambda,
    List<int> errorPositions,
  ) {
    if (syndromes.isEmpty) return <int>[];

    int t = syndromes.length ~/ 2;

    // S(x) = S_0 + S_1 x + ...
    Polynomial S = Polynomial(field, syndromes);

    // Ω(x) = S(x) * Λ(x) mod x^{2t}
    Polynomial omegaFull = S * lambda;
    int maxDeg = 2 * t;
    List<int> omegaCoeffs =
        omegaFull.coefficients.length > maxDeg
            ? omegaFull.coefficients.sublist(0, maxDeg)
            : List<int>.from(omegaFull.coefficients);
    Polynomial omega = Polynomial(field, omegaCoeffs);

    Polynomial lambdaPrime = _derivative(lambda);

    List<int> errorValues = [];
    for (int pos in errorPositions) {
      int Xi = points[pos];
      int XiInv = field.inverse(Xi);

      int omegaVal = omega.evaluate(XiInv);
      int lambdaPrimeVal = lambdaPrime.evaluate(XiInv);
      if (lambdaPrimeVal == 0) {
        // редкий вырожденный случай
        errorValues.add(0);
        continue;
      }

      // s_i = -Xi * Ω(Xi^{-1}) / Λ'(Xi^{-1})
      int s_i = field.neg(
        field.div(field.mul(Xi, omegaVal), lambdaPrimeVal),
      );

      // e_i = s_i / w_i
      int wi = _weights[pos];
      int e_i = field.div(s_i, wi);
      errorValues.add(e_i);
    }

    return errorValues;
  }

  /// Интерполяция многочлена сообщения из исправленного кодового слова
  Polynomial _interpolateMessage(List<int> codeword) {
    // Берём первые k точек
    List<int> xVals = points.take(k).toList();
    List<int> yVals = codeword.take(k).toList();
    return _lagrangeInterpolation(xVals, yVals);
  }

  /// Интерполяция Лагранжа
  Polynomial _lagrangeInterpolation(List<int> xValues, List<int> yValues) {
    int m = xValues.length;
    Polynomial result = Polynomial.zero(field);

    for (int i = 0; i < m; i++) {
      Polynomial li = Polynomial.constant(field, 1);
      int denominator = 1;

      for (int j = 0; j < m; j++) {
        if (i == j) continue;
        Polynomial factor =
            Polynomial(field, [field.neg(xValues[j]), 1]); // (x - x_j)
        li = li * factor;
        denominator = field.mul(
          denominator,
          field.sub(xValues[i], xValues[j]),
        );
      }

      int coeff = field.div(yValues[i], denominator);
      li = li.scalarMul(coeff);
      result = result + li;
    }

    return result;
  }

  /// Декодирование
  DecodingResult decode(List<int> received, {int? t}) {
    t ??= encoder.maxErrors;

    if (received.length != n) {
      return DecodingResult.failure('Длина принятого слова должна быть $n');
    }
    if (t < 0 || t > encoder.maxErrors) {
      return DecodingResult.failure('t не может превышать ${encoder.maxErrors}');
    }

    // 1. Синдромы
    List<int> syndromes = _computeSyndromes(received, t);

    // Если все синдромы ноль — ошибок нет
    if (syndromes.isEmpty || syndromes.every((s) => s == 0)) {
      Polynomial f = _interpolateMessage(received);
      if (f.degree > k - 1) {
        return DecodingResult.failure('Принятое слово не является кодовым');
      }
      List<int> message = List.generate(k, (i) => f[i]);
      return DecodingResult.success(message, f, []);
    }

    // 2. Берлекэмп–Мэсси: локатор ошибок Λ(x)
    Polynomial lambda = _berlekampMassey(syndromes);

    // 3. Chien search: позиции ошибок
    List<int> errorPositions = _chienSearch(lambda);

    if (errorPositions.length != lambda.degree) {
      return DecodingResult.failure(
        'Количество найденных ошибок не совпадает со степенью Λ(x)',
      );
    }
    if (errorPositions.length > encoder.maxErrors) {
      return DecodingResult.failure('Обнаружено слишком много ошибок');
    }

    // 4. Форни: значения ошибок e_i
    List<int> errorValues = _forney(syndromes, lambda, errorPositions);

    // 5. Исправляем
    List<int> corrected = List.from(received);
    for (int i = 0; i < errorPositions.length; i++) {
      int pos = errorPositions[i];
      corrected[pos] = field.sub(corrected[pos], errorValues[i]);
    }

    // 6. Восстанавливаем f(x) по исправленному слову
    Polynomial f = _interpolateMessage(corrected);
    if (f.degree > k - 1) {
      return DecodingResult.failure('Ошибка восстановления многочлена');
    }

    List<int> message = List.generate(k, (i) => f[i]);

    // 7. Проверка: перекодируем и сравниваем
    List<int> encoded = encoder.encode(message);
    for (int i = 0; i < n; i++) {
      if (encoded[i] != corrected[i]) {
        return DecodingResult.failure('Верификация не пройдена');
      }
    }

    return DecodingResult.success(message, f, errorPositions);
  }
}
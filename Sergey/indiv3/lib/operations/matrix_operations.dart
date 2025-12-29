import '../models/gf_matrix.dart';

/// Операции над матрицами в GF(p)
class MatrixOperations {
  final int p;

  MatrixOperations(this.p);

  int _mod(int x) => ((x % p) + p) % p;

  /// Приведение к ступенчатому виду (Row Echelon Form)
  GFMatrix rowEchelonForm(GFMatrix matrix) {
    final result = _copyMatrix(matrix);
    int lead = 0;

    for (int r = 0; r < result.rows; r++) {
      if (lead >= result.cols) break;

      int i = r;
      while (result.get(i, lead) == 0) {
        i++;
        if (i == result.rows) {
          i = r;
          lead++;
          if (lead == result.cols) return result;
        }
      }

      // Меняем строки местами
      if (i != r) {
        _swapRows(result, i, r);
      }

      // Делаем ведущий элемент равным 1
      final leadVal = result.get(r, lead);
      if (leadVal != 0 && leadVal != 1) {
        final inv = _modInverse(leadVal);
        _scaleRow(result, r, inv);
      }

      // Обнуляем элементы ниже
      for (int j = r + 1; j < result.rows; j++) {
        final factor = result.get(j, lead);
        if (factor != 0) {
          for (int k = lead; k < result.cols; k++) {
            result.set(j, k, _mod(result.get(j, k) - factor * result.get(r, k)));
          }
        }
      }
      lead++;
    }

    return result;
  }

  /// Приведение к приведённому ступенчатому виду (Reduced REF)
  GFMatrix reducedRowEchelonForm(GFMatrix matrix) {
    final result = rowEchelonForm(matrix);

    // Обратный ход
    for (int r = result.rows - 1; r >= 0; r--) {
      // Находим ведущий элемент в строке
      int lead = -1;
      for (int c = 0; c < result.cols; c++) {
        if (result.get(r, c) != 0) {
          lead = c;
          break;
        }
      }
      if (lead == -1) continue;

      // Обнуляем элементы выше
      for (int i = r - 1; i >= 0; i--) {
        final factor = result.get(i, lead);
        if (factor != 0) {
          for (int k = lead; k < result.cols; k++) {
            result.set(i, k, _mod(result.get(i, k) - factor * result.get(r, k)));
          }
        }
      }
    }

    return result;
  }

  GFMatrix _copyMatrix(GFMatrix m) {
    final data = List.generate(
      m.rows,
      (i) => List<int>.from(m.data[i]),
    );
    return GFMatrix(data, m.p);
  }

  void _swapRows(GFMatrix m, int i, int j) {
    final temp = m.data[i];
    m.data[i] = m.data[j];
    m.data[j] = temp;
  }

  void _scaleRow(GFMatrix m, int row, int scalar) {
    for (int j = 0; j < m.cols; j++) {
      m.set(row, j, _mod(m.get(row, j) * scalar));
    }
  }

  int _modInverse(int a) {
    a = _mod(a);
    for (int x = 1; x < p; x++) {
      if (_mod(a * x) == 1) return x;
    }
    return 1;
  }
}
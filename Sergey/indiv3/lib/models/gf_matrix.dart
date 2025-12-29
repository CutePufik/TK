/// Матрица над конечным полем GF(p)
class GFMatrix {
  final List<List<int>> data;
  final int p;
  final int rows;
  final int cols;

  GFMatrix(this.data, this.p)
      : rows = data.length,
        cols = data.isNotEmpty ? data[0].length : 0 {
    // Нормализация
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        data[i][j] = _mod(data[i][j]);
      }
    }
  }

  /// Создание единичной матрицы
  GFMatrix.identity(int size, this.p)
      : rows = size,
        cols = size,
        data = List.generate(
          size,
          (i) => List.generate(size, (j) => i == j ? 1 : 0),
        );

  /// Создание нулевой матрицы
  GFMatrix.zeros(this.rows, this.cols, this.p)
      : data = List.generate(rows, (_) => List.filled(cols, 0));

  int _mod(int x) => ((x % p) + p) % p;

  /// Получить элемент
  int get(int i, int j) => data[i][j];

  /// Установить элемент
  void set(int i, int j, int value) {
    data[i][j] = _mod(value);
  }

  /// Получить строку
  List<int> getRow(int i) => List.from(data[i]);

  /// Получить столбец
  List<int> getCol(int j) => List.generate(rows, (i) => data[i][j]);

  /// Транспонирование
  GFMatrix get transpose {
    final result = List.generate(
      cols,
      (i) => List.generate(rows, (j) => data[j][i]),
    );
    return GFMatrix(result, p);
  }

  /// Умножение матриц
  GFMatrix multiply(GFMatrix other) {
    if (cols != other.rows) {
      throw ArgumentError('Incompatible matrix dimensions');
    }

    final result = List.generate(
      rows,
      (i) => List.generate(other.cols, (j) {
        int sum = 0;
        for (int k = 0; k < cols; k++) {
          sum += data[i][k] * other.data[k][j];
        }
        return _mod(sum);
      }),
    );
    return GFMatrix(result, p);
  }

  /// Проверка на нулевую матрицу
  bool get isZero {
    for (var row in data) {
      for (var val in row) {
        if (val != 0) return false;
      }
    }
    return true;
  }

  /// Умножение на -1 (mod p)
  GFMatrix get negate {
    final result = List.generate(
      rows,
      (i) => List.generate(cols, (j) => _mod(-data[i][j])),
    );
    return GFMatrix(result, p);
  }

  /// Горизонтальная конкатенация
  GFMatrix horizontalConcat(GFMatrix other) {
    if (rows != other.rows) {
      throw ArgumentError('Row count mismatch');
    }

    final result = List.generate(
      rows,
      (i) => [...data[i], ...other.data[i]],
    );
    return GFMatrix(result, p);
  }

  /// Подматрица
  GFMatrix subMatrix(int startRow, int startCol, int numRows, int numCols) {
    final result = List.generate(
      numRows,
      (i) => List.generate(numCols, (j) => data[startRow + i][startCol + j]),
    );
    return GFMatrix(result, p);
  }

  /// Проверка на единичную матрицу
  bool get isIdentity {
    if (rows != cols) return false;
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (i == j && data[i][j] != 1) return false;
        if (i != j && data[i][j] != 0) return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var row in data) {
      buffer.writeln('  [${row.join(', ')}]');
    }
    return buffer.toString();
  }

  /// Компактный вывод для больших матриц
  String toCompactString({int maxRows = 5}) {
    final buffer = StringBuffer();
    final displayRows = rows <= maxRows ? rows : maxRows;

    for (int i = 0; i < displayRows; i++) {
      buffer.writeln('  [${data[i].join(', ')}]');
    }

    if (rows > maxRows) {
      buffer.writeln('  ... (ещё ${rows - maxRows} строк)');
    }

    return buffer.toString();
  }
}
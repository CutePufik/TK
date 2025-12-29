import '../common/finite_field.dart';

/// Матрица над конечным полем
class Matrix {
  final FiniteField field;
  final List<List<int>> data;
  final int rows;
  final int cols;

  Matrix(this.field, this.data)
      : rows = data.length,
        cols = data.isEmpty ? 0 : data[0].length;

  /// Создать нулевую матрицу
  factory Matrix.zero(FiniteField field, int rows, int cols) {
    return Matrix(
      field,
      List.generate(rows, (_) => List.filled(cols, 0)),
    );
  }

  /// Получить элемент
  int get(int i, int j) => field.mod(data[i][j]);

  /// Установить элемент
  void set(int i, int j, int value) {
    data[i][j] = field.mod(value);
  }

  /// Решение системы линейных уравнений Ax = b методом Гаусса
  /// Возвращает null если система не имеет решения или имеет бесконечно много решений
  List<int>? solve(List<int> b) {
    if (b.length != rows) {
      throw ArgumentError('Размер вектора b не соответствует числу строк');
    }

    // Создаем расширенную матрицу [A|b]
    List<List<int>> augmented = List.generate(
      rows,
      (i) => [...data[i].map((x) => field.mod(x)), field.mod(b[i])],
    );

    int pivotRow = 0;
    int pivotCol = 0;

    // Прямой ход
    while (pivotRow < rows && pivotCol < cols) {
      // Поиск ненулевого элемента в столбце
      int maxRow = pivotRow;
      for (int i = pivotRow + 1; i < rows; i++) {
        if (augmented[i][pivotCol] != 0) {
          maxRow = i;
          break;
        }
      }

      if (augmented[maxRow][pivotCol] == 0) {
        pivotCol++;
        continue;
      }

      // Перестановка строк
      var temp = augmented[pivotRow];
      augmented[pivotRow] = augmented[maxRow];
      augmented[maxRow] = temp;

      // Нормализация ведущего элемента
      int pivotVal = augmented[pivotRow][pivotCol];
      int pivotInv = field.inverse(pivotVal);
      for (int j = pivotCol; j <= cols; j++) {
        augmented[pivotRow][j] = field.mul(augmented[pivotRow][j], pivotInv);
      }

      // Обнуление элементов ниже и выше pivot
      for (int i = 0; i < rows; i++) {
        if (i != pivotRow && augmented[i][pivotCol] != 0) {
          int factor = augmented[i][pivotCol];
          for (int j = pivotCol; j <= cols; j++) {
            augmented[i][j] = field.sub(
              augmented[i][j],
              field.mul(factor, augmented[pivotRow][j]),
            );
          }
        }
      }

      pivotRow++;
      pivotCol++;
    }

    // Проверка на совместность и извлечение решения
    List<int> solution = List.filled(cols, 0);
    List<int> pivotCols = [];

    for (int i = 0; i < rows; i++) {
      int firstNonZero = -1;
      for (int j = 0; j < cols; j++) {
        if (augmented[i][j] != 0) {
          firstNonZero = j;
          break;
        }
      }
      if (firstNonZero == -1) {
        // Строка нулей, проверяем правую часть
        if (augmented[i][cols] != 0) {
          return null; // Несовместная система
        }
      } else {
        pivotCols.add(firstNonZero);
        solution[firstNonZero] = augmented[i][cols];
      }
    }

    return solution;
  }

  /// Решение системы с поиском любого ненулевого решения однородной системы
  /// или частного решения неоднородной системы
  List<int>? solveHomogeneous() {
    // Решаем систему Ax = 0, ищем ненулевое решение
    List<List<int>> augmented = List.generate(
      rows,
      (i) => data[i].map((x) => field.mod(x)).toList(),
    );

    List<int> pivotCols = [];
    int pivotRow = 0;

    for (int col = 0; col < cols && pivotRow < rows; col++) {
      int maxRow = pivotRow;
      for (int i = pivotRow; i < rows; i++) {
        if (augmented[i][col] != 0) {
          maxRow = i;
          break;
        }
      }

      if (augmented[maxRow][col] == 0) continue;

      var temp = augmented[pivotRow];
      augmented[pivotRow] = augmented[maxRow];
      augmented[maxRow] = temp;

      int pivotVal = augmented[pivotRow][col];
      int pivotInv = field.inverse(pivotVal);
      for (int j = col; j < cols; j++) {
        augmented[pivotRow][j] = field.mul(augmented[pivotRow][j], pivotInv);
      }

      for (int i = 0; i < rows; i++) {
        if (i != pivotRow && augmented[i][col] != 0) {
          int factor = augmented[i][col];
          for (int j = col; j < cols; j++) {
            augmented[i][j] = field.sub(
              augmented[i][j],
              field.mul(factor, augmented[pivotRow][j]),
            );
          }
        }
      }

      pivotCols.add(col);
      pivotRow++;
    }

    // Находим свободную переменную
    Set<int> pivotSet = pivotCols.toSet();
    int? freeVar;
    for (int j = 0; j < cols; j++) {
      if (!pivotSet.contains(j)) {
        freeVar = j;
        break;
      }
    }

    if (freeVar == null) {
      return null; // Только тривиальное решение
    }

    // Строим решение, полагая свободную переменную = 1
    List<int> solution = List.filled(cols, 0);
    solution[freeVar] = 1;

    for (int i = pivotRow - 1; i >= 0; i--) {
      int pivotCol = pivotCols[i];
      int sum = 0;
      for (int j = pivotCol + 1; j < cols; j++) {
        sum = field.add(sum, field.mul(augmented[i][j], solution[j]));
      }
      solution[pivotCol] = field.neg(sum);
    }

    return solution;
  }

  @override
  String toString() {
    return data.map((row) => row.join('\t')).join('\n');
  }
}
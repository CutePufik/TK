import random
import copy


class GF:
    p = 31

    def __init__(self, val):
        self.val = val % self.p

    def __add__(self, other):
        return GF(self.val + other.val)

    def __sub__(self, other):
        return GF(self.val - other.val)

    def __mul__(self, other):
        return GF(self.val * other.val)

    def __eq__(self, other):
        return self.val == other.val
    
    def __repr__(self):
        return str(self.val)

    def inv(self):
        """Обратный элемент (Расширенный алгоритм Евклида)."""
        if self.val == 0:
            raise ValueError("Деление на ноль")
        t, newt = 0, 1
        r, newr = self.p, self.val
        while newr != 0:
            q = r // newr
            t, newt = newt, t - q * newt
            r, newr = newr, r - q * newr
        if t < 0: t += self.p
        return GF(t)

    @staticmethod
    def zero(): return GF(0)
    @staticmethod
    def one(): return GF(1)


class Matrix:
    """Матрица над GF(p)."""
    def __init__(self, rows, cols, data=None):
        self.rows = rows
        self.cols = cols
        if data:
            self.data = copy.deepcopy(data)
        else:
            self.data = [[GF.zero() for _ in range(cols)] for _ in range(rows)]

    def __getitem__(self, idx):
        return self.data[idx]

    def __repr__(self):
        return "\n".join([" ".join(f"{x.val:2d}" for x in row) for row in self.data])

    def __mul__(self, other):
        if self.cols != other.rows:
            raise ValueError("Несовпадение размерностей")
        res = Matrix(self.rows, other.cols)
        for i in range(self.rows):
            for j in range(other.cols):
                acc = GF.zero()
                for k in range(self.cols):
                    acc = acc + self.data[i][k] * other.data[k][j]
                res.data[i][j] = acc
        return res

    def rref(self):
        """
        Возвращает: (Matrix RREF, list pivots)
        """
        m = Matrix(self.rows, self.cols, self.data)
        pivot_row = 0
        pivots = []
        for col in range(self.cols):
            if pivot_row >= self.rows: break
            
            # Поиск ведущего элемента
            pivot_idx = -1
            for r in range(pivot_row, self.rows):
                if m.data[r][col].val != 0:
                    pivot_idx = r
                    break
            
            if pivot_idx == -1: continue 
            
            pivots.append(col)
            m.data[pivot_row], m.data[pivot_idx] = m.data[pivot_idx], m.data[pivot_row]
            
            # Нормализация
            inv = m.data[pivot_row][col].inv()
            m.data[pivot_row] = [x * inv for x in m.data[pivot_row]]
            
            # Зануление столбца
            for r in range(self.rows):
                if r != pivot_row:
                    factor = m.data[r][col]
                    m.data[r] = [m.data[r][k] - factor * m.data[pivot_row][k] for k in range(self.cols)]
            
            pivot_row += 1
        return m, pivots

    def rank(self):
        _, pivots = self.rref()
        return len(pivots)

    def inverse(self):
        """Обратная матрица"""
        if self.rows != self.cols: raise ValueError("Матрица не квадратная")
        aug = Matrix(self.rows, self.rows * 2)
        for r in range(self.rows):
            for c in range(self.cols):
                aug.data[r][c] = self.data[r][c]
            aug.data[r][self.rows + r] = GF.one()
        
        res, pivots = aug.rref()
        
        if len(pivots) != self.rows:
            raise ValueError("Матрица вырождена")
            
        inv = Matrix(self.rows, self.cols)
        for r in range(self.rows):
            for c in range(self.cols):
                inv.data[r][c] = res.data[r][self.rows + c]
        return inv

    def get_columns(self, indices):
        """Возвращает подматрицу из выбранных столбцов."""
        res = Matrix(self.rows, len(indices))
        for r in range(self.rows):
            for i, col_idx in enumerate(indices):
                res.data[r][i] = self.data[r][col_idx]
        return res


def generate_full_rank_matrix(rows, cols):
    """
    Генерирует случайную матрицу гарантированного ранга k=rows.
    Использует перемешивание столбцов, чтобы равномерно распределить базис.
    """
    data = [[GF.zero() for _ in range(cols)] for _ in range(rows)]
    for r in range(rows):
        for c in range(cols):
            if c < rows:
                data[r][c] = GF.one() if r == c else GF.zero()
            else:
                data[r][c] = GF(random.randint(0, GF.p - 1))
    
    indices = list(range(cols))
    random.shuffle(indices)
    
    shuffled_data = [[GF.zero() for _ in range(cols)] for _ in range(rows)]
    for r in range(rows):
        for new_c, old_c in enumerate(indices):
            shuffled_data[r][new_c] = data[r][old_c]
            
    return Matrix(rows, cols, shuffled_data)

def create_permutation_matrix(n, indices_to_permute):
    """
    Создает матрицу P. Перемешивает только indices_to_permute.
    """
    pi = list(range(n))
    sub_indices = indices_to_permute.copy()
    random.shuffle(sub_indices)
    
    for original, new_val in zip(indices_to_permute, sub_indices):
        pi[original] = new_val
        
    P = Matrix(n, n)
    for col in range(n):
        row = pi[col]
        P.data[row][col] = GF.one()
    return P

def solve_linear_system(Y, X):
    """Находит S: Y = S * X."""
    _, pivots = X.rref()
    if len(pivots) < X.rows:
        raise ValueError(f"Ранг X ({len(pivots)}) меньше k ({X.rows}). Система недоопределена.")
        
    basis_indices = pivots[:X.rows]
    X_sub = X.get_columns(basis_indices)
    Y_sub = Y.get_columns(basis_indices)
    
    return Y_sub * X_sub.inverse()


def main():
    print(f"--- Протокол эквивалентности кодов (GF{GF.p}) ---")
    
    # Параметры
    n = 20
    k = 8 
    
    print(f"Параметры: n={n}, k={k}")
    print(f"Проверка условия уязвимости k < n/2: {k} < {n/2} -> {k < n/2}")
    if k >= n/2:
        print("ВНИМАНИЕ: Атака может не сработать!")

    # 1. Публичные параметры
    G = generate_full_rank_matrix(k, n)
    print(f"Матрица G ранга {G.rank()} сгенерирована.")

    alice_indices = [i for i in range(n) if i % 2 == 0]
    bob_indices = [i for i in range(n) if i % 2 != 0]


    P_A = create_permutation_matrix(n, alice_indices)
    G_prime_A = G * P_A
    G_A, _ = G_prime_A.rref()
    
    P_B = create_permutation_matrix(n, bob_indices)
    G_prime_B = G * P_B
    G_B, _ = G_prime_B.rref()

    # 3. Общий секрет
    K_Alice, _ = (G_B * P_A).rref()
    K_Bob, _ = (G_A * P_B).rref()
    
    # Проверка коммутации
    AB = P_A * P_B
    BA = P_B * P_A
    commute = True
    for r in range(n):
        for c in range(n):
            if AB[r][c] != BA[r][c]: commute = False
    print(f"Проверка: P_A и P_B коммутируют: {commute}")

    # Атака Евы
    print("\n--- Запуск атаки Евы ---")
    
    # Проверка предпосылок атаки
    rank_even = G.get_columns(bob_indices).rank()
    rank_odd = G.get_columns(alice_indices).rank()
    print(f"Ранги подматриц G: Чётные={rank_even}, Нечётные={rank_odd} (нужно {k})")
    
    if rank_even < k or rank_odd < k:
        print("ОШИБКА: Случайная матрица G имеет вырожденные подматрицы. Перезапустите генерацию.")
        return


    try:
        S_A_rec = solve_linear_system(G_A.get_columns(bob_indices), G.get_columns(bob_indices))
        print("S_A восстановлена.")
    except ValueError as e:
        print(f"Сбой на S_A: {e}")
        return

    try:
        S_B_rec = solve_linear_system(G_B.get_columns(alice_indices), G.get_columns(alice_indices))
        print("S_B восстановлена.")
    except ValueError as e:
        print(f"Сбой на S_B: {e}")
        return

    M_A = S_A_rec.inverse() * G_A  # = G * P_A
    M_B = S_B_rec.inverse() * G_B  # = G * P_B
    
    M_rec = Matrix(k, n)
    for c in range(n):
        if c in alice_indices:
            for r in range(k): M_rec.data[r][c] = M_A.data[r][c]
        else:
            for r in range(k): M_rec.data[r][c] = M_B.data[r][c]

    K_Eve, _ = M_rec.rref()
    
    success = True
    for r in range(k):
        for c in range(n):
            if K_Eve[r][c] != K_Alice[r][c]: success = False
            
    print(f"\nСтатус атаки: {'УСПЕХ' if success else 'ПРОВАЛ'}")
    if success:
        print("Ева восстановила секрет.")
        print("Сравнение первых строк:")
        print(f"Alice: {K_Alice.data[0]}")
        print(f"Eve:   {K_Eve.data[0]}")

if __name__ == "__main__":
    main()
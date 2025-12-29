import numpy as np
import galois

# --- ЧАСТЬ 1: Класс для работы с кодами Рида-Соломона ---
class RSCodes:
    def __init__(self, n, k, gf):
        self.n = n
        self.k = k
        self.gf = gf
        # Точки оценки (alpha_1, ..., alpha_n)
        self.alpha = self.gf.elements[1:n+1] 
        self.v = (n - k) // 2

    def encode(self, message):
        """Кодирование: c = (f(alpha_1), ..., f(alpha_n))"""
        if len(message) != self.k:
            raise ValueError(f"Message length must be {self.k}")
        # f(x) = m_{k-1}x^{k-1} + ... + m_0
        f_poly = galois.Poly(message[::-1], field=self.gf) 
        codeword = f_poly(self.alpha)
        return codeword, f_poly

    def add_error(self, codeword, t):
        """Внесение случайных ошибок"""
        e = self.gf.Zeros(self.n)
        error_indices = np.random.choice(self.n, t, replace=False)
        error_values = self.gf.Random(t, low=1)
        e[error_indices] = error_values
        z = codeword + e
        return z, e

    def decode_welch_berlekamp(self, z):
        """Декодер Велча-Берлекэмпа"""
        deg_L = self.v
        deg_N = self.k + self.v - 1
        num_vars_N = deg_N + 1
        num_vars_L = deg_L + 1
        
        A = self.gf.Zeros((self.n, num_vars_N + num_vars_L))
        for i in range(self.n):
            a_i = self.alpha[i]
            z_i = z[i]
            # Уравнение: N(a) - z*L(a) = 0
            A[i, :num_vars_N] = a_i ** np.arange(num_vars_N)
            A[i, num_vars_N:] = -z_i * (a_i ** np.arange(num_vars_L))

        null_space = A.null_space()
        if null_space.shape[0] == 0: return None 
            
        sol = null_space[0]
        N_poly = galois.Poly(sol[:num_vars_N][::-1], field=self.gf)
        L_poly = galois.Poly(sol[num_vars_N:][::-1], field=self.gf)
        
        f_recovered, remainder = divmod(N_poly, L_poly)
        return f_recovered if remainder == 0 else None

    def decode_berlekamp_massey(self, z):
        """
        БОНУС: Честная реализация декодера Берлекэмпа-Мэсси.
        1. Вычисление весов GRS.
        2. Вычисление синдромов.
        3. Алгоритм БМ для поиска локатора ошибок.
        4. Поиск корней (Chien Search).
        5. Восстановление по чистым точкам.
        """
        # 1. Вычисление весов для GRS
        weights = self.gf.Zeros(self.n)
        for i in range(self.n):
            denom = self.gf(1)
            for j in range(self.n):
                if i != j:
                    denom *= (self.alpha[i] - self.alpha[j])
            weights[i] = self.gf(1) / denom

        # 2. Вычисление синдромов
        syndromes = self.gf.Zeros(2 * self.v)
        for j in range(2 * self.v):
            term = z * weights * (self.alpha ** j)
            syndromes[j] = np.sum(term)

        # 3. Алгоритм Берлекэмпа-Мэсси (Ядро)
        Lambda = galois.Poly([1], field=self.gf)
        B = galois.Poly([1], field=self.gf)
        L = 0 
        
        for r in range(2 * self.v):
            delta = syndromes[r]
            coeffs = Lambda.coeffs[::-1]
            for i in range(1, len(coeffs)):
                if r - i >= 0:
                    delta += coeffs[i] * syndromes[r - i]
            
            if delta == 0:
                B = B * galois.Poly([1, 0], field=self.gf)
            else:
                T = Lambda - delta * B * galois.Poly([1, 0], field=self.gf)
                if 2 * L <= r:
                    B = Lambda * (delta ** -1)
                    L = r + 1 - L
                    Lambda = T
                else:
                    B = B * galois.Poly([1, 0], field=self.gf)
                    Lambda = T

        # 4. Поиск корней (Chien Search)
        error_indices = []
        for i in range(self.n):
            inv_loc = self.alpha[i] ** -1
            if Lambda(inv_loc) == 0:
                error_indices.append(i)
        
        # 5. Восстановление
        valid_indices = [i for i in range(self.n) if i not in error_indices]
        
        if len(valid_indices) < self.k:
            return None
            
        x_clean = self.alpha[valid_indices[:self.k]]
        y_clean = z[valid_indices[:self.k]]
        
        f_recovered = galois.lagrange_poly(x_clean, y_clean)
        return f_recovered

# --- ЧАСТЬ 2: Класс для моделирования MPC ---
class MPC_Simulation:
    def __init__(self, n, lambda_weights, gf):
        self.n = n
        self.weights = lambda_weights
        self.gf = gf
        self.t_shamir = (n - 1) // 3  
        self.k_code = self.t_shamir + 1
        self.rs = RSCodes(n, self.k_code, gf)

    def run(self):
        print("\n" + "="*60)
        print("ЗАДАНИЕ 2: MPC ПРОТОКОЛ (СХЕМА ШАМИРА)")
        print("="*60)
        
        secrets = self.gf.Random(self.n)
        target_S = np.sum(self.weights * secrets)

        # (a) Разделение
        shares_matrix = self.gf.Zeros((self.n, self.n))
        for j in range(self.n):
            coeffs = np.concatenate(([secrets[j]], self.gf.Random(self.k_code - 1)))
            f_j = galois.Poly(coeffs[::-1], field=self.gf)
            shares_matrix[j, :] = f_j(self.rs.alpha)

        # (b) Вычисления
        z_vector = self.gf.Zeros(self.n)
        for i in range(self.n):
            z_vector[i] = np.sum(self.weights * shares_matrix[:, i])

        print(f"--- Запуск MPC (Участников: {self.n}, Порог k: {self.k_code}) ---")
        print(f"1. Истинная сумма секретов (S): {target_S}")
        print(f"2. Результаты участников (до атаки): {z_vector}")

        # (c) Атака
        errors_count = (self.n - self.k_code) // 2
        corrupted_z, _ = self.rs.add_error(z_vector, errors_count)
        print(f"3. Вектор с ошибками (атака {errors_count} чел.): {corrupted_z}")

        # (d) Восстановление
        recovered_poly = self.rs.decode_berlekamp_massey(corrupted_z)
        
        if recovered_poly is None:
            print("ОШИБКА: Не удалось восстановить результат.")
        else:
            calculated_S = recovered_poly(0)
            print(f"4. Восстановленное S (через Берлекэмп-Мэсси): {calculated_S}")
            
            if calculated_S == target_S:
                print(">>> ИТОГ: УСПЕХ! Значение совпало.")
            else:
                print(">>> ИТОГ: ПРОВАЛ!")
            
            recalculated_z = recovered_poly(self.rs.alpha)
            cheaters = [i for i in range(self.n) if recalculated_z[i] != corrupted_z[i]]
            print(f"   Обнаруженные обманщики (индексы): {cheaters}")

# --- ЗАПУСК ---
if __name__ == "__main__":
    GF = galois.GF(2**6)
    N, K = 15, 7
    rs = RSCodes(N, K, GF)
    
    print("="*60)
    print("ЗАДАНИЕ 1: СРАВНЕНИЕ ДЕКОДЕРОВ (WB vs BM)")
    print("="*60)
    
    msg = GF.Random(K)
    print(f"[!] Исходное сообщение:      {msg}")
    
    codeword, original_poly = rs.encode(msg)
    v_errors = (N - K) // 2
    received, e = rs.add_error(codeword, t=v_errors)
    
    print(f"[!] Внесено ошибок:          {v_errors}")
    print(f"[!] Вектор ошибки e:         {e}")
    print(f"[!] Принятый вектор z:       {received}")
    
    print("-" * 60)
    
    # 1. Тест Велча-Берлекэмпа
    res_wb = rs.decode_welch_berlekamp(received)
    status_wb = "УСПЕХ" if res_wb == original_poly else "ОШИБКА"
    print(f">>> [Декодер Welch-Berlekamp]:   {status_wb}")
    if res_wb == original_poly:
        print(f"    Полином: {res_wb}")

    print("-" * 60)

    # 2. Тест Берлекэмпа-Мэсси (Бонус)
    res_bm = rs.decode_berlekamp_massey(received)
    status_bm = "УСПЕХ (+5 БОНУС)" if res_bm == original_poly else "ОШИБКА"
    print(f">>> [Декодер Berlekamp-Massey]:  {status_bm}")
    if res_bm == original_poly:
        print(f"    Полином: {res_bm}")
    
    # Задание 2
    lambdas = GF.Random(N)
    mpc = MPC_Simulation(N, lambdas, GF)
    mpc.run()
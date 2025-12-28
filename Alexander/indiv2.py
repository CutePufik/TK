import random



def inv_mod(a, q):
    """Мультипликативная инверсия в поле F_q."""
    if a == 0:
        raise ValueError("Обратного элемента для 0 не существует")
    return pow(a, q - 2, q)

def poly_eval(coeffs, x, q):
    """Вычисление значения полинома (схема Горнера)."""
    res = 0
    for c in reversed(coeffs):
        res = (res * x + c) % q
    return res

def poly_add(p1, p2, q):
    l = max(len(p1), len(p2))
    res = [0] * l
    for i in range(l):
        c1 = p1[i] if i < len(p1) else 0
        c2 = p2[i] if i < len(p2) else 0
        res[i] = (c1 + c2) % q
    return res

def poly_sub(p1, p2, q):
    l = max(len(p1), len(p2))
    res = [0] * l
    for i in range(l):
        c1 = p1[i] if i < len(p1) else 0
        c2 = p2[i] if i < len(p2) else 0
        res[i] = (c1 - c2) % q
    return res

def poly_mul_scalar(p, s, q):
    return [(c * s) % q for c in p]

def poly_mul(p1, p2, q):
    res = [0] * (len(p1) + len(p2) - 1)
    for i in range(len(p1)):
        for j in range(len(p2)):
            res[i + j] = (res[i + j] + p1[i] * p2[j]) % q
    return res

def lagrange_interpolate_safe(x_vals, y_vals, q):
    """
    Интерполяция Лагранжа.
    Принимает набор точек (x, y) и возвращает коэффициенты полинома.
    """
    k = len(x_vals)
    final_poly = [0]
    
    for i in range(k):
        num_poly = [1]
        denom = 1
        for j in range(k):
            if i == j: continue
            
            # (x - x_j)
            term_poly = [(q - x_vals[j]) % q, 1]
            num_poly = poly_mul(num_poly, term_poly, q)
            
            term_denom = (x_vals[i] - x_vals[j]) % q
            denom = (denom * term_denom) % q
            
        factor = (y_vals[i] * inv_mod(denom, q)) % q
        term_res = poly_mul_scalar(num_poly, factor, q)
        final_poly = poly_add(final_poly, term_res, q)
        
    return final_poly

# =========================================================
# 2. Ядро: RS Code + Berlekamp-Massey (Corrected)
# =========================================================

def rs_encode(msg_coeffs, alphas, q):
    return [poly_eval(msg_coeffs, a, q) for a in alphas]

def calculate_weights(alphas, q):
    """
    Вычисление весов для перехода от evaluation code к синдромам.
    w_i = 1 / product_{j!=i} (alpha_i - alpha_j)
    """
    n = len(alphas)
    weights = []
    for i in range(n):
        denom = 1
        for j in range(n):
            if i == j: continue
            diff = (alphas[i] - alphas[j]) % q
            denom = (denom * diff) % q
        weights.append(inv_mod(denom, q))
    return weights

def rs_decode_bm_correct(received, alphas, n, k, q):
    """
    Правильный декодер Берлекэмпа-Мэсси для Evaluation RS кодов.
    """
    # 1. Вычисляем веса (нужны для корректного определения синдромов)
    weights = calculate_weights(alphas, q)
    
    # 2. Вычисляем синдромы
    # Для Evaluation кодов синдром S_j = sum(r_i * w_i * alpha_i^j)
    # Количество синдромов = n - k
    num_syndromes = n - k
    syndromes = []
    
    for j in range(num_syndromes):
        val = 0
        for i in range(n):
            # term = r_i * w_i * alpha_i^j
            term = (received[i] * weights[i]) % q
            term = (term * pow(alphas[i], j, q)) % q
            val = (val + term) % q
        syndromes.append(val)
        
    # Если все синдромы 0, ошибок нет
    if all(s == 0 for s in syndromes):
        return lagrange_interpolate_safe(alphas[:k], received[:k], q), []

    # 3. Алгоритм Берлекэмпа-Мэсси (Классический)
    # Находит LFSR кратчайшей длины, порождающий последовательность синдромов
    Lambda = [1]  # Полином локаторов
    B = [1]       # Вспомогательный полином для обновления
    L = 0         # Текущая длина регистра
    m = 1         # Количество сдвигов
    b = 1         # Предыдущее расхождение (discrepancy)
    
    for r in range(num_syndromes):
        # Вычисляем расхождение delta
        delta = syndromes[r]
        for i in range(1, len(Lambda)):
            if r - i >= 0:
                delta = (delta + Lambda[i] * syndromes[r - i]) % q
        
        if delta == 0:
            m += 1
        else:
            # Обновляем Lambda
            # T(x) = Lambda(x) - delta * b^-1 * x^m * B(x)
            factor = (delta * inv_mod(b, q)) % q
            shifted_B = [0] * m + B
            term = poly_mul_scalar(shifted_B, factor, q)
            T = poly_sub(Lambda, term, q)
            
            if 2 * L <= r:
                L = r + 1 - L
                B = Lambda[:] # Копируем старый Lambda
                b = delta
                m = 1
                Lambda = T
            else:
                m += 1
                Lambda = T

    # 4. Поиск Ченя (Chien Search)
    # Для данного определения синдромов, корни Lambda(x) равны 1/alpha_i,
    # где alpha_i - позиции ошибок.
    # То есть Lambda(alpha_i^-1) == 0 => ошибка в i.
    
    error_indices = []
    for i in range(n):
        if alphas[i] == 0:
            # BM для Evaluation codes обычно требует ненулевых точек, 
            # либо специальной обработки. Пропустим для стабильности, 
            # в тесте используем точки 1..n.
            continue
            
        inv_alpha = inv_mod(alphas[i], q)
        if poly_eval(Lambda, inv_alpha, q) == 0:
            error_indices.append(i)
            
    # 5. Восстановление (Erasure Decoding)
    # Используем ТОЛЬКО валидные точки.
    valid_x = []
    valid_y = []
    
    for i in range(n):
        if i not in error_indices:
            valid_x.append(alphas[i])
            valid_y.append(received[i])
    
    # Проверка на достаточность точек
    if len(valid_x) < k:
        # Невозможно восстановить
        return [0]*k, error_indices
        
    # Берем ровно k валидных точек для интерполяции
    decoded_coeffs = lagrange_interpolate_safe(valid_x[:k], valid_y[:k], q)
    
    # Паддинг нулями до длины k (если степень полинома < k-1)
    while len(decoded_coeffs) < k:
        decoded_coeffs.append(0)
        
    return decoded_coeffs, error_indices

# =========================================================
# 3. Тесты и Моделирование
# =========================================================

def generate_errors(n, num_errors, q):
    """
    Генерирует вектор ошибок длины n с num_errors ненулевыми элементами.
    Возвращает: (вектор ошибок, список индексов ошибок)
    """
    error_vec = [0] * n
    # Выбираем случайные позиции для ошибок
    indices = random.sample(range(n), num_errors)
    for idx in indices:
        val = random.randint(1, q - 1)
        error_vec[idx] = val
    return error_vec, indices

def test_task1_rs_bm():
    print("\n=== ЗАДАНИЕ 1: Тест RS (Berlekamp-Massey) ===")
    q = 31
    n = 10
    k = 4  
    # Способность исправлять ошибки t = floor((n-k)/2) = floor(6/2) = 3
    t_cap = (n - k) // 2
    
    # Используем точки 1..10 (исключаем 0 для простоты BM)
    alphas = list(range(1, n + 1))
    
    msg = [random.randint(0, q-1) for _ in range(k)]
    print(f"Поле F_{q}, n={n}, k={k}, исправляет t={t_cap}")
    print(f"Сообщение: {msg}")
    
    codeword = rs_encode(msg, alphas, q)
    print(f"Код: {codeword}")
    
    # Генерируем ровно 3 ошибки (максимум)
    error_pos = random.sample(range(n), t_cap)
    received = list(codeword)
    for pos in error_pos:
        received[pos] = (received[pos] + random.randint(1, q-1)) % q
        
    print(f"Внесены ошибки в позиции: {sorted(error_pos)}")
    print(f"Принято: {received}")
    
    # Декодируем
    decoded, found_errors = rs_decode_bm_correct(received, alphas, n, k, q)
    
    print(f"Найдено ошибок: {sorted(found_errors)}")
    print(f"Декодировано: {decoded[:k]}")
    
    # Проверка
    # Сравниваем элементы, т.к. decoded может быть длиннее за счет старших нулей
    match = True
    for i in range(k):
        v1 = msg[i]
        v2 = decoded[i] if i < len(decoded) else 0
        if v1 != v2:
            match = False
            break
            
    if match and set(found_errors) == set(error_pos):
        print(">> УСПЕХ: Сообщение восстановлено, все ошибки найдены.")
    else:
        print(">> ОШИБКА: Декодирование провалилось.")

def mpc_simulation_correct():
    print("\n=== ЗАДАНИЕ 2: Моделирование MPC (Исправленное) ===")
    # Параметры должны быть согласованы
    n = 10
    q = 31
    
    # Схема Шамира: степень полинома t_priv.
    # Количество долей для восстановления = t_priv + 1.
    t_priv = 2
    
    # Код Рида-Соломона:
    # Сообщение (коэффициенты полинома Шамира) имеет длину k = t_priv + 1.
    k_rs = t_priv + 1 # k = 3
    
    # Способность исправлять ошибки: t_err = floor((n - k)/2)
    # t_err = floor((10 - 3)/2) = 3.
    # Значит, мы можем пережить атаку 3 злоумышленников.
    t_err_cap = (n - k_rs) // 2
    
    print(f"Участники: {n}, Порог схемы: {t_priv} (k_RS={k_rs})")
    print(f"Код может исправить до {t_err_cap} ошибок.")
    
    alphas = list(range(1, n + 1))
    
    weights = [random.randint(1, q-1) for _ in range(n)]
    secrets = [random.randint(0, q-1) for _ in range(n)]
    true_sum = sum(w*s for w,s in zip(weights, secrets)) % q
    print(f"Истинная сумма (цель): {true_sum}")
    
    # 1. Раздача долей
    all_shares = []
    for i in range(n):
        poly = [secrets[i]] + [random.randint(0, q-1) for _ in range(t_priv)]
        shares = rs_encode(poly, alphas, q)
        all_shares.append(shares)
        
    # 2. Локальные вычисления
    local_results = []
    for j in range(n):
        val = 0
        for i in range(n):
            val = (val + weights[i] * all_shares[i][j]) % q
        local_results.append(val)
        
    print(f"Честные результаты: {local_results}")
    
    # 3. Атака
    # Атакуем 2 участников (меньше максимума 3, должно работать железно)
    num_attacked = 2
    attack_indices = random.sample(range(n), num_attacked)
    corrupted_results = list(local_results)
    for idx in attack_indices:
        corrupted_results[idx] = (corrupted_results[idx] + random.randint(1, q-1)) % q
        
    print(f"Атака на индексы: {sorted(attack_indices)}")
    print(f"Вектор с ошибками: {corrupted_results}")
    
    # 4. Восстановление
    decoded_poly, found_errors = rs_decode_bm_correct(corrupted_results, alphas, n, k_rs, q)
    
    # Результат MPC - свободный член P(0). P(x) = decoded_poly
    result = decoded_poly[0]
    
    print(f"Обнаруженные враги: {sorted(found_errors)}")
    print(f"Восстановленная сумма: {result}")
    
    if result == true_sum:
        print(">> MPC УСПЕХ: Результат совпал.")
    else:
        print(">> MPC ОШИБКА: Результат не совпал.")

def test_edge_cases():
    print("\n=== ДОПОЛНИТЕЛЬНЫЙ ТЕСТ 1: Работа на пределе (Max Capacity) ===")
    # Параметры: n=7, k=3. 
    # Предел ошибок: floor((7-3)/2) = 2 ошибки.
    q = 17
    n = 7
    k = 3
    t_limit = (n - k) // 2
    
    alphas = list(range(1, n + 1))
    msg = [random.randint(0, q-1) for _ in range(k)]
    
    codeword = rs_encode(msg, alphas, q)
    
    # Вносим ровно 2 ошибки (максимум)
    err_vec, err_indices = generate_errors(n, t_limit, q)
    received = [(c + e) % q for c, e in zip(codeword, err_vec)]
    
    print(f"Параметры: n={n}, k={k}, ошибок внесено: {t_limit}")
    print(f"Индексы ошибок: {err_indices}")
    
    decoded, found_indices = rs_decode_bm_correct(received, alphas, n, k, q)
    
    # Сравниваем
    is_correct = True
    for i in range(k):
        if msg[i] != (decoded[i] if i < len(decoded) else 0):
            is_correct = False
            break
            
    if is_correct and set(found_indices) == set(err_indices):
        print(">> УСПЕХ: Декодер справился с максимальным числом ошибок.")
    else:
        print(f">> ОШИБКА: Не удалось декодировать на пределе. Получено: {decoded[:k]}")


def test_failure_mode():
    print("\n=== ДОПОЛНИТЕЛЬНЫЙ ТЕСТ 2: Слишком много ошибок (Negative Test) ===")
    # Параметры: n=10, k=4. Предел t=3.
    # Мы внесем 4 ошибки. Декодер должен сломаться (не вернуть исходное сообщение).
    q = 31
    n = 10
    k = 4
    t_limit = 3
    errors_inserted = 4
    
    alphas = list(range(1, n + 1))
    msg = [random.randint(0, q-1) for _ in range(k)]
    codeword = rs_encode(msg, alphas, q)
    
    # Вносим 4 ошибки
    err_vec, err_indices = generate_errors(n, errors_inserted, q)
    received = [(c + e) % q for c, e in zip(codeword, err_vec)]
    
    print(f"Параметры: n={n}, k={k}, предел={t_limit}, внесено={errors_inserted}")
    
    decoded, found_indices = rs_decode_bm_correct(received, alphas, n, k, q)
    
    # Проверяем, совпадает ли декодированное сообщение с исходным
    # (Оно НЕ должно совпадать, так как ошибок слишком много)
    is_same = True
    for i in range(k):
        if msg[i] != (decoded[i] if i < len(decoded) else 0):
            is_same = False
            break
            
    if not is_same:
        print(">> УСПЕХ (Ожидаемый): Декодер не смог восстановить сообщение (ошибок слишком много).")
    else:
        # Крайне маловероятный случай, когда вектор ошибок перевел слово в другое валидное кодовое слово
        print(">> ВНИМАНИЕ: Декодер случайно нашел валидное слово (коллизия).")



if __name__ == "__main__":
    # Фиксируем seed для воспроизводимости
    random.seed(123)
    
    # Основные тесты
    test_task1_rs_bm()
    mpc_simulation_correct()
    
    # Дополнительные тесты
    test_edge_cases()
    test_failure_mode()
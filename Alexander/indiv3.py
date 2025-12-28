import sympy
from sympy import symbols, Poly, GF, Matrix, eye

N = 11      # Длина кода
P = 3       # Характеристика поля F_3

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

def format_poly(poly, x_sym):
    """
    Красивый вывод полинома.
    Пример: 1*x^2 + 2 -> x^2 + 2
    """
    if poly == 0 or poly == Poly(0, x_sym):
        return "0"
    
    # Коэффициенты от старшей степени к младшей
    coeffs = [int(c) % P for c in poly.all_coeffs()]
    degree = len(coeffs) - 1
    terms = []
    
    for i, c in enumerate(coeffs):
        if c == 0: continue
        power = degree - i
        
        # Формирование коэффициента
        if c == 1 and power > 0:
            coeff_str = ""
        else:
            coeff_str = str(c)
            
        if power == 0:
            terms.append(f"{coeff_str}")
        elif power == 1:
            terms.append(f"{coeff_str}{x_sym}")
        else:
            terms.append(f"{coeff_str}{x_sym}^{power}")
            
    return " + ".join(terms) if terms else "0"

def normalize_poly(poly, domain):
    """
    Делает полином моническим (старший коэффициент = 1).
    """
    if poly == 0: return poly
    lc = int(poly.LC()) % P
    if lc == 1: return poly
    # Умножаем на обратный к старшему коэффициенту
    inv_lc = pow(lc, P - 2, P)
    return poly * inv_lc

def get_reciprocal_poly(poly, x_sym, domain):
    """
    Возвращает нормированный возвратный полином g*(x).
    g*(x) = g(0)^(-1) * x^deg * g(1/x)
    """
    if poly == 0: return Poly(0, x_sym, domain=domain)
    
    coeffs = [int(c) % P for c in poly.all_coeffs()]
    # Разворачиваем (a_n...a_0 -> a_0...a_n)
    recip_coeffs = list(reversed(coeffs))
    
    # Убираем ведущие нули
    while recip_coeffs and recip_coeffs[0] == 0:
        recip_coeffs.pop(0)
    
    if not recip_coeffs: return Poly(0, x_sym, domain=domain)

    # Создаем полином и нормализуем его
    res_poly = Poly(recip_coeffs, x_sym, domain=domain)
    return normalize_poly(res_poly, domain)

def matrix_mod_p(M, p):
    """Приводит элементы матрицы к [0, p-1]."""
    return M.applyfunc(lambda x: int(x) % p)

def get_cyclic_generator_matrix(g_poly, n, k, p):
    """
    Классическая G (k x n): строки - сдвиги g(x).
    """
    # coeffs: [g_r, ..., g_0] -> reverse -> [g_0, ..., g_r]
    g_coeffs = [int(c) % p for c in g_poly.all_coeffs()]
    g_coeffs.reverse()
    
    rows = []
    for i in range(k):
        row = [0] * n
        for j, val in enumerate(g_coeffs):
            if i + j < n:
                row[i + j] = val
        rows.append(row)
    return Matrix(rows)

def get_cyclic_parity_matrix(h_poly, n, r, p):
    """
    Классическая H (r x n): строки - сдвиги h*(x).
    """
    x = h_poly.gen
    # Вычисляем h*(x)
    h_recip = get_reciprocal_poly(h_poly, x, h_poly.domain)
    
    # Коэффициенты h*(x): [h*_0, ..., h*_k]
    coeffs = [int(c) % p for c in h_recip.all_coeffs()]
    coeffs.reverse() # Для вектора: [const, x, x^2...]
    
    rows = []
    # Количество строк = n - k = r
    for i in range(r):
        row = [0] * n
        for j, val in enumerate(coeffs):
            if i + j < n:
                row[i + j] = val
        rows.append(row)
    return Matrix(rows)

def get_systematic_matrices(G_nonsys, n, k, p):
    """
    Пытается привести к виду [I | P].
    Возвращает (G_sys, H_sys) или (None, None).
    """
    # RREF
    G_rref, pivot_cols = G_nonsys.rref()
    G_sys = matrix_mod_p(G_rref[:k, :], p)
    
    expected_pivots = tuple(range(k))
    if pivot_cols != expected_pivots:
        return None, None
    
    # H = [-P^T | I]
    P_matrix = G_sys[:k, k:]
    Minus_P_T = matrix_mod_p(-P_matrix.T, p)
    I_nk = eye(n - k)
    
    H_sys = Minus_P_T.row_join(I_nk)
    return G_sys, H_sys


def solve():
    x = symbols('x')
    domain = GF(P)
    
    print(f"=== ЗАДАНИЕ: Циклические коды (n={N}, p={P}) ===\n")
    

    main_poly = Poly(x**N - 1, x, domain=domain)
    factors_data = sympy.factor_list(main_poly)[1]
 
    irreducibles = [normalize_poly(f, domain) for f, exp in factors_data]
    
    print(f"1) Неприводимые делители x^{N}-1:")
    for i, f in enumerate(irreducibles):
        print(f"   f_{i+1}(x) = {format_poly(f, x)}")
    
    num_codes = 2 ** len(irreducibles)
    print(f"\n   Количество кодов: {num_codes}")

    codes_list = []
    
    for i in range(num_codes):
        mask = f"{i:0{len(irreducibles)}b}"
        g = Poly(1, x, domain=domain)
        factors_indices = []
        
        for idx, bit in enumerate(mask):
            if bit == '1':
                g = g * irreducibles[idx]
                factors_indices.append(idx + 1)
        
        g = normalize_poly(g, domain)
        h, rem = sympy.div(main_poly, g, domain=domain)
        h = normalize_poly(h, domain)
        k = N - g.degree()
        
        # Проверка целостности
        check_prod = (g * h - main_poly).is_zero
        
        codes_list.append({
            'id': i,
            'indices': factors_indices,
            'g': g,
            'h': h,
            'k': k,
            'valid': check_prod
        })

    print(f"\n2-3) Параметры кодов (выводим все {num_codes}):")
    print(f"{'ID':<3} | {'Множ.':<8} | {'k':<3} | {'g(x)':<30} | {'h(x)':<30}")
    print("-" * 90)
    for c in codes_list:
        g_str = format_poly(c['g'], x)
        h_str = format_poly(c['h'], x)
        print(f"#{c['id']:<2} | {str(c['indices']):<8} | {c['k']:<3} | {g_str:<30} | {h_str:<30}")

    print("\n4) Взаимоотношения:")
    print(f"{'Код':<4} | {'Двойственный (Dual)':<22} | {'Обратный (Recip)':<20}")
    print("-" * 60)
    
    for c in codes_list:
        h_recip = get_reciprocal_poly(c['h'], x, domain)
        g_recip = get_reciprocal_poly(c['g'], x, domain)
        
        dual = next((item for item in codes_list if item['g'] == h_recip), None)
        recip = next((item for item in codes_list if item['g'] == g_recip), None)
        
        dual_str = f"#{dual['id']}" if dual else "?"
        recip_str = f"#{recip['id']}" if recip else "?"
        
        print(f"#{c['id']:<4} | {dual_str:<22} | {recip_str:<20}")
    
    print("   * Аннуляторный код совпадает с двойственным.")


    print("\n5-6) Матрицы для двух нетривиальных кодов (k=6):")
    
    targets = [1, 2]
    selected = [c for c in codes_list if c['id'] in targets]
    
    for c in selected:
        print(f"\n" + "="*65)
        print(f" КОД #{c['id']} (k={c['k']})")
        print(f" g(x) = {format_poly(c['g'], x)}")
        print("="*65)
        
       
        G = get_cyclic_generator_matrix(c['g'], N, c['k'], P)
        H = get_cyclic_parity_matrix(c['h'], N, N-c['k'], P)
        
        print("\n[5a] G (классическая):")
        sympy.pprint(G)
        print("\n[5b] H (классическая):")
        sympy.pprint(H)
        
        # Проверка
        ortho = matrix_mod_p(G * H.T, P).is_zero_matrix
        print(f"   -> Проверка G * H^T = 0: {'OK' if ortho else 'FAIL'}")
        
        # Систематические
        G_sys, H_sys = get_systematic_matrices(G, N, c['k'], P)
        
        if G_sys:
            print("\n[6a] G_sys [I | P]:")
            sympy.pprint(G_sys)
            print("\n[6b] H_sys [-P^T | I]:")
            sympy.pprint(H_sys)
            
            ortho_sys = matrix_mod_p(G_sys * H_sys.T, P).is_zero_matrix
            print(f"   -> Проверка G_sys * H_sys^T = 0: {'OK' if ortho_sys else 'FAIL'}")
        else:
            print("\n[6] Невозможно получить вид [I | P] без перестановки столбцов (первые k столбцов зависимы).")

if __name__ == "__main__":
    solve()
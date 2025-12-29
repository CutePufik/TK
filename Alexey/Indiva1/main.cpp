#include <iostream>
#include <vector>
#include <random>
#include <cmath>
#include <string>
#include <fstream>
#include <iomanip>

// определения и включения для stb_image
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define _CRT_SECURE_NO_WARNINGS
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

int n = 7;  // Длина блока кода Хэмминга (n=7 для (7,4)-кода)
int r = 3;  // Длина синдрома/сообщения (r=3, т.к 2^r - 1 = 7)

// Функция вычисления синдрома в виде десятичного числа
int syndrom(const std::vector<int>& x, int n_val) {
    int s = 0;
    for (int i = 1; i <= n_val; ++i) {
        if (x[i - 1] == 1) {
            s ^= i;
        }
    }
    return s;
}

// Преобразование бинарного вектора в число 
int binvect_to_num(const std::vector<int>& v) {
    int num = 0;
    for (int b : v) {
        num = (num << 1) | b;
    }
    return num;
}

// Декодирование сообщения: вычисление синдрома и преобразование в r-битный вектор
std::vector<int> encode(const std::vector<int>& x_, int r_val) {
    int s_ = syndrom(x_, n);
    std::vector<int> bits(r_val, 0);
    int temp = s_;
    for (int i = r_val - 1; i >= 0; --i) {
        bits[i] = temp % 2;
        temp /= 2;
    }
    return bits;
}

// Задание 1: Функция вложения сообщения в контейнер
std::vector<int> task1(const std::vector<int>& x, const std::vector<int>& m, int n_val) {
    int pos = syndrom(x, n_val);  // Вычисляем текущий синдром контейнера
    int mes_num = binvect_to_num(m);  // Преобразуем сообщение в число
    if (pos == mes_num) {
        return x;  // Если синдром уже равен сообщению, изменений не нужно
    }
    else if (pos != 0) {
        std::vector<int> e(n_val, 0);  // Создаём вектор ошибки
        e[(mes_num ^ pos) - 1] = 1;  // Устанавливаем 1 в позиции, корректирующей синдром
        std::vector<int> result(n_val);
        for (int i = 0; i < n_val; ++i) {
            result[i] = x[i] ^ e[i];  // Применяем ошибку (XOR для GF(2))
        }
        return result;
    }
    else {
        std::vector<int> e(n_val, 0);  // Создаём вектор ошибки
        e[mes_num - 1] = 1;  // Устанавливаем 1 в позиции, соответствующей сообщению
        std::vector<int> result(n_val);
        for (int i = 0; i < n_val; ++i) {
            result[i] = x[i] ^ e[i];  // Применяем ошибку
        }
        return result;
    }
}

// Извлечение младших битов (LSB) из данных изображения
std::vector<int> get_lsb_bits(const unsigned char* data, int width, int height, int channels) {
    std::vector<int> bits;
    int total_pixels = width * height;  // Общее количество пикселей
    for (int i = 0; i < total_pixels * channels; ++i) {
        bits.push_back(data[i] & 1);  // Извлекаем LSB каждого байта (канала)
    }
    return bits;
}

// Установка новых LSB в данных изображения (возвращает новый массив данных)
unsigned char* set_lsb_bits(const unsigned char* orig_data, const std::vector<int>& bits, int width, int height, int channels) {
    int total_bytes = width * height * channels;  // Общее количество байтов в изображении
    unsigned char* new_data = new unsigned char[total_bytes];
    std::copy(orig_data, orig_data + total_bytes, new_data);  // Копируем оригинальные данные
    for (int i = 0; i < total_bytes; ++i) {
        new_data[i] = (new_data[i] & ~1) | bits[i];  // Заменяем LSB на новый бит
    }
    return new_data;
}

// Кодирование сообщения в изображение с использованием последовательного LSB
void encode_image_lsb(const std::string& img_path, const std::vector<int>& message_bits, int n_val, int r_val, const std::string& output_path) {
    int width, height, channels;
    unsigned char* data = stbi_load(img_path.c_str(), &width, &height, &channels, 0);  // Загружаем изображение
    if (!data) {
        std::cerr << "Error loading image: " << img_path << std::endl;  // Ошибка загрузки
        return;
    }
    if (channels != 3 && channels != 4) {
        std::cerr << "Unsupported channels: " << channels << ". Expecting RGB (3) or RGBA (4)." << std::endl;  // Проверка количества каналов
        stbi_image_free(data);
        return;
    }

    std::vector<int> lsb_bits = get_lsb_bits(data, width, height, channels);  // Извлекаем LSB

    // Разбиваем LSB на блоки длиной n
    std::vector<std::vector<int>> blocks_x;
    for (size_t i = 0; i < lsb_bits.size(); i += n_val) {
        std::vector<int> block(lsb_bits.begin() + i, lsb_bits.begin() + std::min(i + n_val, lsb_bits.size()));
        if (block.size() < static_cast<size_t>(n_val)) {
            block.resize(n_val, 0);
        }
        blocks_x.push_back(block);
    }

    // Разбиваем сообщение на блоки длиной r
    std::vector<std::vector<int>> blocks_m;
    for (size_t i = 0; i < message_bits.size(); i += r_val) {
        std::vector<int> block(message_bits.begin() + i, message_bits.begin() + std::min(i + r_val, message_bits.size()));
        if (block.size() < static_cast<size_t>(r_val)) {
            block.resize(r_val, 0);
        }
        blocks_m.push_back(block);
    }

    int num_blocks = static_cast<int>(blocks_m.size());  // Количество блоков сообщения

    // Заголовок: num_blocks в виде r-битного бинарного вектора
    std::vector<int> header_bits(r_val, 0);
    int temp = num_blocks;
    for (int i = r_val - 1; i >= 0; --i) {
        header_bits[i] = temp % 2;
        temp /= 2;
    }
    blocks_m.insert(blocks_m.begin(), header_bits);  // Добавляем заголовок в начало

    if (blocks_m.size() > blocks_x.size()) {
        std::cerr << "Message too long for this image" << std::endl;  // Проверка длины сообщения
        stbi_image_free(data);
        return;
    }

    // Кодирование блоков
    std::vector<std::vector<int>> encoded_blocks;
    for (size_t i = 0; i < blocks_m.size(); ++i) {
        auto encoded = task1(blocks_x[i], blocks_m[i], n_val);  // Встраиваем сообщение в блок
        encoded_blocks.push_back(encoded);
    }

    // Добавляем оставшиеся неизменённые блоки
    for (size_t i = blocks_m.size(); i < blocks_x.size(); ++i) {
        encoded_blocks.push_back(blocks_x[i]);
    }

    // Собираем новые биты в плоский вектор
    std::vector<int> new_bits;
    for (const auto& block : encoded_blocks) {
        for (int b : block) {
            new_bits.push_back(b);
        }
    }
    new_bits.resize(lsb_bits.size());  // Обрезаем до исходной длины

    // Устанавливаем новые LSB
    unsigned char* new_data = set_lsb_bits(data, new_bits, width, height, channels);

    // Сохраняем изображение
    stbi_write_png(output_path.c_str(), width, height, channels, new_data, width * channels);
    std::cout << "Image successfully saved" << std::endl;  // если всё гуд

    delete[] new_data;  // Освобождаем память
    stbi_image_free(data);  // Освобождаем оригинальные данные
}

// Декодирование сообщения из изображения с последовательным LSB
std::vector<int> decode_image_lsb(const std::string& img_path, int n_val, int r_val) {
    int width, height, channels;
    unsigned char* data = stbi_load(img_path.c_str(), &width, &height, &channels, 0);  // Загружаем изображение
    if (!data) {
        std::cerr << "Error loading image: " << img_path << std::endl;
        return {};  // Возвращаем пустой вектор при ошибке
    }
    std::vector<int> lsb_bits = get_lsb_bits(data, width, height, channels);  // Извлекаем LSB
    stbi_image_free(data);  // Освобождаем память

    // Разбиваем LSB на блоки
    std::vector<std::vector<int>> blocks_x;
    for (size_t i = 0; i < lsb_bits.size(); i += n_val) {
        std::vector<int> block(lsb_bits.begin() + i, lsb_bits.begin() + std::min(i + n_val, lsb_bits.size()));
        if (block.size() < static_cast<size_t>(n_val)) {
            block.resize(n_val, 0);  // Дополняем нулями
        }
        blocks_x.push_back(block);
    }

    // Читаем заголовок: количество блоков
    int num_blocks = syndrom(blocks_x[0], n_val);

    std::vector<int> message_bits;  // Собираем извлечённое сообщение
    for (int i = 1; i <= num_blocks; ++i) {
        if (static_cast<size_t>(i) >= blocks_x.size()) break;  // Проверка на выход за пределы
        auto bits_block = encode(blocks_x[i], r_val);  // Извлекаем блок сообщения
        message_bits.insert(message_bits.end(), bits_block.begin(), bits_block.end());
    }

    return message_bits;
}

// Генерация псевдослучайного порядка индексов пикселей (для бонуски)
std::vector<int> generate_pixel_order(int width, int height, int channels, unsigned int seed) {
    int total_bits = width * height * channels;  // Общее количество битов LSB
    std::vector<int> indices(total_bits);
    for (int i = 0; i < total_bits; ++i) {
        indices[i] = i;  // Заполняем последовательными индексами
    }
    std::mt19937 gen(seed);  // Инициализируем ГПСЧ 
    std::shuffle(indices.begin(), indices.end(), gen);  // Перемешиваем индексы
    return indices;
}

// Кодирование с псевдослучайными позициями LSB (бонуска)
void encode_image_lsb_random(const std::string& img_path, const std::vector<int>& message_bits, int n_val, int r_val, const std::string& output_path, unsigned int seed) {
    int width, height, channels;
    unsigned char* data = stbi_load(img_path.c_str(), &width, &height, &channels, 0);  // Загружаем изображение
    if (!data) {
        std::cerr << "Error loading image: " << img_path << std::endl;
        return;
    }
    std::vector<int> lsb_bits = get_lsb_bits(data, width, height, channels);  // Извлекаем LSB
    int total_bits = static_cast<int>(lsb_bits.size());  // Общее количество битов

    // Получаем перемешанный порядок индексов
    std::vector<int> pixel_order = generate_pixel_order(width, height, channels, seed);

    // Создаём блоки из перемешанных битов
    std::vector<std::vector<int>> blocks_x;
    for (int i = 0; i <= total_bits - n_val; i += n_val) {
        std::vector<int> block(n_val);
        for (int j = 0; j < n_val; ++j) {
            block[j] = lsb_bits[pixel_order[i + j]];  // Берем биты по перемешанным индексам
        }
        blocks_x.push_back(block);
    }

    // Разбиваем сообщение на блоки
    std::vector<std::vector<int>> blocks_m;
    for (size_t i = 0; i < message_bits.size(); i += r_val) {
        std::vector<int> block(message_bits.begin() + i, message_bits.begin() + std::min(i + r_val, message_bits.size()));
        if (block.size() < static_cast<size_t>(r_val)) {
            block.resize(r_val, 0);
        }
        blocks_m.push_back(block);
    }

    int num_blocks = static_cast<int>(blocks_m.size());  // Количество блоков

    // Заголовок
    std::vector<int> header_bits(r_val, 0);
    int temp = num_blocks;
    for (int i = r_val - 1; i >= 0; --i) {
        header_bits[i] = temp % 2;
        temp /= 2;
    }
    blocks_m.insert(blocks_m.begin(), header_bits);  // Добавляем заголовок

    if (blocks_m.size() > blocks_x.size()) {
        std::cerr << "Message too long for this image" << std::endl;
        stbi_image_free(data);
        return;
    }

    // Кодирование блоков
    std::vector<std::vector<int>> encoded_blocks;
    for (size_t i = 0; i < blocks_m.size(); ++i) {
        auto encoded = task1(blocks_x[i], blocks_m[i], n_val);
        encoded_blocks.push_back(encoded);
    }

    // Добавляем оставшиеся блоки
    for (size_t i = blocks_m.size(); i < blocks_x.size(); ++i) {
        encoded_blocks.push_back(blocks_x[i]);
    }

    // Собираем новые биты
    std::vector<int> new_bits;
    for (const auto& block : encoded_blocks) {
        for (int b : block) {
            new_bits.push_back(b);
        }
    }
    new_bits.resize(total_bits);  // Обрезаем

    // Отображаем новые биты обратно в оригинальные позиции
    std::vector<int> modified_bits = lsb_bits;
    for (int i = 0; i < total_bits; ++i) {
        modified_bits[pixel_order[i]] = new_bits[i];  // Восстанавливаем порядок
    }

    // Устанавливаем новые LSB
    unsigned char* new_data = set_lsb_bits(data, modified_bits, width, height, channels);

    // Сохраняем
    stbi_write_png(output_path.c_str(), width, height, channels, new_data, width * channels);
    std::cout << "Image successfully saved. Key (seed): " << seed << std::endl;  // Выводим seed как ключ

    delete[] new_data;
    stbi_image_free(data);
}

// Декодирование с псевдослучайными позициями LSB (бонуска)
std::vector<int> decode_image_lsb_random(const std::string& img_path, int n_val, int r_val, unsigned int seed) {
    int width, height, channels;
    unsigned char* data = stbi_load(img_path.c_str(), &width, &height, &channels, 0);  // Загружаем изображение
    if (!data) {
        std::cerr << "Error loading image: " << img_path << std::endl;
        return {};
    }
    std::vector<int> lsb_bits = get_lsb_bits(data, width, height, channels);  // Извлекаем LSB
    int total_bits = static_cast<int>(lsb_bits.size());
    stbi_image_free(data);  // память

    std::vector<int> pixel_order = generate_pixel_order(width, height, channels, seed);  // Генерируем порядок

    std::vector<std::vector<int>> blocks_x;
    for (int i = 0; i <= total_bits - n_val; i += n_val) {
        std::vector<int> block(n_val);
        for (int j = 0; j < n_val; ++j) {
            block[j] = lsb_bits[pixel_order[i + j]];  // Тут берем биты по порядку
        }
        blocks_x.push_back(block);
    }

    // Читаем заголовок
    int num_blocks = syndrom(blocks_x[0], n_val);

    std::vector<int> message_bits;  // Собираем сообщение
    for (int i = 1; i <= num_blocks; ++i) {
        if (static_cast<size_t>(i) >= blocks_x.size()) break;
        auto bits_block = encode(blocks_x[i], r_val);
        message_bits.insert(message_bits.end(), bits_block.begin(), bits_block.end());
    }

    return message_bits;
}

// Тесты, подобные NIST: Frequency (Monobit) Test
double frequency_test(const std::vector<int>& bits) {
    size_t n = bits.size();
    int s = 0;
    for (int b : bits) {
        s += (b == 1 ? 1 : -1);  // Суммируем +1 для 1 и -1 для 0
    }
    double s_obs = std::abs(s) / std::sqrt(static_cast<double>(n));  // Наблюдаемое значение
    double p_value = std::erfc(s_obs / std::sqrt(2.0));  // Вычисляем p-value
    return p_value;
}

// Тест Runs: Проверка последовательностей
double runs_test(const std::vector<int>& bits) {
    size_t n = bits.size();
    double pi = 0.0;
    for (int b : bits) pi += b;
    pi /= n;  // Доля единиц
    if (std::abs(pi - 0.5) > (2.0 / std::sqrt(static_cast<double>(n)))) {
        return 0.0;  // Если доля слишком далека от 0.5
    }
    int v_obs = 1;
    for (size_t i = 1; i < n; ++i) {
        if (bits[i] != bits[i - 1]) {
            ++v_obs;  // Считаем смены (runs)
        }
    }
    double denom = 2.0 * std::sqrt(2.0 * n) * pi * (1.0 - pi);  // Знаменатель
    double p_value = std::erfc(std::abs(v_obs - 2.0 * n * pi * (1.0 - pi)) / denom);
    return p_value;
}

// Тест Block Frequency: Частота в блоках
double block_frequency_test(const std::vector<int>& bits, int M = 128) {
    size_t n = bits.size();
    int N = static_cast<int>(n) / M;  // Количество блоков
    if (N == 0) return 0.0;
    double chi_square = 0.0;
    for (int i = 0; i < N; ++i) {
        double sum_block = 0.0;
        for (int j = 0; j < M; ++j) {
            sum_block += bits[i * M + j];  // Сумма в блоке
        }
        double pi_block = sum_block / M;  // Доля единиц в блоке
        chi_square += 4.0 * M * std::pow(pi_block - 0.5, 2);  // Хи-квадрат
    }
    double p_value = std::exp(-chi_square / 2.0);  // p-value
    return p_value;
}

// Запуск всех тестов
void run_all_tests(const std::vector<int>& bits) {
    std::cout << "Running basic NIST-like tests..." << std::endl << std::endl;
    std::cout << std::fixed << std::setprecision(4);  // Формат вывода
    std::cout << "Frequency Test (Monobit): p = " << frequency_test(bits) << std::endl;
    std::cout << "Runs Test: p = " << runs_test(bits) << std::endl;
    std::cout << "Block Frequency Test: p = " << block_frequency_test(bits) << std::endl;
}

// Вспомогательная функция для загрузки LSB для тестов
std::vector<int> load_lsb_bits(const std::string& img_path) {
    int width, height, channels;
    unsigned char* data = stbi_load(img_path.c_str(), &width, &height, &channels, 0);  // Загружаем изображение
    if (!data) {
        std::cerr << "Error loading image for LSB: " << img_path << std::endl;
        return {};  // Пустой вектор при ошибке
    }
    auto bits = get_lsb_bits(data, width, height, channels);  // Извлекаем биты
    stbi_image_free(data);  // Освобождаем память
    return bits;
}

int main() {
    // Пример для задания 1: Тестируем вложение и извлечение без изображения
    std::vector<int> x(n, 0);  // Исходный контейнер
    std::vector<int> m(r, 0);  // Сообщение
    std::mt19937 gen(std::random_device{}());  // Генератор случайных чисел
    std::uniform_int_distribution<int> dist(0, 1);  // Распределение 0/1
    for (int i = 0; i < n; ++i) x[i] = dist(gen);  // Заполняем контейнер случайными битами
    for (int i = 0; i < r; ++i) m[i] = dist(gen);  // Заполняем сообщение случайными битами
    std::cout << "container: ";
    for (int b : x) std::cout << b << " ";
    std::cout << std::endl;
    std::cout << "message: ";
    for (int b : m) std::cout << b << " ";
    std::cout << std::endl;

    auto x_ = task1(x, m, n);  // Встраиваем сообщение
    auto m_ = encode(x_, r);  // Извлекаем
    std::cout << "modified container: ";
    for (int b : x_) std::cout << b << " ";
    std::cout << std::endl;
    std::cout << "extracted message: ";
    for (int b : m_) std::cout << b << " ";
    std::cout << std::endl;
    bool equal = (m == m_);  // Проверяем совпадение
    std::cout << (equal ? "true" : "false") << std::endl;

    // Пример кодирования в изображение (последовательное)
    std::vector<int> message_bits = { 1,0,1, 0,1,1, 1,1,0, 0,0,1, 1,0,0, 1,0,1 };  // Тестовое сообщение
    encode_image_lsb("2.png", message_bits, n, r, "output.png");  // Кодируем

    auto message = decode_image_lsb("output.png", n, r);  // Декодируем
    std::cout << "extracted message from image: ";
    for (int b : message) std::cout << b << " ";
    std::cout << std::endl;

    // Бонусная часть: Случайное вложение
    unsigned int seed = static_cast<unsigned int>(gen() % (1LL << 32));  // Генерируем случайный seed
    std::vector<int> message_bits_random = { 1,0,1, 1,0,1, 0,0,1, 0,1,1, 0,0,0, 1,1,0 };  // Тестовое сообщение для random
    encode_image_lsb_random("2.png", message_bits_random, n, r, "encoded.png", seed);  // Кодируем с random

    auto decoded = decode_image_lsb_random("encoded.png", n, r, seed);  // Декодируем с тем же seed
    std::cout << "Decoded message: ";
    for (int b : decoded) std::cout << b << " ";
    std::cout << std::endl;

    // Сохранение бинарных файлов с LSB для тестов
    auto bits_seq = load_lsb_bits("output.png");  // LSB из последовательного
    std::ofstream f_seq("lsb_bits_seq.bin", std::ios::binary);  // Открываем файл
    for (size_t i = 0; i < bits_seq.size(); i += 8) {
        unsigned char byte = 0;
        for (int j = 0; j < 8; ++j) {
            if (i + j < bits_seq.size()) {
                byte = (byte << 1) | bits_seq[i + j];  // Собираем байт
            }
            else {
                byte <<= 1;  // Дополняем нулями
            }
        }
        f_seq.write(reinterpret_cast<const char*>(&byte), 1);  // Записываем байт
    }
    f_seq.close();  // Закрываем файл

    auto bits_random = load_lsb_bits("encoded.png");  // LSB из random
    std::ofstream f_random("lsb_bits_random.bin", std::ios::binary);
    for (size_t i = 0; i < bits_random.size(); i += 8) {
        unsigned char byte = 0;
        for (int j = 0; j < 8; ++j) {
            if (i + j < bits_random.size()) {
                byte = (byte << 1) | bits_random[i + j];
            }
            else {
                byte <<= 1;
            }
        }
        f_random.write(reinterpret_cast<const char*>(&byte), 1);
    }
    f_random.close();

    // Запуск тестов для последовательного вложения
    std::vector<int> bits_test_seq;
    std::ifstream f_test_seq("lsb_bits_seq.bin", std::ios::binary);  // Читаем файл
    unsigned char byte;
    while (f_test_seq.read(reinterpret_cast<char*>(&byte), 1)) {
        for (int i = 7; i >= 0; --i) {
            bits_test_seq.push_back((byte >> i) & 1);  // Извлекаем биты из байта
        }
    }
    run_all_tests(bits_test_seq);  // Запускаем тесты

    // Запуск тестов для случайного вложения
    std::vector<int> bits_test_random;
    std::ifstream f_test_random("lsb_bits_random.bin", std::ios::binary);
    while (f_test_random.read(reinterpret_cast<char*>(&byte), 1)) {
        for (int i = 7; i >= 0; --i) {
            bits_test_random.push_back((byte >> i) & 1);
        }
    }
    run_all_tests(bits_test_random);

    return 0;
}
-- =========================================================
-- aggregates.sql — агрегація, групування, операції над множинами
-- Практична робота №11
-- Виконується на даних, створених dml.sql (пр_9)
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;


-- =========================================================
-- ЧАСТИНА 1: Агрегатні функції та GROUP BY
-- =========================================================

\echo '=== ЧАСТИНА 1: агрегати ==='

-- 1.1. Кількість курсів у кожному підрозділі (COUNT + GROUP BY)
-- COUNT(*) рахує ВСІ рядки у групі;
-- COUNT(column) — тільки ті, де column IS NOT NULL.
\echo '--- 1.1. Кількість курсів у кожному підрозділі ---'

SELECT
    d.code                 AS dep_code,
    d.name                 AS department,
    COUNT(c.course_id)     AS courses_count
FROM college.departments d
LEFT JOIN college.courses c ON c.department_id = d.department_id
GROUP BY d.department_id, d.code, d.name
ORDER BY courses_count DESC, d.code;

-- Пояснення: LEFT JOIN потрібен, щоб показати й кафедри БЕЗ курсів
-- (якщо таких немає, COUNT дасть 0 — не NULL).


-- 1.2. Середня кількість кредитів курсів (AVG)
\echo '--- 1.2. Середні кредити курсів ---'

SELECT
    ROUND(AVG(credits), 2)      AS avg_credits,
    SUM(credits)                AS total_credits,
    COUNT(*)                    AS courses_total
FROM college.courses;

-- AVG повертає NUMERIC для цілих значень і DOUBLE для float.
-- ROUND(x, 2) округлює до 2 знаків після коми.


-- 1.3. AVG по групах — середні кредити курсів у підрозділі
\echo '--- 1.3. Середні кредити курсів у підрозділі ---'

SELECT
    d.code                        AS dep_code,
    COUNT(c.course_id)            AS courses_cnt,
    ROUND(AVG(c.credits), 2)      AS avg_credits,
    ROUND(AVG(c.tuition), 2)      AS avg_tuition
FROM college.departments d
LEFT JOIN college.courses c ON c.department_id = d.department_id
GROUP BY d.department_id, d.code
ORDER BY d.code;


-- 1.4. Мінімальна та максимальна оцінка (MIN, MAX)
\echo '--- 1.4. MIN і MAX серед реєстрацій ---'

SELECT
    MIN(grade) AS min_grade,
    MAX(grade) AS max_grade,
    ROUND(AVG(grade), 2) AS avg_grade,
    COUNT(grade) AS graded_count,         -- рахуємо тільки НЕ-NULL
    COUNT(*)     AS total_enrollments     -- рахуємо всі
FROM college.enrollments;

-- Зверніть увагу: COUNT(grade) < COUNT(*), бо у частини enrollments
-- grade = NULL. Агрегатні функції (крім COUNT(*)) ігнорують NULL.


-- 1.5. MIN/MAX у групах — екстремальні оцінки у кожному курсі
\echo '--- 1.5. MIN/MAX оцінок по курсах ---'

SELECT
    c.code                   AS course_code,
    c.title                  AS course_title,
    COUNT(e.student_id)      AS enrolled_cnt,
    MIN(e.grade)             AS min_grade,
    MAX(e.grade)             AS max_grade,
    ROUND(AVG(e.grade), 2)   AS avg_grade
FROM college.courses c
LEFT JOIN college.enrollments e ON e.course_id = c.course_id
GROUP BY c.course_id, c.code, c.title
ORDER BY c.code;


-- 1.6. Сумарна кількість реєстрацій на курс із HAVING
\echo '--- 1.6. Курси з >= 2 реєстраціями ---'

SELECT
    e.course_id                   AS course_id,
    c.code                        AS course_code,
    COUNT(*)                      AS enrollments
FROM college.enrollments e
JOIN college.courses c ON c.course_id = e.course_id
GROUP BY e.course_id, c.code
HAVING COUNT(*) >= 2
ORDER BY enrollments DESC;


-- =========================================================
-- ЧАСТИНА 2: WHERE vs HAVING — демонстрація різниці
-- =========================================================

\echo '=== ЧАСТИНА 2: WHERE vs HAVING ==='

-- 2.1. Варіант A — WHERE: фільтрує рядки ДО групування
\echo '--- 2.1. WHERE: тільки оцінки >= 80, потім групуємо ---'

SELECT
    e.course_id,
    COUNT(*) AS enrollments_with_good_grade
FROM college.enrollments e
WHERE e.grade >= 80                    -- фільтр до групування
GROUP BY e.course_id
ORDER BY e.course_id;

-- Семантика: беремо лише рядки з оцінкою >= 80, потім групуємо за курсом.
-- COUNT показує, скільки саме ВИСОКИХ оцінок на кожному курсі.


-- 2.2. Варіант B — HAVING: фільтрує ГРУПИ після агрегації
\echo '--- 2.2. HAVING: усі реєстрації групуємо, потім лишаємо курси з >=2 ---'

SELECT
    e.course_id,
    COUNT(*) AS total_enrollments
FROM college.enrollments e
GROUP BY e.course_id
HAVING COUNT(*) >= 2                   -- фільтр після агрегації
ORDER BY e.course_id;

-- Семантика: берем УСІ реєстрації, рахуємо на курс,
-- потім лишаємо ТІЛЬКИ групи, де кількість >= 2.


-- 2.3. Одночасно WHERE і HAVING (типовий звіт)
\echo '--- 2.3. WHERE + HAVING разом ---'

SELECT
    e.course_id,
    COUNT(*) AS good_enrollments,
    ROUND(AVG(e.grade), 2) AS avg_grade
FROM college.enrollments e
WHERE e.grade IS NOT NULL              -- спочатку відкидаємо NULL
GROUP BY e.course_id
HAVING COUNT(*) >= 2                   -- потім лише курси з >= 2 оцінками
ORDER BY avg_grade DESC;

-- Порядок виконання SQL:
-- 1. FROM / JOIN      — збираємо дані
-- 2. WHERE            — фільтруємо РЯДКИ
-- 3. GROUP BY         — групуємо
-- 4. HAVING           — фільтруємо ГРУПИ
-- 5. SELECT           — вибираємо колонки / агрегати
-- 6. ORDER BY         — сортуємо
-- 7. LIMIT            — обрізаємо


-- =========================================================
-- ЧАСТИНА 3: Операції над множинами
-- =========================================================

\echo '=== ЧАСТИНА 3: UNION, INTERSECT, EXCEPT ==='

-- Готуємо дві підмножини — коди курсів перших двох підрозділів

-- 3.1. UNION — об'єднання БЕЗ дублікатів
\echo '--- 3.1. UNION (без дублікатів) ---'

SELECT code FROM college.courses WHERE department_id = 1
UNION
SELECT code FROM college.courses WHERE department_id = 2
ORDER BY code;


-- 3.2. UNION ALL — об'єднання ЗІ збереженням дублікатів
\echo '--- 3.2. UNION ALL (зі збереженням дублікатів) ---'

SELECT code FROM college.courses WHERE department_id = 1
UNION ALL
SELECT code FROM college.courses WHERE department_id = 2
ORDER BY code;

-- У нашому випадку курсу не може бути в двох підрозділах одночасно
-- (UNIQUE на code). Тому UNION і UNION ALL дадуть той самий результат.
-- Різниця буде видна там, де є дублікати:

\echo '--- 3.2b. Різниця UNION vs UNION ALL на штучних даних ---'

-- Створимо дублікати штучно через VALUES
WITH set_a AS (SELECT * FROM (VALUES ('DB'), ('WEB'), ('ALG')) t(code)),
     set_b AS (SELECT * FROM (VALUES ('DB'), ('ALG'), ('ML'))  t(code))

-- UNION прибере дублікати
SELECT code, 'UNION' AS op FROM set_a UNION SELECT code, 'UNION' FROM set_b
UNION ALL
-- UNION ALL залишить усе
SELECT code, 'UNION ALL' FROM (SELECT * FROM set_a UNION ALL SELECT * FROM set_b) u
ORDER BY op, code;


-- 3.3. INTERSECT — перетин (тільки спільні рядки)
\echo '--- 3.3. INTERSECT ---'

WITH set_a AS (SELECT * FROM (VALUES ('DB'), ('WEB'), ('ALG')) t(code)),
     set_b AS (SELECT * FROM (VALUES ('DB'), ('ALG'), ('ML'))  t(code))
SELECT code FROM set_a
INTERSECT
SELECT code FROM set_b
ORDER BY code;
-- Результат: DB, ALG (тільки ті, що є в ОБОХ множинах)


-- 3.4. EXCEPT — різниця (рядки A, яких немає в B)
\echo '--- 3.4. EXCEPT ---'

WITH set_a AS (SELECT * FROM (VALUES ('DB'), ('WEB'), ('ALG')) t(code)),
     set_b AS (SELECT * FROM (VALUES ('DB'), ('ALG'), ('ML'))  t(code))
SELECT code FROM set_a
EXCEPT
SELECT code FROM set_b
ORDER BY code;
-- Результат: WEB (єдиний, якого немає в set_b)


-- 3.5. Практичне використання: студенти, записані на DB, але НЕ на WEB
\echo '--- 3.5. Студенти на курсі DB, але не на WEB ---'

SELECT e.student_id
FROM college.enrollments e
JOIN college.courses c ON c.course_id = e.course_id
WHERE c.code = 'DB'
EXCEPT
SELECT e.student_id
FROM college.enrollments e
JOIN college.courses c ON c.course_id = e.course_id
WHERE c.code = 'WEB'
ORDER BY student_id;


-- =========================================================
-- ЧАСТИНА 4: Прикладний звіт «Топ курсів за кількістю студентів»
-- =========================================================

\echo '=== ЧАСТИНА 4: топ курсів ==='

SELECT
    c.code                       AS course_code,
    c.title                      AS course_title,
    d.code                       AS dep_code,
    COUNT(e.student_id)          AS student_count,
    COUNT(e.grade)               AS graded_count,
    ROUND(AVG(e.grade), 2)       AS avg_grade,
    MIN(e.grade)                 AS min_grade,
    MAX(e.grade)                 AS max_grade
FROM college.courses c
LEFT JOIN college.enrollments e ON e.course_id = c.course_id
JOIN college.departments d       ON d.department_id = c.department_id
GROUP BY c.course_id, c.code, c.title, d.code
HAVING COUNT(e.student_id) > 0   -- показуємо тільки курси зі студентами
ORDER BY student_count DESC, avg_grade DESC NULLS LAST
LIMIT 10;


-- =========================================================
-- ЧАСТИНА 5: Бонус — поведінка агрегатів з NULL
-- =========================================================

\echo '=== ЧАСТИНА 5: NULL і агрегати ==='

-- 5.1. Різниця COUNT(*) і COUNT(column)
SELECT
    COUNT(*)              AS all_rows,              -- усі рядки
    COUNT(grade)          AS non_null_grades,       -- тільки з оцінкою
    COUNT(DISTINCT grade) AS distinct_grades,       -- унікальні оцінки
    SUM(grade)            AS sum_grades,
    AVG(grade)            AS avg_grades,            -- ігнорує NULL
    MAX(grade)            AS max_grade              -- ігнорує NULL
FROM college.enrollments;

-- 5.2. COUNT(*) на порожній таблиці = 0, не NULL
SELECT COUNT(*) AS count_on_empty
FROM college.enrollments
WHERE 1 = 0;    -- заведомо порожній результат
-- Очікуємо: 0

-- 5.3. Інші агрегати на порожньому наборі = NULL
SELECT
    COUNT(grade)  AS cnt,     -- 0
    SUM(grade)    AS sm,      -- NULL
    AVG(grade)    AS av,      -- NULL
    MIN(grade)    AS mn,      -- NULL
    MAX(grade)    AS mx       -- NULL
FROM college.enrollments
WHERE 1 = 0;


\echo '=== УСІ ЗВІТИ ВИКОНАНО ==='

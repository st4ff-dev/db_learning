-- =========================================================
-- join.sql — INNER / LEFT / RIGHT / FULL JOIN
-- Практична робота №15
-- Виконується на даних, створених dml.sql (пр_9).
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;


-- =========================================================
-- ЧАСТИНА 0: Підготовка «асиметричних» даних
-- =========================================================
-- Щоб OUTER JOIN показали цікавий результат, потрібні рядки,
-- для яких немає пари в іншій таблиці:
--   • кафедра БЕЗ курсів  → буде видно в LEFT JOIN
--   • студент БЕЗ реєстрацій → буде видно в LEFT JOIN
-- Курс БЕЗ кафедри не можемо зробити (FK NOT NULL).
-- Для FULL JOIN з "дірками" з обох боків — створимо допоміжну
-- schema join_demo з таблицями без суворих FK.

\echo '=== ЧАСТИНА 0: підготовка асиметричних даних ==='

-- 0.1. Кафедра без курсів (якщо немає)
INSERT INTO college.departments (code, name)
VALUES ('HR', 'Гуманітарні науки')
ON CONFLICT (code) DO NOTHING;

-- 0.2. Студент без реєстрацій (якщо немає)
INSERT INTO college.students (student_number, full_name, email, enrollment_year)
VALUES ('ST-LONELY-001', 'Самітник Одинокий', 'lonely@college.ua', 2024)
ON CONFLICT (student_number) DO NOTHING;

-- 0.3. Допоміжна схема для FULL JOIN демо (з релаксованими FK)
DROP SCHEMA IF EXISTS join_demo CASCADE;
CREATE SCHEMA join_demo;

CREATE TABLE join_demo.departments (
    department_id INTEGER PRIMARY KEY,
    name          TEXT
);

CREATE TABLE join_demo.courses (
    course_id     INTEGER PRIMARY KEY,
    title         TEXT,
    department_id INTEGER     -- NULL дозволено!
);

INSERT INTO join_demo.departments VALUES
    (1, 'IT'),
    (2, 'Фізика'),
    (3, 'Математика'),
    (4, 'HR — без курсів');

INSERT INTO join_demo.courses VALUES
    (10, 'Бази даних',      1),
    (20, 'Вебтехнології',    1),
    (30, 'Загальна фізика',  2),
    (40, 'Сирота-курс',      NULL);        -- курс БЕЗ кафедри

-- Тепер маємо асиметрію з обох боків:
--   • Кафедра 4 (HR) — без курсів
--   • Курс 40 (Сирота) — без кафедри


-- =========================================================
-- ЧАСТИНА 1: INNER JOIN
-- =========================================================
-- Залишає тільки рядки з парою в обох таблицях.

\echo '=== ЧАСТИНА 1: INNER JOIN ==='

-- 1.1. На реальних даних
\echo '--- 1.1. INNER JOIN на college.* ---'

SELECT d.name AS department, c.title AS course
FROM college.courses AS c
JOIN college.departments AS d USING (department_id)
ORDER BY d.name, c.title;

-- Пояснення: кафедра HR не з'явиться у результаті, бо для неї
-- немає жодного курсу. Кожен рядок — існуюча пара (курс, кафедра).

-- 1.2. На демо-схемі
\echo '--- 1.2. INNER JOIN на join_demo ---'

SELECT d.name AS department, c.title AS course
FROM join_demo.courses c
JOIN join_demo.departments d USING (department_id)
ORDER BY d.name;

-- Пояснення:
--   • Кафедра "HR — без курсів" (id=4) зникла — немає курсів.
--   • Курс "Сирота-курс" (id=40) зник — немає кафедри (NULL FK).
--   • Залишилось 3 рядки замість 4+4.


-- =========================================================
-- ЧАСТИНА 2: LEFT JOIN
-- =========================================================
-- Залишає ВСІ рядки лівої таблиці; для правої — NULL, якщо пари немає.

\echo '=== ЧАСТИНА 2: LEFT JOIN ==='

-- 2.1. departments → courses: показує кафедри без курсів
\echo '--- 2.1. LEFT JOIN: departments ← courses ---'

SELECT d.name AS department, c.title AS course
FROM college.departments AS d
LEFT JOIN college.courses AS c USING (department_id)
ORDER BY d.name, c.title;

-- Пояснення: у рядку для кафедри HR колонка course = NULL —
-- бо курсів у неї немає, але сама кафедра збереглася у виводі.

-- 2.2. Знайти кафедри, у яких НЕМАЄ жодного курсу
\echo '--- 2.2. Кафедри без курсів ---'

SELECT d.code, d.name
FROM college.departments AS d
LEFT JOIN college.courses AS c USING (department_id)
WHERE c.course_id IS NULL;

-- Класичний патерн "anti-join": LEFT JOIN + WHERE child IS NULL
-- повертає записи лівої таблиці БЕЗ пари у правій.


-- =========================================================
-- ЧАСТИНА 3: RIGHT JOIN
-- =========================================================
-- Дзеркально до LEFT JOIN: залишає ВСІ рядки ПРАВОЇ таблиці.
-- У більшості випадків замінюється LEFT JOIN зі зміною порядку.

\echo '=== ЧАСТИНА 3: RIGHT JOIN ==='

-- 3.1. На join_demo: показує "сирота-курс" (без кафедри)
\echo '--- 3.1. RIGHT JOIN: departments ← courses ---'

SELECT d.name AS department, c.title AS course
FROM join_demo.departments d
RIGHT JOIN join_demo.courses c USING (department_id)
ORDER BY c.title;

-- Пояснення: з'явився курс "Сирота-курс" з department = NULL.
-- Кафедра HR тут НЕ показана (вона в лівій таблиці, а RIGHT залишає
-- тільки праву).

-- 3.2. Еквівалент через LEFT JOIN (той самий результат)
\echo '--- 3.2. Еквівалентний LEFT JOIN ---'

SELECT d.name AS department, c.title AS course
FROM join_demo.courses c
LEFT JOIN join_demo.departments d USING (department_id)
ORDER BY c.title;

-- Правило: ЛЕВОЙ-таблицею слід робити ту, рядки якої потрібно
-- гарантовано побачити.


-- =========================================================
-- ЧАСТИНА 4: FULL JOIN
-- =========================================================
-- Залишає ВСІ рядки з обох таблиць.
-- Для рядків без пари — NULL з протилежного боку.

\echo '=== ЧАСТИНА 4: FULL JOIN ==='

\echo '--- 4.1. FULL JOIN на join_demo ---'

SELECT
    COALESCE(d.name, '— без кафедри —')  AS department,
    COALESCE(c.title, '— без курсу —')    AS course
FROM join_demo.departments d
FULL JOIN join_demo.courses c USING (department_id)
ORDER BY department, course;

-- Очікуваний результат (5 рядків):
--   IT                 → Бази даних
--   IT                 → Вебтехнології
--   Фізика             → Загальна фізика
--   HR — без курсів    → — без курсу —           (ліва таблиця, права NULL)
--   — без кафедри —    → Сирота-курс             (права таблиця, ліва NULL)

-- 4.2. Виявити ВСІ розсинхронізації одним запитом
\echo '--- 4.2. Пошук будь-яких сирот з обох боків ---'

SELECT
    d.department_id AS dep_id,
    d.name          AS department,
    c.course_id     AS course_id,
    c.title         AS course,
    CASE
        WHEN c.course_id   IS NULL THEN 'кафедра без курсів'
        WHEN d.department_id IS NULL THEN 'курс без кафедри'
        ELSE 'match'
    END AS problem
FROM join_demo.departments d
FULL JOIN join_demo.courses c USING (department_id)
WHERE d.department_id IS NULL OR c.course_id IS NULL;


-- =========================================================
-- ЧАСТИНА 5: Звіт «студент — курс — оцінка» (3 JOIN)
-- =========================================================

\echo '=== ЧАСТИНА 5: Звіт студент — курс — оцінка ==='

-- 5.1. Повний звіт з усіма студентами, які мають реєстрації
\echo '--- 5.1. INNER JOIN трьох таблиць ---'

SELECT
    s.student_number     AS номер,
    s.full_name          AS студент,
    c.code               AS курс_код,
    c.title              AS курс_назва,
    e.grade              AS оцінка,
    d.name               AS кафедра
FROM college.enrollments AS e
JOIN college.students   AS s USING (student_id)
JOIN college.courses    AS c USING (course_id)
JOIN college.departments AS d USING (department_id)
ORDER BY s.full_name, c.code;

-- 5.2. Той самий звіт, але показуємо ВСІХ студентів,
--     включно з тими, хто ще не записався на жоден курс
\echo '--- 5.2. Усі студенти з LEFT JOIN ---'

SELECT
    s.student_number                AS номер,
    s.full_name                     AS студент,
    COALESCE(c.code,  '—')          AS курс_код,
    COALESCE(c.title, '— немає —')  AS курс_назва,
    e.grade                         AS оцінка
FROM college.students      AS s
LEFT JOIN college.enrollments AS e USING (student_id)
LEFT JOIN college.courses     AS c USING (course_id)
ORDER BY s.full_name, c.code;

-- У виводі з'явиться "Самітник Одинокий" з NULL у колонках курсу.


-- =========================================================
-- ЧАСТИНА 6: USING vs ON
-- =========================================================

\echo '=== ЧАСТИНА 6: USING vs ON ==='

-- 6.1. USING: короткий синтаксис, об'єднує колонку В ОДНУ
\echo '--- 6.1. JOIN ... USING (department_id) ---'

SELECT *
FROM join_demo.courses c
JOIN join_demo.departments d USING (department_id)
LIMIT 3;

-- У виводі буде ОДНА колонка department_id (об'єднана).

-- 6.2. ON: гнучкий синтаксис, зберігає ОБИДВІ колонки
\echo '--- 6.2. JOIN ... ON c.department_id = d.department_id ---'

SELECT *
FROM join_demo.courses c
JOIN join_demo.departments d ON c.department_id = d.department_id
LIMIT 3;

-- У виводі будуть ДВІ колонки department_id: c.department_id і d.department_id.

-- 6.3. ON дозволяє складні умови — USING ні
\echo '--- 6.3. ON з додатковою умовою ---'

SELECT c.title, d.name
FROM join_demo.courses c
JOIN join_demo.departments d
    ON c.department_id = d.department_id
   AND d.department_id <> 2    -- виключаємо кафедру 2 прямо в JOIN
ORDER BY c.title;

-- USING такого не вміє — тільки рівність однойменних колонок.


-- =========================================================
-- ЧАСТИНА 7: Поширені помилки й патерни
-- =========================================================

\echo '=== ЧАСТИНА 7: Запобігання множенню рядків ==='

-- 7.1. Небезпека: JOIN з таблицею, де пара не унікальна
-- Якщо у студента 2 телефони, JOIN "студенти-телефони" подвоїть рядки.
-- Приклад на college_norm.student_phones з пр_12 (якщо запускали).

-- 7.2. Правильний патерн: агрегація перед JOIN, щоб не подвоювати
\echo '--- 7.2. Безпечний JOIN з агрегатом ---'

SELECT
    s.full_name,
    COUNT(e.course_id) AS courses_count,
    ROUND(AVG(e.grade), 2) AS avg_grade
FROM college.students s
LEFT JOIN college.enrollments e USING (student_id)
GROUP BY s.student_id, s.full_name
ORDER BY courses_count DESC;

-- Тут ми раді «множенню» рядків enrollments — воно треба для COUNT.
-- Але якби додали ще JOIN з courses, не груповий — були б дублікати.


\echo '=== УСІ JOIN ВИКОНАНО ==='

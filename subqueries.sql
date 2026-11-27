-- =========================================================
-- subqueries.sql — скалярні, багаторядкові й корельовані підзапити
-- Практична робота №16
-- Виконується на даних, створених dml.sql (пр_9).
-- У нашій схемі колонка плати називається tuition (а не tuition_fee).
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;


-- =========================================================
-- ЧАСТИНА 1: Скалярні підзапити (повертають 1 значення)
-- =========================================================
-- Семантика: підзапит виконується ОДИН РАЗ і повертає 1 рядок × 1 колонку.
-- Використовується там, де очікується одне значення (константа).

\echo '=== ЧАСТИНА 1: скалярний підзапит ==='

-- 1.1. Середня плата за курс
\echo '--- 1.1. Середня плата ---'
SELECT ROUND(AVG(tuition), 2) AS avg_tuition FROM college.courses;

-- 1.2. Курси, дорожчі за середню плату
\echo '--- 1.2. Курси, дорожчі за середню ---'
SELECT code, title, tuition
FROM college.courses
WHERE tuition > (SELECT AVG(tuition) FROM college.courses)
ORDER BY tuition DESC;

-- Пояснення: внутрішній (SELECT AVG(tuition)...) повертає один
-- NUMERIC — воно підставляється замість підзапиту, і порівняння
-- працює як звичайний >.

-- 1.3. Скалярний підзапит у SELECT-списку
\echo '--- 1.3. Скалярний підзапит у SELECT ---'
SELECT
    code,
    title,
    tuition,
    tuition - (SELECT AVG(tuition) FROM college.courses) AS diff_from_avg
FROM college.courses
ORDER BY diff_from_avg DESC;

-- Тут скалярний підзапит обчислюється РАЗ і використовується
-- для КОЖНОГО рядка. Оптимізатор кешує результат.


-- =========================================================
-- ЧАСТИНА 2: Багаторядкові підзапити з IN
-- =========================================================
-- Семантика: підзапит повертає СПИСОК значень, перевіряється
-- включення зовнішньої колонки у список.

\echo '=== ЧАСТИНА 2: IN підзапит ==='

-- 2.1. Знайти студентів, зареєстрованих на курси з > 4 кредитів
\echo '--- 2.1. Студенти на "важких" курсах ---'

SELECT DISTINCT s.student_number, s.full_name
FROM college.students s
WHERE s.student_id IN (
    SELECT e.student_id
    FROM college.enrollments e
    WHERE e.course_id IN (
        SELECT course_id FROM college.courses WHERE credits > 4
    )
)
ORDER BY s.full_name;

-- Семантика: вкладені IN-підзапити працюють як серія фільтрів.
-- Спочатку беремо курси з credits > 4, потім реєстрації на них,
-- потім відповідних студентів.

-- 2.2. NOT IN — заперечення
\echo '--- 2.2. Курси, на які НІХТО не записаний ---'

SELECT code, title FROM college.courses
WHERE course_id NOT IN (
    SELECT course_id FROM college.enrollments
    WHERE course_id IS NOT NULL   -- захист від NULL у NOT IN!
);

-- ВАЖЛИВО: NOT IN з NULL дає несподівані результати.
-- Якщо у підзапиті є хоч один NULL, увесь NOT IN повертає FALSE.
-- Безпечніший варіант — NOT EXISTS (див. §4).


-- =========================================================
-- ЧАСТИНА 3: ANY і ALL
-- =========================================================
-- ANY (SOME) — умова має виконатися хоча б для ОДНОГО значення підзапиту.
-- ALL — має виконатися для ВСІХ значень підзапиту.

\echo '=== ЧАСТИНА 3: ANY і ALL ==='

-- 3.1. Курси з кредитами > БУДЬ-ЯКИЙ курс фізики (ANY)
\echo '--- 3.1. credits > ANY (курси фізики) ---'

SELECT code, title, credits
FROM college.courses
WHERE credits > ANY (
    SELECT credits FROM college.courses
    WHERE department_id = (SELECT department_id FROM college.departments WHERE code = 'FIZ')
)
ORDER BY credits DESC;

-- Семантика: якщо у фізики є курс на 4 кредити, то > ANY(4) = TRUE
-- для 5 і 6, але не для 3. Еквівалент: credits > MIN(credits фізики).

-- 3.2. Курси з кредитами > ВСІ курси фізики (ALL)
\echo '--- 3.2. credits > ALL (курси фізики) ---'

SELECT code, title, credits
FROM college.courses
WHERE credits > ALL (
    SELECT credits FROM college.courses
    WHERE department_id = (SELECT department_id FROM college.departments WHERE code = 'FIZ')
)
ORDER BY credits DESC;

-- Семантика: credits має бути більшим за КОЖНЕ значення підзапиту.
-- Еквівалент: credits > MAX(credits фізики).

-- 3.3. Еквівалентність ANY/ALL через MIN/MAX (часто ефективніше)
\echo '--- 3.3. Еквівалентні форми через MIN/MAX ---'

-- ANY → > MIN
SELECT code, credits FROM college.courses
WHERE credits > (SELECT MIN(credits) FROM college.courses
                 WHERE department_id = (SELECT department_id FROM college.departments WHERE code = 'FIZ'));

-- ALL → > MAX
SELECT code, credits FROM college.courses
WHERE credits > (SELECT MAX(credits) FROM college.courses
                 WHERE department_id = (SELECT department_id FROM college.departments WHERE code = 'FIZ'));


-- =========================================================
-- ЧАСТИНА 4: Корельовані підзапити з EXISTS
-- =========================================================
-- Корельований = підзапит ПОСИЛАЄТЬСЯ на колонки зовнішнього запиту.
-- Виконується один раз на кожен зовнішній рядок.
-- EXISTS повертає TRUE, якщо підзапит повертає ХОЧ ОДИН рядок.

\echo '=== ЧАСТИНА 4: EXISTS корельований підзапит ==='

-- 4.1. Кафедри, у яких є хоч один курс із хоч однією реєстрацією
\echo '--- 4.1. Кафедри з "активними" курсами ---'

SELECT d.code, d.name
FROM college.departments d
WHERE EXISTS (
    SELECT 1
    FROM college.courses c
    WHERE c.department_id = d.department_id   -- кореляція!
      AND EXISTS (
          SELECT 1 FROM college.enrollments e
          WHERE e.course_id = c.course_id
      )
);

-- Семантика:
--   • Для кожної кафедри перевіряємо, чи знайдеться курс цієї кафедри
--     (`c.department_id = d.department_id`), на який записано хоча б
--     одного студента.
--   • EXISTS не повертає даних — тільки TRUE/FALSE.
--   • Виграш: ЗУПИНЯЄТЬСЯ на першому знайденому рядку (short-circuit).

-- 4.2. NOT EXISTS — безпечніше за NOT IN
\echo '--- 4.2. Курси, на які ніхто не записаний (NOT EXISTS) ---'

SELECT c.code, c.title
FROM college.courses c
WHERE NOT EXISTS (
    SELECT 1 FROM college.enrollments e
    WHERE e.course_id = c.course_id
);

-- На відміну від NOT IN, NOT EXISTS коректно обробляє NULL.


-- =========================================================
-- ЧАСТИНА 5: Підзапит vs JOIN — те саме двома способами
-- =========================================================

\echo '=== ЧАСТИНА 5: підзапит vs JOIN ==='

-- Задача: знайти студентів, зареєстрованих на курс 'DB'.

-- 5.1. Варіант A — підзапит з IN
\echo '--- 5.1. IN-підзапит ---'
SELECT s.student_number, s.full_name
FROM college.students s
WHERE s.student_id IN (
    SELECT e.student_id
    FROM college.enrollments e
    JOIN college.courses c USING (course_id)
    WHERE c.code = 'DB'
)
ORDER BY s.full_name;

-- 5.2. Варіант B — JOIN
\echo '--- 5.2. JOIN ---'
SELECT DISTINCT s.student_number, s.full_name
FROM college.students s
JOIN college.enrollments e ON e.student_id = s.student_id
JOIN college.courses     c ON c.course_id  = e.course_id
WHERE c.code = 'DB'
ORDER BY s.full_name;

-- 5.3. Варіант C — EXISTS
\echo '--- 5.3. EXISTS ---'
SELECT s.student_number, s.full_name
FROM college.students s
WHERE EXISTS (
    SELECT 1
    FROM college.enrollments e
    JOIN college.courses c USING (course_id)
    WHERE e.student_id = s.student_id
      AND c.code = 'DB'
)
ORDER BY s.full_name;

-- Усі три дають однаковий результат.
-- Різниця — у плані виконання:
--   JOIN  потребує DISTINCT, якщо дубікати.
--   IN    без DISTINCT автоматично (IN є semi-join).
--   EXISTS зупиняється на першому матчі — часто швидший на великих даних.

-- Подивитись плани:
\echo '--- Плани виконання ---'
EXPLAIN SELECT 1 FROM college.students s
WHERE s.student_id IN (
    SELECT e.student_id FROM college.enrollments e
    JOIN college.courses c USING (course_id) WHERE c.code = 'DB');


-- =========================================================
-- ЧАСТИНА 6: Підзапит у FROM (похідна таблиця)
-- =========================================================
-- Підзапит у FROM поводиться як тимчасова таблиця.
-- Корисно для попередньої агрегації / фільтрації.

\echo '=== ЧАСТИНА 6: похідна таблиця ==='

-- 6.1. Статистика по курсах, потім сумарні показники по кафедрах
\echo '--- 6.1. Агрегація у підзапиті, підсумок ззовні ---'

SELECT
    d.code AS dep_code,
    d.name AS department,
    COUNT(*) AS courses_cnt,
    SUM(course_stats.students) AS total_students,
    ROUND(AVG(course_stats.avg_grade), 2) AS avg_dept_grade
FROM college.departments d
JOIN (
    -- Внутрішній: по курсу — скільки студентів, середня оцінка
    SELECT
        c.course_id,
        c.department_id,
        COUNT(e.student_id)  AS students,
        AVG(e.grade)         AS avg_grade
    FROM college.courses c
    LEFT JOIN college.enrollments e ON e.course_id = c.course_id
    GROUP BY c.course_id, c.department_id
) course_stats USING (department_id)
GROUP BY d.code, d.name
ORDER BY total_students DESC NULLS LAST;

-- Семантика: внутрішній підзапит дає per-course агрегат,
-- зовнішній GROUP BY — підсумок по кафедрі.
-- Без підзапиту такий звіт потребував би nested-aggregates,
-- що SQL прямо не підтримує.

-- 6.2. Той самий ефект через CTE (WITH) — читабельніше
\echo '--- 6.2. Через WITH (CTE) ---'

WITH course_stats AS (
    SELECT c.course_id, c.department_id,
           COUNT(e.student_id) AS students,
           AVG(e.grade)        AS avg_grade
    FROM college.courses c
    LEFT JOIN college.enrollments e USING (course_id)
    GROUP BY c.course_id, c.department_id
)
SELECT d.code, d.name,
       COUNT(*) AS courses_cnt,
       SUM(cs.students) AS total_students
FROM college.departments d
JOIN course_stats cs USING (department_id)
GROUP BY d.code, d.name;

-- CTE виконує те саме, але читається зверху вниз: спершу визначаємо
-- проміжну "таблицю", потім використовуємо її в головному запиті.


-- =========================================================
-- ЧАСТИНА 7: Корельовані підзапити у SELECT-списку
-- =========================================================

\echo '=== ЧАСТИНА 7: корельований підзапит у SELECT ==='

SELECT
    c.code,
    c.title,
    c.credits,
    (SELECT COUNT(*) FROM college.enrollments e
     WHERE e.course_id = c.course_id) AS enrolled_cnt,
    (SELECT ROUND(AVG(e.grade), 2) FROM college.enrollments e
     WHERE e.course_id = c.course_id AND e.grade IS NOT NULL) AS avg_grade
FROM college.courses c
ORDER BY enrolled_cnt DESC;

-- Для КОЖНОГО рядка c виконуються 2 підзапити (по одному).
-- На малих даних — зручно; на великих — часто повільніше, ніж JOIN+GROUP BY.


\echo '=== УСІ ПІДЗАПИТИ ВИКОНАНО ==='

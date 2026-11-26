-- =========================================================
-- dml.sql — маніпулювання даними: INSERT, UPDATE, DELETE, SELECT
-- Практична робота №9
-- Виконується на схемі з schema.sql (пр_7, пр_8)
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;

-- ---------- Очищення попередніх тестових даних ----------
-- RESTART IDENTITY скидає лічильник, щоб ID починалися з 1.
-- CASCADE очищує enrollments, що посилаються на students та courses.

TRUNCATE TABLE
    college.enrollments,
    college.courses,
    college.students,
    college.departments
RESTART IDENTITY CASCADE;


-- =========================================================
-- ЧАСТИНА 1: INSERT — наповнення таблиць тестовими даними
-- =========================================================

\echo '=== ЧАСТИНА 1: INSERT ==='

-- 1.1. Кафедри
INSERT INTO college.departments (code, name) VALUES
    ('IT',  'Інформаційні технології'),
    ('FIZ', 'Фізика'),
    ('MAT', 'Математика');

-- 1.2. Курси, прив'язані до кафедр (IT = department_id 1)
INSERT INTO college.courses (department_id, code, title, credits, tuition) VALUES
    (1, 'DB',   'Бази даних',       4, 4500.00),
    (1, 'WEB',  'Вебтехнології',    3, 3800.00),
    (1, 'ALG',  'Алгоритми',        5, 5200.00),
    (2, 'PH1',  'Загальна фізика',  4, 4200.00),
    (3, 'MA1',  'Дискретна математика', 3, 3500.00);

-- 1.3. Студенти з використанням RETURNING
\echo '--- 1.3. INSERT студентів з RETURNING ---'

INSERT INTO college.students
    (student_number, full_name, email, birth_date, enrollment_year)
VALUES
    ('ST-2024-001', 'Петренко Олег Іванович',  'petrenko@college.ua', '2005-03-12', 2024),
    ('ST-2024-002', 'Іваненко Марія Сергіївна', 'ivanenko@college.ua', '2005-07-08', 2024),
    ('ST-2024-003', 'Коваль Назар Петрович',    'koval@college.ua',    '2005-11-22', 2024)
RETURNING student_id, student_number, full_name;

-- RETURNING повертає рядки одразу після INSERT — зручно,
-- коли потрібно отримати згенеровані ID для подальшої вставки.

-- 1.4. Ще один студент з RETURNING у вигляді таблиці для наступних INSERT
INSERT INTO college.students
    (student_number, full_name, email, birth_date, enrollment_year)
VALUES
    ('ST-2023-017', 'Мельник Соломія Андріївна', 'melnyk@college.ua', '2004-08-15', 2023)
RETURNING *;


-- 1.5. Реєстрації на курси (M:N розв'язок)
INSERT INTO college.enrollments (student_id, course_id, grade, status) VALUES
    (1, 1,  92.5, 'completed'),  -- Петренко → Бази даних
    (1, 2,  85.0, 'active'),     -- Петренко → Вебтехнології
    (2, 1,  NULL, 'active'),     -- Іваненко → Бази даних (без оцінки)
    (2, 3,  78.0, 'active'),     -- Іваненко → Алгоритми
    (3, 4,  65.0, 'completed'),  -- Коваль → Фізика
    (4, 5,  88.0, 'completed');  -- Мельник → Математика

-- Перевірка кількості рядків
\echo 'Кількість доданих записів:'
SELECT 'departments' AS tab, COUNT(*) AS rows FROM college.departments
UNION ALL
SELECT 'students',    COUNT(*) FROM college.students
UNION ALL
SELECT 'courses',     COUNT(*) FROM college.courses
UNION ALL
SELECT 'enrollments', COUNT(*) FROM college.enrollments;


-- =========================================================
-- ЧАСТИНА 2: UPDATE — безпечна зміна рядків за умовою
-- =========================================================

\echo '=== ЧАСТИНА 2: UPDATE ==='

-- 2.1. Стан ДО оновлення
\echo '--- 2.1. ДО UPDATE ---'
SELECT student_id, course_id, grade, status
FROM college.enrollments
WHERE student_id = 2 AND course_id = 1;
-- Очікуємо: status = 'active', grade = NULL

-- 2.2. Оновлення: виставити оцінку 90 і статус 'completed'
-- УВАГА: обов'язково WHERE з двома умовами, щоб зачепити рівно один рядок
UPDATE college.enrollments
SET grade  = 90.0,
    status = 'completed'
WHERE student_id = 2 AND course_id = 1
RETURNING student_id, course_id, grade, status;

-- 2.3. Стан ПІСЛЯ оновлення
\echo '--- 2.3. ПІСЛЯ UPDATE ---'
SELECT student_id, course_id, grade, status
FROM college.enrollments
WHERE student_id = 2 AND course_id = 1;
-- Очікуємо: status = 'completed', grade = 90.0

-- 2.4. Масове оновлення з умовою:
-- всім «active» завершеним (grade не NULL) поставити 'completed'
\echo '--- 2.4. Масовий UPDATE з умовою ---'
UPDATE college.enrollments
SET status = 'completed'
WHERE status = 'active' AND grade IS NOT NULL
RETURNING student_id, course_id, grade, status;

-- 2.5. Інший патерн — UPDATE з обчисленням на основі поточного значення
-- (додаємо 2 бали всім з оцінкою < 80 як бонусну коригувальну)
\echo '--- 2.5. UPDATE з обчисленням ---'
UPDATE college.enrollments
SET grade = grade + 2
WHERE grade IS NOT NULL AND grade < 80
RETURNING student_id, course_id, grade;


-- =========================================================
-- ЧАСТИНА 3: DELETE — видалення з умовою
-- =========================================================

\echo '=== ЧАСТИНА 3: DELETE ==='

-- 3.1. Стан ДО видалення
\echo '--- 3.1. ДО DELETE ---'
SELECT * FROM college.enrollments WHERE student_id = 1 AND course_id = 2;

-- 3.2. Видалення запису з умовою
DELETE FROM college.enrollments
WHERE student_id = 1 AND course_id = 2
RETURNING student_id, course_id, grade, status;

-- 3.3. Стан ПІСЛЯ видалення
\echo '--- 3.3. ПІСЛЯ DELETE ---'
SELECT * FROM college.enrollments WHERE student_id = 1 AND course_id = 2;
-- Очікуємо: 0 рядків

-- 3.4. Що станеться з пов'язаними даними?
-- • Студент 1 (Петренко) не видаляється — лишається в students.
-- • Курс 2 (Вебтехнології) теж лишається в courses.
-- • Видалено тільки САМ зв'язок (запис на курс).
--
-- Якби спробували видалити САМОГО СТУДЕНТА:
--     DELETE FROM college.students WHERE student_id = 1;
-- Поведінка залежить від правила ON DELETE у fk_enrollments_student:
--   - ON DELETE CASCADE (наш випадок) — автоматично видалить усі
--     записи в enrollments для цього студента.
--   - ON DELETE RESTRICT — заблокує видалення, доки є залежні записи.

-- Демонстрація CASCADE (у транзакції, щоб відкотити):
BEGIN;
    SELECT COUNT(*) AS enrollments_before FROM college.enrollments WHERE student_id = 1;
    DELETE FROM college.students WHERE student_id = 1;
    SELECT COUNT(*) AS enrollments_after FROM college.enrollments WHERE student_id = 1;
    -- Очікуємо: 0 рядків — CASCADE видалив записи студента автоматично
ROLLBACK;


-- =========================================================
-- ЧАСТИНА 4: П'ять базових SELECT-запитів
-- =========================================================

\echo '=== ЧАСТИНА 4: SELECT запити ==='

-- 4.1. Запит з псевдонімами (AS)
\echo '--- Запит 1: псевдоніми колонок і таблиці ---'
SELECT
    s.student_number AS номер,
    s.full_name      AS студент,
    s.enrollment_year AS рік_вступу
FROM college.students AS s
ORDER BY s.full_name;

-- 4.2. Обчислюваний стовпець (конкатенація, арифметика)
\echo '--- Запит 2: обчислювані стовпці ---'
SELECT
    c.code                                  AS код,
    c.title                                 AS назва,
    c.credits                               AS кредити,
    c.tuition                               AS плата,
    (c.tuition / c.credits)::NUMERIC(10,2)  AS ціна_за_кредит,
    c.title || ' (' || c.code || ')'        AS повна_назва
FROM college.courses AS c
ORDER BY ціна_за_кредит DESC;

-- 4.3. Фільтр + сортування за кількома колонками
\echo '--- Запит 3: WHERE + ORDER BY ---'
SELECT
    e.student_id AS студент,
    e.course_id  AS курс,
    e.grade      AS оцінка,
    e.status     AS статус
FROM college.enrollments AS e
WHERE e.grade IS NOT NULL
ORDER BY e.grade DESC, e.student_id ASC;

-- 4.4. Використання DISTINCT + LIMIT
\echo '--- Запит 4: DISTINCT + LIMIT ---'
SELECT DISTINCT
    s.enrollment_year AS рік_вступу
FROM college.students AS s
ORDER BY рік_вступу DESC
LIMIT 5;

-- 4.5. CASE для умовного обчислення
\echo '--- Запит 5: CASE WHEN ---'
SELECT
    e.student_id AS студент,
    e.course_id  AS курс,
    e.grade      AS оцінка,
    CASE
        WHEN e.grade IS NULL THEN 'не виставлено'
        WHEN e.grade >= 90   THEN 'відмінно'
        WHEN e.grade >= 75   THEN 'добре'
        WHEN e.grade >= 60   THEN 'задовільно'
        ELSE                     'незадовільно'
    END AS рейтинг
FROM college.enrollments AS e
ORDER BY e.grade DESC NULLS LAST;


-- =========================================================
-- ЧАСТИНА 5: INSERT ... SELECT — альтернативна форма вставки
-- =========================================================

\echo '=== ЧАСТИНА 5: INSERT ... SELECT ==='

-- Створимо тимчасову таблицю для демонстрації
CREATE TEMPORARY TABLE top_students AS
SELECT student_id, full_name, enrollment_year
FROM college.students
WHERE 1 = 0;  -- тільки структура, без рядків

-- Заповнюємо вибіркою з основної таблиці
INSERT INTO top_students (student_id, full_name, enrollment_year)
SELECT s.student_id, s.full_name, s.enrollment_year
FROM college.students s
JOIN college.enrollments e ON e.student_id = s.student_id
WHERE e.grade >= 85
GROUP BY s.student_id, s.full_name, s.enrollment_year;

SELECT * FROM top_students ORDER BY full_name;

DROP TABLE top_students;


-- =========================================================
-- КІНЕЦЬ
-- =========================================================

\echo '=== Усі DML-операції виконано успішно ==='

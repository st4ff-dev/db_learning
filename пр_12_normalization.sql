-- =========================================================
-- normalization.sql — нормалізована схема в 3НФ/BCNF
-- Практична робота №12
-- Схема: college_norm (щоб не чіпати основну college.*)
-- СКБД: PostgreSQL 14+
-- =========================================================

-- Створюємо окрему схему для демонстрації
DROP SCHEMA IF EXISTS college_norm CASCADE;
CREATE SCHEMA college_norm;
SET search_path TO college_norm, public;


-- =========================================================
-- ДЕМО 1: Денормалізоване відношення (ненормалізоване)
-- =========================================================
-- Модель: одна «плоска» таблиця, що містить ВСЮ інформацію
-- про запис студента на курс, його кафедру та оцінку.
-- Це гіпотетична вхідна точка перед нормалізацією.

DROP TABLE IF EXISTS college_norm.enrollment_report;

CREATE TABLE college_norm.enrollment_report (
    -- Дані студента (повторюються в кожному рядку для того ж студента)
    student_id      INTEGER       NOT NULL,
    student_name    VARCHAR(100)  NOT NULL,
    student_phones  VARCHAR(500),   -- ❌ порушує 1НФ (список через кому)
    enrollment_year SMALLINT      NOT NULL,

    -- Дані курсу (повторюються в кожному рядку для того ж курсу)
    course_code    VARCHAR(20)    NOT NULL,
    course_title   VARCHAR(200)   NOT NULL,
    course_credits SMALLINT       NOT NULL,
    course_tuition NUMERIC(10,2)  NOT NULL,

    -- Дані кафедри (транзитивно залежать від курсу)
    department_id   INTEGER       NOT NULL,
    department_code VARCHAR(10)   NOT NULL,
    department_name TEXT          NOT NULL,

    -- Дані реєстрації
    enrolled_at DATE           NOT NULL,
    grade       NUMERIC(5,2),
    status      VARCHAR(20)    NOT NULL,

    CONSTRAINT pk_enrollment_report PRIMARY KEY (student_id, course_code)
);

-- Приклад денормалізованих даних (помилки надлишковості очевидні)
INSERT INTO college_norm.enrollment_report VALUES
    (1, 'Петренко О.І.', '+380501112233, +380671234567', 2024,
     'DB',  'Бази даних',    4, 4500.00,
     1, 'IT', 'Інформаційні технології',
     '2026-09-01', 92.5, 'completed'),

    (1, 'Петренко О.І.', '+380501112233, +380671234567', 2024,
     'WEB', 'Вебтехнології',  3, 3800.00,
     1, 'IT', 'Інформаційні технології',
     '2026-09-01', 85.0, 'active'),

    (2, 'Іваненко М.С.', '+380502223344',                 2024,
     'DB',  'Бази даних',    4, 4500.00,
     1, 'IT', 'Інформаційні технології',
     '2026-09-01', 90.0, 'completed'),

    (3, 'Коваль Н.П.', '+380503334455',                   2024,
     'PH1', 'Загальна фізика', 4, 4200.00,
     2, 'FIZ', 'Фізика',
     '2026-09-01', 65.0, 'completed');

-- Проблеми:
-- • Назва кафедри «Інформаційні технології» повторюється 3 рази.
-- • Назва курсу «Бази даних» дублюється для різних студентів.
-- • Телефони студента зберігаються як «список через кому» — не атомарно.
-- • Якщо перейменувати кафедру — доведеться оновити всі рядки.
-- • Видалення останнього запису про кафедру втратить саме знання про неї.


-- =========================================================
-- ДЕМО 2: Нормалізована схема у 3НФ / BCNF
-- =========================================================
-- Після декомпозиції кожне відношення містить дані ОДНОЇ сутності.

-- 2.1. Кафедри — department_id → (code, name)
CREATE TABLE college_norm.departments (
    department_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          VARCHAR(10) NOT NULL UNIQUE,
    name          TEXT        NOT NULL
);

-- 2.2. Студенти — student_id → (name, enrollment_year)
CREATE TABLE college_norm.students (
    student_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    enrollment_year SMALLINT     NOT NULL
);

-- 2.3. Телефони студентів — винесено для усунення 1НФ-порушення
CREATE TABLE college_norm.student_phones (
    student_id INTEGER     NOT NULL
        REFERENCES college_norm.students(student_id) ON DELETE CASCADE,
    phone      VARCHAR(20) NOT NULL,
    PRIMARY KEY (student_id, phone)
);

-- 2.4. Курси — course_code → (title, credits, tuition, department_id)
CREATE TABLE college_norm.courses (
    course_id     INTEGER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          VARCHAR(20)    NOT NULL UNIQUE,
    title         VARCHAR(200)   NOT NULL,
    credits       SMALLINT       NOT NULL CHECK (credits BETWEEN 1 AND 30),
    tuition       NUMERIC(10,2)  NOT NULL CHECK (tuition >= 0),
    department_id INTEGER        NOT NULL
        REFERENCES college_norm.departments(department_id) ON DELETE RESTRICT
);

-- 2.5. Реєстрації — (student_id, course_id) → (enrolled_at, grade, status)
CREATE TABLE college_norm.enrollments (
    student_id  INTEGER     NOT NULL
        REFERENCES college_norm.students(student_id) ON DELETE CASCADE,
    course_id   INTEGER     NOT NULL
        REFERENCES college_norm.courses(course_id)   ON DELETE RESTRICT,
    enrolled_at DATE        NOT NULL DEFAULT CURRENT_DATE,
    grade       NUMERIC(5,2) CHECK (grade IS NULL OR grade BETWEEN 0 AND 100),
    status      VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','completed','dropped','failed')),

    PRIMARY KEY (student_id, course_id)
);


-- =========================================================
-- ДЕМО 3: Перенесення даних з денормалізованої таблиці
-- =========================================================
-- INSERT ... SELECT з DISTINCT, щоб усунути дублікати

INSERT INTO college_norm.departments (code, name)
SELECT DISTINCT department_code, department_name
FROM college_norm.enrollment_report;

INSERT INTO college_norm.students (full_name, enrollment_year)
SELECT DISTINCT student_name, enrollment_year
FROM college_norm.enrollment_report;

-- Телефони — розбиваємо список через кому на окремі рядки
INSERT INTO college_norm.student_phones (student_id, phone)
SELECT s.student_id,
       TRIM(unnest(string_to_array(r.student_phones, ',')))
FROM college_norm.enrollment_report r
JOIN college_norm.students s ON s.full_name = r.student_name
WHERE r.student_phones IS NOT NULL;

INSERT INTO college_norm.courses (code, title, credits, tuition, department_id)
SELECT DISTINCT r.course_code, r.course_title, r.course_credits, r.course_tuition, d.department_id
FROM college_norm.enrollment_report r
JOIN college_norm.departments d ON d.code = r.department_code;

INSERT INTO college_norm.enrollments (student_id, course_id, enrolled_at, grade, status)
SELECT s.student_id, c.course_id, r.enrolled_at, r.grade, r.status
FROM college_norm.enrollment_report r
JOIN college_norm.students s ON s.full_name = r.student_name
JOIN college_norm.courses  c ON c.code = r.course_code;


-- =========================================================
-- ДЕМО 4: Перевірка — ті ж дані тепер без дублікатів
-- =========================================================

\echo '--- Таблиця departments (унікальні записи) ---'
SELECT * FROM college_norm.departments;

\echo '--- Таблиця students (унікальні) ---'
SELECT * FROM college_norm.students;

\echo '--- Таблиця student_phones (кожен телефон — свій рядок) ---'
SELECT * FROM college_norm.student_phones;

\echo '--- Таблиця courses (посилаються на department_id, не на назву) ---'
SELECT * FROM college_norm.courses;

\echo '--- Таблиця enrollments ---'
SELECT * FROM college_norm.enrollments;


-- =========================================================
-- ДЕМО 5: Усунення аномалії — перейменування кафедри
-- =========================================================
-- У денормалізованій таблиці довелося б оновлювати багато рядків.
-- У нормалізованій — один рядок у departments.

\echo '--- 5.1. Аномалія оновлення у ДЕНОРМАЛІЗОВАНІЙ таблиці ---'

BEGIN;
    UPDATE college_norm.enrollment_report
    SET department_name = 'Інформатика та технології'
    WHERE department_code = 'IT';

    -- Дивимось, скільки рядків довелося зачепити:
    -- залежить від кількості студентів, записаних на курси IT.
    SELECT COUNT(*) AS rows_updated
    FROM college_norm.enrollment_report
    WHERE department_code = 'IT';
ROLLBACK;

\echo '--- 5.2. Те ж саме у НОРМАЛІЗОВАНІЙ схемі ---'

BEGIN;
    UPDATE college_norm.departments
    SET name = 'Інформатика та технології'
    WHERE code = 'IT';

    SELECT COUNT(*) AS rows_updated
    FROM college_norm.departments
    WHERE code = 'IT';
    -- Завжди 1 рядок, незалежно від кількості курсів чи студентів.
ROLLBACK;


\echo '=== НОРМАЛІЗАЦІЯ ЗАВЕРШЕНА ==='

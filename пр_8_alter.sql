-- =========================================================
-- alter.sql — демонстрація ALTER, TRUNCATE, DROP
-- Практична робота №8
-- Виконується на структурі, створеній schema.sql (пр_7, пр_8)
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;

-- =========================================================
-- ЧАСТИНА 1: ALTER TABLE на college.courses
-- =========================================================

\echo '=== ЧАСТИНА 1: ALTER TABLE ==='

-- 1.1. Додати нову колонку description (текст, дозволяє NULL)
\echo '--- 1.1. ADD COLUMN description ---'
ALTER TABLE college.courses ADD COLUMN description TEXT;

-- Перевірка: колонка з'явилась, у всіх рядках NULL
SELECT course_id, code, title, description
FROM college.courses
ORDER BY course_id;

-- 1.2. Встановити значення за замовчуванням
\echo '--- 1.2. SET DEFAULT ---'
ALTER TABLE college.courses
    ALTER COLUMN description SET DEFAULT 'опис відсутній';

-- Перевірка: DEFAULT застосовується тільки до нових INSERT
INSERT INTO college.courses (code, title, department_id, credits, tuition)
VALUES ('CS103', 'Веб-розробка', 1, 5, 4800.00);

SELECT code, title, description
FROM college.courses
WHERE code = 'CS103';
-- Очікуємо: description = 'опис відсутній'

-- Існуючі рядки лишаються з NULL — DEFAULT не змінює їх заднім числом
SELECT code, title, description
FROM college.courses
WHERE code = 'CS101';
-- Очікуємо: description = NULL

-- 1.3. Видалити колонку description
\echo '--- 1.3. DROP COLUMN description ---'
ALTER TABLE college.courses DROP COLUMN description;

-- Перевірка: колонка зникла
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'college' AND table_name = 'courses'
ORDER BY ordinal_position;
-- У списку немає description

-- Прибираємо тестовий запис CS103
DELETE FROM college.courses WHERE code = 'CS103';


-- =========================================================
-- ЧАСТИНА 2: Інші форми ALTER (переносимість, без виконання)
-- =========================================================
-- Закоментовано, щоб не ламати основну схему. Розкоментуйте по черзі
-- для експериментів:
--
-- ALTER TABLE college.courses RENAME COLUMN title TO course_title;
-- ALTER TABLE college.courses RENAME TO disciplines;
-- ALTER TABLE college.courses ALTER COLUMN credits TYPE INTEGER;
-- ALTER TABLE college.courses ALTER COLUMN tuition SET NOT NULL;
-- ALTER TABLE college.courses ADD CONSTRAINT ck_courses_tuition_max
--     CHECK (tuition <= 100000);


-- =========================================================
-- ЧАСТИНА 3: DROP vs TRUNCATE на тестовій таблиці
-- =========================================================

\echo '=== ЧАСТИНА 3: TRUNCATE vs DROP ==='

-- 3.1. Створити тестову таблицю
\echo '--- 3.1. Створення test_truncate ---'
DROP TABLE IF EXISTS college.test_truncate;

CREATE TABLE college.test_truncate (
    id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL
);

-- 3.2. Додати кілька рядків
INSERT INTO college.test_truncate (name) VALUES
    ('перший запис'),
    ('другий запис'),
    ('третій запис');

\echo 'Кількість рядків ДО TRUNCATE:'
SELECT COUNT(*) AS rows_before FROM college.test_truncate;
-- Очікуємо: 3

SELECT * FROM college.test_truncate ORDER BY id;

-- 3.3. Виконати TRUNCATE — видалити ВСІ рядки, зберегти структуру
\echo '--- 3.3. TRUNCATE ---'
TRUNCATE TABLE college.test_truncate;

\echo 'Кількість рядків ПІСЛЯ TRUNCATE:'
SELECT COUNT(*) AS rows_after FROM college.test_truncate;
-- Очікуємо: 0

-- Таблиця існує! Можемо знову вставляти:
INSERT INTO college.test_truncate (name) VALUES ('після truncate');
SELECT * FROM college.test_truncate;
-- Зверніть увагу: id почнеться з 4 (IDENTITY не скидається без RESTART)

-- 3.4. TRUNCATE з RESTART IDENTITY — скидає послідовність
\echo '--- 3.4. TRUNCATE ... RESTART IDENTITY ---'
TRUNCATE TABLE college.test_truncate RESTART IDENTITY;
INSERT INTO college.test_truncate (name) VALUES ('знову з id=1');
SELECT * FROM college.test_truncate;
-- Тепер id = 1

-- 3.5. DROP — повне знищення таблиці
\echo '--- 3.5. DROP TABLE ---'
DROP TABLE college.test_truncate;

-- Спроба селекту тепер падає з помилкою:
-- SELECT * FROM college.test_truncate;
-- ERROR: relation "college.test_truncate" does not exist


-- =========================================================
-- ЧАСТИНА 4: Спроба видалити таблицю з FK-посиланням
-- =========================================================

\echo '=== ЧАСТИНА 4: FK-залежність ==='

-- 4.1. Спроба видалити departments (помилка!)
\echo '--- 4.1. DROP TABLE departments (має впасти з помилкою) ---'

-- Обгортаємо в BEGIN/ROLLBACK, щоб не руйнувати схему й наступного разу
BEGIN;

-- Ця команда ЗАВЖДИ падає, доки є fk_courses_department:
-- Розкоментуйте, щоб побачити повідомлення:
--
-- DROP TABLE college.departments;
--
-- Очікуване повідомлення:
-- ERROR:  cannot drop table college.departments because other objects depend on it
-- DETAIL:  constraint fk_courses_department on table college.courses depends on table college.departments
-- HINT:  Use DROP ... CASCADE to drop the dependent objects too.

ROLLBACK;

-- 4.2. Правильний варіант — DROP CASCADE (небезпечно для production!)
\echo '--- 4.2. DROP TABLE ... CASCADE (демонстрація у транзакції) ---'

BEGIN;

DROP TABLE college.departments CASCADE;
-- NOTICE: drop cascades to constraint fk_courses_department on table college.courses

-- Перевірити, що departments зникла, courses залишилась, але без FK
-- SELECT table_name FROM information_schema.tables WHERE table_schema='college';

-- Відкочуємо назад — не хочемо реально зламати схему
ROLLBACK;

\echo 'Відкочено. Структура збережена.'

-- 4.3. Безпечний варіант — спочатку видалити FK, потім таблицю
\echo '--- 4.3. ALTER TABLE DROP CONSTRAINT, потім DROP TABLE ---'

BEGIN;

-- Знімаємо посилання
ALTER TABLE college.courses DROP CONSTRAINT fk_courses_department;

-- Тепер DROP працює без CASCADE
DROP TABLE college.departments;

-- Але courses тепер «осиротіла» — її department_id посилається на неіснуюче
-- Відкочуємо назад
ROLLBACK;


-- =========================================================
-- ЧАСТИНА 5: Безпечні експерименти (у транзакції з ROLLBACK)
-- =========================================================

\echo '=== ЧАСТИНА 5: Безпечний паттерн "BEGIN ... ROLLBACK" ==='

BEGIN;

-- Робимо будь-яку ризиковану зміну
ALTER TABLE college.students ADD COLUMN gpa NUMERIC(3,2) DEFAULT 0.00;

-- Перевіряємо результат
SELECT student_number, full_name, gpa FROM college.students;

-- Якби хотіли зберегти зміни — COMMIT;
-- Тут не зберігаємо:
ROLLBACK;

-- Колонка gpa зникла, наче її й не було
SELECT column_name FROM information_schema.columns
WHERE table_schema='college' AND table_name='students'
ORDER BY ordinal_position;


-- =========================================================
-- КІНЕЦЬ. Основна схема залишається недоторканою.
-- =========================================================

\echo '=== УСІ ЕКСПЕРИМЕНТИ ЗАВЕРШЕНО ==='
\echo 'Основна схема college.* не змінена.'

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'college'
ORDER BY table_name;

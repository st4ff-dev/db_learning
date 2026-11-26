-- =========================================================
-- integrity.sql — реалізація цілісності даних
-- Практична робота №10
-- Демонструє PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT,
-- каскадні дії RESTRICT і CASCADE.
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;

-- ---------- Очищення демонстраційних таблиць ----------
DROP TABLE IF EXISTS college.demo_pages      CASCADE;
DROP TABLE IF EXISTS college.demo_books      CASCADE;
DROP TABLE IF EXISTS college.demo_employees  CASCADE;


-- =========================================================
-- ЧАСТИНА 1: Створення таблиць з ПОВНИМ набором обмежень
-- =========================================================

\echo '=== ЧАСТИНА 1: створення таблиць з обмеженнями ==='

-- 1.1. Таблиця demo_employees — демонструє UNIQUE, CHECK, DEFAULT, NOT NULL
CREATE TABLE college.demo_employees (
    employee_id INTEGER     GENERATED ALWAYS AS IDENTITY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(100),                              -- NULL дозволено
    phone       VARCHAR(20),                               -- NULL дозволено
    salary      NUMERIC(10,2) NOT NULL DEFAULT 20000.00,   -- DEFAULT
    hire_date   DATE          NOT NULL DEFAULT CURRENT_DATE,
    age         SMALLINT      NOT NULL,                    -- CHECK далі

    CONSTRAINT pk_demo_employees        PRIMARY KEY (employee_id),
    CONSTRAINT uq_demo_employees_email  UNIQUE (email),      -- UNIQUE з NULL
    CONSTRAINT uq_demo_employees_phone  UNIQUE (phone),
    CONSTRAINT ck_demo_employees_salary CHECK (salary >= 0),
    CONSTRAINT ck_demo_employees_age    CHECK (age BETWEEN 18 AND 100)
);

COMMENT ON TABLE college.demo_employees IS 'Демо: обмеження NOT NULL, UNIQUE, CHECK, DEFAULT';


-- 1.2. Таблиця demo_books (батьківська) — для демо CASCADE
CREATE TABLE college.demo_books (
    book_id INTEGER     GENERATED ALWAYS AS IDENTITY,
    title   VARCHAR(200) NOT NULL,
    author  VARCHAR(100) NOT NULL,

    CONSTRAINT pk_demo_books PRIMARY KEY (book_id)
);

-- 1.3. Таблиця demo_pages (дочірня) — демо ON DELETE CASCADE
CREATE TABLE college.demo_pages (
    page_id     INTEGER     GENERATED ALWAYS AS IDENTITY,
    book_id     INTEGER     NOT NULL,
    page_number INTEGER     NOT NULL,
    content     TEXT,

    CONSTRAINT pk_demo_pages         PRIMARY KEY (page_id),
    CONSTRAINT fk_demo_pages_book
        FOREIGN KEY (book_id)
        REFERENCES college.demo_books (book_id)
        ON DELETE CASCADE,                        -- ← КАСКАД
    CONSTRAINT uq_demo_pages_book_page
        UNIQUE (book_id, page_number),
    CONSTRAINT ck_demo_pages_number
        CHECK (page_number > 0)
);

COMMENT ON TABLE college.demo_pages IS 'Демо: ON DELETE CASCADE — сторінки видаляються з книгою';


-- 1.4. Наповнюємо книги й сторінки
INSERT INTO college.demo_books (title, author) VALUES
    ('Linux основи',   'Торвальдс'),
    ('SQL за 21 день', 'Денніс');

INSERT INTO college.demo_pages (book_id, page_number, content) VALUES
    (1, 1, 'Розділ 1: Що таке Linux'),
    (1, 2, 'Розділ 2: Файлова система'),
    (1, 3, 'Розділ 3: Процеси'),
    (2, 1, 'День 1: SELECT'),
    (2, 2, 'День 2: WHERE');


-- =========================================================
-- ЧАСТИНА 2: Демонстрація ON DELETE RESTRICT
-- =========================================================
-- Для цього використовуємо існуючу залежність:
-- college.departments → college.courses (fk_courses_department, RESTRICT)
-- Якщо даних немає — виконайте спочатку dml.sql.

\echo '=== ЧАСТИНА 2: ON DELETE RESTRICT ==='

\echo '--- 2.1. Спроба видалити кафедру з курсами (має впасти) ---'

-- Переконаємося, що курс посилається на кафедру IT (department_id = 1)
SELECT d.department_id, d.code AS dep_code,
       COUNT(c.course_id) AS courses_count
FROM college.departments d
LEFT JOIN college.courses c ON c.department_id = d.department_id
GROUP BY d.department_id, d.code
ORDER BY d.department_id;

-- У транзакції (щоб відкотити й не руйнувати схему)
BEGIN;

-- Ця команда ЗАВЖДИ впаде, бо RESTRICT:
-- DELETE FROM college.departments WHERE department_id = 1;
--
-- Очікуване повідомлення:
-- ERROR:  update or delete on table "departments" violates
--         foreign key constraint "fk_courses_department" on table "courses"
-- DETAIL: Key (department_id)=(1) is still referenced from table "courses".

-- Щоб скрипт пройшов без фактичної помилки, обгортаємо в DO з EXCEPTION:
DO $$
BEGIN
    DELETE FROM college.departments WHERE department_id = 1;
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'ОЧІКУВАНА ПОМИЛКА: %', SQLERRM;
END $$;

ROLLBACK;


-- =========================================================
-- ЧАСТИНА 3: Демонстрація ON DELETE CASCADE
-- =========================================================

\echo '=== ЧАСТИНА 3: ON DELETE CASCADE ==='

\echo '--- 3.1. Стан ДО видалення книги ---'
SELECT b.book_id, b.title,
       (SELECT COUNT(*) FROM college.demo_pages p WHERE p.book_id = b.book_id) AS pages_count
FROM college.demo_books b
ORDER BY b.book_id;

\echo '--- 3.2. Видаляємо книгу 1 (разом із 3 сторінками) ---'
BEGIN;

    DELETE FROM college.demo_books WHERE book_id = 1
    RETURNING book_id, title;

    -- Перевіряємо, що сторінки видалилися автоматично
    SELECT COUNT(*) AS pages_of_book1_after
    FROM college.demo_pages WHERE book_id = 1;
    -- Очікуємо: 0

    -- Сторінки іншої книги не зачеплено
    SELECT COUNT(*) AS pages_of_book2
    FROM college.demo_pages WHERE book_id = 2;
    -- Очікуємо: 2

ROLLBACK;  -- повертаємо дані на місце

\echo 'Після ROLLBACK дані відновлено:'
SELECT b.book_id, b.title,
       (SELECT COUNT(*) FROM college.demo_pages p WHERE p.book_id = b.book_id) AS pages_count
FROM college.demo_books b
ORDER BY b.book_id;


-- =========================================================
-- ЧАСТИНА 4: Спроби порушення КОЖНОГО обмеження
-- =========================================================

\echo '=== ЧАСТИНА 4: порушення обмежень ==='

-- 4.1. NOT NULL
\echo '--- 4.1. NOT NULL ---'
DO $$
BEGIN
    INSERT INTO college.demo_employees (full_name, age) VALUES (NULL, 30);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'NOT NULL: %', SQLERRM;
END $$;

-- 4.2. PRIMARY KEY (спроба вставити з уже існуючим PK)
\echo '--- 4.2. PRIMARY KEY (ALWAYS IDENTITY захищає від ручної вставки) ---'
DO $$
BEGIN
    -- GENERATED ALWAYS не дозволяє явно задати значення
    INSERT INTO college.demo_employees (employee_id, full_name, age)
    VALUES (1, 'Тест', 25);
EXCEPTION
    WHEN generated_always THEN
        RAISE NOTICE 'IDENTITY ALWAYS: %', SQLERRM;
END $$;

-- 4.3. UNIQUE
\echo '--- 4.3. UNIQUE ---'
INSERT INTO college.demo_employees (full_name, email, age)
VALUES ('Іван', 'ivan@test.ua', 30);

DO $$
BEGIN
    INSERT INTO college.demo_employees (full_name, email, age)
    VALUES ('Інший Іван', 'ivan@test.ua', 28);
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'UNIQUE: %', SQLERRM;
END $$;

-- 4.4. CHECK (діапазон віку 18..100)
\echo '--- 4.4. CHECK ---'
DO $$
BEGIN
    INSERT INTO college.demo_employees (full_name, age) VALUES ('Молодий', 15);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'CHECK age: %', SQLERRM;
END $$;

DO $$
BEGIN
    INSERT INTO college.demo_employees (full_name, age, salary)
    VALUES ('Боржник', 30, -1000);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'CHECK salary: %', SQLERRM;
END $$;

-- 4.5. FOREIGN KEY (сторінка з неіснуючою книгою)
\echo '--- 4.5. FOREIGN KEY ---'
DO $$
BEGIN
    INSERT INTO college.demo_pages (book_id, page_number, content)
    VALUES (9999, 1, 'Не існує книги 9999');
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'FOREIGN KEY: %', SQLERRM;
END $$;


-- =========================================================
-- ЧАСТИНА 5: UNIQUE і NULL — скільки NULL дозволено?
-- =========================================================

\echo '=== ЧАСТИНА 5: UNIQUE і NULL ==='

-- У колонці email стоїть UNIQUE. Спробуємо вставити кілька рядків з NULL.
INSERT INTO college.demo_employees (full_name, email, age) VALUES
    ('Анна', NULL, 25),
    ('Богдан', NULL, 27),
    ('Віктор', NULL, 29);

\echo 'Усі три NULL прийняті:'
SELECT employee_id, full_name, email
FROM college.demo_employees
WHERE email IS NULL;

-- Чому? Бо NULL != NULL за семантикою SQL — UNIQUE не вважає два NULL дублікатами.
-- У PostgreSQL 15+ з'явилася опція NULLS NOT DISTINCT, що міняє цю поведінку:
-- CONSTRAINT uq_... UNIQUE NULLS NOT DISTINCT (email)


-- =========================================================
-- ЧАСТИНА 6: DEFAULT і коли він спрацьовує
-- =========================================================

\echo '=== ЧАСТИНА 6: DEFAULT ==='

-- 6.1. DEFAULT спрацьовує, коли колонка НЕ ВКАЗАНА в INSERT
INSERT INTO college.demo_employees (full_name, age)
VALUES ('Марія', 35);

SELECT full_name, salary, hire_date
FROM college.demo_employees
WHERE full_name = 'Марія';
-- salary = 20000.00 (з DEFAULT), hire_date = сьогодні

-- 6.2. DEFAULT НЕ спрацьовує, якщо явно передано NULL
-- Але salary має NOT NULL, тому помилка
DO $$
BEGIN
    INSERT INTO college.demo_employees (full_name, age, salary)
    VALUES ('Невдалий', 40, NULL);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'DEFAULT НЕ спрацьовує при явному NULL: %', SQLERRM;
END $$;

-- 6.3. DEFAULT спрацьовує тільки при INSERT, не при UPDATE
UPDATE college.demo_employees
SET salary = DEFAULT        -- ось так треба явно
WHERE full_name = 'Анна';

SELECT full_name, salary FROM college.demo_employees WHERE full_name = 'Анна';


-- =========================================================
-- ЧАСТИНА 7: Підсумкова перевірка — усі обмеження активні
-- =========================================================

\echo '=== ЧАСТИНА 7: перелік усіх обмежень демо-таблиць ==='

SELECT
    conname           AS constraint_name,
    CASE contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'c' THEN 'CHECK'
        WHEN 'n' THEN 'NOT NULL'
        ELSE contype::text
    END               AS constraint_type,
    conrelid::regclass AS table_name
FROM pg_constraint
WHERE conrelid::regclass::text LIKE 'college.demo_%'
ORDER BY table_name, contype, conname;


\echo '=== УСІ ПЕРЕВІРКИ ВИКОНАНО ==='

-- =========================================================
-- schema.sql — визначення схеми college.*
-- Практична робота №7: DDL для коледжу
-- СКБД: PostgreSQL 14+
-- =========================================================

-- Підключаємось до бази college та працюємо у схемі college
SET search_path TO college, public;

-- ---------- Очищення (DROP у зворотному порядку залежностей) ----------
DROP TABLE IF EXISTS college.enrollments CASCADE;
DROP TABLE IF EXISTS college.courses     CASCADE;
DROP TABLE IF EXISTS college.students    CASCADE;
DROP TABLE IF EXISTS college.departments CASCADE;

-- =========================================================
-- 1. departments — кафедри
-- =========================================================
CREATE TABLE college.departments (
    department_id INTEGER GENERATED ALWAYS AS IDENTITY,
    code          VARCHAR(10) NOT NULL,
    name          TEXT        NOT NULL,

    CONSTRAINT pk_departments        PRIMARY KEY (department_id),
    CONSTRAINT uq_departments_code   UNIQUE      (code),
    CONSTRAINT ck_departments_code_len
        CHECK (LENGTH(code) BETWEEN 2 AND 10)
);

COMMENT ON TABLE  college.departments IS 'Кафедри навчального закладу';
COMMENT ON COLUMN college.departments.code IS 'Коротка абревіатура, напр. CS, MATH';

-- =========================================================
-- 2. students — студенти
-- =========================================================
CREATE TABLE college.students (
    student_id      INTEGER     GENERATED ALWAYS AS IDENTITY,
    student_number  VARCHAR(20) NOT NULL,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100),
    birth_date      DATE,
    enrollment_year SMALLINT    NOT NULL,

    CONSTRAINT pk_students                    PRIMARY KEY (student_id),
    CONSTRAINT uq_students_student_number     UNIQUE      (student_number),
    CONSTRAINT uq_students_email              UNIQUE      (email),
    CONSTRAINT ck_students_enrollment_year
        CHECK (enrollment_year BETWEEN 1990 AND 2100),
    CONSTRAINT ck_students_email_format
        CHECK (email IS NULL OR email LIKE '%@%.%')
);

COMMENT ON TABLE college.students IS 'Студенти коледжу';

-- =========================================================
-- 3. courses — навчальні дисципліни
-- =========================================================
CREATE TABLE college.courses (
    course_id     INTEGER        GENERATED ALWAYS AS IDENTITY,
    code          VARCHAR(20)    NOT NULL,
    title         VARCHAR(200)   NOT NULL,
    department_id INTEGER        NOT NULL,
    credits       SMALLINT       NOT NULL,
    tuition       NUMERIC(10, 2) NOT NULL DEFAULT 0.00,

    CONSTRAINT pk_courses               PRIMARY KEY (course_id),
    CONSTRAINT uq_courses_code          UNIQUE      (code),
    CONSTRAINT fk_courses_department
        FOREIGN KEY (department_id)
        REFERENCES college.departments (department_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_courses_credits       CHECK (credits BETWEEN 1 AND 30),
    CONSTRAINT ck_courses_tuition       CHECK (tuition >= 0)
);

COMMENT ON TABLE  college.courses IS 'Навчальні дисципліни';
COMMENT ON COLUMN college.courses.credits IS 'Кількість кредитів ECTS (1..30)';
COMMENT ON COLUMN college.courses.tuition IS 'Плата за навчання, грн';

-- =========================================================
-- 4. enrollments — записи на курс (M:N students ↔ courses)
-- =========================================================
CREATE TABLE college.enrollments (
    student_id  INTEGER        NOT NULL,
    course_id   INTEGER        NOT NULL,
    enrolled_at DATE           NOT NULL DEFAULT CURRENT_DATE,
    grade       NUMERIC(5, 2),
    status      VARCHAR(20)    NOT NULL DEFAULT 'active',

    CONSTRAINT pk_enrollments
        PRIMARY KEY (student_id, course_id),
    CONSTRAINT fk_enrollments_student
        FOREIGN KEY (student_id)
        REFERENCES college.students (student_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (course_id)
        REFERENCES college.courses (course_id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_enrollments_grade
        CHECK (grade IS NULL OR grade BETWEEN 0 AND 100),
    CONSTRAINT ck_enrollments_status
        CHECK (status IN ('active', 'completed', 'dropped', 'failed'))
);

COMMENT ON TABLE  college.enrollments IS 'Записи студентів на курси';
COMMENT ON COLUMN college.enrollments.grade IS 'Підсумкова оцінка 0..100; NULL — ще не виставлена';

-- ---------- Індекси для прискорення типових запитів ----------
CREATE INDEX idx_courses_department  ON college.courses (department_id);
CREATE INDEX idx_enrollments_course  ON college.enrollments (course_id);
CREATE INDEX idx_students_year       ON college.students (enrollment_year);

-- ---------- Тестові дані для перевірки ----------
INSERT INTO college.departments (code, name) VALUES
    ('CS',   'Комп''ютерні науки'),
    ('MATH', 'Математика'),
    ('PHYS', 'Фізика');

INSERT INTO college.students (student_number, full_name, email, birth_date, enrollment_year) VALUES
    ('ST-2024-001', 'Петренко Олег Іванович',  'petrenko@college.ua',  '2005-03-12', 2024),
    ('ST-2024-002', 'Іваненко Марія Сергіївна', 'ivanenko@college.ua', '2005-07-08', 2024),
    ('ST-2023-017', 'Коваль Назар Петрович',    'koval@college.ua',    '2004-11-22', 2023);

INSERT INTO college.courses (code, title, department_id, credits, tuition) VALUES
    ('CS101',   'Основи баз даних',    1, 5, 4500.00),
    ('CS102',   'Алгоритми',           1, 6, 5000.00),
    ('MATH201', 'Дискретна математика', 2, 4, 3800.00);

INSERT INTO college.enrollments (student_id, course_id, grade, status) VALUES
    (1, 1, 92.5, 'completed'),
    (1, 2, 85.0, 'active'),
    (2, 1, NULL, 'active'),
    (3, 3, 78.0, 'completed');

-- ---------- Перевірочні запити ----------
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'college';
-- SELECT * FROM college.departments;
-- SELECT * FROM college.courses;

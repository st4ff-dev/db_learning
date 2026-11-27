-- =========================================================
-- Migration V1 — Initial schema
-- Author: student
-- Date:   2026-11-27
-- Description: Створює базову схему college.* з 4 таблицями
--              (стан, еквівалентний schema.sql з пр_7/пр_8).
-- =========================================================

-- Забезпечуємо, що схема college існує
CREATE SCHEMA IF NOT EXISTS college;

SET search_path TO college, public;

-- ---------- 1. departments ----------
CREATE TABLE college.departments (
    department_id INTEGER     GENERATED ALWAYS AS IDENTITY,
    code          VARCHAR(10) NOT NULL,
    name          TEXT        NOT NULL,

    CONSTRAINT pk_departments      PRIMARY KEY (department_id),
    CONSTRAINT uq_departments_code UNIQUE      (code)
);

-- ---------- 2. students ----------
CREATE TABLE college.students (
    student_id      INTEGER      GENERATED ALWAYS AS IDENTITY,
    student_number  VARCHAR(20)  NOT NULL,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100),
    birth_date      DATE,
    enrollment_year SMALLINT     NOT NULL,

    CONSTRAINT pk_students                PRIMARY KEY (student_id),
    CONSTRAINT uq_students_student_number UNIQUE      (student_number),
    CONSTRAINT uq_students_email          UNIQUE      (email),
    CONSTRAINT ck_students_enrollment_year
        CHECK (enrollment_year BETWEEN 1990 AND 2100)
);

-- ---------- 3. courses ----------
CREATE TABLE college.courses (
    course_id     INTEGER        GENERATED ALWAYS AS IDENTITY,
    code          VARCHAR(20)    NOT NULL,
    title         VARCHAR(200)   NOT NULL,
    department_id INTEGER        NOT NULL,
    credits       SMALLINT       NOT NULL,
    tuition       NUMERIC(10, 2) NOT NULL DEFAULT 0.00,

    CONSTRAINT pk_courses       PRIMARY KEY (course_id),
    CONSTRAINT uq_courses_code  UNIQUE      (code),
    CONSTRAINT fk_courses_department
        FOREIGN KEY (department_id)
        REFERENCES college.departments (department_id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_courses_credits CHECK (credits BETWEEN 1 AND 30),
    CONSTRAINT ck_courses_tuition CHECK (tuition >= 0)
);

-- ---------- 4. enrollments ----------
CREATE TABLE college.enrollments (
    student_id  INTEGER     NOT NULL,
    course_id   INTEGER     NOT NULL,
    enrolled_at DATE        NOT NULL DEFAULT CURRENT_DATE,
    grade       NUMERIC(5, 2),
    status      VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT pk_enrollments PRIMARY KEY (student_id, course_id),
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

-- Тестові дані
INSERT INTO college.departments (code, name) VALUES
    ('IT',  'Інформаційні технології'),
    ('FIZ', 'Фізика'),
    ('MAT', 'Математика');

INSERT INTO college.students (student_number, full_name, email, enrollment_year) VALUES
    ('ST-2024-001', 'Петренко Олег',  'petrenko@college.ua', 2024),
    ('ST-2024-002', 'Іваненко Марія', 'ivanenko@college.ua', 2024);

INSERT INTO college.courses (code, title, department_id, credits, tuition) VALUES
    ('DB',  'Бази даних',    1, 4, 4500.00),
    ('WEB', 'Вебтехнології', 1, 3, 3800.00);

INSERT INTO college.enrollments (student_id, course_id, grade, status) VALUES
    (1, 1, 92.5, 'completed'),
    (2, 1, NULL, 'active');

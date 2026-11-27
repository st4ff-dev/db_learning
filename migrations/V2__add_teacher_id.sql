-- =========================================================
-- Migration V2 — Add teacher_id to courses
-- Author: student
-- Date:   2026-11-27
-- Description:
--   Створює таблицю teachers і додає обов'язковий стовпець
--   teacher_id до courses з FK на teachers.
--
-- Складність: таблиця courses вже містить дані, а нова колонка
-- має бути NOT NULL. Пряме додавання NOT NULL-колонки без DEFAULT
-- викличе помилку "column contains null values". Тому розбиваємо
-- на три кроки:
--   1) Створити teachers і вставити принаймні одного teacher
--      (щоб було на що посилатися).
--   2) Додати teacher_id як NULL, заповнити існуючі рядки.
--   3) Додати NOT NULL + FK.
-- =========================================================

SET search_path TO college, public;

-- ---------- Крок 1. Створити teachers і базовий запис ----------
CREATE TABLE college.teachers (
    teacher_id  INTEGER      GENERATED ALWAYS AS IDENTITY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(100),
    academic_rank VARCHAR(50),

    CONSTRAINT pk_teachers        PRIMARY KEY (teacher_id),
    CONSTRAINT uq_teachers_email  UNIQUE      (email)
);

-- Вставляємо «невідомого» викладача для успадкованих курсів
INSERT INTO college.teachers (full_name, email, academic_rank) VALUES
    ('Не призначено', NULL, NULL),
    ('Сидоренко А.В.', 'sydorenko@college.ua', 'доцент'),
    ('Коваленко П.І.', 'kovalenko@college.ua', 'професор');

-- ---------- Крок 2. Додати колонку як NULL ----------
ALTER TABLE college.courses
    ADD COLUMN teacher_id INTEGER;

-- ---------- Крок 3. Backfill — заповнити існуючі рядки ----------
-- Призначаємо першого «справжнього» викладача (id=2) на всі старі курси.
UPDATE college.courses
SET teacher_id = 2
WHERE teacher_id IS NULL;

-- ---------- Крок 4. Накласти NOT NULL ----------
ALTER TABLE college.courses
    ALTER COLUMN teacher_id SET NOT NULL;

-- ---------- Крок 5. Створити FK ----------
ALTER TABLE college.courses
    ADD CONSTRAINT fk_courses_teacher
    FOREIGN KEY (teacher_id)
    REFERENCES college.teachers (teacher_id)
    ON DELETE RESTRICT;

-- ---------- Крок 6. Корисний індекс для JOIN за FK ----------
CREATE INDEX IF NOT EXISTS idx_courses_teacher
    ON college.courses (teacher_id);

-- Коментар
COMMENT ON COLUMN college.courses.teacher_id IS 'FK на викладача, що веде курс';

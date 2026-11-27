-- =========================================================
-- Rollback for V2 — Remove teacher_id and teachers table
-- УВАГА: дані про викладачів будуть ВТРАЧЕНІ.
-- Переконайтеся, що маєте бекап, перш ніж виконувати.
-- =========================================================

SET search_path TO college, public;

-- 1. Прибрати індекс і FK
DROP INDEX IF EXISTS college.idx_courses_teacher;

ALTER TABLE college.courses
    DROP CONSTRAINT IF EXISTS fk_courses_teacher;

-- 2. Видалити колонку з courses
ALTER TABLE college.courses
    DROP COLUMN IF EXISTS teacher_id;

-- 3. Видалити таблицю teachers
DROP TABLE IF EXISTS college.teachers;

-- =========================================================
-- Rollback for V3 — Restore status column and old CHECK
-- УВАГА: значення status будуть ВІДНОВЛЕНІ як 'active' за замовчуванням.
-- Якщо оригінальні значення були інші — вони втрачені назавжди.
-- =========================================================

SET search_path TO college, public;

-- 1. Відновити CHECK на grade (без обмеження точності)
ALTER TABLE college.enrollments
    DROP CONSTRAINT IF EXISTS ck_enrollments_grade;

ALTER TABLE college.enrollments
    ADD CONSTRAINT ck_enrollments_grade
    CHECK (grade IS NULL OR grade BETWEEN 0 AND 100);

-- 2. Повернути колонку status
ALTER TABLE college.enrollments
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'active';

-- 3. Повернути CHECK на status
ALTER TABLE college.enrollments
    ADD CONSTRAINT ck_enrollments_status
    CHECK (status IN ('active', 'completed', 'dropped', 'failed'));

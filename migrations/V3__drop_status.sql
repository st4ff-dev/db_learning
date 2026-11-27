-- =========================================================
-- Migration V3 — Drop legacy status, promote via check tightening
-- Author: student
-- Date:   2026-11-27
-- Description:
--   Видаляємо непотрібний стовпець status з enrollments
--   (вирішено, що статус реєстрації однозначно виводиться
--   з наявності/значення grade та дати).
--
--   Також як приклад зміни обмеження — звужуємо CHECK
--   на enrollments.grade: було 0..100, стає 0..100 з точністю
--   до одного знаку (всі грейди кратні 0.5 або менше знаків).
--   Для прикладу demonstruje DROP + ADD constraint.
-- =========================================================

SET search_path TO college, public;

-- ---------- Крок 1. Видалити CHECK на status, FK (нема) та колонку ----------
-- У пр_7 ми створили CHECK: ck_enrollments_status.
-- DROP COLUMN автоматично прибере CHECK, але явне DROP CONSTRAINT
-- робить міграцію прозорішою й передбачуваною.

ALTER TABLE college.enrollments
    DROP CONSTRAINT IF EXISTS ck_enrollments_status;

ALTER TABLE college.enrollments
    DROP COLUMN IF EXISTS status;

-- ---------- Крок 2. Приклад зміни CHECK-обмеження ----------
-- Було: grade IS NULL OR grade BETWEEN 0 AND 100
-- Стає: grade IS NULL OR (grade BETWEEN 0 AND 100 AND grade = ROUND(grade, 1))
--
-- Нове правило: оцінка з точністю до 1 знака після коми.

ALTER TABLE college.enrollments
    DROP CONSTRAINT IF EXISTS ck_enrollments_grade;

ALTER TABLE college.enrollments
    ADD CONSTRAINT ck_enrollments_grade
    CHECK (
        grade IS NULL
        OR (grade BETWEEN 0 AND 100 AND grade = ROUND(grade, 1))
    );

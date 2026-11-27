-- =========================================================
-- Rollback for V1 — Drop initial schema
-- Застосовується ТІЛЬКИ в exceptional circumstances
-- (напр., skidання середовища). Не для production.
-- =========================================================

DROP TABLE IF EXISTS college.enrollments CASCADE;
DROP TABLE IF EXISTS college.courses     CASCADE;
DROP TABLE IF EXISTS college.students    CASCADE;
DROP TABLE IF EXISTS college.departments CASCADE;
-- Схема college може містити об'єкти з інших практичних — не видаляємо

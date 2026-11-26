-- =========================================================
-- denormalization.sql — гіпотеза свідомої денормалізації
-- Практична робота №13
-- Додає лічильник студентів до courses + тригери для узгодженості
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;


-- =========================================================
-- ЧАСТИНА 1: Додаємо денормалізоване поле
-- =========================================================

\echo '=== ЧАСТИНА 1: ALTER TABLE courses ==='

ALTER TABLE college.courses
    ADD COLUMN IF NOT EXISTS current_students_count INTEGER NOT NULL DEFAULT 0
        CHECK (current_students_count >= 0);

-- Ініціалізація: порахувати поточні значення
UPDATE college.courses c
SET current_students_count = COALESCE(e.cnt, 0)
FROM (
    SELECT course_id, COUNT(*) AS cnt
    FROM college.enrollments
    GROUP BY course_id
) e
WHERE c.course_id = e.course_id;

-- Для курсів без enrollments залишаємо 0 (DEFAULT спрацював)
SELECT code, title, current_students_count
FROM college.courses
ORDER BY current_students_count DESC;


-- =========================================================
-- ЧАСТИНА 2: Тригерна функція для підтримки узгодженості
-- =========================================================

\echo '=== ЧАСТИНА 2: створення тригера ==='

CREATE OR REPLACE FUNCTION college.trg_update_course_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE college.courses
        SET current_students_count = current_students_count + 1
        WHERE course_id = NEW.course_id;

    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE college.courses
        SET current_students_count = GREATEST(current_students_count - 1, 0)
        WHERE course_id = OLD.course_id;

    ELSIF (TG_OP = 'UPDATE') THEN
        -- Якщо course_id змінився — декремент для старого, інкремент для нового
        IF NEW.course_id IS DISTINCT FROM OLD.course_id THEN
            UPDATE college.courses
            SET current_students_count = GREATEST(current_students_count - 1, 0)
            WHERE course_id = OLD.course_id;

            UPDATE college.courses
            SET current_students_count = current_students_count + 1
            WHERE course_id = NEW.course_id;
        END IF;
    END IF;

    RETURN NULL;   -- AFTER-тригер
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_sync_course_count ON college.enrollments;

CREATE TRIGGER tg_sync_course_count
AFTER INSERT OR UPDATE OR DELETE ON college.enrollments
FOR EACH ROW
EXECUTE FUNCTION college.trg_update_course_count();


-- =========================================================
-- ЧАСТИНА 3: Тестування тригера
-- =========================================================

\echo '=== ЧАСТИНА 3: перевірка тригера ==='

-- 3.1. Стан ДО
\echo '--- 3.1. ДО вставки ---'
SELECT course_id, code, current_students_count
FROM college.courses
WHERE course_id IN (1, 2)
ORDER BY course_id;

-- 3.2. Додаємо нового студента й реєструємо його на курс 1
BEGIN;
    INSERT INTO college.students (student_number, full_name, enrollment_year)
    VALUES ('ST-TEST-999', 'Тестовий Студент', 2024)
    RETURNING student_id \gset

    INSERT INTO college.enrollments (student_id, course_id, status)
    VALUES (:student_id, 1, 'active');

    \echo '--- 3.2. ПІСЛЯ INSERT (course_id=1 має +1) ---'
    SELECT course_id, code, current_students_count
    FROM college.courses
    WHERE course_id IN (1, 2)
    ORDER BY course_id;

ROLLBACK;

\echo '--- Після ROLLBACK значення повернулося ---'
SELECT course_id, code, current_students_count
FROM college.courses
WHERE course_id IN (1, 2)
ORDER BY course_id;


-- =========================================================
-- ЧАСТИНА 4: Процедура звіряння (reconciliation)
-- =========================================================
-- Запускається планово, напр. раз на годину CRON-задачею,
-- щоб відловити можливий дрейф між лічильником і реальними даними.

\echo '=== ЧАСТИНА 4: процедура звіряння ==='

CREATE OR REPLACE FUNCTION college.reconcile_course_counts()
RETURNS TABLE(course_id INTEGER, old_count INTEGER, real_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    WITH diffs AS (
        SELECT c.course_id, c.current_students_count AS old_c, COUNT(e.*) AS real_c
        FROM college.courses c
        LEFT JOIN college.enrollments e ON e.course_id = c.course_id
        GROUP BY c.course_id, c.current_students_count
        HAVING c.current_students_count <> COUNT(e.*)
    )
    UPDATE college.courses c
    SET current_students_count = diffs.real_c
    FROM diffs
    WHERE c.course_id = diffs.course_id
    RETURNING c.course_id, diffs.old_c, diffs.real_c;
END;
$$ LANGUAGE plpgsql;

-- Виклик:
\echo '--- Звіряння лічильників ---'
SELECT * FROM college.reconcile_course_counts();
-- Якщо нуль рядків — усе узгоджено.


-- =========================================================
-- ЧАСТИНА 5: Порівняння швидкості запитів
-- =========================================================

\echo '=== ЧАСТИНА 5: вимір швидкості ==='

\echo '--- 5.1. БЕЗ денормалізації (через JOIN + GROUP BY) ---'
EXPLAIN ANALYZE
SELECT c.code, COUNT(e.student_id) AS students
FROM college.courses c
LEFT JOIN college.enrollments e ON e.course_id = c.course_id
GROUP BY c.code
ORDER BY students DESC
LIMIT 10;

\echo '--- 5.2. З денормалізованим лічильником ---'
EXPLAIN ANALYZE
SELECT code, current_students_count
FROM college.courses
ORDER BY current_students_count DESC
LIMIT 10;


-- =========================================================
-- ЧАСТИНА 6: Альтернатива — матеріалізоване уявлення
-- =========================================================

\echo '=== ЧАСТИНА 6: матеріалізоване уявлення ==='

DROP MATERIALIZED VIEW IF EXISTS college.mv_course_stats;

CREATE MATERIALIZED VIEW college.mv_course_stats AS
SELECT
    c.course_id,
    c.code,
    c.title,
    COUNT(e.student_id)      AS students_count,
    COUNT(e.grade)           AS graded_count,
    ROUND(AVG(e.grade), 2)   AS avg_grade,
    MIN(e.grade)             AS min_grade,
    MAX(e.grade)             AS max_grade
FROM college.courses c
LEFT JOIN college.enrollments e ON e.course_id = c.course_id
GROUP BY c.course_id, c.code, c.title;

-- Унікальний індекс дає змогу REFRESH CONCURRENTLY (без блокування читачів)
CREATE UNIQUE INDEX idx_mv_course_stats ON college.mv_course_stats(course_id);

SELECT * FROM college.mv_course_stats ORDER BY students_count DESC;

-- REFRESH оновлює дані:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY college.mv_course_stats;
-- Запускається планово, наприклад раз на годину.


\echo '=== ДЕНОРМАЛІЗАЦІЮ НАЛАШТОВАНО ==='

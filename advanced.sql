-- =========================================================
-- advanced.sql — складні багатотабличні запити
-- Практична робота №17
-- Виконується на даних з dml.sql (пр_9) + таблицею teachers з V2 (пр_14).
-- Якщо teachers ще немає — скрипт створить і наповнить її.
-- СКБД: PostgreSQL 14+
-- =========================================================

SET search_path TO college, public;


-- =========================================================
-- ЧАСТИНА 0: Переконуємось, що є таблиця teachers
-- =========================================================
-- Якщо V2__add_teacher_id.sql з пр_14 ще не застосовано — створюємо.

\echo '=== ЧАСТИНА 0: підготовка teachers ==='

CREATE TABLE IF NOT EXISTS college.teachers (
    teacher_id    INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(100) UNIQUE,
    academic_rank VARCHAR(50)
);

-- Якщо teachers порожня — наповнюємо
INSERT INTO college.teachers (full_name, email, academic_rank)
SELECT * FROM (VALUES
    ('Сидоренко А.В.', 'sydorenko@college.ua', 'доцент'),
    ('Коваленко П.І.', 'kovalenko@college.ua', 'професор'),
    ('Мельник О.С.',   'melnyk@college.ua',   'асистент'),
    ('Довженко І.В.',  'dovzhenko@college.ua', 'доцент')
) AS t (full_name, email, academic_rank)
WHERE NOT EXISTS (SELECT 1 FROM college.teachers);

-- Якщо в courses ще немає колонки teacher_id — додаємо
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'college'
          AND table_name   = 'courses'
          AND column_name  = 'teacher_id'
    ) THEN
        ALTER TABLE college.courses ADD COLUMN teacher_id INTEGER;

        -- Призначаємо викладачів курсам (щоб було з чим працювати у звіті)
        UPDATE college.courses SET teacher_id = 1 WHERE code = 'DB';
        UPDATE college.courses SET teacher_id = 1 WHERE code = 'WEB';
        UPDATE college.courses SET teacher_id = 2 WHERE code = 'ALG';
        UPDATE college.courses SET teacher_id = 3 WHERE code = 'PH1';
        UPDATE college.courses SET teacher_id = 2 WHERE code = 'MA1';

        -- FK
        ALTER TABLE college.courses
            ADD CONSTRAINT fk_courses_teacher
            FOREIGN KEY (teacher_id) REFERENCES college.teachers(teacher_id)
            ON DELETE RESTRICT;
    END IF;
END $$;

-- Для демо: додамо курс БЕЗ реєстрацій, щоб §3 показав дані
INSERT INTO college.courses (code, title, department_id, credits, tuition, teacher_id)
VALUES ('EMPTY1', 'Непопулярний курс', 2, 3, 3000, 4)
ON CONFLICT (code) DO NOTHING;


-- =========================================================
-- ЗАПИТ 1: Підрозділ → кількість курсів → кількість реєстрацій
-- =========================================================
-- Мета: загальний dashboard по кафедрах — скільки курсів і
-- скільки записів студентів.

\echo '=== ЗАПИТ 1: кафедра → курси → реєстрації ==='

SELECT
    d.name                              AS department,
    COUNT(DISTINCT c.course_id)         AS courses,
    COUNT(e.student_id)                 AS enrollments
FROM college.departments AS d
LEFT JOIN college.courses     AS c USING (department_id)
LEFT JOIN college.enrollments AS e USING (course_id)
GROUP BY d.department_id, d.name
ORDER BY enrollments DESC;

-- Чому LEFT JOIN: щоб у звіті з'явилися й кафедри без курсів,
-- і курси без реєстрацій (з 0 у відповідних колонках).
--
-- Чому COUNT(DISTINCT c.course_id): коли на курс записано 2 студентів,
-- JOIN з enrollments створить 2 рядки для цього курсу. Без DISTINCT
-- counter покаже кількість (курс × реєстрацій), а не кількість курсів.
--
-- COUNT(e.student_id) рахує лише НЕ-NULL значення: якщо курс без
-- реєстрацій, enrollments.student_id = NULL і не рахується.


-- =========================================================
-- ЗАПИТ 2: Середній бал студента (HAVING)
-- =========================================================
-- Мета: показати середню оцінку кожного студента;
-- відсіяти тих, у кого ЖОДНОЇ виставленої оцінки немає.

\echo '=== ЗАПИТ 2: середній бал студента ==='

SELECT
    s.student_number                  AS номер,
    s.full_name                       AS студент,
    COUNT(e.grade)                    AS оцінок,
    ROUND(AVG(e.grade), 2)            AS середнє,
    MIN(e.grade)                      AS мін,
    MAX(e.grade)                      AS макс
FROM college.students    s
JOIN college.enrollments e ON e.student_id = s.student_id
GROUP BY s.student_id, s.student_number, s.full_name
HAVING COUNT(e.grade) >= 1
ORDER BY середнє DESC NULLS LAST;

-- HAVING фільтрує ГРУПИ (студентів) після агрегації.
-- Умова "хоча б одна оцінка" = COUNT(e.grade) >= 1
-- (не COUNT(*), бо grade може бути NULL).


-- =========================================================
-- ЗАПИТ 3a: Курси без жодної реєстрації — LEFT JOIN + NULL
-- =========================================================

\echo '=== ЗАПИТ 3a: курси без реєстрацій (LEFT JOIN + NULL) ==='

SELECT c.code, c.title
FROM college.courses       c
LEFT JOIN college.enrollments e ON e.course_id = c.course_id
WHERE e.student_id IS NULL
ORDER BY c.code;

-- Класичний anti-join патерн: LEFT JOIN + WHERE child IS NULL
-- повертає записи лівої таблиці БЕЗ пари у правій.


-- =========================================================
-- ЗАПИТ 3b: Той самий результат — NOT EXISTS
-- =========================================================

\echo '=== ЗАПИТ 3b: курси без реєстрацій (NOT EXISTS) ==='

SELECT c.code, c.title
FROM college.courses c
WHERE NOT EXISTS (
    SELECT 1 FROM college.enrollments e
    WHERE e.course_id = c.course_id
)
ORDER BY c.code;

-- Семантично еквівалентний до 3a.
-- Переваги NOT EXISTS:
--   • Коректно обробляє NULL (NOT IN може зламатися).
--   • Short-circuit: зупиняється на першому матчі.
--   • Явно показує намір "перевірка існування".


-- =========================================================
-- ЗАПИТ 4: Викладачі з найбільшою кількістю курсів
-- =========================================================
-- Мета: знайти максимальне навантаження і викладачів, що його мають.

\echo '=== ЗАПИТ 4: найзавантаженіші викладачі ==='

-- 4a. Через підзапит у HAVING
SELECT
    t.teacher_id,
    t.full_name,
    COUNT(c.course_id) AS courses_cnt
FROM college.teachers t
JOIN college.courses c ON c.teacher_id = t.teacher_id
GROUP BY t.teacher_id, t.full_name
HAVING COUNT(c.course_id) = (
    SELECT MAX(course_count) FROM (
        SELECT COUNT(*) AS course_count
        FROM college.courses
        WHERE teacher_id IS NOT NULL
        GROUP BY teacher_id
    ) t2
)
ORDER BY t.full_name;

-- Підзапит знаходить MAX навантаження; HAVING лишає тільки
-- тих викладачів, у кого саме стільки курсів.

-- 4b. Через віконну функцію (альтернатива — бонус)
\echo '--- 4b. Через віконну функцію RANK ---'

WITH ranked AS (
    SELECT
        t.teacher_id,
        t.full_name,
        COUNT(c.course_id) AS courses_cnt,
        RANK() OVER (ORDER BY COUNT(c.course_id) DESC) AS rnk
    FROM college.teachers t
    JOIN college.courses c ON c.teacher_id = t.teacher_id
    GROUP BY t.teacher_id, t.full_name
)
SELECT teacher_id, full_name, courses_cnt
FROM ranked
WHERE rnk = 1;


-- =========================================================
-- ЗАПИТ 5: Студенти з оцінкою ВИЩЕ ЗА СЕРЕДНЮ по курсу
-- =========================================================
-- Корельований підзапит: середнє по курсу обчислюється ОКРЕМО
-- для кожного рядка (поточний course_id).

\echo '=== ЗАПИТ 5: студенти з оцінкою вище середньої по курсу ==='

SELECT
    s.full_name                                                AS студент,
    c.code                                                     AS курс_код,
    c.title                                                    AS курс_назва,
    e.grade                                                    AS оцінка,
    ROUND((
        SELECT AVG(e2.grade)
        FROM college.enrollments e2
        WHERE e2.course_id = c.course_id
          AND e2.grade IS NOT NULL
    ), 2)                                                      AS середнє_по_курсу
FROM college.enrollments e
JOIN college.students s ON s.student_id = e.student_id
JOIN college.courses  c ON c.course_id  = e.course_id
WHERE e.grade IS NOT NULL
  AND e.grade > (
      SELECT AVG(e2.grade)
      FROM college.enrollments e2
      WHERE e2.course_id = e.course_id
        AND e2.grade IS NOT NULL
  )
ORDER BY c.code, e.grade DESC;

-- Семантика: для кожної реєстрації перевіряємо, чи grade поточного
-- рядка перевищує середнє саме по цьому курсу.
-- Підзапит "корельований": залежить від e.course_id.


-- =========================================================
-- ЗАПИТ 6: INTERSECT — коди курсів у двох кафедрах
-- =========================================================
-- Мета: знайти коди, що зустрічаються одночасно в курсах кафедр IT і FIZ.
-- У нашій моделі код курсу УНІКАЛЬНИЙ по всій таблиці, тому прямий
-- INTERSECT на code дасть порожній результат. Для показових даних
-- беремо перші символи коду (префікс).

\echo '=== ЗАПИТ 6: INTERSECT ==='

-- 6a. Прямий INTERSECT (у нашій реальності курсові коди унікальні)
\echo '--- 6a. Прямий INTERSECT між кафедрами IT і FIZ ---'

SELECT code FROM college.courses WHERE department_id = 1   -- IT
INTERSECT
SELECT code FROM college.courses WHERE department_id = 2   -- FIZ
ORDER BY code;
-- Результат порожній — у реальній моделі код курсу унікальний.

-- 6b. INTERSECT на префікс коду (щоб побачити працюючий приклад)
\echo '--- 6b. Спільні ПЕРШІ символи коду курсу ---'

SELECT SUBSTRING(code FROM 1 FOR 2) AS prefix
FROM college.courses WHERE department_id = 1
INTERSECT
SELECT SUBSTRING(code FROM 1 FOR 2) AS prefix
FROM college.courses WHERE department_id = 2;
-- Теж порожній на наших даних (IT: DB/WEB/ALG/EMPTY, FIZ: PH1).

-- 6c. Більш практичний приклад INTERSECT — студенти, що записані
-- одночасно на DB і WEB
\echo '--- 6c. Студенти, записані одночасно на DB і WEB ---'

SELECT e.student_id FROM college.enrollments e
JOIN college.courses c ON c.course_id = e.course_id
WHERE c.code = 'DB'
INTERSECT
SELECT e.student_id FROM college.enrollments e
JOIN college.courses c ON c.course_id = e.course_id
WHERE c.code = 'WEB'
ORDER BY student_id;


-- =========================================================
-- БОНУС: Комплексний звіт з усім одразу
-- =========================================================
-- Для кожного студента: скільки курсів, середня оцінка,
-- найкращий курс, кафедра найкращого курсу.

\echo '=== БОНУС: комплексний звіт ==='

WITH student_stats AS (
    SELECT
        e.student_id,
        COUNT(e.course_id)       AS courses_cnt,
        ROUND(AVG(e.grade), 2)   AS avg_grade,
        MAX(e.grade)             AS best_grade
    FROM college.enrollments e
    WHERE e.grade IS NOT NULL
    GROUP BY e.student_id
),
best_course AS (
    SELECT DISTINCT ON (e.student_id)
        e.student_id,
        c.code  AS best_course_code,
        c.title AS best_course_title,
        d.name  AS best_dept
    FROM college.enrollments e
    JOIN college.courses     c ON c.course_id = e.course_id
    JOIN college.departments d USING (department_id)
    WHERE e.grade IS NOT NULL
    ORDER BY e.student_id, e.grade DESC
)
SELECT
    s.full_name            AS студент,
    ss.courses_cnt         AS курсів,
    ss.avg_grade           AS середнє,
    bc.best_course_code    AS кращий_курс,
    bc.best_dept           AS кращий_курс_кафедра
FROM college.students s
LEFT JOIN student_stats  ss ON ss.student_id = s.student_id
LEFT JOIN best_course    bc ON bc.student_id = s.student_id
ORDER BY ss.avg_grade DESC NULLS LAST;


\echo '=== УСІ ЗАПИТИ ВИКОНАНО ==='

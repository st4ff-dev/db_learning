#!/usr/bin/env bash
# =========================================================
# apply.sh — простий runner міграцій у стилі Flyway.
# Застосовує файли V*__*.sql по черзі, фіксує виконані
# у таблиці schema_migrations і пропускає вже застосовані.
#
# Використання:
#   ./apply.sh                   # застосувати всі нові V-міграції
#   ./apply.sh --status          # показати поточний стан
#   ./apply.sh --rollback V3     # відкотити одну конкретну версію
# =========================================================
set -euo pipefail

DB_USER="${DB_USER:-student}"
DB_NAME="${DB_NAME:-college}"
DB_HOST="${DB_HOST:-localhost}"
MIGRATIONS_DIR="$(cd "$(dirname "$0")" && pwd)"

PSQL="psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_HOST} -v ON_ERROR_STOP=1 -X -q"

# ---------- Створюємо таблицю трекінгу, якщо її ще немає ----------
ensure_tracking_table() {
    ${PSQL} <<'SQL' >/dev/null
CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version      VARCHAR(20)  PRIMARY KEY,
    filename     VARCHAR(255) NOT NULL,
    applied_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    applied_by   VARCHAR(50)  NOT NULL DEFAULT CURRENT_USER,
    checksum     TEXT
);
SQL
}

# ---------- Статус ----------
show_status() {
    ensure_tracking_table
    echo "=== Застосовані міграції ==="
    ${PSQL} -c "SELECT version, filename, applied_at, applied_by
                FROM public.schema_migrations
                ORDER BY version"
    echo
    echo "=== Усі файли V*.sql у $MIGRATIONS_DIR ==="
    ls -1 "$MIGRATIONS_DIR"/V*.sql 2>/dev/null || echo "немає"
}

# ---------- Rollback однієї версії ----------
rollback_one() {
    local ver="$1"
    local file
    file=$(ls "$MIGRATIONS_DIR"/U${ver#V}__*.sql 2>/dev/null | head -1 || true)
    if [[ -z "$file" ]]; then
        echo "❌ Файл rollback для $ver не знайдено"
        exit 1
    fi
    echo "⏪ Відкочуємо $ver з файлу $(basename "$file")..."
    ${PSQL} -f "$file"
    ${PSQL} -c "DELETE FROM public.schema_migrations WHERE version = '$ver'"
    echo "✅ $ver відкочено"
}

# ---------- Застосування всіх нових ----------
apply_all() {
    ensure_tracking_table
    local applied_count=0
    local skipped_count=0

    for file in "$MIGRATIONS_DIR"/V*__*.sql; do
        [[ -e "$file" ]] || { echo "Файли міграцій не знайдено"; return; }

        # Витягуємо версію: V1__init.sql → V1
        local base version
        base=$(basename "$file")
        version=$(echo "$base" | sed -E 's/^(V[0-9]+)__.*/\1/')

        # Перевіряємо, чи вже застосовано
        local already
        already=$(${PSQL} -tAc "SELECT 1 FROM public.schema_migrations WHERE version = '$version' LIMIT 1")

        if [[ "$already" == "1" ]]; then
            echo "⏩ $version вже застосовано — пропускаємо $base"
            ((skipped_count++))
            continue
        fi

        echo "▶️  Застосовуємо $base..."
        local checksum
        checksum=$(shasum -a 256 "$file" | awk '{print $1}')

        ${PSQL} -f "$file"
        ${PSQL} -c "INSERT INTO public.schema_migrations (version, filename, checksum)
                    VALUES ('$version', '$base', '$checksum')"

        echo "✅ $version застосовано"
        ((applied_count++))
    done

    echo
    echo "Готово. Нових міграцій застосовано: $applied_count, пропущено: $skipped_count"
}

# ---------- Main ----------
case "${1:-}" in
    --status)
        show_status
        ;;
    --rollback)
        if [[ -z "${2:-}" ]]; then
            echo "Вкажіть версію: $0 --rollback V3"
            exit 1
        fi
        rollback_one "$2"
        ;;
    "")
        apply_all
        ;;
    *)
        echo "Невідома команда: $1"
        echo "Доступні: --status | --rollback V<n> | (без аргументів)"
        exit 1
        ;;
esac

-- =============================================
-- HR Bot Database Schema for Supabase
-- =============================================
-- Создайте новый проект в Supabase и выполните этот скрипт
-- в SQL Editor (https://app.supabase.com)
-- =============================================

-- =============================================
-- ТАБЛИЦА: candidates (Группа «Направленные»)
-- =============================================
-- Хранит данные о кандидатах, добавленных через бота

CREATE TABLE IF NOT EXISTS candidates (
    -- Первичный ключ
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === Данные кандидата ===
    full_name TEXT NOT NULL,
    age INTEGER CHECK (age > 0 AND age < 150),
    gender TEXT CHECK (gender IN ('мужской', 'женский')),
    position TEXT NOT NULL,
    experience TEXT,
    phone TEXT NOT NULL,
    object_location TEXT NOT NULL,

    -- === Метаданные Telegram ===
    telegram_user_id BIGINT NOT NULL,
    telegram_username TEXT,
    telegram_chat_id BIGINT NOT NULL,
    telegram_message_id BIGINT,

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_date DATE DEFAULT CURRENT_DATE NOT NULL
);

-- Комментарии к таблице
COMMENT ON TABLE candidates IS 'Кандидаты, добавленные через группу «Направленные»';
COMMENT ON COLUMN candidates.full_name IS 'ФИО кандидата';
COMMENT ON COLUMN candidates.age IS 'Возраст кандидата';
COMMENT ON COLUMN candidates.gender IS 'Пол: мужской или женский';
COMMENT ON COLUMN candidates.position IS 'Желаемая должность';
COMMENT ON COLUMN candidates.experience IS 'Опыт работы (свободный текст)';
COMMENT ON COLUMN candidates.phone IS 'Номер телефона';
COMMENT ON COLUMN candidates.object_location IS 'Объект/место работы';
COMMENT ON COLUMN candidates.telegram_user_id IS 'ID пользователя Telegram, добавившего запись';
COMMENT ON COLUMN candidates.telegram_username IS 'Username пользователя Telegram';
COMMENT ON COLUMN candidates.telegram_chat_id IS 'ID чата/группы Telegram';
COMMENT ON COLUMN candidates.telegram_message_id IS 'ID сообщения в Telegram';
COMMENT ON COLUMN candidates.created_date IS 'Дата создания (для отчётов)';

-- Индексы для быстрых запросов
CREATE INDEX IF NOT EXISTS idx_candidates_created_date
    ON candidates(created_date);

CREATE INDEX IF NOT EXISTS idx_candidates_chat_id
    ON candidates(telegram_chat_id);

CREATE INDEX IF NOT EXISTS idx_candidates_phone
    ON candidates(phone);

CREATE INDEX IF NOT EXISTS idx_candidates_position
    ON candidates(position);


-- =============================================
-- ТАБЛИЦА: payments (Группа «Оплата мс»)
-- =============================================
-- Хранит данные об отработанных часах сотрудников

CREATE TABLE IF NOT EXISTS payments (
    -- Первичный ключ
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === Данные об оплате ===
    work_date DATE NOT NULL,
    object_location TEXT NOT NULL,
    position TEXT NOT NULL,
    full_name TEXT NOT NULL,
    hours DECIMAL(5,2) NOT NULL CHECK (hours > 0 AND hours <= 24),

    -- === Метаданные Telegram ===
    telegram_user_id BIGINT NOT NULL,
    telegram_username TEXT,
    telegram_chat_id BIGINT NOT NULL,
    telegram_message_id BIGINT,

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Комментарии к таблице
COMMENT ON TABLE payments IS 'Записи об оплате из группы «Оплата мс»';
COMMENT ON COLUMN payments.work_date IS 'Дата работы';
COMMENT ON COLUMN payments.object_location IS 'Объект/место работы';
COMMENT ON COLUMN payments.position IS 'Должность сотрудника';
COMMENT ON COLUMN payments.full_name IS 'ФИО сотрудника';
COMMENT ON COLUMN payments.hours IS 'Количество отработанных часов';

-- Индексы
CREATE INDEX IF NOT EXISTS idx_payments_work_date
    ON payments(work_date);

CREATE INDEX IF NOT EXISTS idx_payments_chat_id
    ON payments(telegram_chat_id);

CREATE INDEX IF NOT EXISTS idx_payments_employee
    ON payments(full_name, work_date);

CREATE INDEX IF NOT EXISTS idx_payments_object
    ON payments(object_location, work_date);


-- =============================================
-- ТАБЛИЦА: bot_logs (Логирование)
-- =============================================
-- Опциональная таблица для отладки и мониторинга

CREATE TABLE IF NOT EXISTS bot_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === Данные события ===
    event_type TEXT NOT NULL,
    -- Типы: message_received, message_classified,
    --       parse_success, parse_error,
    --       db_insert, db_error,
    --       llm_request, llm_error

    severity TEXT DEFAULT 'info' CHECK (severity IN ('debug', 'info', 'warn', 'error')),

    -- === Контекст ===
    chat_id BIGINT,
    user_id BIGINT,
    message_text TEXT,
    parsed_data JSONB,
    error_message TEXT,
    execution_time_ms INTEGER,

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE bot_logs IS 'Логи работы бота для отладки и мониторинга';

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_bot_logs_created
    ON bot_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bot_logs_type
    ON bot_logs(event_type);

CREATE INDEX IF NOT EXISTS idx_bot_logs_severity
    ON bot_logs(severity) WHERE severity IN ('warn', 'error');

-- Автоматическая очистка старых логов (старше 30 дней)
-- Выполняется через pg_cron или вручную
-- DELETE FROM bot_logs WHERE created_at < NOW() - INTERVAL '30 days';


-- =============================================
-- ТАБЛИЦА: bot_config (Конфигурация)
-- =============================================
-- Хранит настройки бота (chat_id групп, словари и т.д.)

CREATE TABLE IF NOT EXISTS bot_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE bot_config IS 'Конфигурация бота';

-- Начальные данные конфигурации
INSERT INTO bot_config (key, value, description) VALUES
    ('chat_candidates', '{"chat_id": null, "name": "Направленные"}',
     'ID группы для кандидатов'),
    ('chat_payments', '{"chat_id": null, "name": "Оплата мс"}',
     'ID группы для оплаты'),
    ('known_positions', '["горничная", "уборщица", "охранник", "администратор", "повар", "официант", "бармен", "кассир", "продавец", "менеджер", "водитель"]',
     'Список известных должностей для эвристик'),
    ('known_objects', '["МП", "ТЦ", "Marriott", "Hilton"]',
     'Список известных объектов')
ON CONFLICT (key) DO NOTHING;


-- =============================================
-- VIEWS (Представления для отчётов)
-- =============================================

-- Отчёт по кандидатам за сегодня
CREATE OR REPLACE VIEW v_candidates_today AS
SELECT
    full_name,
    phone,
    position,
    object_location,
    created_at
FROM candidates
WHERE created_date = CURRENT_DATE
ORDER BY created_at;

-- Статистика по кандидатам за последние 7 дней
CREATE OR REPLACE VIEW v_candidates_stats_weekly AS
SELECT
    created_date,
    COUNT(*) as total_candidates,
    COUNT(DISTINCT position) as unique_positions,
    COUNT(DISTINCT object_location) as unique_objects
FROM candidates
WHERE created_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY created_date
ORDER BY created_date DESC;

-- Статистика по оплатам
CREATE OR REPLACE VIEW v_payments_summary AS
SELECT
    work_date,
    object_location,
    position,
    COUNT(DISTINCT full_name) as employees_count,
    SUM(hours) as total_hours
FROM payments
WHERE work_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY work_date, object_location, position
ORDER BY work_date DESC, object_location;


-- =============================================
-- FUNCTIONS (Функции)
-- =============================================

-- Функция для получения отчёта по кандидатам за дату
CREATE OR REPLACE FUNCTION get_candidates_report(report_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
    full_name TEXT,
    phone TEXT,
    position TEXT,
    object_location TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.full_name,
        c.phone,
        c.position,
        c.object_location,
        c.created_at
    FROM candidates c
    WHERE c.created_date = report_date
    ORDER BY c.created_at;
END;
$$ LANGUAGE plpgsql;

-- Функция для подсчёта кандидатов за период
CREATE OR REPLACE FUNCTION count_candidates(
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER AS $$
DECLARE
    result INTEGER;
BEGIN
    SELECT COUNT(*) INTO result
    FROM candidates
    WHERE created_date BETWEEN start_date AND end_date;

    RETURN result;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================
-- Включите RLS если нужно ограничить доступ

-- ALTER TABLE candidates ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE bot_logs ENABLE ROW LEVEL SECURITY;

-- Пример политики: доступ только для service role
-- CREATE POLICY "Service role full access" ON candidates
--     FOR ALL
--     TO service_role
--     USING (true)
--     WITH CHECK (true);


-- =============================================
-- GRANTS (Права доступа)
-- =============================================
-- По умолчанию service_role имеет полный доступ
-- anon и authenticated не имеют доступа к этим таблицам

REVOKE ALL ON candidates FROM anon, authenticated;
REVOKE ALL ON payments FROM anon, authenticated;
REVOKE ALL ON bot_logs FROM anon, authenticated;
REVOKE ALL ON bot_config FROM anon, authenticated;

-- Если нужен доступ через API (не рекомендуется для бота):
-- GRANT SELECT, INSERT ON candidates TO authenticated;
-- GRANT SELECT, INSERT ON payments TO authenticated;

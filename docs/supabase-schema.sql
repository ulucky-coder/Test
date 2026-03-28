-- =============================================
-- HR Bot Database Schema for Supabase (v2.0)
-- =============================================
-- Версия 2.0: Добавлены статусы, дубликаты, связи, аудит
-- Создайте новый проект в Supabase и выполните этот скрипт
-- в SQL Editor (https://app.supabase.com)
-- =============================================

-- =============================================
-- ТИПЫ ДАННЫХ (ENUMS)
-- =============================================

-- Статусы кандидата в воронке найма
CREATE TYPE candidate_status AS ENUM (
    'направлен',      -- Только добавлен
    'собеседование',  -- Назначено/прошло собеседование
    'оформление',     -- На этапе оформления документов
    'работает',       -- Трудоустроен
    'отказ',          -- Отказ (кандидат или компания)
    'архив'           -- В архиве (неактуален)
);

-- Типы событий аудита
CREATE TYPE audit_action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'STATUS_CHANGE'
);

-- Уровни важности уведомлений
CREATE TYPE notification_level AS ENUM (
    'info',
    'warning',
    'error',
    'critical'
);


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
    phone_normalized TEXT GENERATED ALWAYS AS (
        regexp_replace(phone, '[^0-9]', '', 'g')
    ) STORED,
    object_location TEXT NOT NULL,

    -- === Статус в воронке найма ===
    status candidate_status DEFAULT 'направлен' NOT NULL,
    status_changed_at TIMESTAMPTZ DEFAULT NOW(),
    status_changed_by BIGINT,  -- telegram_user_id кто изменил
    status_comment TEXT,       -- комментарий к изменению статуса

    -- === Метаданные Telegram ===
    telegram_user_id BIGINT NOT NULL,
    telegram_username TEXT,
    telegram_chat_id BIGINT NOT NULL,
    telegram_message_id BIGINT,

    -- === Флаги ===
    is_duplicate BOOLEAN DEFAULT FALSE,
    duplicate_of UUID REFERENCES candidates(id),
    is_deleted BOOLEAN DEFAULT FALSE,

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_date DATE DEFAULT CURRENT_DATE NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Комментарии к таблице
COMMENT ON TABLE candidates IS 'Кандидаты, добавленные через группу «Направленные»';
COMMENT ON COLUMN candidates.full_name IS 'ФИО кандидата';
COMMENT ON COLUMN candidates.phone_normalized IS 'Телефон только цифры (для поиска дубликатов)';
COMMENT ON COLUMN candidates.status IS 'Текущий статус в воронке найма';
COMMENT ON COLUMN candidates.is_duplicate IS 'Флаг дубликата';
COMMENT ON COLUMN candidates.duplicate_of IS 'Ссылка на оригинальную запись (если дубликат)';

-- Индексы для быстрых запросов
CREATE INDEX IF NOT EXISTS idx_candidates_created_date ON candidates(created_date);
CREATE INDEX IF NOT EXISTS idx_candidates_chat_id ON candidates(telegram_chat_id);
CREATE INDEX IF NOT EXISTS idx_candidates_phone ON candidates(phone);
CREATE INDEX IF NOT EXISTS idx_candidates_phone_normalized ON candidates(phone_normalized);
CREATE INDEX IF NOT EXISTS idx_candidates_position ON candidates(position);
CREATE INDEX IF NOT EXISTS idx_candidates_status ON candidates(status);
CREATE INDEX IF NOT EXISTS idx_candidates_object ON candidates(object_location);
CREATE INDEX IF NOT EXISTS idx_candidates_not_deleted ON candidates(id) WHERE is_deleted = FALSE;

-- Уникальный индекс для предотвращения полных дубликатов
CREATE UNIQUE INDEX IF NOT EXISTS idx_candidates_unique_recent
ON candidates(phone_normalized, position, object_location)
WHERE created_date >= CURRENT_DATE - INTERVAL '30 days'
  AND is_deleted = FALSE
  AND is_duplicate = FALSE;


-- =============================================
-- ТАБЛИЦА: candidate_status_history
-- =============================================
-- История изменений статусов кандидатов

CREATE TABLE IF NOT EXISTS candidate_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id UUID NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,

    old_status candidate_status,
    new_status candidate_status NOT NULL,

    changed_by_user_id BIGINT NOT NULL,
    changed_by_username TEXT,
    comment TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE candidate_status_history IS 'История изменений статусов кандидатов';

CREATE INDEX IF NOT EXISTS idx_status_history_candidate ON candidate_status_history(candidate_id);
CREATE INDEX IF NOT EXISTS idx_status_history_date ON candidate_status_history(created_at DESC);


-- =============================================
-- ТАБЛИЦА: payments (Группа «Оплата мс»)
-- =============================================
-- Хранит данные об отработанных часах сотрудников

CREATE TABLE IF NOT EXISTS payments (
    -- Первичный ключ
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === Связь с кандидатом (если найден) ===
    candidate_id UUID REFERENCES candidates(id),

    -- === Данные об оплате ===
    work_date DATE NOT NULL,
    object_location TEXT NOT NULL,
    position TEXT NOT NULL,
    full_name TEXT NOT NULL,
    full_name_normalized TEXT GENERATED ALWAYS AS (
        lower(regexp_replace(full_name, '\s+', ' ', 'g'))
    ) STORED,
    hours DECIMAL(5,2) NOT NULL CHECK (hours > 0 AND hours <= 24),

    -- === Метаданные Telegram ===
    telegram_user_id BIGINT NOT NULL,
    telegram_username TEXT,
    telegram_chat_id BIGINT NOT NULL,
    telegram_message_id BIGINT,

    -- === Флаги ===
    is_deleted BOOLEAN DEFAULT FALSE,

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE payments IS 'Записи об оплате из группы «Оплата мс»';
COMMENT ON COLUMN payments.candidate_id IS 'Ссылка на кандидата (автоматический matching)';
COMMENT ON COLUMN payments.full_name_normalized IS 'ФИО нормализованное для поиска';

-- Индексы
CREATE INDEX IF NOT EXISTS idx_payments_work_date ON payments(work_date);
CREATE INDEX IF NOT EXISTS idx_payments_chat_id ON payments(telegram_chat_id);
CREATE INDEX IF NOT EXISTS idx_payments_employee ON payments(full_name, work_date);
CREATE INDEX IF NOT EXISTS idx_payments_object ON payments(object_location, work_date);
CREATE INDEX IF NOT EXISTS idx_payments_candidate ON payments(candidate_id);
CREATE INDEX IF NOT EXISTS idx_payments_name_normalized ON payments(full_name_normalized);
CREATE INDEX IF NOT EXISTS idx_payments_not_deleted ON payments(id) WHERE is_deleted = FALSE;


-- =============================================
-- ТАБЛИЦА: audit_log (Аудит изменений)
-- =============================================
-- Полная история всех изменений в системе

CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === Что изменено ===
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action audit_action NOT NULL,

    -- === Данные до/после ===
    old_data JSONB,
    new_data JSONB,
    changed_fields TEXT[],  -- список изменённых полей

    -- === Кто изменил ===
    user_id BIGINT,
    username TEXT,

    -- === Контекст ===
    ip_address INET,
    user_agent TEXT,
    source TEXT DEFAULT 'telegram_bot',  -- telegram_bot, api, admin_panel

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE audit_log IS 'Полная история изменений для аудита';

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_record ON audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_table_record ON audit_log(table_name, record_id);

-- Партиционирование по месяцам (опционально, для больших объёмов)
-- CREATE INDEX IF NOT EXISTS idx_audit_month ON audit_log(date_trunc('month', created_at));


-- =============================================
-- ТАБЛИЦА: admin_notifications
-- =============================================
-- Уведомления для администраторов

CREATE TABLE IF NOT EXISTS admin_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === Содержание ===
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    level notification_level DEFAULT 'info' NOT NULL,

    -- === Контекст ===
    source TEXT,  -- workflow name, function name
    related_table TEXT,
    related_record_id UUID,
    metadata JSONB,

    -- === Статус доставки ===
    is_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ,
    sent_to_chat_id BIGINT,
    error_message TEXT,

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE admin_notifications IS 'Очередь уведомлений для администраторов';

CREATE INDEX IF NOT EXISTS idx_notifications_unsent ON admin_notifications(created_at)
    WHERE is_sent = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_level ON admin_notifications(level);


-- =============================================
-- ТАБЛИЦА: llm_cache (Кэш LLM ответов)
-- =============================================
-- Кэширование ответов DeepSeek для экономии

CREATE TABLE IF NOT EXISTS llm_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- === Ключ кэша ===
    message_hash TEXT NOT NULL UNIQUE,  -- MD5 хэш сообщения
    message_text TEXT NOT NULL,

    -- === Результат ===
    parsed_result JSONB NOT NULL,
    model_used TEXT DEFAULT 'deepseek-chat',

    -- === Статистика ===
    hit_count INTEGER DEFAULT 0,
    last_hit_at TIMESTAMPTZ,

    -- === Временные метки ===
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours'
);

COMMENT ON TABLE llm_cache IS 'Кэш ответов LLM для экономии API вызовов';

CREATE INDEX IF NOT EXISTS idx_llm_cache_hash ON llm_cache(message_hash);
CREATE INDEX IF NOT EXISTS idx_llm_cache_expires ON llm_cache(expires_at);


-- =============================================
-- ТАБЛИЦА: bot_logs (Логирование)
-- =============================================

CREATE TABLE IF NOT EXISTS bot_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    event_type TEXT NOT NULL,
    severity TEXT DEFAULT 'info' CHECK (severity IN ('debug', 'info', 'warn', 'error')),

    chat_id BIGINT,
    user_id BIGINT,
    message_text TEXT,
    parsed_data JSONB,
    error_message TEXT,
    execution_time_ms INTEGER,

    -- === Дополнительный контекст ===
    workflow_name TEXT,
    node_name TEXT,
    stack_trace TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE bot_logs IS 'Логи работы бота для отладки и мониторинга';

CREATE INDEX IF NOT EXISTS idx_bot_logs_created ON bot_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bot_logs_type ON bot_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_bot_logs_severity ON bot_logs(severity) WHERE severity IN ('warn', 'error');
CREATE INDEX IF NOT EXISTS idx_bot_logs_workflow ON bot_logs(workflow_name);


-- =============================================
-- ТАБЛИЦА: bot_config (Конфигурация)
-- =============================================

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
    ('chat_admin', '{"chat_id": null, "name": "Админ"}',
     'ID чата/группы для уведомлений администратору'),
    ('known_positions', '["горничная", "уборщица", "охранник", "администратор", "повар", "официант", "бармен", "кассир", "продавец", "менеджер", "водитель"]',
     'Список известных должностей для эвристик'),
    ('known_objects', '["МП", "ТЦ", "Marriott", "Hilton"]',
     'Список известных объектов'),
    ('duplicate_check_days', '30',
     'За сколько дней проверять дубликаты'),
    ('llm_cache_ttl_hours', '24',
     'Время жизни кэша LLM в часах')
ON CONFLICT (key) DO NOTHING;


-- =============================================
-- ФУНКЦИИ: Проверка дубликатов
-- =============================================

-- Функция поиска потенциальных дубликатов кандидата
CREATE OR REPLACE FUNCTION find_candidate_duplicates(
    p_phone TEXT,
    p_full_name TEXT DEFAULT NULL,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    phone TEXT,
    position TEXT,
    object_location TEXT,
    status candidate_status,
    created_at TIMESTAMPTZ,
    similarity_score INTEGER
) AS $$
DECLARE
    v_phone_normalized TEXT;
    v_name_normalized TEXT;
BEGIN
    -- Нормализуем входные данные
    v_phone_normalized := regexp_replace(p_phone, '[^0-9]', '', 'g');
    v_name_normalized := lower(regexp_replace(COALESCE(p_full_name, ''), '\s+', ' ', 'g'));

    RETURN QUERY
    SELECT
        c.id,
        c.full_name,
        c.phone,
        c.position,
        c.object_location,
        c.status,
        c.created_at,
        CASE
            -- Полное совпадение телефона
            WHEN c.phone_normalized = v_phone_normalized THEN 100
            -- Совпадение последних 10 цифр
            WHEN RIGHT(c.phone_normalized, 10) = RIGHT(v_phone_normalized, 10) THEN 90
            -- Похожее ФИО (если передано)
            WHEN p_full_name IS NOT NULL
                 AND similarity(lower(c.full_name), v_name_normalized) > 0.6 THEN 70
            ELSE 50
        END AS similarity_score
    FROM candidates c
    WHERE c.is_deleted = FALSE
      AND c.is_duplicate = FALSE
      AND c.created_date >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
      AND (
          -- Совпадение по телефону
          c.phone_normalized = v_phone_normalized
          OR RIGHT(c.phone_normalized, 10) = RIGHT(v_phone_normalized, 10)
          -- Или по ФИО (требует расширение pg_trgm)
          OR (p_full_name IS NOT NULL AND similarity(lower(c.full_name), v_name_normalized) > 0.6)
      )
    ORDER BY similarity_score DESC, c.created_at DESC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_candidate_duplicates IS 'Поиск потенциальных дубликатов по телефону и ФИО';


-- =============================================
-- ФУНКЦИИ: Связывание кандидатов с оплатами
-- =============================================

-- Функция автоматического связывания payment с candidate
CREATE OR REPLACE FUNCTION link_payment_to_candidate(
    p_payment_id UUID
) RETURNS UUID AS $$
DECLARE
    v_payment RECORD;
    v_candidate_id UUID;
BEGIN
    -- Получаем данные платежа
    SELECT * INTO v_payment FROM payments WHERE id = p_payment_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Ищем кандидата по нормализованному ФИО и объекту
    SELECT c.id INTO v_candidate_id
    FROM candidates c
    WHERE c.is_deleted = FALSE
      AND c.status = 'работает'
      AND c.object_location = v_payment.object_location
      AND (
          -- Точное совпадение нормализованного ФИО
          lower(regexp_replace(c.full_name, '\s+', ' ', 'g')) = v_payment.full_name_normalized
          -- Или похожее ФИО
          OR similarity(lower(c.full_name), v_payment.full_name_normalized) > 0.8
      )
    ORDER BY
        CASE WHEN lower(regexp_replace(c.full_name, '\s+', ' ', 'g')) = v_payment.full_name_normalized
             THEN 0 ELSE 1 END,
        c.created_at DESC
    LIMIT 1;

    -- Обновляем payment если нашли
    IF v_candidate_id IS NOT NULL THEN
        UPDATE payments SET candidate_id = v_candidate_id WHERE id = p_payment_id;
    END IF;

    RETURN v_candidate_id;
END;
$$ LANGUAGE plpgsql;

-- Функция массового связывания всех несвязанных payments
CREATE OR REPLACE FUNCTION link_all_unlinked_payments()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
    v_payment RECORD;
BEGIN
    FOR v_payment IN
        SELECT id FROM payments
        WHERE candidate_id IS NULL AND is_deleted = FALSE
    LOOP
        IF link_payment_to_candidate(v_payment.id) IS NOT NULL THEN
            v_count := v_count + 1;
        END IF;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- ФУНКЦИИ: Изменение статуса кандидата
-- =============================================

CREATE OR REPLACE FUNCTION change_candidate_status(
    p_candidate_id UUID,
    p_new_status candidate_status,
    p_user_id BIGINT,
    p_username TEXT DEFAULT NULL,
    p_comment TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_old_status candidate_status;
BEGIN
    -- Получаем текущий статус
    SELECT status INTO v_old_status FROM candidates WHERE id = p_candidate_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Если статус не изменился
    IF v_old_status = p_new_status THEN
        RETURN TRUE;
    END IF;

    -- Обновляем кандидата
    UPDATE candidates SET
        status = p_new_status,
        status_changed_at = NOW(),
        status_changed_by = p_user_id,
        status_comment = p_comment,
        updated_at = NOW()
    WHERE id = p_candidate_id;

    -- Записываем в историю
    INSERT INTO candidate_status_history (
        candidate_id, old_status, new_status,
        changed_by_user_id, changed_by_username, comment
    ) VALUES (
        p_candidate_id, v_old_status, p_new_status,
        p_user_id, p_username, p_comment
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- ФУНКЦИИ: Аудит (триггеры)
-- =============================================

-- Универсальная функция аудита
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_changed_fields TEXT[];
    v_user_id BIGINT;
BEGIN
    -- Определяем user_id из данных
    IF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
        v_user_id := OLD.telegram_user_id;
    ELSIF TG_OP = 'INSERT' THEN
        v_old_data := NULL;
        v_new_data := to_jsonb(NEW);
        v_user_id := NEW.telegram_user_id;
    ELSE -- UPDATE
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
        v_user_id := NEW.telegram_user_id;

        -- Находим изменённые поля
        SELECT array_agg(key) INTO v_changed_fields
        FROM (
            SELECT key FROM jsonb_each(v_old_data)
            EXCEPT
            SELECT key FROM jsonb_each(v_new_data)
            UNION
            SELECT key FROM jsonb_each(v_new_data)
            EXCEPT
            SELECT key FROM jsonb_each(v_old_data)
            UNION
            SELECT o.key FROM jsonb_each(v_old_data) o
            JOIN jsonb_each(v_new_data) n ON o.key = n.key
            WHERE o.value IS DISTINCT FROM n.value
        ) changed;
    END IF;

    -- Вставляем запись аудита
    INSERT INTO audit_log (
        table_name, record_id, action,
        old_data, new_data, changed_fields,
        user_id, source
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP::audit_action,
        v_old_data,
        v_new_data,
        v_changed_fields,
        v_user_id,
        'telegram_bot'
    );

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Триггеры аудита
CREATE TRIGGER audit_candidates
    AFTER INSERT OR UPDATE OR DELETE ON candidates
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

CREATE TRIGGER audit_payments
    AFTER INSERT OR UPDATE OR DELETE ON payments
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();


-- =============================================
-- ФУНКЦИИ: Отчёты
-- =============================================

-- Расширенный отчёт по кандидатам
CREATE OR REPLACE FUNCTION get_candidates_report_extended(
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_status candidate_status DEFAULT NULL,
    p_position TEXT DEFAULT NULL,
    p_object TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    phone TEXT,
    position TEXT,
    object_location TEXT,
    status candidate_status,
    age INTEGER,
    experience TEXT,
    created_at TIMESTAMPTZ,
    recruiter_username TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.full_name,
        c.phone,
        c.position,
        c.object_location,
        c.status,
        c.age,
        c.experience,
        c.created_at,
        c.telegram_username
    FROM candidates c
    WHERE c.is_deleted = FALSE
      AND c.is_duplicate = FALSE
      AND c.created_date BETWEEN p_start_date AND p_end_date
      AND (p_status IS NULL OR c.status = p_status)
      AND (p_position IS NULL OR c.position ILIKE '%' || p_position || '%')
      AND (p_object IS NULL OR c.object_location ILIKE '%' || p_object || '%')
    ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Статистика воронки найма
CREATE OR REPLACE FUNCTION get_funnel_stats(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    status candidate_status,
    count BIGINT,
    percentage NUMERIC
) AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM candidates
    WHERE created_date BETWEEN p_start_date AND p_end_date
      AND is_deleted = FALSE;

    RETURN QUERY
    SELECT
        c.status,
        COUNT(*) as count,
        ROUND(COUNT(*)::NUMERIC / NULLIF(v_total, 0) * 100, 1) as percentage
    FROM candidates c
    WHERE c.created_date BETWEEN p_start_date AND p_end_date
      AND c.is_deleted = FALSE
    GROUP BY c.status
    ORDER BY
        CASE c.status
            WHEN 'направлен' THEN 1
            WHEN 'собеседование' THEN 2
            WHEN 'оформление' THEN 3
            WHEN 'работает' THEN 4
            WHEN 'отказ' THEN 5
            WHEN 'архив' THEN 6
        END;
END;
$$ LANGUAGE plpgsql;

-- Статистика по рекрутерам
CREATE OR REPLACE FUNCTION get_recruiter_stats(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    telegram_username TEXT,
    total_candidates BIGINT,
    hired_count BIGINT,
    conversion_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(c.telegram_username, 'Unknown') as telegram_username,
        COUNT(*) as total_candidates,
        COUNT(*) FILTER (WHERE c.status = 'работает') as hired_count,
        ROUND(
            COUNT(*) FILTER (WHERE c.status = 'работает')::NUMERIC /
            NULLIF(COUNT(*), 0) * 100,
            1
        ) as conversion_rate
    FROM candidates c
    WHERE c.created_date BETWEEN p_start_date AND p_end_date
      AND c.is_deleted = FALSE
    GROUP BY c.telegram_username
    ORDER BY total_candidates DESC;
END;
$$ LANGUAGE plpgsql;

-- Отчёт по оплатам с группировкой
CREATE OR REPLACE FUNCTION get_payments_report(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '7 days',
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_object TEXT DEFAULT NULL,
    p_group_by TEXT DEFAULT 'date' -- date, object, position, employee
)
RETURNS TABLE (
    group_key TEXT,
    total_hours NUMERIC,
    employees_count BIGINT,
    records_count BIGINT
) AS $$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT
            %I::TEXT as group_key,
            SUM(hours)::NUMERIC as total_hours,
            COUNT(DISTINCT full_name) as employees_count,
            COUNT(*) as records_count
        FROM payments
        WHERE is_deleted = FALSE
          AND work_date BETWEEN $1 AND $2
          AND ($3 IS NULL OR object_location ILIKE ''%%'' || $3 || ''%%'')
        GROUP BY %I
        ORDER BY %I',
        CASE p_group_by
            WHEN 'date' THEN 'work_date'
            WHEN 'object' THEN 'object_location'
            WHEN 'position' THEN 'position'
            WHEN 'employee' THEN 'full_name'
            ELSE 'work_date'
        END,
        CASE p_group_by
            WHEN 'date' THEN 'work_date'
            WHEN 'object' THEN 'object_location'
            WHEN 'position' THEN 'position'
            WHEN 'employee' THEN 'full_name'
            ELSE 'work_date'
        END,
        CASE p_group_by
            WHEN 'date' THEN 'work_date'
            WHEN 'object' THEN 'object_location'
            WHEN 'position' THEN 'position'
            WHEN 'employee' THEN 'full_name'
            ELSE 'work_date'
        END
    ) USING p_start_date, p_end_date, p_object;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- ФУНКЦИИ: Уведомления админу
-- =============================================

-- Создание уведомления
CREATE OR REPLACE FUNCTION create_admin_notification(
    p_title TEXT,
    p_message TEXT,
    p_level notification_level DEFAULT 'info',
    p_source TEXT DEFAULT NULL,
    p_related_table TEXT DEFAULT NULL,
    p_related_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    INSERT INTO admin_notifications (
        title, message, level, source,
        related_table, related_record_id, metadata
    ) VALUES (
        p_title, p_message, p_level, p_source,
        p_related_table, p_related_id, p_metadata
    ) RETURNING id INTO v_notification_id;

    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql;

-- Получение непрочитанных уведомлений
CREATE OR REPLACE FUNCTION get_pending_notifications(
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    message TEXT,
    level notification_level,
    source TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id, n.title, n.message, n.level, n.source, n.created_at
    FROM admin_notifications n
    WHERE n.is_sent = FALSE
    ORDER BY
        CASE n.level
            WHEN 'critical' THEN 1
            WHEN 'error' THEN 2
            WHEN 'warning' THEN 3
            ELSE 4
        END,
        n.created_at
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- ФУНКЦИИ: LLM Кэш
-- =============================================

-- Получение из кэша
CREATE OR REPLACE FUNCTION get_llm_cache(
    p_message_hash TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT parsed_result INTO v_result
    FROM llm_cache
    WHERE message_hash = p_message_hash
      AND expires_at > NOW();

    IF FOUND THEN
        -- Обновляем статистику
        UPDATE llm_cache SET
            hit_count = hit_count + 1,
            last_hit_at = NOW()
        WHERE message_hash = p_message_hash;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Сохранение в кэш
CREATE OR REPLACE FUNCTION set_llm_cache(
    p_message_hash TEXT,
    p_message_text TEXT,
    p_result JSONB,
    p_ttl_hours INTEGER DEFAULT 24
) RETURNS VOID AS $$
BEGIN
    INSERT INTO llm_cache (message_hash, message_text, parsed_result, expires_at)
    VALUES (p_message_hash, p_message_text, p_result, NOW() + (p_ttl_hours || ' hours')::INTERVAL)
    ON CONFLICT (message_hash) DO UPDATE SET
        parsed_result = EXCLUDED.parsed_result,
        expires_at = NOW() + (p_ttl_hours || ' hours')::INTERVAL,
        hit_count = 0;
END;
$$ LANGUAGE plpgsql;

-- Очистка устаревшего кэша
CREATE OR REPLACE FUNCTION cleanup_llm_cache()
RETURNS INTEGER AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM llm_cache WHERE expires_at < NOW();
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- VIEWS (Представления для отчётов)
-- =============================================

-- Кандидаты за сегодня
CREATE OR REPLACE VIEW v_candidates_today AS
SELECT
    id, full_name, phone, position, object_location,
    status, age, experience, telegram_username, created_at
FROM candidates
WHERE created_date = CURRENT_DATE
  AND is_deleted = FALSE
ORDER BY created_at;

-- Воронка найма
CREATE OR REPLACE VIEW v_hiring_funnel AS
SELECT
    status,
    COUNT(*) as count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER() * 100, 1) as percentage
FROM candidates
WHERE is_deleted = FALSE
  AND created_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY status
ORDER BY
    CASE status
        WHEN 'направлен' THEN 1
        WHEN 'собеседование' THEN 2
        WHEN 'оформление' THEN 3
        WHEN 'работает' THEN 4
        WHEN 'отказ' THEN 5
        WHEN 'архив' THEN 6
    END;

-- Связь кандидатов с оплатами
CREATE OR REPLACE VIEW v_candidate_payments AS
SELECT
    c.id as candidate_id,
    c.full_name as candidate_name,
    c.phone,
    c.status,
    COUNT(p.id) as payment_records,
    SUM(p.hours) as total_hours,
    MIN(p.work_date) as first_work_date,
    MAX(p.work_date) as last_work_date
FROM candidates c
LEFT JOIN payments p ON p.candidate_id = c.id AND p.is_deleted = FALSE
WHERE c.is_deleted = FALSE
GROUP BY c.id, c.full_name, c.phone, c.status;

-- Статистика за неделю
CREATE OR REPLACE VIEW v_weekly_stats AS
SELECT
    created_date,
    COUNT(*) as total_candidates,
    COUNT(*) FILTER (WHERE status = 'направлен') as status_new,
    COUNT(*) FILTER (WHERE status = 'собеседование') as status_interview,
    COUNT(*) FILTER (WHERE status = 'работает') as status_hired,
    COUNT(*) FILTER (WHERE status = 'отказ') as status_rejected
FROM candidates
WHERE created_date >= CURRENT_DATE - INTERVAL '7 days'
  AND is_deleted = FALSE
GROUP BY created_date
ORDER BY created_date DESC;


-- =============================================
-- РАСШИРЕНИЯ (если не установлены)
-- =============================================

-- Для функции similarity() нужно расширение pg_trgm
CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- =============================================
-- ОЧИСТКА И ОБСЛУЖИВАНИЕ
-- =============================================

-- Функция очистки старых данных
CREATE OR REPLACE FUNCTION cleanup_old_data(
    p_audit_days INTEGER DEFAULT 90,
    p_logs_days INTEGER DEFAULT 30,
    p_cache_days INTEGER DEFAULT 7
) RETURNS TABLE (
    table_name TEXT,
    deleted_count INTEGER
) AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Очистка аудита
    DELETE FROM audit_log WHERE created_at < NOW() - (p_audit_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    table_name := 'audit_log'; deleted_count := v_count;
    RETURN NEXT;

    -- Очистка логов
    DELETE FROM bot_logs WHERE created_at < NOW() - (p_logs_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    table_name := 'bot_logs'; deleted_count := v_count;
    RETURN NEXT;

    -- Очистка отправленных уведомлений
    DELETE FROM admin_notifications
    WHERE is_sent = TRUE AND created_at < NOW() - (p_logs_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    table_name := 'admin_notifications'; deleted_count := v_count;
    RETURN NEXT;

    -- Очистка кэша
    v_count := cleanup_llm_cache();
    table_name := 'llm_cache'; deleted_count := v_count;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- ПРАВА ДОСТУПА
-- =============================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- Если нужен доступ (не рекомендуется):
-- GRANT SELECT ON candidates TO authenticated;
-- GRANT SELECT ON payments TO authenticated;

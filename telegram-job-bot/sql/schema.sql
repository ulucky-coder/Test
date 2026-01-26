-- =====================================================
-- Telegram Job Repost Bot - Supabase Schema
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- Table: source_groups
-- Группы-источники для мониторинга вакансий
-- =====================================================
CREATE TABLE IF NOT EXISTS source_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL UNIQUE,
    username VARCHAR(255),
    title VARCHAR(500),
    group_type VARCHAR(20) DEFAULT 'public' CHECK (group_type IN ('public', 'private')),
    invite_link TEXT,
    is_active BOOLEAN DEFAULT true,
    priority INTEGER DEFAULT 1 CHECK (priority BETWEEN 1 AND 10),
    last_checked_at TIMESTAMPTZ,
    last_message_id BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for active groups lookup
CREATE INDEX idx_source_groups_active ON source_groups(is_active) WHERE is_active = true;

-- =====================================================
-- Table: target_channels
-- Целевые группы/каналы для публикации
-- =====================================================
CREATE TABLE IF NOT EXISTS target_channels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    telegram_id BIGINT NOT NULL UNIQUE,
    username VARCHAR(255),
    title VARCHAR(500),
    channel_type VARCHAR(20) DEFAULT 'group' CHECK (channel_type IN ('group', 'channel')),
    is_active BOOLEAN DEFAULT true,
    bot_is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- Table: job_templates
-- Шаблоны для форматирования вакансий
-- =====================================================
CREATE TABLE IF NOT EXISTS job_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    template_text TEXT NOT NULL,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    variables JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure only one default template
CREATE UNIQUE INDEX idx_job_templates_default ON job_templates(is_default) WHERE is_default = true;

-- =====================================================
-- Table: posted_jobs
-- История опубликованных вакансий (для дедупликации)
-- =====================================================
CREATE TABLE IF NOT EXISTS posted_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_hash VARCHAR(64) NOT NULL,
    original_message_id BIGINT,
    source_group_id UUID REFERENCES source_groups(id) ON DELETE SET NULL,
    source_telegram_id BIGINT,
    target_channel_id UUID REFERENCES target_channels(id) ON DELETE SET NULL,
    posted_message_id BIGINT,
    original_text TEXT,
    formatted_text TEXT,
    parsed_data JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(20) DEFAULT 'posted' CHECK (status IN ('pending', 'posted', 'failed', 'skipped')),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    posted_at TIMESTAMPTZ
);

-- Index for deduplication check
CREATE INDEX idx_posted_jobs_hash ON posted_jobs(content_hash);

-- Index for cleanup (posts older than 2 weeks)
CREATE INDEX idx_posted_jobs_created ON posted_jobs(created_at);

-- =====================================================
-- Table: job_queue
-- Очередь вакансий для публикации
-- =====================================================
CREATE TABLE IF NOT EXISTS job_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_hash VARCHAR(64) NOT NULL,
    source_group_id UUID REFERENCES source_groups(id) ON DELETE CASCADE,
    source_telegram_id BIGINT,
    original_message_id BIGINT,
    original_text TEXT NOT NULL,
    parsed_data JSONB,
    formatted_text TEXT,
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'ready', 'published', 'failed')),
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    error_message TEXT,
    scheduled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for pending jobs
CREATE INDEX idx_job_queue_status ON job_queue(status, priority DESC, created_at ASC);

-- =====================================================
-- Table: bot_settings
-- Настройки бота
-- =====================================================
CREATE TABLE IF NOT EXISTS bot_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(255) NOT NULL UNIQUE,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- Table: keywords
-- Ключевые слова для фильтрации вакансий
-- =====================================================
CREATE TABLE IF NOT EXISTS keywords (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    word VARCHAR(255) NOT NULL UNIQUE,
    keyword_type VARCHAR(20) DEFAULT 'include' CHECK (keyword_type IN ('include', 'exclude')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- Table: contacts
-- Контакты рекрутеров для ссылок в шаблонах
-- =====================================================
CREATE TABLE IF NOT EXISTS contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    telegram_username VARCHAR(255),
    telegram_id BIGINT,
    bot_link TEXT,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- Table: activity_log
-- Лог активности бота
-- =====================================================
CREATE TABLE IF NOT EXISTS activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB DEFAULT '{}'::jsonb,
    source_group_id UUID REFERENCES source_groups(id) ON DELETE SET NULL,
    job_id UUID,
    severity VARCHAR(20) DEFAULT 'info' CHECK (severity IN ('debug', 'info', 'warning', 'error', 'critical')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for recent logs
CREATE INDEX idx_activity_log_created ON activity_log(created_at DESC);
CREATE INDEX idx_activity_log_severity ON activity_log(severity, created_at DESC);

-- =====================================================
-- Functions
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers
CREATE TRIGGER update_source_groups_updated_at
    BEFORE UPDATE ON source_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_target_channels_updated_at
    BEFORE UPDATE ON target_channels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_job_templates_updated_at
    BEFORE UPDATE ON job_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_job_queue_updated_at
    BEFORE UPDATE ON job_queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bot_settings_updated_at
    BEFORE UPDATE ON bot_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Function: Cleanup old posted jobs (older than 2 weeks)
-- =====================================================
CREATE OR REPLACE FUNCTION cleanup_old_posted_jobs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM posted_jobs
    WHERE created_at < NOW() - INTERVAL '14 days';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    INSERT INTO activity_log (event_type, event_data, severity)
    VALUES ('cleanup', jsonb_build_object('deleted_count', deleted_count), 'info');

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Function: Check duplicate by hash
-- =====================================================
CREATE OR REPLACE FUNCTION is_duplicate_job(p_hash VARCHAR(64))
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM posted_jobs
        WHERE content_hash = p_hash
        AND created_at > NOW() - INTERVAL '14 days'
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Initial Data: Default template
-- =====================================================
INSERT INTO job_templates (name, template_text, is_default, variables) VALUES (
    'default_job_template',
    E'🔥 СРОЧНО. {location}. {company_type}. Девочки, открыт набор в смену!\n\n🏢 Вакансия: {title}\n📍 Метро: {metro} ({metro_distance}).\n\n💰 ДЕНЬГИ:\n• {salary} руб/смена.\n• Выплаты: {payment_terms}.\n\n🎁 БОНУСЫ:\n{bonuses}\n\nТребования: {requirements}\nОпыт: {experience}.\n\n👇 ЖМИ НА ССЫЛКУ И ЗАПИСЫВАЙСЯ:\n{contact_link}',
    true,
    '["location", "company_type", "title", "metro", "metro_distance", "salary", "payment_terms", "bonuses", "requirements", "experience", "contact_link"]'::jsonb
) ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- Initial Data: Default keywords
-- =====================================================
INSERT INTO keywords (word, keyword_type) VALUES
    ('вакансия', 'include'),
    ('ищем', 'include'),
    ('требуется', 'include'),
    ('работа', 'include'),
    ('подработка', 'include'),
    ('набор', 'include'),
    ('срочно', 'include'),
    ('оплата', 'include')
ON CONFLICT (word) DO NOTHING;

-- =====================================================
-- Initial Data: Default settings
-- =====================================================
INSERT INTO bot_settings (key, value, description) VALUES
    ('check_interval_minutes', '60'::jsonb, 'Интервал проверки групп в минутах'),
    ('posts_per_hour', '24'::jsonb, 'Максимум постов в час'),
    ('ai_parser_enabled', 'true'::jsonb, 'Использовать AI для парсинга'),
    ('regex_parser_enabled', 'true'::jsonb, 'Использовать regex для парсинга'),
    ('min_message_length', '50'::jsonb, 'Минимальная длина сообщения для обработки'),
    ('max_message_length', '4000'::jsonb, 'Максимальная длина сообщения'),
    ('duplicate_check_days', '14'::jsonb, 'Дней для проверки дубликатов'),
    ('retry_failed_jobs', 'true'::jsonb, 'Повторять неудачные публикации'),
    ('max_retry_attempts', '3'::jsonb, 'Максимум попыток публикации')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- Scheduled job for cleanup (run daily via Supabase cron or external scheduler)
-- =====================================================
-- SELECT cron.schedule('cleanup-old-jobs', '0 3 * * *', 'SELECT cleanup_old_posted_jobs()');

-- =====================================================
-- Row Level Security (RLS) Policies
-- =====================================================
ALTER TABLE source_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE target_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE posted_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE keywords ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Service role has full access (for bot operations)
CREATE POLICY "Service role full access" ON source_groups FOR ALL USING (true);
CREATE POLICY "Service role full access" ON target_channels FOR ALL USING (true);
CREATE POLICY "Service role full access" ON job_templates FOR ALL USING (true);
CREATE POLICY "Service role full access" ON posted_jobs FOR ALL USING (true);
CREATE POLICY "Service role full access" ON job_queue FOR ALL USING (true);
CREATE POLICY "Service role full access" ON bot_settings FOR ALL USING (true);
CREATE POLICY "Service role full access" ON keywords FOR ALL USING (true);
CREATE POLICY "Service role full access" ON contacts FOR ALL USING (true);
CREATE POLICY "Service role full access" ON activity_log FOR ALL USING (true);

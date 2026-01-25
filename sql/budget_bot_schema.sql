-- ============================================
-- Budget Bot - PostgreSQL Schema
-- Полная схема базы данных для Telegram бота
-- ============================================

-- ============================================
-- 1. ТАБЛИЦЫ
-- ============================================

-- Таблица пользователей
CREATE TABLE IF NOT EXISTS users (
  chat_id BIGINT PRIMARY KEY,
  username VARCHAR(64),
  budget_limit NUMERIC(12,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица расходов
CREATE TABLE IF NOT EXISTS expenses (
  id SERIAL PRIMARY KEY,
  chat_id BIGINT NOT NULL REFERENCES users(chat_id) ON DELETE CASCADE,
  category VARCHAR(50) NOT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для оптимизации
CREATE INDEX IF NOT EXISTS idx_expenses_chat_id ON expenses(chat_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);
CREATE INDEX IF NOT EXISTS idx_expenses_chat_date ON expenses(chat_id, date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);

-- ============================================
-- 2. ФУНКЦИИ
-- ============================================

-- Функция: Месячная статистика пользователя
CREATE OR REPLACE FUNCTION get_monthly_stats(p_chat_id BIGINT)
RETURNS TABLE (
  total_spent NUMERIC,
  budget_limit NUMERIC,
  remaining NUMERIC,
  percent_used NUMERIC,
  transaction_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(e.amount), 0)::NUMERIC as total_spent,
    COALESCE(u.budget_limit, 0)::NUMERIC as budget_limit,
    (COALESCE(u.budget_limit, 0) - COALESCE(SUM(e.amount), 0))::NUMERIC as remaining,
    CASE
      WHEN COALESCE(u.budget_limit, 0) > 0
      THEN ROUND((COALESCE(SUM(e.amount), 0) / u.budget_limit * 100)::NUMERIC, 1)
      ELSE 0
    END as percent_used,
    COUNT(e.id)::INTEGER as transaction_count
  FROM users u
  LEFT JOIN expenses e ON e.chat_id = u.chat_id
    AND DATE_TRUNC('month', e.date) = DATE_TRUNC('month', CURRENT_DATE)
  WHERE u.chat_id = p_chat_id
  GROUP BY u.budget_limit;
END;
$$ LANGUAGE plpgsql;

-- Функция: Статистика по категориям за месяц
CREATE OR REPLACE FUNCTION get_category_stats(p_chat_id BIGINT)
RETURNS TABLE (
  category VARCHAR(50),
  total_amount NUMERIC,
  percentage NUMERIC,
  transaction_count INTEGER
) AS $$
DECLARE
  v_total NUMERIC;
BEGIN
  -- Получаем общую сумму за месяц
  SELECT COALESCE(SUM(amount), 0) INTO v_total
  FROM expenses
  WHERE chat_id = p_chat_id
    AND DATE_TRUNC('month', date) = DATE_TRUNC('month', CURRENT_DATE);

  RETURN QUERY
  SELECT
    e.category,
    SUM(e.amount)::NUMERIC as total_amount,
    CASE
      WHEN v_total > 0
      THEN ROUND((SUM(e.amount) / v_total * 100)::NUMERIC, 1)
      ELSE 0
    END as percentage,
    COUNT(*)::INTEGER as transaction_count
  FROM expenses e
  WHERE e.chat_id = p_chat_id
    AND DATE_TRUNC('month', e.date) = DATE_TRUNC('month', CURRENT_DATE)
  GROUP BY e.category
  ORDER BY total_amount DESC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Функция: Расходы за вчера
CREATE OR REPLACE FUNCTION get_yesterday_expenses(p_chat_id BIGINT)
RETURNS TABLE (
  category VARCHAR(50),
  amount NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.category,
    e.amount,
    e.created_at
  FROM expenses e
  WHERE e.chat_id = p_chat_id
    AND e.date = CURRENT_DATE - INTERVAL '1 day'
  ORDER BY e.created_at;
END;
$$ LANGUAGE plpgsql;

-- Функция: Расходы за период
CREATE OR REPLACE FUNCTION get_expenses_by_period(
  p_chat_id BIGINT,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE (
  id INTEGER,
  category VARCHAR(50),
  amount NUMERIC,
  date DATE,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.category,
    e.amount,
    e.date,
    e.created_at
  FROM expenses e
  WHERE e.chat_id = p_chat_id
    AND e.date BETWEEN p_start_date AND p_end_date
  ORDER BY e.date DESC, e.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Функция: Дневная статистика
CREATE OR REPLACE FUNCTION get_daily_stats(p_chat_id BIGINT, p_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
  total_spent NUMERIC,
  transaction_count INTEGER,
  avg_transaction NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(e.amount), 0)::NUMERIC as total_spent,
    COUNT(e.id)::INTEGER as transaction_count,
    COALESCE(AVG(e.amount), 0)::NUMERIC as avg_transaction
  FROM expenses e
  WHERE e.chat_id = p_chat_id
    AND e.date = p_date;
END;
$$ LANGUAGE plpgsql;

-- Функция: Топ категорий за всё время
CREATE OR REPLACE FUNCTION get_top_categories(p_chat_id BIGINT, p_limit INTEGER DEFAULT 5)
RETURNS TABLE (
  category VARCHAR(50),
  total_amount NUMERIC,
  transaction_count INTEGER,
  avg_amount NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.category,
    SUM(e.amount)::NUMERIC as total_amount,
    COUNT(*)::INTEGER as transaction_count,
    ROUND(AVG(e.amount)::NUMERIC, 2) as avg_amount
  FROM expenses e
  WHERE e.chat_id = p_chat_id
  GROUP BY e.category
  ORDER BY total_amount DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Функция: Сравнение с прошлым месяцем
CREATE OR REPLACE FUNCTION get_month_comparison(p_chat_id BIGINT)
RETURNS TABLE (
  current_month_total NUMERIC,
  previous_month_total NUMERIC,
  difference NUMERIC,
  percent_change NUMERIC
) AS $$
DECLARE
  v_current NUMERIC;
  v_previous NUMERIC;
BEGIN
  -- Текущий месяц
  SELECT COALESCE(SUM(amount), 0) INTO v_current
  FROM expenses
  WHERE chat_id = p_chat_id
    AND DATE_TRUNC('month', date) = DATE_TRUNC('month', CURRENT_DATE);

  -- Прошлый месяц
  SELECT COALESCE(SUM(amount), 0) INTO v_previous
  FROM expenses
  WHERE chat_id = p_chat_id
    AND DATE_TRUNC('month', date) = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month');

  RETURN QUERY
  SELECT
    v_current,
    v_previous,
    (v_current - v_previous)::NUMERIC,
    CASE
      WHEN v_previous > 0
      THEN ROUND(((v_current - v_previous) / v_previous * 100)::NUMERIC, 1)
      ELSE 0
    END;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. ТРИГГЕРЫ
-- ============================================

-- Триггер для обновления updated_at в users
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 4. ВСПОМОГАТЕЛЬНЫЕ ЗАПРОСЫ
-- ============================================

-- Удаление старых данных (запускать через cron)
-- DELETE FROM expenses WHERE date < CURRENT_DATE - INTERVAL '1 year';

-- Получить всех пользователей с тратами за вчера (для daily report)
-- SELECT DISTINCT u.chat_id, u.username
-- FROM users u
-- WHERE EXISTS (
--   SELECT 1 FROM expenses e
--   WHERE e.chat_id = u.chat_id
--   AND e.date = CURRENT_DATE - INTERVAL '1 day'
-- );

-- ============================================
-- 5. ПРАВА ДОСТУПА (для Supabase RLS)
-- ============================================

-- Включить RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

-- Политики (раскомментировать если нужны)
-- CREATE POLICY "Users can view own data" ON users
--   FOR SELECT USING (true);
-- CREATE POLICY "Users can insert own data" ON users
--   FOR INSERT WITH CHECK (true);
-- CREATE POLICY "Users can update own data" ON users
--   FOR UPDATE USING (true);

-- CREATE POLICY "Expenses select policy" ON expenses
--   FOR SELECT USING (true);
-- CREATE POLICY "Expenses insert policy" ON expenses
--   FOR INSERT WITH CHECK (true);

-- Для service role (n8n) - полный доступ
-- GRANT ALL ON users TO service_role;
-- GRANT ALL ON expenses TO service_role;
-- GRANT USAGE, SELECT ON SEQUENCE expenses_id_seq TO service_role;

-- ============================================
-- ГОТОВО!
-- Выполните этот скрипт в Supabase SQL Editor
-- ============================================

-- ============================================================
-- HR BOT MIGRATIONS
-- Выполните этот SQL в Supabase SQL Editor
-- ============================================================

-- 1. Добавляем колонку для отслеживания синхронизации с Google Sheets
ALTER TABLE approved_candidates
ADD COLUMN IF NOT EXISTS synced_to_sheets boolean DEFAULT false;

ALTER TABLE rejected_candidates
ADD COLUMN IF NOT EXISTS synced_to_sheets boolean DEFAULT false;

-- 2. Создаём таблицу для webhook логов
CREATE TABLE IF NOT EXISTS webhook_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  table_name text NOT NULL,
  record_id uuid,
  payload jsonb,
  webhook_url text,
  status text DEFAULT 'pending',
  response_code int,
  error_message text,
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- 3. Функция для отправки webhook уведомлений
CREATE OR REPLACE FUNCTION notify_status_change()
RETURNS trigger AS $$
DECLARE
  webhook_url text := 'https://ulucky.app.n8n.cloud/webhook/status-change';
  payload jsonb;
BEGIN
  payload := jsonb_build_object(
    'event', TG_OP,
    'table', TG_TABLE_NAME,
    'timestamp', now(),
    'record', row_to_json(NEW)
  );

  -- Логируем событие
  INSERT INTO webhook_logs (event_type, table_name, record_id, payload, webhook_url)
  VALUES (TG_OP, TG_TABLE_NAME, NEW.id, payload, webhook_url);

  -- Отправляем через pg_net (если установлен) или через Edge Function
  -- PERFORM net.http_post(webhook_url, payload, '{}', 5000);

  -- Используем NOTIFY для realtime
  PERFORM pg_notify('status_changes', payload::text);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Триггеры для отслеживания изменений статусов
DROP TRIGGER IF EXISTS on_approved_candidate ON approved_candidates;
CREATE TRIGGER on_approved_candidate
  AFTER INSERT ON approved_candidates
  FOR EACH ROW
  EXECUTE FUNCTION notify_status_change();

DROP TRIGGER IF EXISTS on_rejected_candidate ON rejected_candidates;
CREATE TRIGGER on_rejected_candidate
  AFTER INSERT ON rejected_candidates
  FOR EACH ROW
  EXECUTE FUNCTION notify_status_change();

DROP TRIGGER IF EXISTS on_session_status_change ON candidate_sessions;
CREATE TRIGGER on_session_status_change
  AFTER UPDATE OF status ON candidate_sessions
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_status_change();

-- 5. Индексы для оптимизации запросов аналитики
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON candidate_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON candidate_sessions(status);
CREATE INDEX IF NOT EXISTS idx_approved_created_at ON approved_candidates(created_at);
CREATE INDEX IF NOT EXISTS idx_rejected_created_at ON rejected_candidates(created_at);
CREATE INDEX IF NOT EXISTS idx_chat_history_session ON n8n_chat_histories(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_history_created ON n8n_chat_histories(created_at);

-- ============================================================
-- ГОТОВО! Триггеры будут отправлять NOTIFY при:
-- - Новый одобренный кандидат
-- - Новый отклонённый кандидат
-- - Изменение статуса сессии
-- ============================================================

-- ============================================================
-- HR BOT ANALYTICS VIEWS
-- Выполните этот SQL в Supabase SQL Editor
-- ============================================================

-- 1. Статистика кандидатов по дням
CREATE OR REPLACE VIEW analytics_candidates_daily AS
SELECT
  DATE(started_at) as date,
  COUNT(*) as total_candidates,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
  COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress,
  COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected
FROM candidate_sessions
WHERE started_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(started_at)
ORDER BY date DESC;

-- 2. Статистика по неделям
CREATE OR REPLACE VIEW analytics_candidates_weekly AS
SELECT
  DATE_TRUNC('week', started_at)::date as week_start,
  COUNT(*) as total_candidates,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
  COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress,
  ROUND(
    COUNT(CASE WHEN status = 'completed' THEN 1 END)::numeric /
    NULLIF(COUNT(*), 0) * 100, 1
  ) as completion_rate_percent
FROM candidate_sessions
WHERE started_at >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', started_at)
ORDER BY week_start DESC;

-- 3. Статистика по вакансиям
CREATE OR REPLACE VIEW analytics_vacancies AS
SELECT
  v.id as vacancy_id,
  v.position_name,
  v.status as vacancy_status,
  COUNT(DISTINCT cs.id) as total_applicants,
  COUNT(DISTINCT ac.id) as approved_count,
  COUNT(DISTINCT rc.id) as rejected_count,
  ROUND(
    COUNT(DISTINCT ac.id)::numeric /
    NULLIF(COUNT(DISTINCT cs.id), 0) * 100, 1
  ) as approval_rate_percent
FROM vacancies v
LEFT JOIN candidate_sessions cs ON cs.id IS NOT NULL  -- связь через responses если есть
LEFT JOIN approved_candidates ac ON ac.id IS NOT NULL
LEFT JOIN rejected_candidates rc ON rc.id IS NOT NULL
GROUP BY v.id, v.position_name, v.status
ORDER BY total_applicants DESC;

-- 4. Конверсия воронки
CREATE OR REPLACE VIEW analytics_funnel AS
SELECT
  'Всего сессий' as stage,
  1 as stage_order,
  COUNT(*) as count
FROM candidate_sessions
WHERE started_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT
  'Заполнили анкету' as stage,
  2 as stage_order,
  COUNT(*) as count
FROM candidate_sessions
WHERE status = 'completed'
  AND started_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT
  'Одобрены' as stage,
  3 as stage_order,
  COUNT(*) as count
FROM approved_candidates
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT
  'Отклонены' as stage,
  4 as stage_order,
  COUNT(*) as count
FROM rejected_candidates
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'

ORDER BY stage_order;

-- 5. Неактивные кандидаты (для напоминаний)
CREATE OR REPLACE VIEW inactive_candidates AS
SELECT
  cs.id as session_id,
  cs.telegram_user_id,
  cs.first_name,
  cs.language,
  cs.status,
  cs.started_at,
  MAX(nch.created_at) as last_message_at,
  EXTRACT(EPOCH FROM (NOW() - MAX(nch.created_at))) / 3600 as hours_inactive
FROM candidate_sessions cs
LEFT JOIN n8n_chat_histories nch ON nch.session_id = cs.id
WHERE cs.status = 'in_progress'
GROUP BY cs.id, cs.telegram_user_id, cs.first_name, cs.language, cs.status, cs.started_at
HAVING MAX(nch.created_at) < NOW() - INTERVAL '24 hours'
   OR MAX(nch.created_at) IS NULL
ORDER BY last_message_at ASC NULLS FIRST;

-- 6. Сводная статистика (для дашборда)
CREATE OR REPLACE VIEW analytics_summary AS
SELECT
  (SELECT COUNT(*) FROM candidate_sessions WHERE started_at >= CURRENT_DATE) as today_total,
  (SELECT COUNT(*) FROM candidate_sessions WHERE started_at >= CURRENT_DATE - INTERVAL '7 days') as week_total,
  (SELECT COUNT(*) FROM candidate_sessions WHERE started_at >= CURRENT_DATE - INTERVAL '30 days') as month_total,
  (SELECT COUNT(*) FROM approved_candidates WHERE created_at >= CURRENT_DATE) as today_approved,
  (SELECT COUNT(*) FROM approved_candidates WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as week_approved,
  (SELECT COUNT(*) FROM rejected_candidates WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as week_rejected,
  (SELECT COUNT(*) FROM candidate_sessions WHERE status = 'in_progress') as active_sessions,
  (SELECT COUNT(*) FROM vacancies WHERE status = 'active') as active_vacancies;

-- ============================================================
-- ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:
-- ============================================================
-- SELECT * FROM analytics_summary;
-- SELECT * FROM analytics_candidates_daily LIMIT 7;
-- SELECT * FROM analytics_funnel;
-- SELECT * FROM inactive_candidates;

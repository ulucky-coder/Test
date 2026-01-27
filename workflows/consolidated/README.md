# HR Bot - Консолидированные Workflows (3 вместо 9)

Оптимизированная версия: **3 workflow** вместо 9, без потери функциональности.

## Структура

| # | Файл | Триггер | Функции |
|---|------|---------|---------|
| 1 | `01-hr-bot-main.json` | Telegram | Router + Candidate + Payment + Confirm |
| 2 | `02-hr-bot-commands.json` | Telegram (/) | Report + Stats + Export + Status |
| 3 | `03-hr-bot-scheduled.json` | Schedule (3) | Daily Report + Notifications + Maintenance |

## Преимущества

- **Меньше workflows** — проще управлять и отлаживать
- **Нет внутренних webhooks** — быстрее работает, меньше latency
- **Изоляция по типу** — ошибка в scheduled не влияет на main
- **Меньше точек отказа** — надёжнее

## Архитектура

```
TELEGRAM
    │
    ├──► 01-HR-BOT-MAIN (Telegram Trigger)
    │    ├── Callback Handler (кнопки)
    │    │   ├── confirm_yes → Insert + Clear Redis
    │    │   ├── confirm_cancel → Cancel message
    │    │   ├── duplicate_add → Add as new
    │    │   └── status_change → Update status
    │    │
    │    ├── Text Message Handler
    │    │   ├── Classify (эвристики)
    │    │   ├── Check Redis State
    │    │   │
    │    │   ├── [candidate] → DeepSeek → Duplicates → Progress → Confirm
    │    │   ├── [continuation] → DeepSeek → Merge → Progress → Confirm
    │    │   └── [payment] → Regex Parse → Batch Insert → Link
    │    │
    │    └── Command Handler → redirect to 02
    │
    ├──► 02-HR-BOT-COMMANDS (Telegram Trigger, /)
    │    ├── /report [today|week|month|dd.mm-dd.mm]
    │    ├── /stats → Funnel statistics
    │    ├── /export [candidates|payments] [week|month]
    │    ├── /status <name> <new_status>
    │    └── /help
    │
    └──► 03-HR-BOT-SCHEDULED (3 Schedule Triggers)
         ├── Daily 22:00 MSK → Daily Report to chat
         ├── Every 5 min → Send admin notifications
         └── Every Hour → Cleanup + Link payments
```

## Импорт

1. Откройте n8n
2. **+** → **Import from File**
3. Импортируйте файлы в порядке:
   - `03-hr-bot-scheduled.json` (первым)
   - `02-hr-bot-commands.json`
   - `01-hr-bot-main.json` (последним)

## Credentials

| Название | Тип | Описание |
|----------|-----|----------|
| HR Bot Telegram | Telegram API | Bot Token от @BotFather |
| HR Bot Supabase | Supabase | service_role key |
| HR Bot Redis | Redis | Хост, порт, пароль |
| DeepSeek API | HTTP Header Auth | `Authorization: Bearer sk-xxx` |

## Environment Variables

```bash
# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdef...
TELEGRAM_CHAT_CANDIDATES=-1001234567890
TELEGRAM_CHAT_PAYMENTS=-1001234567891
TELEGRAM_ADMIN_CHAT_ID=123456789

# DeepSeek
DEEPSEEK_API_KEY=sk-xxxxxxxx
```

## Сравнение с 9-workflow версией

| Метрика | 9 workflows | 3 workflows |
|---------|-------------|-------------|
| Файлов | 9 | 3 |
| Внутренних webhooks | 4 | 0 |
| Точек отказа | Больше | Меньше |
| Latency | Выше (webhook calls) | Ниже |
| Сложность отладки | Распределённая | Централизованная |
| Изоляция | По функции | По типу триггера |

## Тестирование

### Workflow 1 (Main)
```
# Кандидат
Иванов Пётр, охранник, 89161234567, ТЦ Мега

# Неполные данные
Мария Сидорова, горничная

# Оплата
26.01
МП
Горничная
Иванова Юлия 11
Петрова Мария 8
```

### Workflow 2 (Commands)
```
/report
/report week
/stats
/export candidates
/status Иванов собеседование
/help
```

### Workflow 3 (Scheduled)
- Daily Report: автоматически в 22:00 MSK
- Notifications: каждые 5 минут
- Maintenance: каждый час

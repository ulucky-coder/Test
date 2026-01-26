# HR Bot - n8n Workflows

Полный набор n8n workflows для HR Telegram бота.

## Список workflows

| # | Файл | Название | Описание |
|---|------|----------|----------|
| 1 | `01-message-router.json` | Message Router | Приём и маршрутизация сообщений из Telegram |
| 2 | `02-candidate-processor.json` | Candidate Processor | Обработка данных кандидатов с LLM |
| 3 | `03-payment-processor.json` | Payment Processor | Обработка данных оплаты (batch insert) |
| 4 | `04-daily-report.json` | Daily Report | Ежедневный отчёт в 22:00 MSK |
| 5 | `05-custom-reports.json` | Custom Reports | Кастомные отчёты по командам |
| 6 | `06-status-manager.json` | Status Manager | Управление статусами кандидатов |
| 7 | `07-admin-notifications.json` | Admin Notifications | Отправка уведомлений администратору |
| 8 | `08-maintenance.json` | Maintenance | Очистка и обслуживание данных |
| 9 | `09-confirm-handler.json` | Confirm Handler | Обработка подтверждений от пользователей |

## Импорт в n8n

### Способ 1: Через интерфейс

1. Откройте n8n (https://ulucky.app.n8n.cloud)
2. Нажмите **+** → **Import from File**
3. Выберите JSON-файл workflow
4. Повторите для каждого файла

### Способ 2: Через CLI (если доступен)

```bash
# Импорт всех workflows
for file in workflows/*.json; do
  n8n import:workflow --input="$file"
done
```

## Настройка Credentials

Перед активацией workflows создайте следующие credentials:

### 1. Telegram Bot API
- **Name:** `HR Bot Telegram`
- **Access Token:** `<ваш токен от @BotFather>`

### 2. Supabase
- **Name:** `HR Bot Supabase`
- **Host:** `https://xxx.supabase.co`
- **Service Role Key:** `<service_role key>`

### 3. Redis
- **Name:** `HR Bot Redis`
- **Host:** `<host>`
- **Port:** `6379`
- **Password:** `<password>` (если есть)

### 4. DeepSeek API (HTTP Header Auth)
- **Name:** `DeepSeek API`
- **Header Name:** `Authorization`
- **Header Value:** `Bearer sk-xxxxxx`

## Environment Variables

Настройте переменные окружения в n8n:

```bash
# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_CANDIDATES=-1001234567890
TELEGRAM_CHAT_PAYMENTS=-1001234567891
TELEGRAM_ADMIN_CHAT_ID=123456789

# DeepSeek
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx

# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJxxxxxxxxx

# n8n Webhooks (URL вашего n8n)
N8N_WEBHOOK_URL=https://ulucky.app.n8n.cloud
```

## Порядок активации

**Важно:** Активируйте workflows в правильном порядке:

1. ✅ `08-maintenance.json` - Maintenance
2. ✅ `07-admin-notifications.json` - Admin Notifications
3. ✅ `06-status-manager.json` - Status Manager
4. ✅ `05-custom-reports.json` - Custom Reports
5. ✅ `04-daily-report.json` - Daily Report
6. ✅ `03-payment-processor.json` - Payment Processor
7. ✅ `09-confirm-handler.json` - Confirm Handler
8. ✅ `02-candidate-processor.json` - Candidate Processor
9. ✅ `01-message-router.json` - Message Router (последним!)

Message Router должен быть активирован последним, так как он вызывает другие workflows через webhooks.

## Архитектура взаимодействия

```
┌─────────────────────────────────────────────────────────────────┐
│                        TELEGRAM                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   01-MESSAGE-ROUTER                              │
│  • Принимает все сообщения и callback_query                     │
│  • Классифицирует (эвристики + LLM)                             │
│  • Маршрутизирует на соответствующие processors                 │
└─────────┬────────────┬────────────┬────────────┬────────────────┘
          │            │            │            │
          ▼            ▼            ▼            ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ 02-CANDIDATE│ │ 03-PAYMENT  │ │ 05-CUSTOM   │ │ 06-STATUS   │
│  PROCESSOR  │ │  PROCESSOR  │ │  REPORTS    │ │  MANAGER    │
└──────┬──────┘ └─────────────┘ └─────────────┘ └─────────────┘
       │
       ▼
┌─────────────┐
│ 09-CONFIRM  │
│   HANDLER   │
└─────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    SCHEDULED WORKFLOWS                           │
├─────────────────────────────────────────────────────────────────┤
│ 04-DAILY-REPORT       │ 22:00 MSK  │ Ежедневный отчёт          │
│ 07-ADMIN-NOTIFICATIONS│ */5 min    │ Уведомления админу        │
│ 08-MAINTENANCE        │ */1 hour   │ Очистка и обслуживание    │
└─────────────────────────────────────────────────────────────────┘
```

## Webhook URLs

После импорта workflows используют следующие webhook URLs:

| Workflow | Webhook Path |
|----------|--------------|
| Candidate Processor | `/webhook/candidate-processor` |
| Payment Processor | `/webhook/payment-processor` |
| Custom Reports | `/webhook/custom-reports` |
| Status Manager | `/webhook/status-manager` |
| Confirm Handler | `/webhook/confirm-handler` |

## Тестирование

### Тест 1: Добавление кандидата
```
Иванов Петр, охранник, 89161234567, ТЦ Мега
```
→ Бот должен показать превью с кнопками подтверждения

### Тест 2: Неполные данные
```
Мария Сидорова, горничная
```
→ Бот должен показать прогресс-бар и запросить недостающие данные

### Тест 3: Оплата
```
26.01
МП
Горничная
Иванова Юлия 11
Каратова Самара 8
```
→ Бот должен подтвердить запись 2 сотрудников

### Тест 4: Команды
```
/report           - Отчёт за сегодня
/report week      - Отчёт за неделю
/stats            - Воронка найма
/status Иванов собеседование - Изменить статус
/help             - Список команд
```

## Troubleshooting

### Workflow не активируется
- Проверьте все credentials
- Убедитесь, что environment variables настроены
- Проверьте каждую ноду на ошибки (красная иконка)

### Бот не отвечает
- Проверьте что Message Router активен
- Проверьте Telegram Bot Token
- Проверьте Chat ID групп

### Ошибки Supabase
- Убедитесь, что используете service_role key
- Проверьте что таблицы созданы (см. `docs/supabase-schema.sql`)

### Ошибки DeepSeek
- Проверьте API ключ
- Проверьте баланс на platform.deepseek.com

## Связанная документация

- [Архитектура системы](../docs/bot-architecture.md)
- [SQL схема базы данных](../docs/supabase-schema.sql)
- [Спецификация workflows](../docs/n8n-workflows-spec.md)
- [Руководство по развёртыванию](../docs/deployment-guide.md)

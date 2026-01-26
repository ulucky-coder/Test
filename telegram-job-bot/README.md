# Telegram Job Repost Bot

Автоматический бот для репоста вакансий из Telegram групп с адаптацией под единый шаблон.

## Возможности

- 📥 **Сбор вакансий** из 30+ групп-источников (публичных и приватных)
- 🤖 **AI-парсинг** (OpenAI/Claude) + regex для извлечения данных
- 📝 **Шаблонизация** постов под единый формат
- 🔄 **Дедупликация** - без повторных публикаций 14 дней
- ⏰ **Планировщик** - автоматический сбор каждый час
- 🌐 **n8n интеграция** - управление через визуальный интерфейс
- 📊 **Supabase** - хранение данных и настроек
- 🐳 **Docker** - простой деплой

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    Source Groups (30+)                       │
└─────────────────────┬───────────────────────────────────────┘
                      │ Pyrogram (MTProto)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   Job Collector                              │
│  • Мониторинг групп каждый час                              │
│  • Фильтрация по ключевым словам                            │
│  • Проверка дубликатов                                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              AI Parser (OpenAI/Claude) + Regex               │
│  • Извлечение: зарплата, локация, требования                │
│  • Confidence score для качества парсинга                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                      Supabase                                │
│  • posted_jobs (дедупликация)                               │
│  • source_groups, job_queue, settings                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   Job Publisher                              │
│  • Форматирование по шаблону                                │
│  • Rate limiting (24 поста/час)                             │
└─────────────────────┬───────────────────────────────────────┘
                      │ Bot API
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Target Group + Channel                          │
└─────────────────────────────────────────────────────────────┘
```

## Быстрый старт

### 1. Клонирование и настройка

```bash
cd telegram-job-bot
cp .env.example .env
```

### 2. Получение API ключей

1. **Telegram API** - https://my.telegram.org/apps
2. **Bot Token** - @BotFather в Telegram
3. **Supabase** - https://supabase.com (создать проект)
4. **OpenAI** (опционально) - https://platform.openai.com/api-keys

### 3. Настройка .env

```env
# Telegram
TELEGRAM_API_ID=your_api_id
TELEGRAM_API_HASH=your_api_hash
TELEGRAM_PHONE=+79001234567
TELEGRAM_BOT_TOKEN=your_bot_token

# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_KEY=your_service_key

# AI (опционально)
OPENAI_API_KEY=sk-xxx
AI_PROVIDER=openai

# Bot settings
TARGET_GROUP_ID=-1001234567890
TARGET_CHANNEL_ID=-1001234567891
WEBHOOK_SECRET=your_random_secret
```

### 4. Настройка базы данных

Выполните SQL из `sql/schema.sql` в Supabase SQL Editor.

### 5. Создание сессии Telegram

```bash
pip install -r requirements.txt
python scripts/setup_session.py
```

### 6. Запуск

```bash
# Локально
python -m src.main

# Docker
docker-compose up -d
```

## API Endpoints

| Endpoint | Метод | Описание |
|----------|-------|----------|
| `/health` | GET | Проверка здоровья |
| `/status` | GET | Статус бота |
| `/collect` | POST | Запустить сбор вакансий |
| `/publish` | POST | Опубликовать из очереди |
| `/publish/single` | POST | Опубликовать одну вакансию |
| `/parse` | POST | Парсинг без публикации |
| `/groups` | GET/POST | Управление группами |
| `/queue` | GET | Просмотр очереди |
| `/settings` | GET/POST | Настройки |
| `/logs` | GET | Логи активности |

Все эндпойнты (кроме `/health`) требуют заголовок `X-API-Key`.

## n8n Интеграция

1. Импортируйте `n8n/workflow.json` в ваш n8n
2. Создайте HTTP Header Auth credential:
   - Name: `Job Bot API Key`
   - Header: `X-API-Key`
   - Value: ваш `WEBHOOK_SECRET`
3. Установите переменную окружения `JOB_BOT_API_URL`

## Шаблон вакансии

```
🔥 СРОЧНО. {location}. {company_type}. Девочки, открыт набор в смену!

🏢 Вакансия: {title}
📍 Метро: {metro} ({metro_distance}).

💰 ДЕНЬГИ:
• {salary} руб/смена.
• Выплаты: {payment_terms}.

🎁 БОНУСЫ:
{bonuses}

Требования: {requirements}
Опыт: {experience}.

👇 ЖМИ НА ССЫЛКУ И ЗАПИСЫВАЙСЯ:
{contact_link}
```

## Добавление групп-источников

### Через API:
```bash
curl -X POST http://localhost:8080/groups \
  -H "X-API-Key: your_secret" \
  -H "Content-Type: application/json" \
  -d '{"telegram_id": -1001234567890, "title": "Job Group", "priority": 5}'
```

### Через Supabase:
```sql
INSERT INTO source_groups (telegram_id, title, username, priority)
VALUES (-1001234567890, 'Вакансии Москва', 'jobs_moscow', 5);
```

## Ключевые слова

По умолчанию бот ищет посты с:
- вакансия, ищем, требуется, работа, подработка, набор, срочно, оплата

Добавить новые:
```sql
INSERT INTO keywords (word, keyword_type)
VALUES ('менеджер', 'include');
```

## Структура проекта

```
telegram-job-bot/
├── src/
│   ├── bot/
│   │   ├── client.py      # Pyrogram клиент
│   │   ├── collector.py   # Сбор вакансий
│   │   ├── publisher.py   # Публикация
│   │   └── scheduler.py   # Планировщик
│   ├── parsers/
│   │   ├── regex_parser.py  # Regex парсинг
│   │   ├── ai_parser.py     # AI парсинг
│   │   └── combined_parser.py
│   ├── database/
│   │   ├── supabase_client.py
│   │   └── models.py
│   ├── api/
│   │   └── webhook.py     # FastAPI сервер
│   ├── templates/
│   │   └── job_template.py
│   ├── config.py
│   └── main.py
├── n8n/
│   └── workflow.json
├── sql/
│   └── schema.sql
├── scripts/
│   └── setup_session.py
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── .env.example
```

## Мониторинг

- Логи: `docker-compose logs -f job-bot`
- Статус: `GET /status`
- Активность: `GET /logs`
- n8n: визуальный мониторинг workflow

## Troubleshooting

### Бот не собирает сообщения
- Проверьте, что user account состоит в группах
- Убедитесь, что `source_groups.is_active = true`
- Проверьте логи: `docker-compose logs job-bot`

### FloodWait ошибки
- Увеличьте `API_DELAY_SECONDS`
- Уменьшите количество групп

### AI парсинг не работает
- Проверьте API ключ OpenAI/Anthropic
- Установите `AI_PROVIDER=none` для отключения

## Лицензия

MIT

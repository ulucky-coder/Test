# Архитектура Telegram-бота для HR-процессов

## Обзор системы

Telegram-бот для автоматизации HR-процессов в двух группах:
- **«Направленные»** — регистрация кандидатов
- **«Оплата мс»** — учёт отработанных часов

### Технологический стек

| Компонент | Технология | Назначение |
|-----------|------------|------------|
| Оркестрация | n8n | Workflow automation |
| База данных | Supabase (PostgreSQL) | Хранение данных |
| Кэш/Состояния | Redis | Состояния диалогов |
| LLM | DeepSeek API | Парсинг и классификация |
| Мессенджер | Telegram Bot API | Интерфейс пользователя |

---

## Архитектура системы

```
┌─────────────────────────────────────────────────────────────────────┐
│                           TELEGRAM                                  │
│  ┌─────────────────┐              ┌─────────────────┐              │
│  │ Группа          │              │ Группа          │              │
│  │ «Направленные»  │              │ «Оплата мс»     │              │
│  └────────┬────────┘              └────────┬────────┘              │
└───────────┼────────────────────────────────┼────────────────────────┘
            │                                │
            ▼                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        n8n WORKFLOWS                                │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │           WORKFLOW 1: Message Router                        │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐ │    │
│  │  │ Telegram │─▶│ Get Chat │─▶│ Classify │─▶│   Route    │ │    │
│  │  │ Trigger  │  │ Context  │  │ Message  │  │            │ │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────┬──────┘ │    │
│  │                                                   │        │    │
│  │                    ┌──────────────┬───────────────┤        │    │
│  │                    ▼              ▼               ▼        │    │
│  │              ┌──────────┐  ┌──────────┐    ┌──────────┐   │    │
│  │              │ Ignore   │  │ Candidate│    │ Payment  │   │    │
│  │              │ (chat)   │  │ Handler  │    │ Handler  │   │    │
│  │              └──────────┘  └────┬─────┘    └────┬─────┘   │    │
│  └─────────────────────────────────┼──────────────┼──────────┘    │
│                                    │              │                │
│  ┌─────────────────────────────────┼──────────────┼────────────┐  │
│  │           WORKFLOW 2: Candidate Processor       │            │  │
│  │                                 │              │            │  │
│  │  ┌──────────┐  ┌──────────┐    │              │            │  │
│  │  │ Redis    │─▶│ DeepSeek │◀───┘              │            │  │
│  │  │ State    │  │ Parser   │                   │            │  │
│  │  └──────────┘  └────┬─────┘                   │            │  │
│  │                     │                         │            │  │
│  │       ┌─────────────┴─────────────┐          │            │  │
│  │       ▼                           ▼          │            │  │
│  │ ┌──────────┐               ┌──────────┐      │            │  │
│  │ │ Complete │               │ Ask More │      │            │  │
│  │ │ → Save   │               │ → Redis  │      │            │  │
│  │ └────┬─────┘               └────┬─────┘      │            │  │
│  │      │                          │            │            │  │
│  │      ▼                          ▼            │            │  │
│  │ ┌──────────┐               ┌──────────┐      │            │  │
│  │ │ Supabase │               │ Telegram │      │            │  │
│  │ │ Insert   │               │ Question │      │            │  │
│  │ └────┬─────┘               └──────────┘      │            │  │
│  │      │                                       │            │  │
│  │      ▼                                       │            │  │
│  │ ┌──────────┐                                 │            │  │
│  │ │ Telegram │                                 │            │  │
│  │ │ Confirm  │                                 │            │  │
│  │ └──────────┘                                 │            │  │
│  └──────────────────────────────────────────────┼────────────┘  │
│                                                 │                │
│  ┌──────────────────────────────────────────────┼────────────┐  │
│  │           WORKFLOW 3: Payment Processor      │            │  │
│  │                                              │            │  │
│  │  ┌──────────┐  ┌──────────┐◀─────────────────┘            │  │
│  │  │ Regex    │─▶│ Validate │                               │  │
│  │  │ Parser   │  │ Data     │                               │  │
│  │  └──────────┘  └────┬─────┘                               │  │
│  │                     │                                     │  │
│  │       ┌─────────────┴─────────────┐                      │  │
│  │       ▼                           ▼                      │  │
│  │ ┌──────────┐               ┌──────────┐                  │  │
│  │ │ Complete │               │ Ask More │                  │  │
│  │ │ → Save   │               │ (Redis)  │                  │  │
│  │ └────┬─────┘               └────┬─────┘                  │  │
│  │      │                          │                        │  │
│  │      ▼                          ▼                        │  │
│  │ ┌──────────┐               ┌──────────┐                  │  │
│  │ │ Supabase │               │ Telegram │                  │  │
│  │ │ Insert   │               │ Question │                  │  │
│  │ └────┬─────┘               └──────────┘                  │  │
│  │      │                                                   │  │
│  │      ▼                                                   │  │
│  │ ┌──────────┐                                             │  │
│  │ │ Telegram │                                             │  │
│  │ │ Confirm  │                                             │  │
│  │ └──────────┘                                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           WORKFLOW 4: Daily Report                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │  │
│  │  │ Schedule │─▶│ Supabase │─▶│ Format   │─▶│ Telegram │ │  │
│  │  │ 22:00MSK │  │ Query    │  │ Report   │  │ Send     │ │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           WORKFLOW 5: State Cleanup                       │  │
│  │  ┌──────────┐  ┌──────────┐                              │  │
│  │  │ Schedule │─▶│ Redis    │  (удаление устаревших        │  │
│  │  │ Hourly   │  │ Cleanup  │   состояний > 24h)           │  │
│  │  └──────────┘  └──────────┘                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
            │                                │
            ▼                                ▼
┌─────────────────────┐          ┌─────────────────────┐
│       REDIS         │          │      SUPABASE       │
│  ┌───────────────┐  │          │  ┌───────────────┐  │
│  │ Dialog States │  │          │  │  candidates   │  │
│  │ - user_id     │  │          │  │  payments     │  │
│  │ - chat_id     │  │          │  └───────────────┘  │
│  │ - context     │  │          │                     │
│  │ - expires     │  │          │                     │
│  └───────────────┘  │          │                     │
└─────────────────────┘          └─────────────────────┘
```

---

## Детальное описание компонентов

### 1. Message Router (Workflow 1)

**Назначение:** Приём сообщений и маршрутизация по типу.

**Логика классификации сообщений:**

```
┌─────────────────────────────────────────────────────────────┐
│                  КЛАССИФИКАЦИЯ СООБЩЕНИЯ                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Проверка: есть ли активный диалог в Redis?             │
│     └─▶ ДА: направить в соответствующий handler            │
│                                                             │
│  2. Определение chat_id:                                   │
│     └─▶ Группа «Направленные» → candidate flow             │
│     └─▶ Группа «Оплата мс» → payment flow                  │
│                                                             │
│  3. Эвристики (быстрая проверка):                          │
│     ├─ Содержит телефон (regex)?          → +30% candidate │
│     ├─ Содержит "лет/год" + число?        → +20% candidate │
│     ├─ Начинается с даты (dd.mm)?         → +40% payment   │
│     ├─ Содержит число + "час"?            → +30% payment   │
│     └─ Содержит должность из словаря?     → +20% любой     │
│                                                             │
│  4. Если confidence < 70%:                                  │
│     └─▶ Отправить в DeepSeek для классификации             │
│                                                             │
│  5. Если confidence < 50% после LLM:                        │
│     └─▶ Игнорировать (обычный чат)                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Словарь должностей для эвристик:**
```
горничная, уборщица, охранник, администратор, повар,
официант, бармен, кассир, продавец, менеджер, водитель
```

### 2. Candidate Processor (Workflow 2)

**Назначение:** Обработка данных кандидатов с использованием LLM.

**Обязательные поля:**
- ФИО (full_name)
- Телефон (phone)
- Должность (position)
- Объект (object_location)

**Опциональные поля:**
- Возраст (age)
- Пол (gender)
- Опыт работы (experience)

**Промпт для DeepSeek:**
```
Ты — HR-ассистент. Извлеки данные кандидата из сообщения.

Сообщение: "{message}"

Контекст предыдущего диалога (если есть):
{context}

Верни JSON:
{
  "full_name": string | null,
  "age": number | null,
  "gender": "мужской" | "женский" | null,
  "position": string | null,
  "experience": string | null,
  "phone": string | null,
  "object_location": string | null,
  "is_complete": boolean,
  "missing_fields": string[],
  "clarification_question": string | null
}

Правила:
- Телефон нормализуй к формату 79XXXXXXXXX
- Пол определяй по имени, если явно не указан
- Возраст может быть указан словами ("тридцать пять")
- Если данных недостаточно, сформулируй вопрос на русском
- is_complete = true только если есть: ФИО, телефон, должность, объект
```

### 3. Payment Processor (Workflow 3)

**Назначение:** Парсинг структурированных данных об оплате.

**Формат входного сообщения:**
```
<дата>
<объект>
<должность>
<ФИО1> <часы1>
<ФИО2> <часы2>
...
```

**Regex-паттерны:**
```javascript
// Дата: dd.mm или dd.mm.yyyy
const datePattern = /^(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?$/;

// Часы: число в конце строки (целое или дробное)
const hoursPattern = /^(.+?)\s+(\d+(?:[.,]\d+)?)\s*$/;

// Проверка на известный объект (опционально)
const knownObjects = ['МП', 'ТЦ', 'Marriott', 'Hilton', ...];
```

**Алгоритм парсинга:**
```
1. Разбить сообщение по строкам
2. Строка 1: попытка парсинга как дата
3. Строка 2: объект (если не дата)
4. Строка 3: должность (из словаря или любой текст)
5. Остальные строки: ФИО + часы
6. Валидация: все обязательные поля заполнены?
7. Если нет — запрос уточнения
```

### 4. Daily Report (Workflow 4)

**Расписание:** Ежедневно в 22:00 MSK (19:00 UTC)

**SQL-запрос:**
```sql
SELECT
  full_name,
  phone,
  position,
  object_location
FROM candidates
WHERE created_date = CURRENT_DATE
ORDER BY created_at;
```

**Формат отчёта:**
```
📊 Отчёт за {дата}

Добавлено кандидатов: {count}

1. {ФИО}
   📞 {телефон}
   💼 {должность}
   📍 {объект}

2. {ФИО}
   ...

---
Всего за сегодня: {count} кандидат(ов)
```

### 5. State Cleanup (Workflow 5)

**Расписание:** Каждый час

**Логика:** Удаление записей Redis с TTL > 24 часов

---

## Структура данных

### Redis: Состояние диалога

**Ключ:** `dialog:{chat_id}:{user_id}`

**Значение (JSON):**
```json
{
  "type": "candidate | payment",
  "started_at": "2024-01-26T10:00:00Z",
  "last_activity": "2024-01-26T10:05:00Z",
  "original_message_id": 12345,
  "collected_data": {
    "full_name": "Иванов Петр",
    "phone": null,
    "position": "охранник",
    "object_location": null
  },
  "missing_fields": ["phone", "object_location"],
  "messages_history": [
    {"role": "user", "content": "Иванов Петр, охранник, 35 лет"},
    {"role": "assistant", "content": "Укажите телефон и объект"}
  ]
}
```

**TTL:** 24 часа (автоматическое удаление)

### Supabase: Схема БД

```sql
-- =============================================
-- ТАБЛИЦА: candidates (Направленные)
-- =============================================
CREATE TABLE candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Данные кандидата
    full_name TEXT NOT NULL,
    age INTEGER,
    gender TEXT CHECK (gender IN ('мужской', 'женский')),
    position TEXT NOT NULL,
    experience TEXT,
    phone TEXT NOT NULL,
    object_location TEXT NOT NULL,

    -- Метаданные Telegram
    telegram_user_id BIGINT NOT NULL,
    telegram_username TEXT,
    telegram_chat_id BIGINT NOT NULL,
    telegram_message_id BIGINT,

    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_date DATE DEFAULT CURRENT_DATE
);

-- Индексы
CREATE INDEX idx_candidates_created_date ON candidates(created_date);
CREATE INDEX idx_candidates_chat_id ON candidates(telegram_chat_id);
CREATE INDEX idx_candidates_phone ON candidates(phone);

-- =============================================
-- ТАБЛИЦА: payments (Оплата мс)
-- =============================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Данные об оплате
    work_date DATE NOT NULL,
    object_location TEXT NOT NULL,
    position TEXT NOT NULL,
    full_name TEXT NOT NULL,
    hours DECIMAL(5,2) NOT NULL CHECK (hours > 0),

    -- Метаданные Telegram
    telegram_user_id BIGINT NOT NULL,
    telegram_username TEXT,
    telegram_chat_id BIGINT NOT NULL,
    telegram_message_id BIGINT,

    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы
CREATE INDEX idx_payments_work_date ON payments(work_date);
CREATE INDEX idx_payments_chat_id ON payments(telegram_chat_id);
CREATE INDEX idx_payments_employee ON payments(full_name, work_date);

-- =============================================
-- ТАБЛИЦА: bot_logs (опционально, для отладки)
-- =============================================
CREATE TABLE bot_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    event_type TEXT NOT NULL,
    chat_id BIGINT,
    user_id BIGINT,
    message_text TEXT,
    parsed_data JSONB,
    error_message TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bot_logs_created ON bot_logs(created_at DESC);
CREATE INDEX idx_bot_logs_type ON bot_logs(event_type);
```

---

## Конфигурация

### Переменные окружения n8n

| Переменная | Описание | Пример |
|------------|----------|--------|
| `TELEGRAM_BOT_TOKEN` | Токен Telegram бота | `123456:ABC-DEF...` |
| `TELEGRAM_CHAT_CANDIDATES` | Chat ID группы «Направленные» | `-1001234567890` |
| `TELEGRAM_CHAT_PAYMENTS` | Chat ID группы «Оплата мс» | `-1001234567891` |
| `DEEPSEEK_API_KEY` | API ключ DeepSeek | `sk-...` |
| `DEEPSEEK_API_URL` | URL API DeepSeek | `https://api.deepseek.com/v1` |
| `REDIS_URL` | URL подключения к Redis | `redis://localhost:6379` |
| `SUPABASE_URL` | URL проекта Supabase | `https://xxx.supabase.co` |
| `SUPABASE_KEY` | Service role key Supabase | `eyJ...` |

### DeepSeek API

**Endpoint:** `https://api.deepseek.com/v1/chat/completions`

**Модель:** `deepseek-chat`

**Формат запроса (OpenAI-совместимый):**
```json
{
  "model": "deepseek-chat",
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."}
  ],
  "temperature": 0.1,
  "max_tokens": 500
}
```

---

## Обработка ошибок

### Стратегия retry

| Компонент | Max retries | Backoff | Действие при неудаче |
|-----------|-------------|---------|---------------------|
| Telegram API | 3 | 1s, 2s, 4s | Логировать, пропустить |
| DeepSeek API | 2 | 2s, 4s | Fallback на эвристики |
| Supabase | 3 | 1s, 2s, 4s | Сохранить в Redis, retry позже |
| Redis | 2 | 1s, 2s | Использовать in-memory |

### Fallback при недоступности LLM

Если DeepSeek недоступен:
1. Попытка классификации только эвристиками
2. Если уверенность < 50% — отправить сообщение:
   ```
   ⚠️ Не удалось обработать сообщение автоматически.
   Пожалуйста, используйте формат:

   Для кандидата:
   ФИО, возраст, пол, должность, опыт, телефон, объект

   Для оплаты:
   дата
   объект
   должность
   ФИО часы
   ```

---

## Безопасность

### Ограничения
- Бот работает только в указанных группах (whitelist chat_id)
- Rate limiting: max 30 сообщений/минуту на пользователя
- Валидация входных данных перед записью в БД

### Логирование
- Все сообщения логируются в `bot_logs` (опционально)
- PII данные (телефоны) не логируются в открытом виде

---

## Мониторинг

### Метрики для отслеживания
- Количество обработанных сообщений/день
- Процент успешных парсингов
- Среднее время ответа
- Количество запросов к LLM
- Ошибки по типам

### Алерты (рекомендуется настроить)
- LLM API недоступен > 5 минут
- Ошибки записи в Supabase
- Redis недоступен

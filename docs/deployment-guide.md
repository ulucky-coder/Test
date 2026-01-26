# Руководство по развёртыванию HR Bot

## Содержание
1. [Предварительные требования](#предварительные-требования)
2. [Создание Telegram бота](#создание-telegram-бота)
3. [Настройка Supabase](#настройка-supabase)
4. [Настройка DeepSeek API](#настройка-deepseek-api)
5. [Настройка Redis](#настройка-redis)
6. [Импорт workflows в n8n](#импорт-workflows-в-n8n)
7. [Тестирование](#тестирование)
8. [Troubleshooting](#troubleshooting)

---

## Предварительные требования

| Компонент | Требование | Статус |
|-----------|------------|--------|
| n8n | Версия 1.0+ | ✅ Есть (ulucky.app.n8n.cloud) |
| Redis | Любая версия | ✅ Есть |
| Supabase | Free tier достаточно | 🔲 Создать |
| DeepSeek API | API ключ | 🔲 Получить |
| Telegram Bot | Bot token | 🔲 Создать |

---

## 1. Создание Telegram бота

### Шаг 1.1: Создание бота через @BotFather

1. Откройте Telegram и найдите [@BotFather](https://t.me/BotFather)
2. Отправьте команду `/newbot`
3. Введите имя бота (например: `HR Tracker Bot`)
4. Введите username бота (например: `hr_tracker_company_bot`)
5. Сохраните полученный **токен**:
   ```
   123456789:ABCdefGHIjklMNOpqrsTUVwxyz
   ```

### Шаг 1.2: Настройка прав бота

Отправьте @BotFather следующие команды:

```
/setprivacy
→ Выберите вашего бота
→ Выберите "Disable"  (чтобы бот видел все сообщения в группах)

/setjoingroups
→ Выберите вашего бота
→ Выберите "Enable"
```

### Шаг 1.3: Добавление бота в группы

1. Добавьте бота в группу **«Направленные»**
2. Добавьте бота в группу **«Оплата мс»**
3. Назначьте бота **администратором** (для чтения всех сообщений)

### Шаг 1.4: Получение Chat ID групп

Отправьте любое сообщение в группу, затем откройте:
```
https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
```

Найдите `chat.id` для каждой группы (отрицательное число, например `-1001234567890`).

Или используйте бота [@getmyid_bot](https://t.me/getmyid_bot) — добавьте его в группу и он покажет Chat ID.

---

## 2. Настройка Supabase

### Шаг 2.1: Создание проекта

1. Перейдите на [supabase.com](https://supabase.com)
2. Войдите или создайте аккаунт
3. Нажмите **New Project**
4. Заполните:
   - **Name:** `hr-bot`
   - **Database Password:** (сгенерируйте и сохраните)
   - **Region:** выберите ближайший (eu-central-1 для России)
5. Нажмите **Create new project**
6. Дождитесь создания (~2 минуты)

### Шаг 2.2: Создание таблиц

1. В Supabase откройте **SQL Editor**
2. Нажмите **New query**
3. Скопируйте содержимое файла `docs/supabase-schema.sql`
4. Нажмите **Run** (или Ctrl+Enter)
5. Убедитесь, что все запросы выполнены успешно

### Шаг 2.3: Получение ключей API

1. Перейдите в **Settings** → **API**
2. Сохраните:
   - **Project URL:** `https://xxx.supabase.co`
   - **service_role key:** `eyJ...` (для записи данных)

⚠️ **Важно:** Используйте `service_role` key, а не `anon` key, так как мы отключили доступ для anon.

### Шаг 2.4: Настройка Chat ID в конфигурации

Обновите таблицу `bot_config`:

```sql
UPDATE bot_config
SET value = '{"chat_id": -1001234567890, "name": "Направленные"}'
WHERE key = 'chat_candidates';

UPDATE bot_config
SET value = '{"chat_id": -1001234567891, "name": "Оплата мс"}'
WHERE key = 'chat_payments';
```

---

## 3. Настройка DeepSeek API

### Шаг 3.1: Регистрация

1. Перейдите на [platform.deepseek.com](https://platform.deepseek.com)
2. Создайте аккаунт
3. Подтвердите email

### Шаг 3.2: Получение API ключа

1. Перейдите в **API Keys**
2. Нажмите **Create new API key**
3. Сохраните ключ: `sk-xxxxxxxxxxxxxxxxxxxxxxxx`

### Шаг 3.3: Пополнение баланса

DeepSeek работает по модели prepaid:
- Минимальное пополнение: ~$5
- Стоимость: ~$0.001-0.002 за сообщение
- $5 хватит на ~2500-5000 сообщений

### Шаг 3.4: Проверка API

```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Authorization: Bearer sk-xxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'
```

Ожидаемый ответ: JSON с `choices[0].message.content`.

---

## 4. Настройка Redis

### Вариант A: Уже есть Redis

Убедитесь, что:
- Redis доступен из n8n
- Знаете connection string: `redis://host:port` или `redis://:password@host:port`

### Вариант B: Managed Redis (рекомендуется)

**Upstash (бесплатно до 10K команд/день):**
1. Зарегистрируйтесь на [upstash.com](https://upstash.com)
2. Создайте новую Redis database
3. Выберите регион (eu-west для минимальной задержки)
4. Скопируйте connection string

**Redis Cloud (бесплатно 30MB):**
1. Зарегистрируйтесь на [redis.com/try-free](https://redis.com/try-free)
2. Создайте subscription (free tier)
3. Создайте database
4. Скопируйте connection details

### Проверка подключения

```bash
redis-cli -u redis://default:password@host:port ping
# Ожидаемый ответ: PONG
```

---

## 5. Импорт workflows в n8n

### Шаг 5.1: Настройка Credentials в n8n

1. Откройте n8n: https://ulucky.app.n8n.cloud
2. Перейдите в **Settings** → **Credentials**
3. Создайте credentials:

**Telegram Bot API:**
- Name: `HR Bot Telegram`
- Access Token: `<ваш токен>`

**Supabase:**
- Name: `HR Bot Supabase`
- Host: `https://xxx.supabase.co`
- Service Role Key: `<service_role key>`

**Redis:**
- Name: `HR Bot Redis`
- Host: `<host>`
- Port: `6379`
- Password: `<password>` (если есть)

### Шаг 5.2: Настройка Environment Variables

1. Перейдите в **Settings** → **Variables** (или используйте .env)
2. Добавьте переменные:

```
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_CANDIDATES=-1001234567890
TELEGRAM_CHAT_PAYMENTS=-1001234567891
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJxxxxxxxxx
REDIS_URL=redis://default:password@host:port
```

### Шаг 5.3: Создание workflows

Создайте 5 workflows согласно спецификации в `docs/n8n-workflows-spec.md`:

1. **HR Bot - Message Router**
2. **HR Bot - Candidate Processor**
3. **HR Bot - Payment Processor**
4. **HR Bot - Daily Report**
5. **HR Bot - State Cleanup**

### Шаг 5.4: Активация workflows

1. Откройте каждый workflow
2. Нажмите **Activate** (переключатель в правом верхнем углу)
3. Убедитесь, что статус = Active

---

## 6. Тестирование

### Тест 1: Message Router

1. Отправьте в группу «Направленные»:
   ```
   Привет, как дела?
   ```
   **Ожидание:** Бот не отвечает (обычный чат)

2. Отправьте:
   ```
   Иванов Петр, охранник, 89161234567, ТЦ Мега
   ```
   **Ожидание:** Бот подтверждает запись ✅

### Тест 2: Candidate Processor (неполные данные)

1. Отправьте:
   ```
   Мария Сидорова, горничная
   ```
   **Ожидание:** Бот спрашивает телефон и объект

2. Ответьте:
   ```
   89167654321, Hilton
   ```
   **Ожидание:** Бот подтверждает запись ✅

### Тест 3: Payment Processor

1. Отправьте в группу «Оплата мс»:
   ```
   26.01
   МП
   Горничная
   Иванова Юлия 11
   Каратова Самара 8
   ```
   **Ожидание:** Бот подтверждает 2 записи ✅

### Тест 4: Daily Report

1. Вручную запустите workflow "Daily Report"
2. **Ожидание:** Сообщение в группу «Направленные» со списком кандидатов за сегодня

### Тест 5: Проверка данных в Supabase

1. Откройте Supabase → Table Editor → candidates
2. Убедитесь, что записи добавлены корректно
3. Проверьте таблицу payments

---

## 7. Troubleshooting

### Проблема: Бот не получает сообщения

**Причины:**
- Privacy mode включён
- Бот не администратор группы
- Неверный Chat ID

**Решение:**
1. Проверьте `/setprivacy` → Disable
2. Назначьте бота администратором
3. Перепроверьте Chat ID через `getUpdates`

### Проблема: DeepSeek возвращает ошибку

**Причины:**
- Недостаточно средств на балансе
- Неверный API ключ
- Rate limit

**Решение:**
1. Проверьте баланс на platform.deepseek.com
2. Проверьте API ключ
3. Добавьте retry с backoff

### Проблема: Supabase insert failed

**Причины:**
- Неверный service key
- Нарушение constraints (например, NULL в NOT NULL поле)
- RLS блокирует доступ

**Решение:**
1. Используйте service_role key (не anon)
2. Проверьте логи в Supabase → Logs
3. Убедитесь, что RLS отключён или настроен правильно

### Проблема: Redis connection failed

**Причины:**
- Неверный host/port
- Firewall блокирует
- Требуется TLS

**Решение:**
1. Проверьте connection string
2. Для Upstash используйте `rediss://` (с TLS)
3. Проверьте whitelist IP в настройках Redis

### Проблема: Workflow не активируется

**Причины:**
- Ошибка в конфигурации ноды
- Отсутствуют credentials

**Решение:**
1. Откройте workflow в редакторе
2. Проверьте каждую ноду на наличие ошибок (красная иконка)
3. Убедитесь, что все credentials назначены

---

## Мониторинг и поддержка

### Логи выполнения

- n8n: **Executions** → просмотр истории запусков
- Supabase: **Logs** → Database, API
- Redis: через CLI или Upstash Console

### Рекомендуемые алерты

1. **Webhook failures** — настройте уведомления в n8n
2. **LLM errors** — логировать в bot_logs, настроить оповещение
3. **Daily report не отправлен** — проверять вручную или через healthcheck

### Бэкапы

- **Supabase:** автоматические daily backups (free tier: 7 дней)
- **Redis:** данные временные, TTL 24h, бэкап не требуется
- **n8n workflows:** экспортируйте JSON периодически

---

## Чеклист развёртывания

- [ ] Создан Telegram бот
- [ ] Получен Bot Token
- [ ] Privacy mode отключён
- [ ] Бот добавлен в группы как админ
- [ ] Получены Chat ID обеих групп
- [ ] Создан проект Supabase
- [ ] Выполнен SQL-скрипт создания таблиц
- [ ] Получен service_role key
- [ ] Получен DeepSeek API key
- [ ] Пополнен баланс DeepSeek
- [ ] Настроен Redis (или используется существующий)
- [ ] Созданы credentials в n8n
- [ ] Настроены environment variables
- [ ] Созданы все 5 workflows
- [ ] Workflows активированы
- [ ] Пройдены все тесты
- [ ] Настроен мониторинг (опционально)

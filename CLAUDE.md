# CLAUDE.md - AI Assistant Guidelines

> This file provides context and guidelines for AI assistants working with this repository.

## Repository Overview

**Project Name:** Test
**Status:** Active Development
**Last Updated:** 2026-01-25

This repository provides integration between **Supabase** (backend database) and **n8n** (workflow automation) via MCP (Model Context Protocol). It includes:

- **Supabase SDK wrapper** - Simplified JavaScript modules for database, auth, realtime, and storage operations
- **n8n API client** - JavaScript client for managing n8n workflows and executions
- **Budget Bot** - A Telegram bot workflow for expense tracking with PostgreSQL backend
- **Workflow management** - Export/import n8n workflows as JSON files

## Project Structure

```
/home/user/Test/
├── .git/                    # Git version control
├── .gitignore               # Git ignore patterns
├── .mcp.json                # MCP server configuration (gitignored)
├── CLAUDE.md                # This file - AI assistant guidelines
├── package.json             # npm package configuration
├── package-lock.json        # npm dependency lock file
├── node_modules/            # npm dependencies (gitignored)
├── scripts/
│   └── list-workflows.js    # CLI script to list n8n workflows
├── sql/
│   └── budget_bot_schema.sql # PostgreSQL schema for Budget Bot
├── src/
│   ├── n8n/                 # n8n API client modules
│   │   ├── index.js         # Main export file
│   │   └── client.js        # n8n API client (workflows, executions)
│   └── supabase/            # Supabase integration modules
│       ├── index.js         # Main export file
│       ├── client.js        # Supabase client configuration
│       ├── data.js          # CRUD operations (read, insert, update, delete, rpc)
│       ├── auth.js          # Authentication operations
│       ├── realtime.js      # Realtime subscriptions (postgres_changes, broadcast, presence)
│       └── storage.js       # File storage operations
└── workflows/
    └── n8n/                 # Exported n8n workflow JSON files
        ├── README.md        # Workflow documentation
        ├── budget-bot.json  # Budget Bot workflow
        └── Budget Bot Fixed.json # Fixed version of Budget Bot
```

### Directory Conventions

| Directory | Purpose |
|-----------|---------|
| `src/supabase/` | Supabase client and operation modules |
| `src/n8n/` | n8n API client for workflow management |
| `scripts/` | CLI utility scripts |
| `sql/` | PostgreSQL schema and migration files |
| `workflows/n8n/` | Exported n8n workflow JSON files |
| `tests/` | Test files (to be added) |

## Technology Stack

- **Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Database:** PostgreSQL via Supabase with RLS (Row Level Security)
- **MCP Integration:** n8n-mcp (Model Context Protocol server for n8n)
- **Automation:** n8n workflow automation (https://ulucky.app.n8n.cloud)
- **Language:** JavaScript (Node.js)
- **Package Manager:** npm
- **Dependencies:**
  - `@supabase/supabase-js` (^2.91.0) - Supabase JavaScript client
- **Testing Framework:** TBD

## Development Workflow

### Getting Started

```bash
# Clone the repository
git clone https://github.com/ulucky-coder/Test.git
cd Test

# Install dependencies
npm install

# Set environment variables
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
export SUPABASE_SERVICE_KEY="your-service-key"  # Optional, for admin operations
export N8N_API_KEY="your-n8n-api-key"           # Required for n8n integration

# (Optional) Set up the Budget Bot database schema
# Run sql/budget_bot_schema.sql in Supabase SQL Editor

# List available n8n workflows
npm run workflows
```

### Common Commands

| Command | Description |
|---------|-------------|
| `npm install` | Install dependencies |
| `npm test` | Run tests (not yet configured) |
| `npm run workflows` | List all n8n workflows |

### Usage Examples

#### Supabase Operations

```javascript
const { read, insert, update, remove, rpc, auth, storage, realtime } = require('./src/supabase');

// Read data with filters and ordering
const users = await read('users', {
  filters: { chat_id: 123456789 },
  order: { created_at: 'desc' },
  limit: 10
});

// Insert data (single or array)
await insert('expenses', { chat_id: 123, category: 'food', amount: 50.00 });

// Update data
await update('users', { budget_limit: 1000 }, { chat_id: 123 });

// Delete data
await remove('expenses', { id: 1 });

// Call stored procedure (RPC)
const stats = await rpc('get_monthly_stats', { p_chat_id: 123456789 });

// Authentication
await auth.signIn('user@example.com', 'password');
await auth.signUp('user@example.com', 'password', { data: { name: 'John' } });

// Storage
await storage.upload('avatars', 'user1.png', fileBuffer);
const url = storage.getPublicUrl('avatars', 'user1.png');

// Realtime subscriptions
realtime.onInsert('expenses', (payload) => {
  console.log('New expense:', payload.new);
});
```

#### n8n API Operations

```javascript
const { getWorkflows, getWorkflow, activateWorkflow, getExecutions } = require('./src/n8n');

// List all workflows
const workflows = await getWorkflows();
const activeOnly = await getWorkflows({ active: true });

// Get specific workflow
const workflow = await getWorkflow('workflow-id');

// Activate/deactivate workflows
await activateWorkflow('workflow-id');
await deactivateWorkflow('workflow-id');

// Get execution history
const executions = await getExecutions({ workflowId: 'id', status: 'success' });
```

### Git Workflow

1. **Branch Naming:**
   - Feature branches: `feature/<description>`
   - Bug fixes: `fix/<description>`
   - AI-assisted branches: `claude/<description>`

2. **Commit Messages:** Use clear, descriptive messages
   - Format: `<type>: <description>`
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

3. **Pull Requests:**
   - Provide clear description of changes
   - Reference related issues
   - Ensure tests pass before merging

## Code Conventions

### JavaScript Guidelines

- Use `const` for constants and `let` for variables (avoid `var`)
- Use async/await for asynchronous operations
- Export functions via `module.exports` (CommonJS)
- Use JSDoc comments for function documentation
- Handle errors with try/catch and throw meaningful error messages
- Use destructuring for imports: `const { func1, func2 } = require('./module')`

### File Naming

- Use lowercase with hyphens for files: `budget-bot.json`, `list-workflows.js`
- Use camelCase for JavaScript module files: `client.js`, `realtime.js`
- SQL files use underscores: `budget_bot_schema.sql`

### Module Pattern

Each module follows this pattern:
```javascript
const { dependency } = require('./other-module');

async function operation(params) {
  // Implementation
}

module.exports = { operation };
```

### Documentation

- JSDoc comments for all exported functions
- Include `@param` and `@returns` annotations
- Document options objects with their properties

## Testing Guidelines

> Update when testing framework is established.

- Write tests for new features
- Ensure existing tests pass before committing
- Aim for meaningful test coverage
- Test edge cases and error conditions

## AI Assistant Instructions

### When Working on This Repository

1. **Always read before modifying:** Understand existing code before making changes
2. **Maintain consistency:** Follow established patterns and conventions
3. **Keep changes focused:** Make only the requested changes, avoid over-engineering
4. **Test your changes:** Run existing tests and add new ones as appropriate
5. **Document significant changes:** Update relevant documentation

### Things to Avoid

- Don't introduce security vulnerabilities (XSS, SQL injection, etc.)
- Don't add unnecessary dependencies
- Don't make breaking changes without explicit approval
- Don't commit sensitive data (API keys, passwords, etc.)
- Don't ignore existing code patterns without good reason

### Helpful Context

- This repository uses Git for version control
- The main development branch is tracked via Git
- Check `.gitignore` for files that should not be committed

## Environment Setup

> Document environment requirements and setup steps here.

### Prerequisites

- Git installed
- Node.js (v16 or later recommended)
- npm (comes with Node.js)
- Supabase project with credentials
- n8n cloud instance (optional, for workflow automation)

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase anonymous/public key | Yes* |
| `SUPABASE_SERVICE_KEY` | Supabase service role key (bypasses RLS) | No |
| `N8N_API_URL` | n8n instance URL (default: https://ulucky.app.n8n.cloud) | No |
| `N8N_API_KEY` | API key for n8n cloud instance | Yes |

*Either `SUPABASE_ANON_KEY` or `SUPABASE_SERVICE_KEY` must be set.

**Note:** Never commit API keys to the repository. Set environment variables locally or use a secrets manager. The `.mcp.json` file is gitignored for this reason.

### MCP Configuration

The project uses Model Context Protocol (MCP) for AI tool integration. Configuration is in `.mcp.json`:

```bash
# Quick setup with Claude CLI
claude mcp add n8n-mcp

# Set your API key as environment variable
export N8N_API_KEY="your-api-key-here"
```

The n8n-mcp server provides workflow automation capabilities through the n8n platform.

## Key Features

### Budget Bot

A Telegram bot workflow for personal expense tracking. The bot allows users to:
- Track expenses by category
- Set monthly budget limits
- View spending statistics and reports
- Compare spending across months

**Database schema:** `sql/budget_bot_schema.sql`

**Tables:**
- `users` - User profiles with budget limits (keyed by `chat_id`)
- `expenses` - Individual expense records with category, amount, and date

**PostgreSQL Functions (RPC):**
| Function | Description |
|----------|-------------|
| `get_monthly_stats(p_chat_id)` | Monthly spending summary with budget status |
| `get_category_stats(p_chat_id)` | Breakdown by category for current month |
| `get_yesterday_expenses(p_chat_id)` | Expenses from previous day |
| `get_expenses_by_period(p_chat_id, start, end)` | Expenses within date range |
| `get_daily_stats(p_chat_id, p_date)` | Single day statistics |
| `get_top_categories(p_chat_id, p_limit)` | Top spending categories all-time |
| `get_month_comparison(p_chat_id)` | Compare current vs previous month |

### n8n Workflow Management

Workflows are stored in `workflows/n8n/` as JSON files. See `workflows/n8n/README.md` for import/export instructions.

**File naming:** Use kebab-case (e.g., `budget-bot.json`)

## Working with n8n Workflows (AI Assistant Guide)

Папка `workflows/n8n/` содержит экспортированные воркфлоу n8n в формате JSON. AI-ассистент может читать, анализировать и модифицировать эти файлы.

### Структура JSON воркфлоу

```json
{
  "name": "Workflow Name",           // Название воркфлоу
  "nodes": [...],                    // Массив нод (узлов)
  "connections": {...},              // Связи между нодами
  "settings": {...},                 // Настройки воркфлоу
  "active": false,                   // Активен ли воркфлоу
  "id": "workflow-id",               // Уникальный ID
  "tags": [...]                      // Теги для организации
}
```

### Структура ноды (node)

```json
{
  "id": "unique-node-id",
  "name": "Node Display Name",
  "type": "n8n-nodes-base.nodetype",  // Тип ноды
  "typeVersion": 1.2,
  "position": [x, y],                  // Позиция на канвасе
  "parameters": {...},                 // Параметры ноды
  "credentials": {...},                // Учётные данные (если нужны)
  "onError": "continueRegularOutput",  // Поведение при ошибке
  "retryOnFail": true,                 // Повторять при ошибке
  "maxTries": 3                        // Макс. попыток
}
```

### Основные типы нод

| Тип ноды | Описание |
|----------|----------|
| `n8n-nodes-base.telegramTrigger` | Триггер входящих сообщений Telegram |
| `n8n-nodes-base.telegram` | Отправка сообщений в Telegram |
| `n8n-nodes-base.postgres` | SQL-запросы к PostgreSQL |
| `n8n-nodes-base.redis` | Операции с Redis (кэш/состояние) |
| `n8n-nodes-base.code` | JavaScript код |
| `n8n-nodes-base.if` | Условное ветвление |
| `n8n-nodes-base.switch` | Множественное ветвление |
| `n8n-nodes-base.scheduleTrigger` | Запуск по расписанию |
| `n8n-nodes-base.errorTrigger` | Обработка ошибок |
| `@n8n/n8n-nodes-langchain.chainLlm` | AI/LLM интеграция |

### Как AI может работать с воркфлоу

#### 1. Чтение и анализ
```bash
# Прочитать воркфлоу
Read: workflows/n8n/budget-bot.json

# Найти все Code-ноды
Grep: "n8n-nodes-base.code" in workflows/n8n/
```

#### 2. Модификация
- **Изменение параметров нод** — редактировать `parameters` в нужной ноде
- **Изменение JS-кода** — редактировать `jsCode` в Code-нодах
- **Изменение SQL-запросов** — редактировать `query` в Postgres-нодах
- **Изменение сообщений** — редактировать `text` в Telegram-нодах

#### 3. Добавление новых нод
При добавлении новой ноды необходимо:
1. Добавить объект ноды в массив `nodes`
2. Добавить связь в объект `connections`
3. Сгенерировать уникальный `id` (UUID формат)

#### 4. Важные правила

**НЕ ИЗМЕНЯТЬ:**
- `id` существующих нод (сломает connections)
- `credentials.id` (ссылки на секреты в n8n)
- `webhookId` (идентификаторы вебхуков)

**МОЖНО ИЗМЕНЯТЬ:**
- `name` — отображаемое имя ноды
- `parameters` — параметры и настройки
- `position` — расположение на канвасе
- `onError`, `retryOnFail`, `maxTries` — обработка ошибок

### Пример: Изменение текста сообщения

Найти ноду по имени:
```json
{
  "name": "Send Welcome",
  "parameters": {
    "text": "👋 Добро пожаловать в Budget Bot!..."
  }
}
```

Изменить поле `text` для обновления сообщения.

### Пример: Изменение SQL-запроса

```json
{
  "name": "DB Save Expense",
  "parameters": {
    "query": "INSERT INTO expenses (chat_id, category, amount) VALUES ($1, $2, $3)...",
    "options": {
      "queryReplacement": "={{ [$json.chatId, $json.category, $json.amount] }}"
    }
  }
}
```

### Пример: Изменение JavaScript-кода

```json
{
  "name": "Parse Message",
  "parameters": {
    "jsCode": "const message = $input.first().json.message;..."
  }
}
```

### Выражения n8n

В параметрах используются выражения n8n:
- `{{ $json.field }}` — доступ к полю текущих данных
- `{{ $('Node Name').first().json.field }}` — данные из конкретной ноды
- `{{ $input.first().json }}` — входные данные
- `{{ $env.VAR_NAME }}` — переменные окружения

### Текущие воркфлоу

| Файл | Описание |
|------|----------|
| `budget-bot.json` | Telegram-бот для учёта расходов |
| `Budget Bot Fixed.json` | Исправленная версия Budget Bot |

### Синхронизация с n8n

После изменения JSON-файла:
1. Откройте n8n: https://ulucky.app.n8n.cloud
2. Импортируйте файл: **+** → **Import from File**
3. Проверьте credentials (могут потребоваться пере-привязки)
4. Активируйте воркфлоу

## Troubleshooting

### Common Issues

1. **Issue:** `SUPABASE_URL is required` error
   - **Solution:** Set the `SUPABASE_URL` environment variable

2. **Issue:** `N8N_API_KEY is not set` warning
   - **Solution:** Set the `N8N_API_KEY` environment variable for n8n API access

3. **Issue:** RPC function not found
   - **Solution:** Run the SQL schema in `sql/budget_bot_schema.sql` in Supabase SQL Editor

## Resources

- Repository: [ulucky-coder/Test](https://github.com/ulucky-coder/Test)
- n8n Cloud Instance: https://ulucky.app.n8n.cloud
- n8n Documentation: https://docs.n8n.io
- n8n-mcp: MCP server for n8n integration
- Supabase Documentation: https://supabase.com/docs
- Supabase JS Client: https://supabase.com/docs/reference/javascript

---

*This CLAUDE.md file should be updated as the project evolves to reflect current structure, conventions, and workflows.*

# n8n Workflows

Эта папка содержит экспортированные workflows из n8n.

## Как добавить workflow

### 1. Экспорт из n8n

1. Откройте workflow в n8n
2. Нажмите **⋮** (три точки) → **Download**
3. Сохраните JSON файл

### 2. Загрузка в репозиторий

Положите файл в эту папку с понятным именем:
```
workflows/n8n/
├── budget-bot.json          # Telegram бот для бюджета
├── daily-report.json        # Ежедневные отчёты
└── user-notifications.json  # Уведомления пользователям
```

### 3. Именование файлов

- Используйте kebab-case: `my-workflow-name.json`
- Давайте описательные имена
- Один workflow = один файл

## Структура workflow JSON

```json
{
  "name": "Workflow Name",
  "nodes": [...],
  "connections": {...},
  "settings": {...}
}
```

## Импорт workflow в n8n

1. Откройте n8n
2. Нажмите **+** → **Import from File**
3. Выберите JSON файл

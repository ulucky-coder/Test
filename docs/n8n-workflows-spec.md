# Спецификация n8n Workflows (v2.0)

## Обзор

| # | Workflow | Триггер | Описание |
|---|----------|---------|----------|
| 1 | HR Bot - Message Router | Telegram Trigger | Приём, классификация и маршрутизация сообщений |
| 2 | HR Bot - Candidate Processor | Webhook (internal) | Обработка данных кандидатов с LLM |
| 3 | HR Bot - Payment Processor | Webhook (internal) | Обработка данных оплаты (batch) |
| 4 | HR Bot - Daily Report | Schedule (22:00 MSK) | Ежедневный отчёт |
| 5 | HR Bot - Custom Reports | Telegram Command | Кастомные отчёты по команде |
| 6 | HR Bot - Status Manager | Telegram Command | Управление статусами кандидатов |
| 7 | HR Bot - Admin Notifications | Schedule (5 min) | Отправка уведомлений администратору |
| 8 | HR Bot - Maintenance | Schedule (hourly) | Очистка, линковка, обслуживание |

---

## Общие компоненты

### Inline-кнопки (Telegram Keyboard)

Используется во всех workflows для улучшения UX.

```javascript
// Функция генерации inline-кнопок
function createInlineKeyboard(buttons) {
  return {
    reply_markup: {
      inline_keyboard: buttons
    }
  };
}

// Пример: кнопки подтверждения
const confirmButtons = [
  [
    { text: '✅ Да', callback_data: 'confirm_yes' },
    { text: '❌ Нет', callback_data: 'confirm_no' }
  ],
  [
    { text: '✏️ Изменить', callback_data: 'confirm_edit' }
  ]
];

// Пример: кнопки статусов
const statusButtons = [
  [
    { text: '📋 Собеседование', callback_data: 'status_собеседование' },
    { text: '📝 Оформление', callback_data: 'status_оформление' }
  ],
  [
    { text: '✅ Работает', callback_data: 'status_работает' },
    { text: '❌ Отказ', callback_data: 'status_отказ' }
  ]
];
```

### Прогресс-бар заполнения

```javascript
// Функция генерации прогресс-бара
function createProgressBar(filled, total) {
  const filledBlocks = Math.round((filled / total) * 10);
  const emptyBlocks = 10 - filledBlocks;
  const percentage = Math.round((filled / total) * 100);

  return `[${'█'.repeat(filledBlocks)}${'░'.repeat(emptyBlocks)}] ${percentage}%`;
}

// Функция форматирования статуса полей
function formatFieldsStatus(data, requiredFields) {
  let result = '';
  const fieldLabels = {
    full_name: 'ФИО',
    phone: 'Телефон',
    position: 'Должность',
    object_location: 'Объект',
    age: 'Возраст',
    gender: 'Пол',
    experience: 'Опыт'
  };

  let filled = 0;
  for (const field of requiredFields) {
    const value = data[field];
    const label = fieldLabels[field];
    if (value) {
      result += `✅ ${label}: ${value}\n`;
      filled++;
    } else {
      result += `❌ ${label}: ?\n`;
    }
  }

  return {
    text: result,
    filled,
    total: requiredFields.length,
    progressBar: createProgressBar(filled, requiredFields.length)
  };
}
```

### LLM Кэширование

```javascript
// Code Node: Check LLM Cache
const crypto = require('crypto');

const message = $input.item.json.message.text;
const messageHash = crypto.createHash('md5').update(message).digest('hex');

// Проверяем кэш в Supabase
const cacheResult = await $('Supabase').query(
  `SELECT get_llm_cache('${messageHash}') as cached_result`
);

if (cacheResult && cacheResult.cached_result) {
  return {
    json: {
      fromCache: true,
      result: cacheResult.cached_result,
      messageHash
    }
  };
}

return {
  json: {
    fromCache: false,
    messageHash,
    message
  }
};
```

```javascript
// Code Node: Save to LLM Cache (после успешного LLM запроса)
const messageHash = $input.item.json.messageHash;
const messageText = $input.item.json.message;
const llmResult = $input.item.json.llmResult;

await $('Supabase').query(
  `SELECT set_llm_cache('${messageHash}', $1, $2, 24)`,
  [messageText, JSON.stringify(llmResult)]
);

return $input.item;
```

---

## Workflow 1: Message Router

### Описание
Принимает все входящие сообщения и callback_query из Telegram, определяет тип и направляет на обработку.

### Структура нод (v2.0)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Telegram   │────▶│   Filter    │────▶│  Message    │────▶│  Check      │
│  Trigger    │     │  Groups     │     │  Type       │     │  Redis      │
└─────────────┘     └─────────────┘     └──────┬──────┘     │  State      │
                                               │            └──────┬──────┘
                    ┌──────────────────────────┤                   │
                    ▼                          ▼                   │
             ┌─────────────┐            ┌─────────────┐            │
             │  Callback   │            │  Text       │            │
             │  Handler    │            │  Message    │◀───────────┘
             └──────┬──────┘            └──────┬──────┘
                    │                          │
                    ▼                          ▼
             ┌─────────────┐            ┌─────────────┐
             │  Process    │            │  Classify   │
             │  Button     │            │  Message    │
             │  Click      │            │  (Heuristics│
             └─────────────┘            │  + LLM)     │
                                        └──────┬──────┘
                                               │
              ┌────────────────┬───────────────┼───────────────┬────────────────┐
              ▼                ▼               ▼               ▼                ▼
       ┌─────────────┐  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
       │  Candidate  │  │  Payment    │ │  Command    │ │  Status     │ │  Ignore     │
       │  Webhook    │  │  Webhook    │ │  Handler    │ │  Handler    │ │  (chat)     │
       └─────────────┘  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

### Детальное описание нод

#### 1.1 Telegram Trigger
```yaml
Type: Telegram Trigger
Settings:
  Bot Token: "{{ $env.TELEGRAM_BOT_TOKEN }}"
  Updates: ["message", "callback_query"]  # Добавлены callback_query для inline-кнопок
Output:
  - message | callback_query
```

#### 1.2 Filter Groups (IF Node)
```yaml
Type: IF
Condition:
  - $json.message?.chat?.id == $env.TELEGRAM_CHAT_CANDIDATES
  - OR $json.message?.chat?.id == $env.TELEGRAM_CHAT_PAYMENTS
  - OR $json.callback_query?.message?.chat?.id == $env.TELEGRAM_CHAT_CANDIDATES
  - OR $json.callback_query?.message?.chat?.id == $env.TELEGRAM_CHAT_PAYMENTS
True Branch: Continue
False Branch: Stop
```

#### 1.3 Message Type (Switch Node)
```yaml
Type: Switch
Rules:
  - callback_query exists → Callback Handler
  - message.text starts with "/" → Command Handler
  - Otherwise → Text Message Handler
```

#### 1.4 Callback Handler (Code Node)
```javascript
// Обработка нажатий inline-кнопок
const callback = $input.item.json.callback_query;
const data = callback.data;
const chatId = callback.message.chat.id;
const messageId = callback.message.message_id;
const userId = callback.from.id;
const username = callback.from.username;

// Парсим callback_data
const [action, ...params] = data.split('_');

let result = {
  action,
  params: params.join('_'),
  chatId,
  messageId,
  userId,
  username,
  originalMessage: callback.message
};

// Отвечаем на callback чтобы убрать "часики"
// (делается через отдельную Telegram ноду)

return { json: result };
```

#### 1.5 Process Button Click (Switch Node)
```yaml
Type: Switch
Rules:
  - action == "confirm" → Confirmation Handler
  - action == "status" → Status Change Webhook
  - action == "edit" → Edit Handler
  - action == "cancel" → Cancel Handler
  - action == "duplicate" → Duplicate Handler
  - action == "report" → Report Handler
```

#### 1.6 Command Handler (Code Node)
```javascript
// Обработка команд /report, /status, /export и т.д.
const message = $input.item.json.message;
const text = message.text || '';
const chatId = message.chat.id;

// Парсим команду
const commandMatch = text.match(/^\/(\w+)(?:\s+(.*))?$/);

if (!commandMatch) {
  return { json: { command: null, isCommand: false } };
}

const command = commandMatch[1].toLowerCase();
const args = commandMatch[2] ? commandMatch[2].trim() : '';

return {
  json: {
    isCommand: true,
    command,
    args,
    message,
    chatId,
    userId: message.from.id,
    username: message.from.username
  }
};
```

#### 1.7 Classify Message (Code Node) - ОБНОВЛЕНО
```javascript
// Классификация сообщения с кэшированием
const crypto = require('crypto');
const message = $input.item.json.message;
const text = message.text || '';
const chatId = message.chat.id;

const CHAT_CANDIDATES = parseInt($env.TELEGRAM_CHAT_CANDIDATES);
const CHAT_PAYMENTS = parseInt($env.TELEGRAM_CHAT_PAYMENTS);

// Быстрые проверки команд
if (text.startsWith('/')) {
  return { json: { ...message, classification: { type: 'command' } } };
}

// Эвристики
let candidateScore = 0;
let paymentScore = 0;

// Группа определяет контекст
if (chatId === CHAT_CANDIDATES) {
  candidateScore += 30;
} else if (chatId === CHAT_PAYMENTS) {
  paymentScore += 30;
}

// Проверка на телефон
const phoneRegex = /(\+7|8|7)[\s\-]?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}/;
if (phoneRegex.test(text)) {
  candidateScore += 30;
}

// Проверка на возраст
const ageRegex = /\d{1,2}\s*(лет|год|года)/i;
if (ageRegex.test(text)) {
  candidateScore += 20;
}

// Проверка на дату в начале
const dateRegex = /^\d{1,2}\.\d{1,2}/;
if (dateRegex.test(text.trim())) {
  paymentScore += 40;
}

// Проверка на часы
const hoursRegex = /\d+\s*(час|ч\.|ч\b)/i;
if (hoursRegex.test(text)) {
  paymentScore += 30;
}

// Проверка на структуру "ФИО число"
const lines = text.split('\n');
const employeeLineRegex = /^[А-Яа-яЁё]+\s+[А-Яа-яЁё]*\s*\d+$/;
const hasEmployeeLines = lines.filter(l => employeeLineRegex.test(l.trim())).length >= 1;
if (hasEmployeeLines) {
  paymentScore += 25;
}

// Должности
const positions = ['горничная', 'уборщица', 'охранник', 'администратор',
                   'повар', 'официант', 'бармен', 'кассир', 'продавец',
                   'менеджер', 'водитель'];
const hasPosition = positions.some(p => text.toLowerCase().includes(p));
if (hasPosition) {
  candidateScore += 15;
  paymentScore += 15;
}

// Определяем тип
let messageType = 'chat';
let confidence = 0;
let needsLLM = false;

if (candidateScore > paymentScore && candidateScore >= 40) {
  messageType = 'candidate';
  confidence = Math.min(candidateScore, 100);
} else if (paymentScore > candidateScore && paymentScore >= 40) {
  messageType = 'payment';
  confidence = Math.min(paymentScore, 100);
} else if (candidateScore >= 30 || paymentScore >= 30) {
  messageType = 'uncertain';
  confidence = Math.max(candidateScore, paymentScore);
  needsLLM = true;
}

// Генерируем хэш для кэширования LLM
const messageHash = crypto.createHash('md5').update(text).digest('hex');

return {
  json: {
    ...message,
    classification: {
      type: messageType,
      confidence,
      candidateScore,
      paymentScore,
      needsLLM,
      messageHash
    }
  }
};
```

---

## Workflow 2: Candidate Processor (v2.0)

### Описание
Обрабатывает данные кандидатов с:
- LLM кэшированием
- Проверкой дубликатов
- Прогресс-баром заполнения
- Inline-кнопками подтверждения

### Структура нод (v2.0)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Webhook    │────▶│  Get Redis  │────▶│  Check LLM  │────▶│  LLM Parse  │
│  Trigger    │     │  State      │     │  Cache      │     │  or Cache   │
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
                                                                   │
                                                                   ▼
                                                            ┌─────────────┐
                                                            │  Check      │
                                                            │  Duplicates │
                                                            └──────┬──────┘
                                                                   │
                                              ┌────────────────────┼────────────────────┐
                                              ▼                    ▼                    ▼
                                       ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
                                       │  Has        │      │  Complete   │      │  Incomplete │
                                       │  Duplicate  │      │  Data       │      │  Data       │
                                       └──────┬──────┘      └──────┬──────┘      └──────┬──────┘
                                              │                    │                    │
                                              ▼                    ▼                    ▼
                                       ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
                                       │  Telegram   │      │  Telegram   │      │  Telegram   │
                                       │  Ask        │      │  Confirm    │      │  Ask More   │
                                       │  Duplicate  │      │  Preview    │      │  + Progress │
                                       │  (buttons)  │      │  (buttons)  │      │  (buttons)  │
                                       └─────────────┘      └─────────────┘      └─────────────┘
```

### Детальное описание нод

#### 2.1 Check LLM Cache (Code Node)
```javascript
const crypto = require('crypto');
const message = $input.item.json.message;
const context = $input.item.json.context;

// Генерируем ключ кэша на основе сообщения + контекста
const cacheKey = JSON.stringify({
  text: message.text,
  existingData: context.collectedData
});
const messageHash = crypto.createHash('md5').update(cacheKey).digest('hex');

return {
  json: {
    message,
    context,
    messageHash,
    checkCache: true
  }
};
```

#### 2.2 Supabase Check Cache
```yaml
Type: Supabase
Operation: RPC
Function: get_llm_cache
Parameters:
  p_message_hash: "{{ $json.messageHash }}"
```

#### 2.3 LLM or Cache (IF + Merge)
```yaml
Type: IF
Condition: $json.cached_result != null
True: Use cached result
False: Call DeepSeek API
```

#### 2.4 DeepSeek Parse (HTTP Request) - ОБНОВЛЕНО
```yaml
Type: HTTP Request
Method: POST
URL: "https://api.deepseek.com/v1/chat/completions"
Headers:
  Authorization: "Bearer {{ $env.DEEPSEEK_API_KEY }}"
Body:
  model: "deepseek-chat"
  temperature: 0.1
  max_tokens: 500
  response_format:
    type: "json_object"
  messages:
    - role: "system"
      content: |
        Ты — HR-ассистент. Извлеки данные кандидата из сообщения.

        Ранее собранные данные:
        {{ JSON.stringify($json.context.collectedData) }}

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

        ОБЯЗАТЕЛЬНЫЕ поля: full_name, phone, position, object_location
        Телефон нормализуй к формату 79XXXXXXXXX
    - role: "user"
      content: "{{ $json.message.text }}"
```

#### 2.5 Save to LLM Cache (Supabase RPC)
```yaml
Type: Supabase
Operation: RPC
Function: set_llm_cache
Parameters:
  p_message_hash: "{{ $json.messageHash }}"
  p_message_text: "{{ $json.message.text }}"
  p_result: "{{ $json.llmResult }}"
  p_ttl_hours: 24
```

#### 2.6 Check Duplicates (Supabase RPC)
```yaml
Type: Supabase
Operation: RPC
Function: find_candidate_duplicates
Parameters:
  p_phone: "{{ $json.collectedData.phone }}"
  p_full_name: "{{ $json.collectedData.full_name }}"
  p_days_back: 30
```

#### 2.7 Process Duplicates (Code Node)
```javascript
const input = $input.item.json;
const duplicates = input.duplicates || [];
const collectedData = input.collectedData;
const message = input.message;

// Если нашли дубликаты с высоким совпадением
const highMatchDuplicates = duplicates.filter(d => d.similarity_score >= 90);

if (highMatchDuplicates.length > 0) {
  const dup = highMatchDuplicates[0];

  return {
    json: {
      hasDuplicate: true,
      duplicate: dup,
      collectedData,
      message,
      // Кнопки для пользователя
      keyboard: {
        inline_keyboard: [
          [
            { text: '➕ Добавить как новый', callback_data: `duplicate_add_${dup.id}` },
            { text: '🔗 Обновить существующий', callback_data: `duplicate_update_${dup.id}` }
          ],
          [
            { text: '❌ Отмена', callback_data: 'duplicate_cancel' }
          ]
        ]
      },
      duplicateMessage: `⚠️ Найден похожий кандидат (совпадение ${dup.similarity_score}%):\n\n` +
        `👤 ${dup.full_name}\n` +
        `📞 ${dup.phone}\n` +
        `💼 ${dup.position}\n` +
        `📍 ${dup.object_location}\n` +
        `📊 Статус: ${dup.status}\n` +
        `📅 Добавлен: ${new Date(dup.created_at).toLocaleDateString('ru-RU')}\n\n` +
        `Что сделать?`
    }
  };
}

return {
  json: {
    hasDuplicate: false,
    collectedData,
    message
  }
};
```

#### 2.8 Build Progress Message (Code Node)
```javascript
const input = $input.item.json;
const data = input.collectedData;
const isComplete = input.isComplete;
const missingFields = input.missingFields || [];

const requiredFields = ['full_name', 'phone', 'position', 'object_location'];
const optionalFields = ['age', 'gender', 'experience'];

const fieldLabels = {
  full_name: 'ФИО',
  phone: 'Телефон',
  position: 'Должность',
  object_location: 'Объект',
  age: 'Возраст',
  gender: 'Пол',
  experience: 'Опыт'
};

// Считаем заполненность
let filledRequired = 0;
let totalRequired = requiredFields.length;

let statusText = '📋 *Данные кандидата*\n\n';

// Обязательные поля
statusText += '*Обязательные:*\n';
for (const field of requiredFields) {
  const value = data[field];
  if (value) {
    statusText += `✅ ${fieldLabels[field]}: ${value}\n`;
    filledRequired++;
  } else {
    statusText += `❌ ${fieldLabels[field]}: _не указано_\n`;
  }
}

// Опциональные поля
statusText += '\n*Дополнительные:*\n';
for (const field of optionalFields) {
  const value = data[field];
  if (value) {
    statusText += `✅ ${fieldLabels[field]}: ${value}\n`;
  } else {
    statusText += `⬜ ${fieldLabels[field]}: _не указано_\n`;
  }
}

// Прогресс-бар
const progress = Math.round((filledRequired / totalRequired) * 100);
const filledBlocks = Math.round(progress / 10);
const progressBar = '█'.repeat(filledBlocks) + '░'.repeat(10 - filledBlocks);
statusText += `\n📊 Заполнено: [${progressBar}] ${progress}%`;

// Кнопки
let keyboard;
if (isComplete) {
  keyboard = {
    inline_keyboard: [
      [
        { text: '✅ Сохранить', callback_data: 'confirm_yes' },
        { text: '✏️ Изменить', callback_data: 'confirm_edit' }
      ],
      [
        { text: '❌ Отмена', callback_data: 'confirm_cancel' }
      ]
    ]
  };
} else {
  // Кнопки для недостающих полей
  const fieldButtons = missingFields.slice(0, 4).map(field => ({
    text: `➕ ${field}`,
    callback_data: `add_field_${field.toLowerCase()}`
  }));

  keyboard = {
    inline_keyboard: [
      fieldButtons.slice(0, 2),
      fieldButtons.slice(2, 4),
      [{ text: '❌ Отмена', callback_data: 'confirm_cancel' }]
    ].filter(row => row.length > 0)
  };
}

return {
  json: {
    ...input,
    statusText,
    keyboard,
    progress,
    clarificationQuestion: input.clarificationQuestion
  }
};
```

#### 2.9 Telegram Ask More with Progress
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $json.message.chat.id }}"
Text: |
  {{ $json.statusText }}

  {{ $json.clarificationQuestion }}
Parse Mode: Markdown
Reply Markup: "{{ JSON.stringify($json.keyboard) }}"
Reply To Message ID: "{{ $json.message.message_id }}"
```

#### 2.10 Telegram Confirm Preview (Complete branch)
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $json.message.chat.id }}"
Text: |
  {{ $json.statusText }}

  ✅ Все обязательные поля заполнены!
  Проверьте данные и подтвердите сохранение.
Parse Mode: Markdown
Reply Markup: "{{ JSON.stringify($json.keyboard) }}"
```

#### 2.11 Supabase Insert (после подтверждения)
```yaml
Type: Supabase
Operation: Insert
Table: candidates
Row:
  full_name: "{{ $json.collectedData.full_name }}"
  age: "{{ $json.collectedData.age }}"
  gender: "{{ $json.collectedData.gender }}"
  position: "{{ $json.collectedData.position }}"
  experience: "{{ $json.collectedData.experience }}"
  phone: "{{ $json.collectedData.phone }}"
  object_location: "{{ $json.collectedData.object_location }}"
  status: "направлен"
  telegram_user_id: "{{ $json.message.from.id }}"
  telegram_username: "{{ $json.message.from.username }}"
  telegram_chat_id: "{{ $json.message.chat.id }}"
  telegram_message_id: "{{ $json.message.message_id }}"
```

#### 2.12 Telegram Final Confirm
```yaml
Type: Telegram
Operation: Edit Message Text  # Редактируем сообщение с превью
Chat ID: "{{ $json.message.chat.id }}"
Message ID: "{{ $json.confirmMessageId }}"
Text: |
  ✅ *Кандидат добавлен!*

  👤 {{ $json.collectedData.full_name }}
  📞 {{ $json.collectedData.phone }}
  💼 {{ $json.collectedData.position }}
  📍 {{ $json.collectedData.object_location }}
  📊 Статус: направлен

  ID: `{{ $json.insertedId }}`
Parse Mode: Markdown
Reply Markup: |
  {
    "inline_keyboard": [
      [
        { "text": "📋 Изменить статус", "callback_data": "status_change_{{ $json.insertedId }}" }
      ]
    ]
  }
```

---

## Workflow 3: Payment Processor (v2.0)

### Описание
Обрабатывает данные об оплате с:
- Batch insert (одним запросом)
- Автоматической линковкой с кандидатами
- Inline-кнопками подтверждения

### Batch Processing (Code Node)
```javascript
// Подготовка batch insert для всех сотрудников
const input = $input.item.json;
const parsed = input.parsed;
const message = input.message;

// Формируем массив записей для batch insert
const records = parsed.employees.map(emp => ({
  work_date: parsed.workDate,
  object_location: parsed.objectLocation,
  position: parsed.position,
  full_name: emp.fullName,
  hours: emp.hours,
  telegram_user_id: message.from.id,
  telegram_username: message.from.username,
  telegram_chat_id: message.chat.id,
  telegram_message_id: message.message_id
}));

return {
  json: {
    records,
    summary: {
      date: parsed.workDate,
      object: parsed.objectLocation,
      position: parsed.position,
      employeesCount: records.length,
      totalHours: records.reduce((sum, r) => sum + r.hours, 0)
    },
    message
  }
};
```

### Supabase Batch Insert
```yaml
Type: Supabase
Operation: Insert
Table: payments
Rows: "{{ $json.records }}"  # Массив записей
```

### Link Payments to Candidates (Supabase RPC)
```yaml
Type: Supabase
Operation: RPC
Function: link_all_unlinked_payments
# Вызывается после batch insert
```

### Telegram Confirm with Summary
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $json.message.chat.id }}"
Text: |
  ✅ *Оплата записана*

  📅 Дата: {{ $json.summary.date }}
  📍 Объект: {{ $json.summary.object }}
  💼 Должность: {{ $json.summary.position }}

  👥 Сотрудников: {{ $json.summary.employeesCount }}
  ⏱ Всего часов: {{ $json.summary.totalHours }}

  _Записи автоматически связаны с кандидатами (если найдены)_
Parse Mode: Markdown
Reply To Message ID: "{{ $json.message.message_id }}"
```

---

## Workflow 5: Custom Reports

### Описание
Обработка команд для генерации кастомных отчётов.

### Поддерживаемые команды
```
/report today          - Отчёт за сегодня
/report week           - Отчёт за неделю
/report month          - Отчёт за месяц
/report 01.01-31.01    - Отчёт за период
/stats                 - Статистика воронки
/stats recruiters      - Статистика по рекрутерам
/export candidates     - Экспорт кандидатов в Excel
/export payments week  - Экспорт оплат за неделю
```

### Структура нод

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Command    │────▶│  Parse      │────▶│  Switch by  │
│  Trigger    │     │  Command    │     │  Command    │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
         ┌─────────────┬───────────────┬───────┴───────┬─────────────┐
         ▼             ▼               ▼               ▼             ▼
  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
  │  Report     │ │  Stats      │ │  Export     │ │  Status     │ │  Unknown    │
  │  Handler    │ │  Handler    │ │  Handler    │ │  Handler    │ │  Command    │
  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

### Parse Command (Code Node)
```javascript
const input = $input.item.json;
const command = input.command;
const args = input.args;

let result = {
  command,
  reportType: null,
  startDate: null,
  endDate: null,
  groupBy: null,
  exportFormat: 'text'
};

// Парсим аргументы
const today = new Date();
const formatDate = (d) => d.toISOString().split('T')[0];

switch (command) {
  case 'report':
    if (args === 'today' || !args) {
      result.reportType = 'candidates';
      result.startDate = formatDate(today);
      result.endDate = formatDate(today);
    } else if (args === 'week') {
      const weekAgo = new Date(today);
      weekAgo.setDate(weekAgo.getDate() - 7);
      result.reportType = 'candidates';
      result.startDate = formatDate(weekAgo);
      result.endDate = formatDate(today);
    } else if (args === 'month') {
      const monthAgo = new Date(today);
      monthAgo.setMonth(monthAgo.getMonth() - 1);
      result.reportType = 'candidates';
      result.startDate = formatDate(monthAgo);
      result.endDate = formatDate(today);
    } else {
      // Парсим диапазон дат dd.mm-dd.mm
      const dateRangeMatch = args.match(/(\d{1,2})\.(\d{1,2})-(\d{1,2})\.(\d{1,2})/);
      if (dateRangeMatch) {
        const year = today.getFullYear();
        result.reportType = 'candidates';
        result.startDate = `${year}-${dateRangeMatch[2].padStart(2,'0')}-${dateRangeMatch[1].padStart(2,'0')}`;
        result.endDate = `${year}-${dateRangeMatch[4].padStart(2,'0')}-${dateRangeMatch[3].padStart(2,'0')}`;
      }
    }
    break;

  case 'stats':
    result.reportType = args === 'recruiters' ? 'recruiter_stats' : 'funnel_stats';
    result.startDate = formatDate(new Date(today.setDate(today.getDate() - 30)));
    result.endDate = formatDate(new Date());
    break;

  case 'export':
    result.exportFormat = 'excel';
    const exportParts = args.split(' ');
    result.reportType = exportParts[0] || 'candidates';
    if (exportParts[1] === 'week') {
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      result.startDate = formatDate(weekAgo);
      result.endDate = formatDate(new Date());
    } else {
      result.startDate = formatDate(new Date(today.setDate(today.getDate() - 30)));
      result.endDate = formatDate(new Date());
    }
    break;
}

return { json: { ...input, ...result } };
```

### Report Handler (Code Node)
```javascript
const input = $input.item.json;
const candidates = input.queryResult || [];
const startDate = input.startDate;
const endDate = input.endDate;

const formatDateRu = (dateStr) => {
  const d = new Date(dateStr);
  return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' });
};

let report = `📊 *Отчёт по кандидатам*\n`;
report += `📅 Период: ${formatDateRu(startDate)} — ${formatDateRu(endDate)}\n\n`;

if (candidates.length === 0) {
  report += `_Кандидатов за указанный период не найдено._`;
} else {
  // Группировка по статусам
  const byStatus = {};
  candidates.forEach(c => {
    if (!byStatus[c.status]) byStatus[c.status] = [];
    byStatus[c.status].push(c);
  });

  report += `👥 Всего: ${candidates.length}\n\n`;

  // Статистика по статусам
  const statusEmoji = {
    'направлен': '📋',
    'собеседование': '🗣',
    'оформление': '📝',
    'работает': '✅',
    'отказ': '❌',
    'архив': '📦'
  };

  for (const [status, list] of Object.entries(byStatus)) {
    report += `${statusEmoji[status] || '•'} ${status}: ${list.length}\n`;
  }

  report += `\n*Последние 10 добавленных:*\n`;

  candidates.slice(0, 10).forEach((c, i) => {
    report += `\n${i + 1}. *${c.full_name}*\n`;
    report += `   📞 ${c.phone}\n`;
    report += `   💼 ${c.position} | 📍 ${c.object_location}\n`;
    report += `   📊 ${c.status}\n`;
  });

  if (candidates.length > 10) {
    report += `\n_...и ещё ${candidates.length - 10} кандидат(ов)_`;
  }
}

// Кнопки для дополнительных действий
const keyboard = {
  inline_keyboard: [
    [
      { text: '📥 Экспорт в Excel', callback_data: `export_candidates_${startDate}_${endDate}` }
    ],
    [
      { text: '📊 Статистика воронки', callback_data: 'report_funnel' },
      { text: '👥 По рекрутерам', callback_data: 'report_recruiters' }
    ]
  ]
};

return {
  json: {
    report,
    keyboard,
    chatId: input.chatId
  }
};
```

### Stats Handler - Funnel (Code Node)
```javascript
const input = $input.item.json;
const stats = input.funnelStats || [];

let report = `📊 *Воронка найма*\n`;
report += `📅 Последние 30 дней\n\n`;

const statusEmoji = {
  'направлен': '📋',
  'собеседование': '🗣',
  'оформление': '📝',
  'работает': '✅',
  'отказ': '❌',
  'архив': '📦'
};

const total = stats.reduce((sum, s) => sum + parseInt(s.count), 0);

stats.forEach(s => {
  const emoji = statusEmoji[s.status] || '•';
  const bar = '█'.repeat(Math.round(s.percentage / 5));
  report += `${emoji} *${s.status}*: ${s.count} (${s.percentage}%)\n`;
  report += `   ${bar}\n\n`;
});

report += `\n📈 *Конверсия:*\n`;
const hired = stats.find(s => s.status === 'работает')?.count || 0;
const conversionRate = total > 0 ? Math.round((hired / total) * 100) : 0;
report += `Направлен → Работает: ${conversionRate}%`;

return {
  json: {
    report,
    chatId: input.chatId
  }
};
```

### Recruiter Stats Handler (Code Node)
```javascript
const input = $input.item.json;
const stats = input.recruiterStats || [];

let report = `👥 *Статистика по рекрутерам*\n`;
report += `📅 Последние 30 дней\n\n`;

if (stats.length === 0) {
  report += `_Данных нет._`;
} else {
  stats.forEach((r, i) => {
    const medal = i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : `${i + 1}.`;
    report += `${medal} @${r.telegram_username || 'Unknown'}\n`;
    report += `   📋 Добавлено: ${r.total_candidates}\n`;
    report += `   ✅ Трудоустроено: ${r.hired_count}\n`;
    report += `   📈 Конверсия: ${r.conversion_rate}%\n\n`;
  });
}

return {
  json: {
    report,
    chatId: input.chatId
  }
};
```

---

## Workflow 6: Excel Export

### Описание
Генерация и отправка Excel-файлов.

### Generate Excel (Code Node)
```javascript
// Используем библиотеку xlsx (нужно установить в n8n)
const XLSX = require('xlsx');

const input = $input.item.json;
const data = input.exportData;
const reportType = input.reportType;

// Подготавливаем данные для Excel
let worksheetData = [];
let filename = '';

if (reportType === 'candidates') {
  filename = `candidates_${input.startDate}_${input.endDate}.xlsx`;

  // Заголовки
  worksheetData.push([
    'ФИО', 'Телефон', 'Должность', 'Объект', 'Статус',
    'Возраст', 'Пол', 'Опыт', 'Рекрутер', 'Дата добавления'
  ]);

  // Данные
  data.forEach(c => {
    worksheetData.push([
      c.full_name,
      c.phone,
      c.position,
      c.object_location,
      c.status,
      c.age || '',
      c.gender || '',
      c.experience || '',
      c.telegram_username || '',
      new Date(c.created_at).toLocaleDateString('ru-RU')
    ]);
  });
} else if (reportType === 'payments') {
  filename = `payments_${input.startDate}_${input.endDate}.xlsx`;

  worksheetData.push([
    'Дата', 'Объект', 'Должность', 'ФИО', 'Часы', 'Рекрутер', 'Дата записи'
  ]);

  data.forEach(p => {
    worksheetData.push([
      p.work_date,
      p.object_location,
      p.position,
      p.full_name,
      p.hours,
      p.telegram_username || '',
      new Date(p.created_at).toLocaleDateString('ru-RU')
    ]);
  });
}

// Создаём workbook
const ws = XLSX.utils.aoa_to_sheet(worksheetData);
const wb = XLSX.utils.book_new();
XLSX.utils.book_append_sheet(wb, ws, 'Data');

// Генерируем buffer
const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });

return {
  json: {
    filename,
    chatId: input.chatId
  },
  binary: {
    data: buffer
  }
};
```

### Telegram Send Document
```yaml
Type: Telegram
Operation: Send Document
Chat ID: "{{ $json.chatId }}"
Document: Binary data from previous node
Filename: "{{ $json.filename }}"
Caption: "📥 Экспорт данных готов!"
```

---

## Workflow 7: Admin Notifications

### Описание
Периодическая проверка и отправка уведомлений администратору.

### Структура нод

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Schedule   │────▶│  Supabase   │────▶│  Format     │────▶│  Telegram   │
│  Every 5min │     │  Get        │     │  Messages   │     │  Send to    │
└─────────────┘     │  Pending    │     └─────────────┘     │  Admin      │
                    └─────────────┘                         └─────────────┘
                                                                   │
                                                                   ▼
                                                            ┌─────────────┐
                                                            │  Mark as    │
                                                            │  Sent       │
                                                            └─────────────┘
```

### Schedule Trigger
```yaml
Type: Schedule Trigger
Rule: "*/5 * * * *"  # Каждые 5 минут
```

### Supabase Get Pending Notifications
```yaml
Type: Supabase
Operation: RPC
Function: get_pending_notifications
Parameters:
  p_limit: 10
```

### Format Messages (Code Node)
```javascript
const notifications = $input.all();

if (notifications.length === 0) {
  return []; // Нет уведомлений - workflow останавливается
}

const levelEmoji = {
  'info': 'ℹ️',
  'warning': '⚠️',
  'error': '❌',
  'critical': '🚨'
};

return notifications.map(n => {
  const item = n.json;
  const emoji = levelEmoji[item.level] || 'ℹ️';

  let message = `${emoji} *${item.title}*\n\n`;
  message += item.message;

  if (item.source) {
    message += `\n\n_Источник: ${item.source}_`;
  }

  message += `\n_${new Date(item.created_at).toLocaleString('ru-RU')}_`;

  return {
    json: {
      id: item.id,
      message,
      level: item.level
    }
  };
});
```

### Telegram Send to Admin
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $env.TELEGRAM_ADMIN_CHAT_ID }}"
Text: "{{ $json.message }}"
Parse Mode: Markdown
```

### Mark as Sent (Supabase)
```yaml
Type: Supabase
Operation: Update
Table: admin_notifications
Filter: id = {{ $json.id }}
Data:
  is_sent: true
  sent_at: NOW()
  sent_to_chat_id: {{ $env.TELEGRAM_ADMIN_CHAT_ID }}
```

---

## Workflow 8: Maintenance

### Описание
Ежечасные задачи обслуживания:
- Очистка устаревших данных
- Связывание payments с candidates
- Очистка LLM кэша
- Очистка Redis

### Структура нод

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Schedule   │────▶│  Cleanup    │────▶│  Link       │────▶│  Log        │
│  Hourly     │     │  Old Data   │     │  Payments   │     │  Results    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### Cleanup Old Data (Supabase RPC)
```yaml
Type: Supabase
Operation: RPC
Function: cleanup_old_data
Parameters:
  p_audit_days: 90
  p_logs_days: 30
  p_cache_days: 7
```

### Link Payments (Supabase RPC)
```yaml
Type: Supabase
Operation: RPC
Function: link_all_unlinked_payments
```

### Log Results (Code Node)
```javascript
const cleanupResult = $('Cleanup Old Data').item.json;
const linkResult = $('Link Payments').item.json;

const summary = {
  timestamp: new Date().toISOString(),
  cleanup: cleanupResult,
  linkedPayments: linkResult
};

// Если много удалено или связано - отправить уведомление админу
const significantCleanup = cleanupResult.some(r => r.deleted_count > 100);
const significantLinks = linkResult > 10;

if (significantCleanup || significantLinks) {
  // Создаём уведомление админу
  return {
    json: {
      ...summary,
      createNotification: true,
      notificationTitle: 'Результаты обслуживания',
      notificationMessage: `Очистка: ${JSON.stringify(cleanupResult)}\nСвязано оплат: ${linkResult}`
    }
  };
}

return { json: summary };
```

---

## Переменные окружения (v2.0)

```bash
# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_CANDIDATES=-1001234567890
TELEGRAM_CHAT_PAYMENTS=-1001234567891
TELEGRAM_ADMIN_CHAT_ID=123456789  # Личный чат или группа админов

# DeepSeek
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
DEEPSEEK_API_URL=https://api.deepseek.com/v1

# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJxxxxxxxxx

# Redis
REDIS_URL=redis://localhost:6379
```

---

## Тестирование (v2.0)

### Новые тестовые сценарии

#### Тест: Проверка дубликатов
```
1. Добавить кандидата: "Иванов Петр, охранник, 89161234567, ТЦ Мега"
2. Попытаться добавить: "Иванов П., охранник, 8-916-123-45-67, Мега"
3. Ожидание: бот предупредит о дубликате с кнопками выбора
```

#### Тест: Inline-кнопки
```
1. Добавить неполные данные: "Мария Петрова, администратор"
2. Ожидание: сообщение с прогресс-баром и кнопками полей
3. Нажать кнопку "➕ Телефон"
4. Ожидание: бот попросит ввести телефон
```

#### Тест: Кастомные отчёты
```
/report today     → Отчёт за сегодня
/report week      → Отчёт за неделю
/stats            → Воронка найма
/export candidates → Excel-файл
```

#### Тест: Статус кандидата
```
/status Иванов собеседование
→ Ожидание: статус изменён, история записана
```

# Спецификация n8n Workflows

## Обзор

| # | Workflow | Триггер | Описание |
|---|----------|---------|----------|
| 1 | HR Bot - Message Router | Telegram Trigger | Приём и маршрутизация сообщений |
| 2 | HR Bot - Candidate Processor | Webhook (internal) | Обработка данных кандидатов |
| 3 | HR Bot - Payment Processor | Webhook (internal) | Обработка данных оплаты |
| 4 | HR Bot - Daily Report | Schedule (22:00 MSK) | Ежедневный отчёт |
| 5 | HR Bot - State Cleanup | Schedule (hourly) | Очистка устаревших состояний |

---

## Workflow 1: Message Router

### Описание
Принимает все входящие сообщения из Telegram, определяет тип и направляет на обработку.

### Структура нод

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Telegram   │────▶│   Filter    │────▶│  Check      │
│  Trigger    │     │  Groups     │     │  Redis      │
└─────────────┘     └─────────────┘     │  State      │
                                        └──────┬──────┘
                                               │
                          ┌────────────────────┴────────────────────┐
                          ▼                                         ▼
                   ┌─────────────┐                           ┌─────────────┐
                   │  Has Active │                           │  No Active  │
                   │  Dialog     │                           │  Dialog     │
                   └──────┬──────┘                           └──────┬──────┘
                          │                                         │
                          ▼                                         ▼
                   ┌─────────────┐                           ┌─────────────┐
                   │  Route to   │                           │  Classify   │
                   │  Handler    │                           │  Message    │
                   └─────────────┘                           └──────┬──────┘
                                                                    │
                                              ┌─────────────────────┼─────────────────────┐
                                              ▼                     ▼                     ▼
                                       ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
                                       │  Candidate  │       │  Payment    │       │  Ignore     │
                                       │  Webhook    │       │  Webhook    │       │  (chat)     │
                                       └─────────────┘       └─────────────┘       └─────────────┘
```

### Детальное описание нод

#### 1.1 Telegram Trigger
```yaml
Type: Telegram Trigger
Settings:
  Bot Token: "{{ $env.TELEGRAM_BOT_TOKEN }}"
  Updates: ["message"]
Output:
  - message.chat.id
  - message.from.id
  - message.from.username
  - message.text
  - message.message_id
```

#### 1.2 Filter Groups (IF Node)
```yaml
Type: IF
Condition:
  - message.chat.id == $env.TELEGRAM_CHAT_CANDIDATES
  - OR message.chat.id == $env.TELEGRAM_CHAT_PAYMENTS
True Branch: Continue
False Branch: Stop (ignore messages from other chats)
```

#### 1.3 Check Redis State
```yaml
Type: Redis
Operation: Get
Key: "dialog:{{ $json.message.chat.id }}:{{ $json.message.from.id }}"
Output:
  - state (JSON or null)
```

#### 1.4 Has Active Dialog (IF Node)
```yaml
Type: IF
Condition: $json.state != null
True Branch: Route to existing handler
False Branch: Classify new message
```

#### 1.5 Classify Message (Code Node)
```javascript
// Классификация сообщения на основе эвристик
const message = $input.item.json.message;
const text = message.text || '';
const chatId = message.chat.id;

const CHAT_CANDIDATES = parseInt($env.TELEGRAM_CHAT_CANDIDATES);
const CHAT_PAYMENTS = parseInt($env.TELEGRAM_CHAT_PAYMENTS);

// Эвристики
let candidateScore = 0;
let paymentScore = 0;

// Группа уже определяет контекст
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

// Проверка на возраст ("лет", "год")
const ageRegex = /\d{1,2}\s*(лет|год|года)/i;
if (ageRegex.test(text)) {
  candidateScore += 20;
}

// Проверка на дату в начале (dd.mm)
const dateRegex = /^\d{1,2}\.\d{1,2}/;
if (dateRegex.test(text.trim())) {
  paymentScore += 40;
}

// Проверка на часы
const hoursRegex = /\d+\s*(час|ч\.|ч\b)/i;
if (hoursRegex.test(text)) {
  paymentScore += 30;
}

// Проверка на структуру "ФИО число" в строках
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
let messageType = 'chat'; // по умолчанию игнорируем
let confidence = 0;

if (candidateScore > paymentScore && candidateScore >= 40) {
  messageType = 'candidate';
  confidence = Math.min(candidateScore, 100);
} else if (paymentScore > candidateScore && paymentScore >= 40) {
  messageType = 'payment';
  confidence = Math.min(paymentScore, 100);
} else if (candidateScore >= 30 || paymentScore >= 30) {
  // Низкая уверенность - нужен LLM
  messageType = 'uncertain';
  confidence = Math.max(candidateScore, paymentScore);
}

return {
  json: {
    ...message,
    classification: {
      type: messageType,
      confidence: confidence,
      candidateScore: candidateScore,
      paymentScore: paymentScore,
      needsLLM: messageType === 'uncertain'
    }
  }
};
```

#### 1.6 LLM Classification (HTTP Request - если needsLLM)
```yaml
Type: HTTP Request
Method: POST
URL: "https://api.deepseek.com/v1/chat/completions"
Headers:
  Authorization: "Bearer {{ $env.DEEPSEEK_API_KEY }}"
  Content-Type: "application/json"
Body:
  model: "deepseek-chat"
  temperature: 0.1
  max_tokens: 100
  messages:
    - role: "system"
      content: |
        Классифицируй сообщение из HR-группы.
        Ответь ТОЛЬКО одним словом: candidate, payment, или chat.

        candidate - информация о новом кандидате на работу (ФИО, возраст, телефон, должность)
        payment - данные об отработанных часах сотрудников (дата, объект, часы)
        chat - обычное сообщение, не относящееся к HR-данным
    - role: "user"
      content: "{{ $json.text }}"
```

#### 1.7 Route to Handler (Switch Node)
```yaml
Type: Switch
Rules:
  - Value: "{{ $json.classification.type }}"
    Outputs:
      "candidate": → Candidate Webhook
      "payment": → Payment Webhook
      "chat": → No Operation (ignore)
```

#### 1.8 Candidate/Payment Webhooks
```yaml
Type: HTTP Request
Method: POST
URL: "http://localhost:5678/webhook/candidate-processor" # или payment-processor
Body: Full message JSON + classification
```

---

## Workflow 2: Candidate Processor

### Описание
Обрабатывает данные кандидатов, использует LLM для извлечения полей.

### Структура нод

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Webhook    │────▶│  Get Redis  │────▶│  Merge      │────▶│  DeepSeek   │
│  Trigger    │     │  State      │     │  Context    │     │  Parse      │
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
                                                                   │
                                              ┌────────────────────┴────────────────────┐
                                              ▼                                         ▼
                                       ┌─────────────┐                           ┌─────────────┐
                                       │  Complete   │                           │  Incomplete │
                                       │  Data       │                           │  Data       │
                                       └──────┬──────┘                           └──────┬──────┘
                                              │                                         │
                                              ▼                                         ▼
                                       ┌─────────────┐                           ┌─────────────┐
                                       │  Supabase   │                           │  Save to    │
                                       │  Insert     │                           │  Redis      │
                                       └──────┬──────┘                           └──────┬──────┘
                                              │                                         │
                                              ▼                                         ▼
                                       ┌─────────────┐                           ┌─────────────┐
                                       │  Clear      │                           │  Telegram   │
                                       │  Redis      │                           │  Ask More   │
                                       └──────┬──────┘                           └─────────────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │  Telegram   │
                                       │  Confirm    │
                                       └─────────────┘
```

### Детальное описание нод

#### 2.1 Webhook Trigger
```yaml
Type: Webhook
Method: POST
Path: /candidate-processor
Authentication: None (internal only)
```

#### 2.2 Get Redis State
```yaml
Type: Redis
Operation: Get
Key: "dialog:{{ $json.chat.id }}:{{ $json.from.id }}"
```

#### 2.3 Merge Context (Code Node)
```javascript
const message = $input.item.json;
const existingState = $('Get Redis State').item?.json || null;

let context = {
  messages: [],
  collectedData: {
    full_name: null,
    age: null,
    gender: null,
    position: null,
    experience: null,
    phone: null,
    object_location: null
  }
};

if (existingState && existingState.value) {
  const state = JSON.parse(existingState.value);
  context = state;
}

// Добавляем новое сообщение
context.messages.push({
  role: 'user',
  content: message.text,
  timestamp: new Date().toISOString()
});

return {
  json: {
    message: message,
    context: context
  }
};
```

#### 2.4 DeepSeek Parse (HTTP Request)
```yaml
Type: HTTP Request
Method: POST
URL: "https://api.deepseek.com/v1/chat/completions"
Headers:
  Authorization: "Bearer {{ $env.DEEPSEEK_API_KEY }}"
  Content-Type: "application/json"
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

        История диалога:
        {{ $json.context.messages.map(m => m.role + ': ' + m.content).join('\n') }}

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
        - Объединяй новые данные с ранее собранными
        - Телефон нормализуй к формату 79XXXXXXXXX (убери +, 8, пробелы, скобки)
        - Пол определяй по имени, если явно не указан
        - Возраст может быть указан словами ("тридцать пять" → 35)
        - is_complete = true только если есть: full_name, phone, position, object_location
        - Если данных недостаточно, сформулируй краткий вопрос на русском в clarification_question
        - missing_fields должен содержать названия полей на русском: "ФИО", "телефон", "должность", "объект"
    - role: "user"
      content: "{{ $json.message.text }}"
```

#### 2.5 Process LLM Response (Code Node)
```javascript
const input = $input.item.json;
const message = input.message;
const llmResponse = JSON.parse($('DeepSeek Parse').item.json.choices[0].message.content);

// Обновляем собранные данные
const collectedData = {
  full_name: llmResponse.full_name || input.context.collectedData.full_name,
  age: llmResponse.age || input.context.collectedData.age,
  gender: llmResponse.gender || input.context.collectedData.gender,
  position: llmResponse.position || input.context.collectedData.position,
  experience: llmResponse.experience || input.context.collectedData.experience,
  phone: llmResponse.phone || input.context.collectedData.phone,
  object_location: llmResponse.object_location || input.context.collectedData.object_location
};

return {
  json: {
    message: message,
    collectedData: collectedData,
    isComplete: llmResponse.is_complete,
    missingFields: llmResponse.missing_fields || [],
    clarificationQuestion: llmResponse.clarification_question,
    context: {
      ...input.context,
      collectedData: collectedData
    }
  }
};
```

#### 2.6 Is Complete (IF Node)
```yaml
Type: IF
Condition: $json.isComplete == true
True Branch: → Supabase Insert
False Branch: → Save to Redis & Ask More
```

#### 2.7 Supabase Insert (Complete branch)
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
  telegram_user_id: "{{ $json.message.from.id }}"
  telegram_username: "{{ $json.message.from.username }}"
  telegram_chat_id: "{{ $json.message.chat.id }}"
  telegram_message_id: "{{ $json.message.message_id }}"
```

#### 2.8 Clear Redis (Complete branch)
```yaml
Type: Redis
Operation: Delete
Key: "dialog:{{ $json.message.chat.id }}:{{ $json.message.from.id }}"
```

#### 2.9 Telegram Confirm (Complete branch)
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $json.message.chat.id }}"
Text: "✅ Данные внесены\n\n👤 {{ $json.collectedData.full_name }}\n📞 {{ $json.collectedData.phone }}\n💼 {{ $json.collectedData.position }}\n📍 {{ $json.collectedData.object_location }}"
Reply To Message ID: "{{ $json.message.message_id }}"
```

#### 2.10 Save to Redis (Incomplete branch)
```yaml
Type: Redis
Operation: Set
Key: "dialog:{{ $json.message.chat.id }}:{{ $json.message.from.id }}"
Value: "{{ JSON.stringify($json.context) }}"
TTL: 86400  # 24 часа
```

#### 2.11 Telegram Ask More (Incomplete branch)
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $json.message.chat.id }}"
Text: "{{ $json.clarificationQuestion }}"
Reply To Message ID: "{{ $json.message.message_id }}"
```

---

## Workflow 3: Payment Processor

### Описание
Обрабатывает данные об оплате с использованием regex-парсинга.

### Структура нод

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Webhook    │────▶│  Get Redis  │────▶│  Regex      │
│  Trigger    │     │  State      │     │  Parse      │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                              ┌┴┐
                                              │?│ Валидация
                                              └┬┘
                          ┌────────────────────┴────────────────────┐
                          ▼                                         ▼
                   ┌─────────────┐                           ┌─────────────┐
                   │  Valid      │                           │  Invalid    │
                   │  Data       │                           │  Data       │
                   └──────┬──────┘                           └──────┬──────┘
                          │                                         │
                          ▼                                         ▼
                   ┌─────────────┐                           ┌─────────────┐
                   │  Split      │                           │  Ask        │
                   │  Employees  │                           │  Correction │
                   └──────┬──────┘                           └─────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  Supabase   │
                   │  Insert     │
                   │  (batch)    │
                   └──────┬──────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  Telegram   │
                   │  Confirm    │
                   └─────────────┘
```

### Детальное описание нод

#### 3.1 Webhook Trigger
```yaml
Type: Webhook
Method: POST
Path: /payment-processor
Authentication: None (internal only)
```

#### 3.2 Get Redis State
```yaml
Type: Redis
Operation: Get
Key: "dialog:{{ $json.chat.id }}:{{ $json.from.id }}"
```

#### 3.3 Regex Parse (Code Node)
```javascript
const message = $input.item.json;
const existingState = $('Get Redis State').item?.json?.value
  ? JSON.parse($('Get Redis State').item.json.value)
  : null;

const text = message.text || '';
const lines = text.split('\n').map(l => l.trim()).filter(l => l);

let result = {
  workDate: existingState?.workDate || null,
  objectLocation: existingState?.objectLocation || null,
  position: existingState?.position || null,
  employees: existingState?.employees || [],
  isComplete: false,
  errors: [],
  rawLines: lines
};

// Паттерны
const datePattern = /^(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?$/;
const employeePattern = /^(.+?)\s+(\d+(?:[.,]\d+)?)\s*$/;

// Известные должности
const positions = ['горничная', 'уборщица', 'охранник', 'администратор',
                   'повар', 'официант', 'бармен', 'кассир', 'продавец',
                   'менеджер', 'водитель'];

let lineIndex = 0;

// Парсим дату (если ещё нет)
if (!result.workDate && lines[lineIndex]) {
  const dateMatch = lines[lineIndex].match(datePattern);
  if (dateMatch) {
    const day = dateMatch[1].padStart(2, '0');
    const month = dateMatch[2].padStart(2, '0');
    const year = dateMatch[3] || new Date().getFullYear();
    result.workDate = `${year}-${month}-${day}`;
    lineIndex++;
  }
}

// Парсим объект (если ещё нет)
if (!result.objectLocation && lines[lineIndex]) {
  // Если строка не похожа на дату и не на сотрудника
  if (!datePattern.test(lines[lineIndex]) &&
      !employeePattern.test(lines[lineIndex])) {
    result.objectLocation = lines[lineIndex];
    lineIndex++;
  }
}

// Парсим должность (если ещё нет)
if (!result.position && lines[lineIndex]) {
  const lowerLine = lines[lineIndex].toLowerCase();
  if (positions.some(p => lowerLine.includes(p))) {
    result.position = lines[lineIndex];
    lineIndex++;
  } else if (!employeePattern.test(lines[lineIndex])) {
    // Предполагаем, что это должность
    result.position = lines[lineIndex];
    lineIndex++;
  }
}

// Парсим сотрудников
for (let i = lineIndex; i < lines.length; i++) {
  const match = lines[i].match(employeePattern);
  if (match) {
    result.employees.push({
      fullName: match[1].trim(),
      hours: parseFloat(match[2].replace(',', '.'))
    });
  } else if (lines[i]) {
    result.errors.push(`Не удалось распознать строку: "${lines[i]}"`);
  }
}

// Проверка полноты
const missingFields = [];
if (!result.workDate) missingFields.push('дата');
if (!result.objectLocation) missingFields.push('объект');
if (!result.position) missingFields.push('должность');
if (result.employees.length === 0) missingFields.push('сотрудники (ФИО и часы)');

result.isComplete = missingFields.length === 0;
result.missingFields = missingFields;

// Формируем вопрос
if (!result.isComplete) {
  result.clarificationQuestion = `Не хватает данных: ${missingFields.join(', ')}.\n\nОжидаемый формат:\nДата\nОбъект\nДолжность\nФИО часы`;
}

return {
  json: {
    message: message,
    parsed: result,
    context: result
  }
};
```

#### 3.4 Is Valid (IF Node)
```yaml
Type: IF
Condition: $json.parsed.isComplete == true
True Branch: → Split Employees
False Branch: → Save Redis & Ask Correction
```

#### 3.5 Split Employees (Split In Batches)
```yaml
Type: Split In Batches
Input: $json.parsed.employees
Batch Size: 1
```

#### 3.6 Supabase Insert (Loop)
```yaml
Type: Supabase
Operation: Insert
Table: payments
Row:
  work_date: "{{ $('Regex Parse').item.json.parsed.workDate }}"
  object_location: "{{ $('Regex Parse').item.json.parsed.objectLocation }}"
  position: "{{ $('Regex Parse').item.json.parsed.position }}"
  full_name: "{{ $json.fullName }}"
  hours: "{{ $json.hours }}"
  telegram_user_id: "{{ $('Regex Parse').item.json.message.from.id }}"
  telegram_username: "{{ $('Regex Parse').item.json.message.from.username }}"
  telegram_chat_id: "{{ $('Regex Parse').item.json.message.chat.id }}"
  telegram_message_id: "{{ $('Regex Parse').item.json.message.message_id }}"
```

#### 3.7 Clear Redis
```yaml
Type: Redis
Operation: Delete
Key: "dialog:{{ $json.message.chat.id }}:{{ $json.message.from.id }}"
```

#### 3.8 Telegram Confirm
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $json.message.chat.id }}"
Text: |
  ✅ Оплата записана

  📅 {{ $json.parsed.workDate }}
  📍 {{ $json.parsed.objectLocation }}
  💼 {{ $json.parsed.position }}
  👥 Сотрудников: {{ $json.parsed.employees.length }}
  ⏱ Всего часов: {{ $json.parsed.employees.reduce((sum, e) => sum + e.hours, 0) }}
Reply To Message ID: "{{ $json.message.message_id }}"
```

#### 3.9 Save Redis (Invalid branch)
```yaml
Type: Redis
Operation: Set
Key: "dialog:{{ $json.message.chat.id }}:{{ $json.message.from.id }}"
Value: "{{ JSON.stringify({ type: 'payment', ...($json.context) }) }}"
TTL: 86400
```

#### 3.10 Telegram Ask Correction
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $json.message.chat.id }}"
Text: "{{ $json.parsed.clarificationQuestion }}"
Reply To Message ID: "{{ $json.message.message_id }}"
```

---

## Workflow 4: Daily Report

### Описание
Отправляет ежедневный отчёт о добавленных кандидатах в 22:00 MSK.

### Структура нод

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Schedule   │────▶│  Supabase   │────▶│  Format     │────▶│  Telegram   │
│  22:00 MSK  │     │  Query      │     │  Report     │     │  Send       │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### Детальное описание нод

#### 4.1 Schedule Trigger
```yaml
Type: Schedule Trigger
Rule: "0 22 * * *"  # Каждый день в 22:00
Timezone: "Europe/Moscow"
```

#### 4.2 Supabase Query
```yaml
Type: Supabase
Operation: Select
Table: candidates
Filters:
  - created_date: eq.{{ new Date().toISOString().split('T')[0] }}
Order By: created_at ASC
```

#### 4.3 Format Report (Code Node)
```javascript
const candidates = $input.all();
const today = new Date().toLocaleDateString('ru-RU', {
  day: 'numeric',
  month: 'long',
  year: 'numeric'
});

if (candidates.length === 0) {
  return {
    json: {
      report: `📊 Отчёт за ${today}\n\nСегодня кандидатов не добавлено.`,
      hasData: false
    }
  };
}

let report = `📊 Отчёт за ${today}\n\n`;
report += `Добавлено кандидатов: ${candidates.length}\n\n`;

candidates.forEach((item, index) => {
  const c = item.json;
  report += `${index + 1}. ${c.full_name}\n`;
  report += `   📞 ${c.phone}\n`;
  report += `   💼 ${c.position}\n`;
  report += `   📍 ${c.object_location}\n\n`;
});

report += `---\nВсего за сегодня: ${candidates.length} кандидат(ов)`;

return {
  json: {
    report: report,
    hasData: true,
    count: candidates.length
  }
};
```

#### 4.4 Telegram Send
```yaml
Type: Telegram
Operation: Send Message
Chat ID: "{{ $env.TELEGRAM_CHAT_CANDIDATES }}"
Text: "{{ $json.report }}"
```

---

## Workflow 5: State Cleanup

### Описание
Очищает устаревшие состояния диалогов из Redis.

### Структура нод

```
┌─────────────┐     ┌─────────────┐
│  Schedule   │────▶│  Redis      │
│  Hourly     │     │  Cleanup    │
└─────────────┘     └─────────────┘
```

### Детальное описание нод

#### 5.1 Schedule Trigger
```yaml
Type: Schedule Trigger
Rule: "0 * * * *"  # Каждый час
```

#### 5.2 Redis Cleanup (Code Node)
```javascript
// Redis автоматически удаляет ключи по TTL,
// но эта нода может использоваться для логирования
// или принудительной очистки

// Если нужна принудительная очистка:
// 1. Получить все ключи dialog:*
// 2. Проверить timestamp в value
// 3. Удалить устаревшие

// В n8n можно использовать Execute Command для redis-cli
// redis-cli KEYS "dialog:*" | xargs -r redis-cli DEL

return {
  json: {
    status: 'TTL-based cleanup is automatic',
    timestamp: new Date().toISOString()
  }
};
```

---

## Переменные окружения n8n

Создайте следующие credentials и environment variables:

### Credentials

1. **Telegram Bot API**
   - Name: `HR Bot Telegram`
   - Access Token: `<BOT_TOKEN>`

2. **Supabase**
   - Name: `HR Bot Supabase`
   - Host: `https://xxx.supabase.co`
   - Service Role Key: `<SERVICE_KEY>`

3. **Redis**
   - Name: `HR Bot Redis`
   - Host: `<REDIS_HOST>`
   - Port: `6379`
   - Password: `<REDIS_PASSWORD>` (если есть)

### Environment Variables

```bash
# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_CANDIDATES=-1001234567890
TELEGRAM_CHAT_PAYMENTS=-1001234567891

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

## Тестирование

### Тестовые сценарии

#### Группа «Направленные»

**Сценарий 1: Полные данные за одно сообщение**
```
Иванов Петр Сергеевич, 35 лет, мужчина, охранник,
работал 2 года в ЧОП Альфа, тел 89161234567, объект ТЦ Мега
```
Ожидание: запись в БД, подтверждение ✅

**Сценарий 2: Неполные данные**
```
Мария Петрова, администратор
```
Ожидание: вопрос о телефоне и объекте

**Сценарий 3: Дополнение после вопроса**
```
(после вопроса бота)
89161234567, работать будет в Hilton
```
Ожидание: запись в БД, подтверждение ✅

#### Группа «Оплата мс»

**Сценарий 1: Стандартный формат**
```
26.01
МП
Горничная
Иванова Юлия 11
Каратова Самара 8
```
Ожидание: 2 записи в БД, подтверждение ✅

**Сценарий 2: Неполный формат**
```
Иванова Юлия 11
Каратова Самара 8
```
Ожидание: вопрос о дате, объекте, должности

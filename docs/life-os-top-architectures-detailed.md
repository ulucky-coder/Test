# Детальные спецификации топовых архитектур Life OS

> Глубокий технический разбор двух лучших архитектур для автономного AI-агента оцифровки жизни.

---

# 1. HYBRID RULES + LLM (Оценка: 8/10)

## 1.1 Концепция

**Принцип**: Двухуровневая система, где детерминированные правила обрабатывают 90% рутинных проверок (дёшево, быстро, предсказуемо), а LLM подключается только для сложного анализа и рекомендаций (дорого, но глубоко).

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA FLOW OVERVIEW                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   [Data Sources] ──→ [Ingestion] ──→ [Metrics Store]                │
│                                            │                         │
│                            ┌───────────────┴───────────────┐        │
│                            ▼                               ▼        │
│                    [Rules Engine]                   [LLM Analyzer]  │
│                     (real-time)                     (scheduled)     │
│                            │                               │        │
│                            ▼                               ▼        │
│                    [Instant Alerts]              [Deep Insights]    │
│                            │                               │        │
│                            └───────────────┬───────────────┘        │
│                                            ▼                         │
│                                   [Notification Hub]                 │
│                                            │                         │
│                                            ▼                         │
│                              [Telegram / Email / Notion]             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 1.2 Компоненты системы

### 1.2.1 Data Ingestion Layer

| Компонент | Технология | Функция |
|-----------|------------|---------|
| **Calendar Sync** | Google Calendar API / CalDAV | События, meetings, блоки времени |
| **Productivity Tracker** | RescueTime API / ActivityWatch | App usage, categories, productivity score |
| **Health Data** | Fitbit/Garmin/Apple Health API | Sleep, HR, HRV, steps, workouts |
| **Manual Input** | Telegram Bot / REST API | Quick notes, mood check-ins, overrides |
| **Git Activity** | GitHub/GitLab webhooks | Commits, PRs, coding sessions |

**Пример ingestion workflow (n8n или cron job):**

```javascript
// Pseudo-code: Daily data ingestion
async function dailyIngestion() {
  const today = new Date().toISOString().split('T')[0];

  // Parallel fetch from all sources
  const [calendar, rescueTime, fitbit, github] = await Promise.all([
    fetchCalendarEvents(today),
    fetchRescueTimeData(today),
    fetchFitbitSleep(today),
    fetchGithubCommits(today)
  ]);

  // Normalize and store
  await db.metrics.insertMany([
    ...normalizeCalendar(calendar),
    ...normalizeProductivity(rescueTime),
    ...normalizeSleep(fitbit),
    ...normalizeCode(github)
  ]);

  // Trigger rules evaluation
  await rulesEngine.evaluate(today);
}
```

---

### 1.2.2 Database Schema

```sql
-- Core metrics table (partitioned by month)
CREATE TABLE metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ts TIMESTAMPTZ NOT NULL,
    metric_type VARCHAR(50) NOT NULL,  -- 'sleep', 'productivity', 'mood', 'exercise'
    source VARCHAR(50) NOT NULL,        -- 'fitbit', 'rescuetime', 'manual'
    value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Partitioning for long-term storage
CREATE INDEX idx_metrics_ts ON metrics (ts DESC);
CREATE INDEX idx_metrics_type ON metrics (metric_type, ts DESC);

-- Example metric values:
-- sleep:        {"duration_min": 420, "deep_min": 90, "rem_min": 100, "awake_min": 30}
-- productivity: {"productive_min": 320, "neutral_min": 60, "distracting_min": 45}
-- mood:         {"score": 7, "energy": 6, "stress": 4, "note": "good morning"}
-- exercise:     {"type": "running", "duration_min": 30, "calories": 280}

-- Rules configuration
CREATE TABLE rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    condition JSONB NOT NULL,      -- Rule condition in structured format
    action JSONB NOT NULL,         -- What to do when triggered
    severity VARCHAR(20) DEFAULT 'info',  -- 'info', 'warning', 'critical'
    enabled BOOLEAN DEFAULT true,
    cooldown_hours INT DEFAULT 24, -- Don't repeat within this window
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rule triggers history
CREATE TABLE rule_triggers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID REFERENCES rules(id),
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    context JSONB,                 -- Data that triggered the rule
    action_taken JSONB,            -- What action was executed
    acknowledged BOOLEAN DEFAULT false
);

-- LLM analysis sessions
CREATE TABLE llm_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_type VARCHAR(50) NOT NULL,  -- 'daily_summary', 'weekly_analysis', 'pattern_detection'
    input_context JSONB NOT NULL,       -- What was sent to LLM
    output JSONB NOT NULL,              -- LLM response (parsed)
    raw_response TEXT,                  -- Raw LLM output
    tokens_used INT,
    cost_usd DECIMAL(10,4),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Derived daily summaries (materialized for fast queries)
CREATE TABLE daily_summaries (
    date DATE PRIMARY KEY,
    sleep_score INT,               -- 0-100
    productivity_score INT,        -- 0-100
    exercise_score INT,            -- 0-100
    mood_avg DECIMAL(3,1),
    deep_work_min INT,
    meetings_min INT,
    alerts_triggered INT,
    llm_insights TEXT[],
    computed_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### 1.2.3 Rules Engine

**Технологии на выбор:**
- **OPA (Open Policy Agent)** — production-grade, Rego language
- **json-rules-engine (Node.js)** — простой, достаточный для начала
- **Custom Python/JS** — максимальный контроль

**Примеры правил:**

```javascript
// rules.json - Конфигурация правил
{
  "rules": [
    {
      "id": "sleep_deficit",
      "name": "Sleep Deficit Alert",
      "description": "Triggers when sleep < 6 hours",
      "condition": {
        "type": "threshold",
        "metric": "sleep.duration_min",
        "operator": "<",
        "value": 360
      },
      "action": {
        "type": "notify",
        "channel": "telegram",
        "message": "⚠️ Sleep deficit: only {{value}} min. Consider early bedtime.",
        "severity": "warning"
      },
      "cooldown_hours": 24
    },
    {
      "id": "productivity_streak",
      "name": "Productivity Streak",
      "description": "Celebrates 3+ days of high productivity",
      "condition": {
        "type": "streak",
        "metric": "productivity.productive_min",
        "operator": ">",
        "value": 300,
        "days": 3
      },
      "action": {
        "type": "notify",
        "channel": "telegram",
        "message": "🔥 {{days}}-day productivity streak! Keep it up.",
        "severity": "info"
      }
    },
    {
      "id": "no_exercise_3_days",
      "name": "Exercise Reminder",
      "description": "No exercise logged for 3 days",
      "condition": {
        "type": "absence",
        "metric": "exercise",
        "days": 3
      },
      "action": {
        "type": "notify",
        "channel": "telegram",
        "message": "🏃 No exercise for 3 days. Even a 15-min walk helps.",
        "severity": "warning"
      }
    },
    {
      "id": "deep_work_low",
      "name": "Deep Work Deficit",
      "description": "Less than 2 hours of deep work today",
      "condition": {
        "type": "daily_threshold",
        "metric": "productivity.categories.deep_work_min",
        "operator": "<",
        "value": 120,
        "check_time": "18:00"  // Check at 6 PM
      },
      "action": {
        "type": "notify",
        "channel": "telegram",
        "message": "📊 Only {{value}} min deep work today. Block tomorrow AM?",
        "severity": "info"
      }
    },
    {
      "id": "screen_time_night",
      "name": "Late Night Screen",
      "description": "Screen activity after 11 PM",
      "condition": {
        "type": "time_window",
        "metric": "productivity.active",
        "operator": ">",
        "value": 0,
        "window": {"start": "23:00", "end": "05:00"}
      },
      "action": {
        "type": "notify",
        "channel": "telegram",
        "message": "🌙 Screen time at {{time}}. Sleep quality will suffer.",
        "severity": "warning"
      }
    },
    {
      "id": "escalate_to_llm",
      "name": "Complex Pattern Escalation",
      "description": "Escalate to LLM when multiple warnings in a week",
      "condition": {
        "type": "compound",
        "operator": "AND",
        "conditions": [
          {"type": "count", "metric": "alerts.warning", "days": 7, "operator": ">", "value": 5},
          {"type": "not_triggered", "rule": "escalate_to_llm", "days": 7}
        ]
      },
      "action": {
        "type": "trigger_llm_analysis",
        "analysis_type": "pattern_investigation",
        "context_days": 14
      }
    }
  ]
}
```

**Rules Engine Implementation (Node.js):**

```javascript
// rules-engine.js
class RulesEngine {
  constructor(db, notifier, llmAnalyzer) {
    this.db = db;
    this.notifier = notifier;
    this.llmAnalyzer = llmAnalyzer;
    this.rules = [];
  }

  async loadRules() {
    this.rules = await this.db.query('SELECT * FROM rules WHERE enabled = true');
  }

  async evaluate(date) {
    const metrics = await this.getMetricsForDate(date);
    const recentAlerts = await this.getRecentAlerts(7);

    for (const rule of this.rules) {
      if (await this.isInCooldown(rule)) continue;

      const triggered = await this.evaluateCondition(rule.condition, metrics, recentAlerts);

      if (triggered) {
        await this.executeAction(rule, triggered.context);
      }
    }
  }

  async evaluateCondition(condition, metrics, recentAlerts) {
    switch (condition.type) {
      case 'threshold':
        return this.evalThreshold(condition, metrics);
      case 'streak':
        return this.evalStreak(condition, metrics);
      case 'absence':
        return this.evalAbsence(condition, metrics);
      case 'compound':
        return this.evalCompound(condition, metrics, recentAlerts);
      default:
        console.warn(`Unknown condition type: ${condition.type}`);
        return null;
    }
  }

  async executeAction(rule, context) {
    // Log trigger
    await this.db.query(
      'INSERT INTO rule_triggers (rule_id, context) VALUES ($1, $2)',
      [rule.id, context]
    );

    switch (rule.action.type) {
      case 'notify':
        const message = this.interpolateMessage(rule.action.message, context);
        await this.notifier.send(rule.action.channel, message, rule.action.severity);
        break;

      case 'trigger_llm_analysis':
        await this.llmAnalyzer.analyze(rule.action.analysis_type, {
          context_days: rule.action.context_days,
          trigger_rule: rule.name,
          trigger_context: context
        });
        break;
    }
  }
}
```

---

### 1.2.4 LLM Analyzer

**Когда вызывается LLM:**
1. **Weekly digest** (scheduled) — воскресенье вечером
2. **Escalation** — когда rules engine обнаруживает сложный паттерн
3. **On-demand** — пользователь запрашивает через chat

```javascript
// llm-analyzer.js
class LLMAnalyzer {
  constructor(db, openaiClient) {
    this.db = db;
    this.openai = openaiClient;
  }

  async weeklyAnalysis() {
    const context = await this.buildWeeklyContext();

    const prompt = `You are a personal productivity and health analyst.
Analyze this week's data and provide actionable insights.

DATA:
${JSON.stringify(context, null, 2)}

ANALYSIS REQUIREMENTS:
1. Identify the top 3 positive patterns this week
2. Identify the top 3 concerning patterns
3. Find correlations (e.g., sleep vs productivity, exercise vs mood)
4. Provide 3 specific, actionable recommendations for next week
5. Rate overall week: 1-10

FORMAT: JSON with keys: positives, concerns, correlations, recommendations, rating, summary`;

    const response = await this.openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
      max_tokens: 1500
    });

    const analysis = JSON.parse(response.choices[0].message.content);

    // Store session
    await this.db.query(`
      INSERT INTO llm_sessions (session_type, input_context, output, tokens_used, cost_usd)
      VALUES ($1, $2, $3, $4, $5)
    `, ['weekly_analysis', context, analysis, response.usage.total_tokens, this.calculateCost(response.usage)]);

    return analysis;
  }

  async buildWeeklyContext() {
    const endDate = new Date();
    const startDate = new Date(endDate - 7 * 24 * 60 * 60 * 1000);

    const [dailySummaries, alerts, manualNotes] = await Promise.all([
      this.db.query(`
        SELECT * FROM daily_summaries
        WHERE date BETWEEN $1 AND $2
        ORDER BY date
      `, [startDate, endDate]),

      this.db.query(`
        SELECT r.name, rt.triggered_at, rt.context
        FROM rule_triggers rt
        JOIN rules r ON r.id = rt.rule_id
        WHERE rt.triggered_at BETWEEN $1 AND $2
      `, [startDate, endDate]),

      this.db.query(`
        SELECT ts, value->>'note' as note
        FROM metrics
        WHERE metric_type = 'mood'
        AND ts BETWEEN $1 AND $2
        AND value->>'note' IS NOT NULL
      `, [startDate, endDate])
    ]);

    return {
      period: { start: startDate.toISOString(), end: endDate.toISOString() },
      daily_summaries: dailySummaries.rows,
      alerts_triggered: alerts.rows,
      user_notes: manualNotes.rows,
      aggregates: this.calculateAggregates(dailySummaries.rows)
    };
  }

  async patternInvestigation(trigger) {
    // Called when rules engine escalates
    const context = await this.buildExtendedContext(trigger.context_days);

    const prompt = `You are investigating a concerning pattern detected by automated rules.

TRIGGER: ${trigger.trigger_rule}
CONTEXT: ${JSON.stringify(trigger.trigger_context)}

EXTENDED DATA (${trigger.context_days} days):
${JSON.stringify(context, null, 2)}

INVESTIGATION:
1. What is the root cause of this pattern?
2. When did it start?
3. What correlates with this issue?
4. What are the immediate risks if unaddressed?
5. What are 3 specific interventions to try this week?

Be direct and specific. No motivational fluff.`;

    // ... similar to weeklyAnalysis
  }
}
```

---

### 1.2.5 Notification Hub

```javascript
// notifier.js
class Notifier {
  constructor(config) {
    this.telegram = new TelegramBot(config.telegramToken);
    this.email = new EmailClient(config.smtp);
    this.notion = new NotionClient(config.notionToken);
  }

  async send(channel, message, severity) {
    const formattedMessage = this.format(message, severity);

    switch (channel) {
      case 'telegram':
        await this.telegram.sendMessage(process.env.TELEGRAM_CHAT_ID, formattedMessage);
        break;
      case 'email':
        await this.email.send({
          to: process.env.USER_EMAIL,
          subject: `Life OS: ${severity.toUpperCase()}`,
          body: formattedMessage
        });
        break;
      case 'notion':
        await this.notion.pages.create({
          parent: { database_id: process.env.NOTION_INBOX_DB },
          properties: {
            Title: { title: [{ text: { content: message } }] },
            Severity: { select: { name: severity } },
            Date: { date: { start: new Date().toISOString() } }
          }
        });
        break;
    }
  }

  format(message, severity) {
    const icons = { info: 'ℹ️', warning: '⚠️', critical: '🚨' };
    return `${icons[severity] || ''} ${message}`;
  }
}
```

---

## 1.3 Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      DEPLOYMENT (Self-Hosted)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│   │   Docker    │    │   Docker    │    │   Docker    │            │
│   │  Ingestion  │    │   Rules     │    │    LLM      │            │
│   │   Workers   │    │   Engine    │    │  Analyzer   │            │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘            │
│          │                  │                  │                    │
│          └──────────────────┼──────────────────┘                    │
│                             │                                        │
│                    ┌────────▼────────┐                              │
│                    │   PostgreSQL    │                              │
│                    │   (Supabase)    │                              │
│                    └────────┬────────┘                              │
│                             │                                        │
│                    ┌────────▼────────┐                              │
│                    │     Redis       │                              │
│                    │  (job queues)   │                              │
│                    └─────────────────┘                              │
│                                                                      │
│   Scheduler: cron / n8n                                             │
│   Secrets: .env / Vault                                             │
│   Monitoring: Prometheus + Grafana (optional)                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: lifeos
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  ingestion:
    build: ./services/ingestion
    environment:
      - DATABASE_URL=postgres://postgres:${DB_PASSWORD}@postgres:5432/lifeos
      - RESCUETIME_API_KEY=${RESCUETIME_API_KEY}
      - FITBIT_ACCESS_TOKEN=${FITBIT_ACCESS_TOKEN}
    depends_on:
      - postgres
      - redis

  rules-engine:
    build: ./services/rules-engine
    environment:
      - DATABASE_URL=postgres://postgres:${DB_PASSWORD}@postgres:5432/lifeos
      - REDIS_URL=redis://redis:6379
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
    depends_on:
      - postgres
      - redis

  llm-analyzer:
    build: ./services/llm-analyzer
    environment:
      - DATABASE_URL=postgres://postgres:${DB_PASSWORD}@postgres:5432/lifeos
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    depends_on:
      - postgres

volumes:
  postgres_data:
```

---

## 1.4 Cost Breakdown

| Компонент | Стоимость/месяц | Комментарий |
|-----------|-----------------|-------------|
| PostgreSQL (Supabase free) | $0 | До 500MB, достаточно на годы |
| Redis (self-hosted) | $0 | В Docker |
| RescueTime | $0-12 | Free tier достаточен |
| Fitbit API | $0 | Бесплатно |
| LLM (GPT-4 Turbo) | $5-15 | ~4 weekly analyses + escalations |
| Telegram Bot | $0 | Бесплатно |
| VPS (optional) | $5-10 | Если не локально |
| **ИТОГО** | **$5-25/месяц** | |

---

## 1.5 Этапы реализации

| Этап | Срок | Deliverable |
|------|------|-------------|
| 1. DB schema + basic ingestion | 3-4 дня | Calendar + RescueTime → PostgreSQL |
| 2. Rules engine (5 базовых правил) | 2-3 дня | Sleep, productivity alerts via Telegram |
| 3. Telegram bot для manual input | 2 дня | /mood, /note, /log commands |
| 4. LLM weekly analysis | 2 дня | Sunday digest в Telegram |
| 5. Escalation logic | 1 день | Rules → LLM при сложных паттернах |
| 6. Dashboard (optional) | 3-5 дней | Grafana или custom |
| **ИТОГО** | **2-3 недели** | |

---

## 1.6 Сильные и слабые стороны

### ✅ Преимущества
- **Cost-efficient**: 90% логики на бесплатных rules
- **Predictable**: правила детерминированы, легко дебажить
- **Fast**: alerts в реальном времени, не ждут LLM
- **Degradation**: без LLM система продолжает работать (только alerts)
- **Auditable**: все правила в коде, версионируются

### ❌ Ограничения
- **Upfront work**: нужно написать правила (но это разовая работа)
- **Limited discovery**: правила не найдут неизвестные паттерны (LLM может, но редко вызывается)
- **Rule maintenance**: со временем правила нужно tuning

---
---

# 2. MULTI-AGENT: COLLECTOR / ANALYZER / COACH (Оценка: 8/10)

## 2.1 Концепция

**Принцип**: Три специализированных автономных агента, каждый отвечает за свою область. Общаются через message queue. Можно масштабировать, заменять, добавлять новых агентов.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MULTI-AGENT ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     DATA SOURCES                             │    │
│  │  Calendar | RescueTime | Fitbit | GitHub | Telegram | ...   │    │
│  └─────────────────────────────┬───────────────────────────────┘    │
│                                │                                     │
│                                ▼                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    COLLECTOR AGENT                           │    │
│  │  • Fetches data from all sources                            │    │
│  │  • Normalizes to unified schema                              │    │
│  │  • Handles auth, rate limits, retries                       │    │
│  │  • Writes to Data Lake                                       │    │
│  └─────────────────────────────┬───────────────────────────────┘    │
│                                │                                     │
│                                ▼                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                       DATA LAKE                              │    │
│  │  Raw Events → Normalized → Aggregated → Features            │    │
│  └───────────────────┬─────────────────────┬───────────────────┘    │
│                      │                     │                         │
│                      ▼                     ▼                         │
│  ┌──────────────────────────┐  ┌──────────────────────────────┐    │
│  │     ANALYZER AGENT       │  │       COACH AGENT            │    │
│  │  • Pattern detection     │  │  • Generates recommendations │    │
│  │  • Anomaly detection     │  │  • Personalized nudges       │    │
│  │  • Correlation mining    │  │  • Answers user questions    │    │
│  │  • Trend analysis        │  │  • Accountability check-ins  │    │
│  │  • ML model inference    │  │  • Goal tracking             │    │
│  └────────────┬─────────────┘  └─────────────┬────────────────┘    │
│               │                              │                       │
│               └──────────────┬───────────────┘                       │
│                              ▼                                       │
│                    [Message Queue / Event Bus]                       │
│                              │                                       │
│                              ▼                                       │
│                    [Notification Channels]                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2.2 Agent Specifications

### 2.2.1 COLLECTOR AGENT

**Ответственность**: Единственный агент, который взаимодействует с внешними API. Отвечает за полноту и качество данных.

```python
# collector_agent.py
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any
import aiohttp

class CollectorAgent:
    """
    Autonomous data collection agent.
    Runs continuously, fetching data from all configured sources.
    """

    def __init__(self, config: dict, db, message_queue):
        self.config = config
        self.db = db
        self.mq = message_queue
        self.sources = self._init_sources()

    def _init_sources(self) -> List[DataSource]:
        return [
            RescueTimeSource(self.config['rescuetime']),
            CalendarSource(self.config['google_calendar']),
            FitbitSource(self.config['fitbit']),
            GitHubSource(self.config['github']),
            TelegramSource(self.config['telegram']),
        ]

    async def run(self):
        """Main loop - runs forever"""
        while True:
            try:
                await self.collection_cycle()
                await asyncio.sleep(self.config['poll_interval_seconds'])
            except Exception as e:
                await self.handle_error(e)
                await asyncio.sleep(60)  # Back off on error

    async def collection_cycle(self):
        """Single collection cycle - fetch from all sources"""
        tasks = [self.fetch_source(source) for source in self.sources]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        for source, result in zip(self.sources, results):
            if isinstance(result, Exception):
                await self.log_source_error(source, result)
            else:
                await self.process_results(source, result)

    async def fetch_source(self, source: DataSource) -> List[RawEvent]:
        """Fetch data from a single source with retries"""
        for attempt in range(3):
            try:
                last_sync = await self.db.get_last_sync(source.name)
                events = await source.fetch(since=last_sync)
                return events
            except RateLimitError:
                await asyncio.sleep(2 ** attempt)
            except AuthError:
                await self.refresh_auth(source)
        raise SourceUnavailableError(source.name)

    async def process_results(self, source: DataSource, events: List[RawEvent]):
        """Normalize and store events"""
        normalized = [self.normalize(event, source) for event in events]

        # Store in data lake
        await self.db.insert_events(normalized)

        # Update sync timestamp
        await self.db.update_last_sync(source.name)

        # Notify Analyzer about new data
        await self.mq.publish('events.new', {
            'source': source.name,
            'count': len(normalized),
            'timestamp': datetime.utcnow().isoformat()
        })

    def normalize(self, event: RawEvent, source: DataSource) -> NormalizedEvent:
        """Convert source-specific format to unified schema"""
        return NormalizedEvent(
            id=generate_uuid(),
            timestamp=event.timestamp,
            source=source.name,
            event_type=source.map_event_type(event),
            data=source.extract_data(event),
            raw=event.raw if self.config['store_raw'] else None
        )


# Data source implementations
class RescueTimeSource(DataSource):
    name = 'rescuetime'

    async def fetch(self, since: datetime) -> List[RawEvent]:
        async with aiohttp.ClientSession() as session:
            # Fetch productivity data
            productivity = await self._fetch_productivity(session, since)
            # Fetch detailed activities
            activities = await self._fetch_activities(session, since)
            return productivity + activities

    def map_event_type(self, event: RawEvent) -> str:
        category_map = {
            'Software Development': 'deep_work',
            'Communication': 'communication',
            'Social Networking': 'distraction',
            'Entertainment': 'distraction',
            'Reference & Learning': 'learning',
        }
        return category_map.get(event.category, 'neutral')


class FitbitSource(DataSource):
    name = 'fitbit'

    async def fetch(self, since: datetime) -> List[RawEvent]:
        events = []

        # Sleep data
        sleep = await self._fetch_sleep(since)
        for record in sleep:
            events.append(RawEvent(
                timestamp=record['endTime'],
                category='sleep',
                data={
                    'duration_min': record['duration'] // 60000,
                    'efficiency': record['efficiency'],
                    'stages': record.get('levels', {}).get('summary', {})
                }
            ))

        # Heart rate
        hr = await self._fetch_heart_rate(since)
        events.extend(self._process_hr(hr))

        # Activity
        activity = await self._fetch_activity(since)
        events.extend(self._process_activity(activity))

        return events
```

**Collector Agent - конфигурация:**

```yaml
# collector-config.yaml
agent:
  name: collector
  poll_interval_seconds: 300  # 5 minutes
  store_raw_events: false     # Save storage

sources:
  rescuetime:
    enabled: true
    api_key: ${RESCUETIME_API_KEY}
    fetch_interval: 15m

  google_calendar:
    enabled: true
    credentials_file: /secrets/google-credentials.json
    calendars:
      - primary
      - work

  fitbit:
    enabled: true
    client_id: ${FITBIT_CLIENT_ID}
    client_secret: ${FITBIT_CLIENT_SECRET}
    scopes:
      - sleep
      - heartrate
      - activity

  github:
    enabled: true
    token: ${GITHUB_TOKEN}
    repos:
      - owner/repo1
      - owner/repo2
    events:
      - push
      - pull_request

  telegram:
    enabled: true
    bot_token: ${TELEGRAM_BOT_TOKEN}
    commands:
      - /mood
      - /note
      - /log
```

---

### 2.2.2 ANALYZER AGENT

**Ответственность**: Анализ данных, поиск паттернов, аномалий, корреляций. Не взаимодействует с пользователем напрямую.

```python
# analyzer_agent.py
from dataclasses import dataclass
from typing import List, Optional
import numpy as np
from sklearn.ensemble import IsolationForest

class AnalyzerAgent:
    """
    Autonomous analysis agent.
    Listens for new data events, performs analysis, publishes insights.
    """

    def __init__(self, config: dict, db, message_queue, llm_client):
        self.config = config
        self.db = db
        self.mq = message_queue
        self.llm = llm_client

        # ML models (loaded/trained on startup)
        self.anomaly_detector = None
        self.pattern_models = {}

    async def run(self):
        """Main loop - event-driven"""
        # Subscribe to events
        await self.mq.subscribe('events.new', self.on_new_events)
        await self.mq.subscribe('analysis.request', self.on_analysis_request)

        # Scheduled tasks
        asyncio.create_task(self.daily_analysis_loop())
        asyncio.create_task(self.weekly_deep_analysis_loop())

        # Keep running
        await asyncio.Event().wait()

    async def on_new_events(self, message: dict):
        """React to new data from Collector"""
        source = message['source']

        # Quick checks (rule-based, no LLM)
        await self.run_quick_checks(source)

        # Update rolling metrics
        await self.update_metrics()

    async def run_quick_checks(self, source: str):
        """Fast, deterministic checks"""
        today = date.today()

        checks = [
            self.check_sleep_threshold(today),
            self.check_productivity_threshold(today),
            self.check_exercise_absence(today),
            self.check_screen_time_night(today),
        ]

        results = await asyncio.gather(*checks)

        for result in results:
            if result and result.triggered:
                await self.mq.publish('insight.detected', {
                    'type': 'quick_check',
                    'insight': result.to_dict(),
                    'timestamp': datetime.utcnow().isoformat()
                })

    async def daily_analysis_loop(self):
        """Run at end of each day"""
        while True:
            await self.wait_until(hour=22, minute=0)  # 10 PM

            try:
                insights = await self.daily_analysis()
                await self.mq.publish('insight.daily', {
                    'date': date.today().isoformat(),
                    'insights': [i.to_dict() for i in insights]
                })
            except Exception as e:
                await self.log_error('daily_analysis', e)

            await asyncio.sleep(3600)  # Ensure we don't run twice

    async def daily_analysis(self) -> List[Insight]:
        """Comprehensive daily analysis"""
        today = date.today()
        insights = []

        # 1. Aggregate today's metrics
        daily_summary = await self.compute_daily_summary(today)

        # 2. Compare to baselines
        baselines = await self.get_baselines()
        deviations = self.compute_deviations(daily_summary, baselines)

        for metric, deviation in deviations.items():
            if abs(deviation.z_score) > 2:
                insights.append(Insight(
                    type='deviation',
                    metric=metric,
                    value=daily_summary[metric],
                    baseline=baselines[metric],
                    z_score=deviation.z_score,
                    direction='above' if deviation.z_score > 0 else 'below'
                ))

        # 3. Anomaly detection (ML)
        if self.anomaly_detector:
            feature_vector = self.extract_features(daily_summary)
            is_anomaly = self.anomaly_detector.predict([feature_vector])[0] == -1
            if is_anomaly:
                insights.append(Insight(
                    type='anomaly',
                    description='Unusual day pattern detected',
                    features=daily_summary
                ))

        # 4. Streak tracking
        streaks = await self.check_streaks(today)
        insights.extend(streaks)

        # 5. If complex patterns detected, use LLM for interpretation
        if len(insights) > 3 or any(i.type == 'anomaly' for i in insights):
            llm_insight = await self.llm_interpret(daily_summary, insights)
            insights.append(llm_insight)

        # Store summary
        await self.db.store_daily_summary(today, daily_summary, insights)

        return insights

    async def weekly_deep_analysis_loop(self):
        """Run once a week - deep LLM analysis"""
        while True:
            await self.wait_until_weekday(weekday=6, hour=20)  # Sunday 8 PM

            try:
                report = await self.weekly_deep_analysis()
                await self.mq.publish('insight.weekly', {
                    'week': self.get_week_string(),
                    'report': report
                })
            except Exception as e:
                await self.log_error('weekly_analysis', e)

            await asyncio.sleep(24 * 3600)

    async def weekly_deep_analysis(self) -> WeeklyReport:
        """LLM-powered weekly analysis"""
        # Gather week data
        week_data = await self.gather_week_data()

        prompt = f"""Analyze this week's life data and provide insights.

DATA:
{json.dumps(week_data, indent=2)}

Provide analysis in JSON format:
{{
  "overall_score": 1-10,
  "executive_summary": "2-3 sentences",
  "wins": ["list of positive patterns"],
  "concerns": ["list of concerning patterns"],
  "correlations": [
    {{"cause": "...", "effect": "...", "confidence": "high/medium/low"}}
  ],
  "recommendations": [
    {{"action": "...", "rationale": "...", "priority": "high/medium/low"}}
  ],
  "focus_for_next_week": "one specific thing to focus on"
}}

Be direct and specific. No motivational fluff."""

        response = await self.llm.complete(prompt, json_mode=True)
        return WeeklyReport.from_dict(json.loads(response))

    async def compute_daily_summary(self, day: date) -> dict:
        """Aggregate all metrics for a day"""
        events = await self.db.get_events_for_day(day)

        return {
            'date': day.isoformat(),
            'sleep': self._aggregate_sleep(events),
            'productivity': self._aggregate_productivity(events),
            'exercise': self._aggregate_exercise(events),
            'mood': self._aggregate_mood(events),
            'focus': self._compute_focus_metrics(events),
            'calendar': self._aggregate_calendar(events),
        }

    def _compute_focus_metrics(self, events: List[Event]) -> dict:
        """Compute deep work / shallow work metrics"""
        deep_work_events = [e for e in events if e.event_type == 'deep_work']

        # Find continuous blocks
        blocks = self._find_continuous_blocks(deep_work_events, gap_threshold_min=10)

        return {
            'deep_work_min': sum(b.duration_min for b in blocks),
            'deep_work_sessions': len(blocks),
            'longest_session_min': max((b.duration_min for b in blocks), default=0),
            'fragmentation_score': self._compute_fragmentation(blocks),
        }
```

**Analyzer - ML Models:**

```python
# analyzer_ml.py
class AnalyzerMLModels:
    """ML models for pattern detection"""

    def __init__(self, db):
        self.db = db
        self.anomaly_detector = None
        self.productivity_predictor = None

    async def train_models(self):
        """Train/update models on historical data"""
        # Need at least 30 days of data
        data = await self.db.get_daily_summaries(days=90)
        if len(data) < 30:
            return

        features = self._extract_feature_matrix(data)

        # Anomaly detection
        self.anomaly_detector = IsolationForest(
            contamination=0.1,  # Expect 10% anomalies
            random_state=42
        )
        self.anomaly_detector.fit(features)

        # Productivity prediction (next day based on today + sleep)
        X, y = self._prepare_productivity_prediction_data(data)
        self.productivity_predictor = GradientBoostingRegressor()
        self.productivity_predictor.fit(X, y)

    def _extract_feature_matrix(self, data: List[dict]) -> np.ndarray:
        """Convert daily summaries to feature vectors"""
        features = []
        for day in data:
            features.append([
                day['sleep']['duration_min'],
                day['sleep']['efficiency'],
                day['productivity']['productive_min'],
                day['productivity']['distracting_min'],
                day['exercise']['duration_min'],
                day['mood']['avg_score'],
                day['focus']['deep_work_min'],
                day['focus']['fragmentation_score'],
                day['calendar']['meetings_min'],
            ])
        return np.array(features)
```

---

### 2.2.3 COACH AGENT

**Ответственность**: Взаимодействие с пользователем. Генерация рекомендаций, nudges, ответы на вопросы.

```python
# coach_agent.py
class CoachAgent:
    """
    User-facing agent.
    Delivers insights, provides recommendations, answers questions.
    """

    def __init__(self, config: dict, db, message_queue, llm_client, notifier):
        self.config = config
        self.db = db
        self.mq = message_queue
        self.llm = llm_client
        self.notifier = notifier

        # User preferences
        self.prefs = None

    async def run(self):
        """Main loop"""
        # Load user preferences
        self.prefs = await self.db.get_user_preferences()

        # Subscribe to insights from Analyzer
        await self.mq.subscribe('insight.detected', self.on_insight)
        await self.mq.subscribe('insight.daily', self.on_daily_insights)
        await self.mq.subscribe('insight.weekly', self.on_weekly_report)

        # Handle user messages
        await self.mq.subscribe('user.message', self.on_user_message)

        # Scheduled nudges
        asyncio.create_task(self.scheduled_nudges_loop())

        await asyncio.Event().wait()

    async def on_insight(self, message: dict):
        """Handle real-time insights from Analyzer"""
        insight = message['insight']

        # Determine if this warrants immediate notification
        if self.should_notify_immediately(insight):
            notification = self.format_insight(insight)
            await self.notifier.send(
                channel=self.prefs['primary_channel'],
                message=notification,
                severity=insight.get('severity', 'info')
            )

    async def on_daily_insights(self, message: dict):
        """Handle end-of-day summary"""
        insights = message['insights']

        # Generate personalized daily summary
        summary = await self.generate_daily_summary(insights)

        # Send via preferred channel
        await self.notifier.send(
            channel=self.prefs['daily_summary_channel'],
            message=summary,
            severity='info'
        )

    async def on_weekly_report(self, message: dict):
        """Handle weekly deep analysis"""
        report = message['report']

        # Format for user consumption
        formatted = self.format_weekly_report(report)

        # Send (usually email or Notion for longer content)
        await self.notifier.send(
            channel=self.prefs['weekly_report_channel'],
            message=formatted,
            severity='info'
        )

    async def on_user_message(self, message: dict):
        """Handle user questions and commands"""
        user_input = message['text']

        # Parse intent
        intent = await self.parse_intent(user_input)

        if intent.type == 'question':
            response = await self.answer_question(intent.query)
        elif intent.type == 'command':
            response = await self.execute_command(intent.command, intent.params)
        elif intent.type == 'log':
            response = await self.log_manual_entry(intent.data)
        else:
            response = await self.general_chat(user_input)

        await self.notifier.send(
            channel=message['reply_channel'],
            message=response
        )

    async def answer_question(self, query: str) -> str:
        """Answer user question about their data"""
        # Retrieve relevant context
        context = await self.retrieve_context(query)

        prompt = f"""You are a personal life analyst assistant.
Answer the user's question based on their data.

USER QUESTION: {query}

RELEVANT DATA:
{json.dumps(context, indent=2)}

Provide a direct, specific answer. Include numbers where relevant.
If the data doesn't contain enough information, say so."""

        return await self.llm.complete(prompt)

    async def retrieve_context(self, query: str) -> dict:
        """RAG-style retrieval for question answering"""
        # Determine time range from query
        time_range = self.extract_time_range(query)

        # Get relevant summaries
        summaries = await self.db.get_daily_summaries(
            start=time_range.start,
            end=time_range.end
        )

        # Get relevant insights
        insights = await self.db.search_insights(
            query=query,
            limit=10
        )

        return {
            'time_range': time_range.to_dict(),
            'daily_summaries': summaries,
            'relevant_insights': insights
        }

    async def scheduled_nudges_loop(self):
        """Send proactive nudges at scheduled times"""
        while True:
            await self.check_and_send_nudges()
            await asyncio.sleep(1800)  # Check every 30 min

    async def check_and_send_nudges(self):
        """Determine if any nudges should be sent now"""
        now = datetime.now()

        nudges = [
            self.morning_intention_nudge(now),
            self.midday_check_in(now),
            self.evening_reflection_prompt(now),
            self.exercise_reminder(now),
            self.break_suggestion(now),
        ]

        for nudge_coro in nudges:
            nudge = await nudge_coro
            if nudge and nudge.should_send:
                await self.notifier.send(
                    channel=self.prefs['nudge_channel'],
                    message=nudge.message
                )

    async def morning_intention_nudge(self, now: datetime) -> Optional[Nudge]:
        """Morning check-in at user's wake time"""
        if not self.is_time_window(now, self.prefs['wake_time'], tolerance_min=30):
            return None

        if await self.already_sent_today('morning_intention'):
            return None

        # Get yesterday's summary for context
        yesterday = await self.db.get_daily_summary(date.today() - timedelta(days=1))

        message = f"""Good morning. Yesterday's stats:
• Sleep: {yesterday['sleep']['duration_min'] // 60}h {yesterday['sleep']['duration_min'] % 60}m
• Deep work: {yesterday['focus']['deep_work_min']} min
• Mood avg: {yesterday['mood']['avg_score']}/10

What's your #1 priority today?"""

        return Nudge(should_send=True, message=message, type='morning_intention')

    def format_weekly_report(self, report: WeeklyReport) -> str:
        """Format weekly report for human consumption"""
        return f"""
## Weekly Life Report

**Overall Score: {report.overall_score}/10**

{report.executive_summary}

### Wins
{self._format_list(report.wins)}

### Concerns
{self._format_list(report.concerns)}

### Key Correlations
{self._format_correlations(report.correlations)}

### Recommendations
{self._format_recommendations(report.recommendations)}

---
**Focus for next week:** {report.focus_for_next_week}
"""
```

---

## 2.3 Message Queue & Communication

```python
# message_queue.py
import aio_pika

class MessageQueue:
    """
    RabbitMQ-based message queue for inter-agent communication.
    Can be replaced with Redis Streams, NATS, or even PostgreSQL NOTIFY.
    """

    def __init__(self, url: str):
        self.url = url
        self.connection = None
        self.channel = None

    async def connect(self):
        self.connection = await aio_pika.connect_robust(self.url)
        self.channel = await self.connection.channel()

        # Declare exchanges
        await self.channel.declare_exchange('lifeos', aio_pika.ExchangeType.TOPIC)

    async def publish(self, topic: str, message: dict):
        """Publish message to topic"""
        exchange = await self.channel.get_exchange('lifeos')
        await exchange.publish(
            aio_pika.Message(
                body=json.dumps(message).encode(),
                content_type='application/json'
            ),
            routing_key=topic
        )

    async def subscribe(self, topic: str, handler: Callable):
        """Subscribe to topic with handler"""
        queue = await self.channel.declare_queue('', exclusive=True)
        await queue.bind('lifeos', routing_key=topic)

        async def wrapper(message: aio_pika.IncomingMessage):
            async with message.process():
                data = json.loads(message.body.decode())
                await handler(data)

        await queue.consume(wrapper)
```

**Топики сообщений:**

| Topic | Publisher | Subscribers | Payload |
|-------|-----------|-------------|---------|
| `events.new` | Collector | Analyzer | `{source, count, timestamp}` |
| `insight.detected` | Analyzer | Coach | `{type, insight, timestamp}` |
| `insight.daily` | Analyzer | Coach | `{date, insights[]}` |
| `insight.weekly` | Analyzer | Coach | `{week, report}` |
| `user.message` | Telegram Bot | Coach | `{text, user_id, reply_channel}` |
| `agent.health` | All | Monitor | `{agent, status, timestamp}` |

---

## 2.4 Data Lake Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DATA LAKE LAYERS                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   BRONZE (Raw)                                                      │
│   ├── S3/MinIO: raw_events/{source}/{date}/{file}.jsonl            │
│   └── Schema: {id, timestamp, source, raw_payload}                  │
│                                                                      │
│   SILVER (Normalized)                                               │
│   ├── PostgreSQL: normalized_events                                 │
│   └── Schema: {id, ts, source, event_type, data JSONB}             │
│                                                                      │
│   GOLD (Aggregated)                                                 │
│   ├── PostgreSQL: daily_summaries, weekly_summaries                │
│   ├── TimescaleDB: metrics_timeseries (for dashboards)             │
│   └── Vector DB: insights_embeddings (for semantic search)         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

```sql
-- Silver layer: normalized events
CREATE TABLE normalized_events (
    id UUID PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL,
    source VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (ts);

-- Create monthly partitions
CREATE TABLE normalized_events_2026_01
    PARTITION OF normalized_events
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

-- Gold layer: daily summaries
CREATE TABLE daily_summaries (
    date DATE PRIMARY KEY,
    sleep JSONB,
    productivity JSONB,
    exercise JSONB,
    mood JSONB,
    focus JSONB,
    calendar JSONB,
    insights JSONB[],
    scores JSONB,  -- {overall, sleep, productivity, ...}
    computed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Gold layer: insights with embeddings
CREATE TABLE insights (
    id UUID PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    insight_type VARCHAR(50),
    content TEXT,
    data JSONB,
    embedding vector(1536)  -- pgvector
);

CREATE INDEX ON insights USING ivfflat (embedding vector_cosine_ops);
```

---

## 2.5 Deployment Architecture

```yaml
# docker-compose.yml
version: '3.8'

services:
  # Message Queue
  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

  # Database
  postgres:
    image: timescale/timescaledb:latest-pg15
    environment:
      POSTGRES_DB: lifeos
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  # Object Storage (for raw events)
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"

  # Agents
  collector:
    build: ./agents/collector
    environment:
      - DATABASE_URL=postgres://postgres:${DB_PASSWORD}@postgres:5432/lifeos
      - RABBITMQ_URL=amqp://rabbitmq:5672
      - MINIO_URL=http://minio:9000
    depends_on:
      - postgres
      - rabbitmq
      - minio
    restart: unless-stopped

  analyzer:
    build: ./agents/analyzer
    environment:
      - DATABASE_URL=postgres://postgres:${DB_PASSWORD}@postgres:5432/lifeos
      - RABBITMQ_URL=amqp://rabbitmq:5672
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    depends_on:
      - postgres
      - rabbitmq
    restart: unless-stopped

  coach:
    build: ./agents/coach
    environment:
      - DATABASE_URL=postgres://postgres:${DB_PASSWORD}@postgres:5432/lifeos
      - RABBITMQ_URL=amqp://rabbitmq:5672
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
    depends_on:
      - postgres
      - rabbitmq
    restart: unless-stopped

  # Telegram Bot (webhook receiver)
  telegram-webhook:
    build: ./services/telegram-webhook
    environment:
      - RABBITMQ_URL=amqp://rabbitmq:5672
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
    ports:
      - "8080:8080"
    depends_on:
      - rabbitmq

volumes:
  rabbitmq_data:
  postgres_data:
  minio_data:
```

---

## 2.6 Cost Breakdown

| Компонент | Стоимость/месяц | Комментарий |
|-----------|-----------------|-------------|
| VPS (4GB RAM) | $20-40 | Для всех контейнеров |
| PostgreSQL storage | $0-5 | Supabase free или self-hosted |
| MinIO storage | $0 | Self-hosted, ~1GB/month данных |
| RabbitMQ | $0 | Self-hosted |
| LLM (GPT-4) | $15-40 | Analyzer weekly + Coach Q&A |
| External APIs | $0-12 | RescueTime premium optional |
| **ИТОГО** | **$35-100/месяц** | |

---

## 2.7 Этапы реализации

| Этап | Срок | Deliverable |
|------|------|-------------|
| 1. Infrastructure setup | 2-3 дня | Docker compose, DBs, RabbitMQ |
| 2. Collector Agent (2 sources) | 4-5 дней | Calendar + RescueTime → Data Lake |
| 3. Analyzer Agent (basic) | 4-5 дней | Daily summaries, quick checks |
| 4. Coach Agent (notifications) | 3-4 дня | Telegram notifications |
| 5. Add more sources | 3-4 дня | Fitbit, GitHub |
| 6. Analyzer ML models | 3-4 дня | Anomaly detection |
| 7. Coach Q&A | 2-3 дня | Answer user questions |
| 8. Polish & testing | 3-4 дней | Error handling, edge cases |
| **ИТОГО** | **5-7 недель** | |

---

## 2.8 Сильные и слабые стороны

### ✅ Преимущества
- **Separation of concerns**: каждый агент делает одно дело хорошо
- **Resilience**: падение одного агента не убивает систему
- **Scalability**: можно реплицировать агентов при нагрузке
- **Extensibility**: легко добавить новых агентов (Planner, Accountability)
- **Testability**: агенты тестируются изолированно

### ❌ Ограничения
- **Complexity**: больше moving parts = больше точек отказа
- **Cost**: выше baseline (infra + LLM calls)
- **DevOps overhead**: нужен мониторинг, логирование, алертинг
- **Overkill для одного пользователя**: оправдано для команды/продукта

---

# 3. СРАВНЕНИЕ ДВУХ АРХИТЕКТУР

| Критерий | Hybrid Rules + LLM | Multi-Agent |
|----------|-------------------|-------------|
| **Сложность** | Средняя | Высокая |
| **Время реализации** | 2-3 недели | 5-7 недель |
| **Стоимость/месяц** | $5-25 | $35-100 |
| **Отказоустойчивость** | Высокая (rules работают без LLM) | Очень высокая (агенты независимы) |
| **Масштабируемость** | Средняя | Отличная |
| **Extensibility** | Средняя (добавление правил) | Отличная (добавление агентов) |
| **Для solo use** | ✅ Идеально | ⚠️ Избыточно |
| **Для команды/продукта** | ⚠️ Ограниченно | ✅ Идеально |

---

## Рекомендация

**Для одного пользователя → Hybrid Rules + LLM**
- Быстрее запустить
- Дешевле поддерживать
- Достаточно мощно для персонального использования

**Для продукта / команды → Multi-Agent**
- Лучше масштабируется
- Проще добавлять функциональность
- Production-grade architecture

**Путь миграции:**
```
1. Начать с Hybrid Rules + LLM (2-3 недели)
2. Валидировать концепцию (1-2 месяца использования)
3. Если нужно масштабировать → рефакторить в Multi-Agent
```

---

*Документ создан: 2026-01-25*
*Версия: 1.0*

# Forms & Leads

Архитектура форм, валидация, **multi-sink доставка лидов** (Sheets / Telegram / CRM), fallback, согласие на ПДн.

## Архитектура

Лид параллельно уходит во **все настроенные** sinks. Каналы независимы: ошибка одного не ломает другие. Если ни один не принял — fallback в `data/leads.json`.

```
[React Hook Form + Zod + <Turnstile /> + useActionState]
        │  formAction(formData) → вызов Server Action напрямую
        ▼
[Server Action: app/actions/submit-lead.ts ('use server')]
   ├─ Rate limit (1 req / 10s / IP)
   ├─ Zod validate (FormData → object → schema.safeParse)
   ├─ Turnstile verify (challenges.cloudflare.com/turnstile/v0/siteverify)
   │      └─ fail → return { error: "Защита от спама не пройдена" }
   └─ Promise.allSettled([
   │     sendToSheets(data),       ← lib/sinks/sheets.ts
   │     sendToTelegram(data),     ← lib/sinks/telegram.ts
   │     sendToCRM(data),          ← lib/sinks/crm.ts (stub до подключения)
   │  ])
   │      ├─ хоть один success → лид сохранён, return { success: true }
   │      ├─ все skipped (нет env) → appendFallback() + warn в логах
   │      └─ все failed (env есть, но API упали) → appendFallback() + error в логах
   └─ return { success: true }     ← пользователю ВСЕГДА success (даже если все каналы упали — fallback страхует)
```

Принципы:

- **Multi-sink через `Promise.allSettled`.** Каналы независимы, упавший Telegram не ломает Sheets. Все вызываются параллельно.
- **Skip vs fail.** Если в `.env` нет ключей канала — он бросает `SinkSkipped` (не считается ошибкой, не идёт в fallback-логику). Если ключи есть, но API упал — это `failure` (логируется, идёт в fallback если других success нет).
- **`data/leads.json` — последний рубеж**, не основной канал. Используется только когда ни один sink не принял лид. Файл gitignored, лежит на VPS в `releases/<sha>/data/leads.json`.
- **Server Action вместо Route Handler** — формы вызывают `submitLead` напрямую через `useActionState`/`<form action={...}>`. Endpoint `/api/lead` не создаётся.
- **Никаких ключей CRM/Sheets/Telegram в клиентском коде** — только в `process.env.*` внутри Server Action.
- **Антиспам через Cloudflare Turnstile** — токен проверяется на сервере **до** sinks. Без валидного токена ничего никуда не идёт.

## Структура `lib/sinks/`

```
lib/
├── crm.ts              ← УСТАРЕЛ (если есть из v3.0/v3.1) — переехало в lib/sinks/crm.ts
├── fallback.ts         ← пишет в data/leads.json
├── rate-limit.ts       ← in-memory rate-limit
└── sinks/
    ├── index.ts        ← экспортирует allSinks + типы + SinkSkipped + classifySinkResults
    ├── sheets.ts       ← Google Sheets через googleapis
    ├── telegram.ts     ← Telegram Bot через node-telegram-bot-api
    └── crm.ts          ← stub-функция (бросает SinkSkipped) — заполняется когда подключаешь CRM
```

### `lib/sinks/index.ts` — диспетчер

```typescript
// lib/sinks/index.ts
import { sendToSheets } from "./sheets";
import { sendToTelegram } from "./telegram";
import { sendToCRM } from "./crm";

export type LeadData = {
  name: string;
  phone: string;
  email?: string;
  message?: string;
  source: string;
};

export class SinkSkipped extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = "SinkSkipped";
  }
}

export const allSinks = [sendToSheets, sendToTelegram, sendToCRM] as const;

export type SinkResult = PromiseSettledResult<unknown>;

export function classifySinkResults(results: SinkResult[]) {
  const successes = results.filter((r) => r.status === "fulfilled");
  const skips = results.filter(
    (r) => r.status === "rejected" && r.reason instanceof SinkSkipped,
  );
  const failures = results.filter(
    (r) => r.status === "rejected" && !(r.reason instanceof SinkSkipped),
  );
  return { successes, skips, failures };
}
```

### `lib/sinks/sheets.ts` — Google Sheets

```typescript
// lib/sinks/sheets.ts
import { google } from "googleapis";
import { SinkSkipped, type LeadData } from "./index";

export async function sendToSheets(data: LeadData): Promise<void> {
  const email = process.env.GOOGLE_SHEETS_CLIENT_EMAIL;
  const key = process.env.GOOGLE_SHEETS_PRIVATE_KEY;
  const spreadsheetId = process.env.GOOGLE_SHEETS_SPREADSHEET_ID;

  if (!email || !key || !spreadsheetId) {
    throw new SinkSkipped("GOOGLE_SHEETS_NOT_CONFIGURED");
  }

  const auth = new google.auth.JWT({
    email,
    // private_key в env часто экранируется как "\\n" — возвращаем настоящие переносы строк
    key: key.replace(/\\n/g, "\n"),
    scopes: ["https://www.googleapis.com/auth/spreadsheets"],
  });

  const sheets = google.sheets({ version: "v4", auth });
  const tab = process.env.GOOGLE_SHEETS_TAB_NAME ?? "Leads";

  // Имя листа в одинарных кавычках с экранированием: чтобы Google Sheets API
  // принимал имена с пробелами и кириллицей ("Лиды", "Список заявок").
  const escapedTab = `'${tab.replace(/'/g, "''")}'`;

  await sheets.spreadsheets.values.append({
    spreadsheetId,
    range: `${escapedTab}!A:F`,
    valueInputOption: "USER_ENTERED",
    insertDataOption: "INSERT_ROWS", // всегда вставлять новый ряд внизу, не затирать соседние данные
    requestBody: {
      values: [[
        new Date().toISOString(),
        data.name,
        data.phone,
        data.email ?? "",
        data.message ?? "",
        data.source,
      ]],
    },
  });
}
```

**Подготовка таблицы (один раз):**

1. Google Cloud Console → Create Project → APIs & Services → Enable Google Sheets API.
2. APIs & Services → Credentials → Create Credentials → **Service Account**. Скачать JSON-ключ.
3. Открыть таблицу в Google Sheets → Share → добавить service-account-email из JSON как **Editor**. Без этого API вернёт 403.
4. Из JSON-ключа в `.env`:
   - `GOOGLE_SHEETS_CLIENT_EMAIL` = `client_email` поле JSON
   - `GOOGLE_SHEETS_PRIVATE_KEY` = `private_key` поле JSON. **Важно:** оборачивай значение в **двойные кавычки** и оставляй литеральные `\n` — sink в runtime сделает `.replace(/\\n/g, "\n")`.

   **Правильно:**
   ```bash
   GOOGLE_SHEETS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
   ```
   Без двойных кавычек либо с одинарными — Next.js dotenv / heredoc-парсер `PROD_ENV_FILE` секрета на VPS обработают `\n` непредсказуемо, и Google API вернёт `error:0480006C:PEM routines::no start line` или `invalid_grant: Invalid JWT Signature`.

5. `GOOGLE_SHEETS_SPREADSHEET_ID` — из URL таблицы: `docs.google.com/spreadsheets/d/<ВОТ-ЭТО>/edit`.
6. (Опционально) `GOOGLE_SHEETS_TAB_NAME` — имя листа, дефолт `Leads`.

В первой строке таблицы можно сделать заголовки: `Дата`, `Имя`, `Телефон`, `Email`, `Сообщение`, `Источник` — `valueInputOption: "USER_ENTERED"` будет писать данные в `A2:F2` и далее.

### `lib/sinks/telegram.ts` — Telegram-бот

```typescript
// lib/sinks/telegram.ts
import TelegramBot from "node-telegram-bot-api";
import { SinkSkipped, type LeadData } from "./index";

export async function sendToTelegram(data: LeadData): Promise<void> {
  const token = process.env.TG_BOT_TOKEN;
  const chatId = process.env.TG_CHAT_ID;

  if (!token || !chatId) {
    throw new SinkSkipped("TELEGRAM_NOT_CONFIGURED");
  }

  // Создаём bot inline на каждый вызов: {polling: false} — это просто обёртка
  // над token, дешёвая (~µs). Module-level singleton не нужен и плохо себя ведёт
  // в Next.js Server Actions при HMR / multi-worker PM2.
  const bot = new TelegramBot(token, { polling: false });

  const rawText = [
    "<b>🆕 Новая заявка</b>",
    `<b>Источник:</b> ${escapeHtml(data.source)}`,
    `<b>Имя:</b> ${escapeHtml(data.name)}`,
    `<b>Телефон:</b> ${escapeHtml(data.phone)}`,
    data.email ? `<b>Email:</b> ${escapeHtml(data.email)}` : null,
    data.message ? `<b>Сообщение:</b> ${escapeHtml(data.message)}` : null,
  ]
    .filter(Boolean)
    .join("\n");

  // Telegram message limit: 4096 символов. Если очень длинный комментарий —
  // обрезаем. Sheets/CRM получат полную версию через свои sinks.
  const text = rawText.length > 4000 ? rawText.slice(0, 4000) + "\n\n<i>...сообщение обрезано</i>" : rawText;

  await bot.sendMessage(chatId, text, { parse_mode: "HTML" });
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[c]!));
}
```

**Подготовка бота (один раз):**

1. В Telegram написать `@BotFather` → `/newbot` → выбрать имя и username. Получить **HTTP API token** (`123456:AAEx...`) — это `TG_BOT_TOKEN`.
2. Создать чат куда будут приходить лиды (личный чат с ботом, групповой чат с командой, или канал). Добавить бота в чат.
3. Узнать `chat_id`:
   - Личный чат: `@userinfobot` → пиши ему любое сообщение → он вернёт твой `chat_id` (число типа `123456789`).
   - Групповой чат: добавь бота, отправь любое сообщение, открой `https://api.telegram.org/bot<TOKEN>/getUpdates` → найди `"chat":{"id": -100...}`. Минусовое число — это `chat_id` группы.
   - Канал: бот должен быть админом канала. `chat_id` канала — `@channelusername` (если public) или числовой ID из getUpdates.
4. В `.env`:
   - `TG_BOT_TOKEN` = токен бота
   - `TG_CHAT_ID` = ID чата (с минусом для групп)
5. Тест локально: запусти `pnpm dev`, отправь тестовую форму, проверь что сообщение пришло в чат.

### `lib/sinks/crm.ts` — stub до подключения

```typescript
// lib/sinks/crm.ts
import { SinkSkipped, type LeadData } from "./index";

/**
 * Подключение CRM. Пока заглушка — возвращает SinkSkipped, лид идёт только в Sheets/Telegram.
 *
 * Чтобы подключить:
 * 1. Выбрать CRM (AmoCRM / Bitrix24 / RetailCRM / etc.).
 * 2. Положить ключи в .env (например, AMO_CRM_URL, AMO_CRM_TOKEN).
 * 3. Заменить тело функции на реальный POST в API CRM (готовые шаблоны — ниже в этом docs).
 * 4. После заполнения функция перестанет бросать SinkSkipped, начнёт принимать лиды.
 */
export async function sendToCRM(data: LeadData): Promise<void> {
  throw new SinkSkipped("CRM_NOT_CONFIGURED");
}
```

**Готовые шаблоны для CRM — в конце этого файла.** Когда придёт время — копируешь нужный шаблон в `lib/sinks/crm.ts`, добавляешь env-переменные, тестируешь.

## Helpers — `lib/rate-limit.ts` и `lib/fallback.ts`

Server Action импортирует две утилиты, которые **не sinks**, но критичны для надёжности воронки:

- `rateLimit` — отсекает дребезг submit'ов с одного IP (в дополнение к Turnstile).
- `appendFallback` — пишет лид в `data/leads.json` если все sinks не приняли (последний рубеж).

Эти файлы создаются **вместе с `lib/sinks/`** в spec 09. Без них Server Action не скомпилируется — `Module not found: '@/lib/rate-limit'`.

### `lib/rate-limit.ts`

```typescript
// lib/rate-limit.ts
//
// In-memory rate-limit per IP. Достаточно для single-instance PM2 (default
// в bootstrap'е). При cluster-mode у каждого worker'а будет свой Map —
// rate-limit станет нестрогим, но Turnstile + appendFallback всё равно
// предотвратят утечку лидов; за реальной защитой нужен Redis или подобное.

const hits = new Map<string, number>();

/**
 * Минимальная пауза между submit'ами с одного IP. «1 в windowMs».
 *
 * @param ip — IP клиента (из x-forwarded-for header).
 * @param windowMs — длина окна в миллисекундах. Обычно 10_000 (10s).
 * @returns true если запрос разрешён, false если бить throttle.
 */
export function rateLimit(ip: string, windowMs: number): boolean {
  const now = Date.now();
  const lastHit = hits.get(ip) ?? 0;

  if (now - lastHit < windowMs) {
    return false;
  }

  hits.set(ip, now);

  // Cleanup старых записей при росте map'а (не блокировать процесс на каждом запросе)
  if (hits.size > 1000) {
    for (const [storedIp, timestamp] of hits) {
      if (now - timestamp > windowMs * 10) {
        hits.delete(storedIp);
      }
    }
  }

  return true;
}
```

Server Action вызывает `rateLimit(ip, 10_000)` — один submit в 10 секунд / IP. Если нужна более сложная логика (3 в минуту, sliding window), реализуй через `Map<ip, number[]>` с массивом timestamps; для лид-форм «1 в N секунд» обычно достаточно — реальную защиту даёт Turnstile.

### `lib/fallback.ts`

```typescript
// lib/fallback.ts
//
// Последний рубеж: если все sinks не приняли лид (упали или skipped),
// сохраняем в data/leads.json. Файл gitignored (.env*-style правило в
// .gitignore). После починки sinks-каналов можно вручную восстановить
// потерянные лиды из этого файла.

import { promises as fs } from "fs";
import path from "path";
import type { LeadData } from "./sinks";

const FALLBACK_PATH = path.join(process.cwd(), "data", "leads.json");

type FallbackEntry = LeadData & { savedAt: string };

export async function appendFallback(data: LeadData): Promise<void> {
  const entry: FallbackEntry = { ...data, savedAt: new Date().toISOString() };

  let existing: FallbackEntry[] = [];
  try {
    const text = await fs.readFile(FALLBACK_PATH, "utf-8");
    existing = JSON.parse(text);
    if (!Array.isArray(existing)) existing = [];
  } catch {
    // Файл ещё не создан — нормально для свежего проекта.
  }

  existing.push(entry);

  await fs.mkdir(path.dirname(FALLBACK_PATH), { recursive: true });
  await fs.writeFile(FALLBACK_PATH, JSON.stringify(existing, null, 2), "utf-8");
}
```

Концепции:

- **Read-modify-write не atomic** — при двух одновременных вызовах одна запись теоретически может потеряться. На лендингах с одним лидом в минуту это нерелевантно. Если случится бот-атака с 10+ одновременными прорывами Turnstile — пара лидов может пропасть из JSON, но они всё равно дошли в Sheets/Telegram (они попадают в JSON только если **все** sinks упали, что само по себе аномалия).
- **`data/leads.json` — gitignored** через шаблон `.gitignore` bootstrap'а (`data/leads.json` строкой). Никогда не коммитится — там персональные данные клиентов.
- **Чтение для восстановления:** `cat ~/prod/{site}/current/data/leads.json | jq` на VPS. Если сайт работает на свежем релизе — это файл с лидами после последнего деплоя; старые релизы хранятся в `releases/<sha>/data/leads.json`.

## Server Action

```typescript
// app/actions/submit-lead.ts
"use server";
import { headers } from "next/headers";
import { z } from "zod";
import { rateLimit } from "@/lib/rate-limit";
import { appendFallback } from "@/lib/fallback";
import { allSinks, classifySinkResults, type LeadData } from "@/lib/sinks";

const schema = z.object({
  name: z.string().min(2),
  phone: z.string().min(10),
  email: z.string().email().optional(),
  message: z.string().optional(),
  source: z.string(),
  consent: z.literal(true),
  turnstileToken: z.string().min(1),
});

export type LeadState = { success: true } | { error: string } | null;

export async function submitLead(
  _prev: LeadState,
  formData: FormData,
): Promise<LeadState> {
  const ip = (await headers()).get("x-forwarded-for") ?? "unknown";
  if (!rateLimit(ip, 10_000)) {
    return { error: "Слишком много запросов. Подождите минуту." };
  }

  const raw = Object.fromEntries(formData);
  const parsed = schema.safeParse({
    ...raw,
    consent: raw.consent === "on" || raw.consent === "true",
  });
  if (!parsed.success) {
    return { error: "Проверьте поля формы" };
  }

  // Turnstile verify ДО sinks, иначе бот успеет насыпать в Sheets/Telegram если они приняли request.
  const verify = await fetch(
    "https://challenges.cloudflare.com/turnstile/v0/siteverify",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        secret: process.env.TURNSTILE_SECRET_KEY!,
        response: parsed.data.turnstileToken,
        remoteip: ip,
      }),
    },
  );
  const verifyResult = (await verify.json()) as { success: boolean };
  if (!verifyResult.success) {
    return { error: "Защита от спама не пройдена" };
  }

  // LeadData без turnstileToken/consent (это transport-поля, в sinks не нужны).
  const leadData: LeadData = {
    name: parsed.data.name,
    phone: parsed.data.phone,
    email: parsed.data.email,
    message: parsed.data.message,
    source: parsed.data.source,
  };

  // Параллельная доставка во все sinks.
  const results = await Promise.allSettled(
    allSinks.map((sink) => sink(leadData)),
  );
  const { successes, skips, failures } = classifySinkResults(results);

  // Реальные ошибки в логи (попадут в pm2 logs / journalctl).
  if (failures.length > 0) {
    console.error(
      "Lead sink failures:",
      failures.map((f) => (f as PromiseRejectedResult).reason),
    );
  }

  // Если ни один sink не принял лид — пишем в JSON fallback, чтобы не потерять.
  if (successes.length === 0) {
    await appendFallback(leadData);
    if (failures.length === 0 && skips.length === allSinks.length) {
      console.warn(
        "All lead sinks are not configured. Set GOOGLE_SHEETS_*, TG_BOT_TOKEN, or AMO_CRM_* in .env to start receiving leads. " +
          "Until then leads are saved only to data/leads.json.",
      );
    }
  }

  return { success: true };
}
```

Поведение:

- **Лиду всегда показываем `success: true`** — даже если все sinks упали, fallback страхует. Пугать пользователя лишний раз не нужно.
- **Хоть один sink принял** → fallback не пишется (избегаем дублирования: лид уже в Sheets/Telegram, JSON-файл — для recovery, а не для архива).
- **Все sinks skipped** (свежий проект, не подключал ничего) → console.warn даёт понятный сигнал в логах: «настрой sink или будешь читать `data/leads.json`».
- **Канал упал API-ошибкой** → `console.error` с деталями. Видно через `ssh deploy@vps 'pm2 logs {site}-prod --lines 50'`.

Почему Server Action, а не Route Handler:

- **Меньше кода** — нет `NextRequest`/`NextResponse`, FormData → schema напрямую.
- **Тип возвращаемого значения** виден на клиенте через `useActionState<LeadState, FormData>`.
- **Прогрессивное улучшение** — `<form action={...}>` работает без JS.
- **Один меньше публичный endpoint** — нет `/api/lead`, защищать от прямых POST не надо. Server Action доступен только из приложения через `next-action` header.

## Клиентская часть

```typescript
// components/forms/ContactForm.tsx
"use client";
import { useActionState, useEffect, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Turnstile, type TurnstileInstance } from "@marsidev/react-turnstile";
import { submitLead, type LeadState } from "@/app/actions/submit-lead";

const schema = z.object({
  name: z.string().min(2, "Минимум 2 символа"),
  phone: z.string().min(10, "Некорректный телефон"),
  email: z.string().email("Некорректный email").optional(),
  message: z.string().optional(),
  consent: z.literal(true, { errorMap: () => ({ message: "Требуется согласие" }) }),
});

const turnstileRef = useRef<TurnstileInstance | null>(null);
const [token, setToken] = useState<string>("");
const [state, formAction, isPending] = useActionState<LeadState, FormData>(submitLead, null);

const { register, formState: { errors } } = useForm({
  resolver: zodResolver(schema),
  mode: "onBlur",
});

// Реакция на результат Server Action
useEffect(() => {
  if (!state) return;
  if (state.success) toast.success("Заявка отправлена!");
  else if (state.error) toast.error(state.error);
  // одноразовый токен — переполучаем для следующего submit
  turnstileRef.current?.reset();
  setToken("");
}, [state]);

// JSX:
<form action={formAction}>
  <input {...register("name")} name="name" />
  <input {...register("phone")} name="phone" />
  {/* ...остальные поля */}
  <input type="hidden" name="source" value="contact-form" />
  <input type="hidden" name="turnstileToken" value={token} />
  <Turnstile
    ref={turnstileRef}
    siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY!}
    onSuccess={setToken}
    options={{ theme: "light", size: "flexible" }}
  />
  <button type="submit" disabled={isPending || !token}>
    {isPending ? "Отправляем..." : "Отправить"}
  </button>
</form>;
```

Клиент **не знает** про sinks. С его стороны — один Server Action `submitLead`. Multi-sink — внутренняя кухня сервера.

## `.env` переменные

```bash
# Cloudflare Turnstile (антиспам)
NEXT_PUBLIC_TURNSTILE_SITE_KEY=0x4AAAAAAAxxxxxxxxxxxx
TURNSTILE_SECRET_KEY=0x4AAAAAAAyyyyyyyyyyyy

# Sink: Google Sheets
GOOGLE_SHEETS_CLIENT_EMAIL=service-account-name@project-id.iam.gserviceaccount.com
GOOGLE_SHEETS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
GOOGLE_SHEETS_SPREADSHEET_ID=1AbCdEfGhIjKlMnOpQrStUvWxYz...
GOOGLE_SHEETS_TAB_NAME=Leads          # опционально, default "Leads"

# Sink: Telegram
TG_BOT_TOKEN=123456789:AAExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TG_CHAT_ID=-1001234567890

# Sink: CRM (placeholder — раскомментируй при подключении)
# AMO_CRM_URL=https://yourdomain.amocrm.ru
# AMO_CRM_TOKEN=eyJ...
```

В `.env.example` — те же ключи без значений (этот файл коммитится в git как контракт):

```bash
NEXT_PUBLIC_TURNSTILE_SITE_KEY=
TURNSTILE_SECRET_KEY=

GOOGLE_SHEETS_CLIENT_EMAIL=
GOOGLE_SHEETS_PRIVATE_KEY=
GOOGLE_SHEETS_SPREADSHEET_ID=

TG_BOT_TOKEN=
TG_CHAT_ID=
```

`NEXT_PUBLIC_TURNSTILE_SITE_KEY` — единственное публичное (по дизайну Cloudflare). Все остальные — серверные, **никогда** не `NEXT_PUBLIC_`.

## Постепенное подключение sinks

Каналы можно включать **по очереди**: установил пакеты, добавил два-три env-переменные → сразу работает. Остальные продолжают быть `SinkSkipped`.

Порядок типичный:

1. **Sheets** — первое подключаешь. Заказчик видит лиды в реальном времени в табличке, может комментировать поля. Service-account-овый JSON получается за 5 минут.
2. **Telegram** — вторая очередь. Уведомление в чат команды «новая заявка» — не пропустишь даже если Sheets никто не открывает.
3. **CRM** — последняя, когда заказчик готов вкладываться в маршрутизацию лидов / автоматизацию воронки. До этого Sheets+Telegram отлично заменяет CRM для команды до 3-5 человек.

В каждом проекте — свой набор. Лендинг для одного эксперта может иметь только Telegram. Энтерпрайз — только AmoCRM + бэкап в Sheets. Бутик-агентство — все три.

## Как добавить новый sink (4 шаг)

1. **Создать `lib/sinks/<name>.ts`** с экспортом `async function sendTo<Name>(data: LeadData): Promise<void>`. В начале — guard через `SinkSkipped` если ключи не настроены.
2. **Добавить env-переменные** в `.env`, `.env.example`, и в GitHub Environment Secret `PROD_ENV_FILE` через `gh secret set`.
3. **Зарегистрировать** в `lib/sinks/index.ts`:
   ```typescript
   import { sendToZapier } from "./zapier";
   export const allSinks = [sendToSheets, sendToTelegram, sendToCRM, sendToZapier] as const;
   ```
4. **Тест локально** — `pnpm dev`, отправь форму, проверь канал и `pm2 logs`/`console`. Если канал не настроен ещё — должен молча skip без ошибок в UI.

## CRM-интеграции (готовые шаблоны)

Скопируй нужный шаблон в `lib/sinks/crm.ts` (заменив stub). Не забудь добавить env-переменные.

### AmoCRM

```typescript
// lib/sinks/crm.ts
import { SinkSkipped, type LeadData } from "./index";

export async function sendToCRM(data: LeadData): Promise<void> {
  const url = process.env.AMO_CRM_URL;     // https://yourdomain.amocrm.ru
  const token = process.env.AMO_CRM_TOKEN; // long-lived integration token

  if (!url || !token) {
    throw new SinkSkipped("AMO_CRM_NOT_CONFIGURED");
  }

  // Имя лида включает обрезанный preview сообщения — менеджер в Amo сразу
  // видит контекст без открытия лида. Полное сообщение пишется в note ниже.
  const messagePreview = data.message ? ` — ${data.message.slice(0, 60)}${data.message.length > 60 ? "..." : ""}` : "";

  const res = await fetch(`${url}/api/v4/leads/complex`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify([{
      name: `Заявка с сайта: ${data.source}${messagePreview}`,
      _embedded: {
        contacts: [{
          name: data.name,
          custom_fields_values: [
            { field_code: "PHONE", values: [{ value: data.phone, enum_code: "WORK" }] },
            ...(data.email ? [{ field_code: "EMAIL", values: [{ value: data.email, enum_code: "WORK" }] }] : []),
          ],
        }],
      },
    }]),
  });

  if (!res.ok) {
    throw new Error(`AmoCRM ${res.status}: ${await res.text()}`);
  }

  // Полное сообщение — отдельной нотой к лиду (если есть). Не критично если
  // упадёт — лид уже создан.
  if (data.message) {
    const created = (await res.json()) as { _embedded?: { leads?: { id: number }[] } };
    const leadId = created._embedded?.leads?.[0]?.id;
    if (leadId) {
      await fetch(`${url}/api/v4/leads/${leadId}/notes`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify([{ note_type: "common", params: { text: data.message } }]),
      }).catch(() => {/* note не критична — игнорируем */});
    }
  }
}
```

### Bitrix24 (вебхук)

```typescript
// lib/sinks/crm.ts
import { SinkSkipped, type LeadData } from "./index";

export async function sendToCRM(data: LeadData): Promise<void> {
  const hook = process.env.BITRIX_WEBHOOK_URL;
  // https://yourdomain.bitrix24.ru/rest/USER_ID/WEBHOOK_KEY/

  if (!hook) {
    throw new SinkSkipped("BITRIX_NOT_CONFIGURED");
  }

  const params = new URLSearchParams({
    "fields[TITLE]": `Заявка: ${data.source}`,
    "fields[NAME]": data.name,
    "fields[PHONE][0][VALUE]": data.phone,
    "fields[PHONE][0][VALUE_TYPE]": "WORK",
    "fields[SOURCE_ID]": "WEB",
  });
  if (data.email) params.append("fields[EMAIL][0][VALUE]", data.email);
  // Пустой COMMENTS не отправляем — Bitrix может выкинуть warning или сохранить
  // лид с пустым полем "комментарий", которое потом мешает менеджеру в фильтрах.
  if (data.message) params.append("fields[COMMENTS]", data.message);

  // POST с body вместо GET с query string: длинные комментарии (>2KB) могут
  // упереться в URL-лимит у proxy. POST такого ограничения не имеет.
  const res = await fetch(`${hook}crm.lead.add.json`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params,
  });
  if (!res.ok) {
    throw new Error(`Bitrix ${res.status}: ${await res.text()}`);
  }
}
```

### YClients, RetailCRM, кастомный

Похожие паттерны: REST POST с `Authorization` header или вебхук-URL. Ключ всегда в `.env`. При интеграции — сохрани соответствие полей в `lib/sinks/crm.ts` (или раздели на несколько `lib/sinks/<crm-name>.ts` если нужно несколько CRM одновременно — тогда добавь их все в `allSinks`).

## Антиспам — Cloudflare Turnstile

Turnstile — бесплатный CAPTCHA-аналог от Cloudflare. По умолчанию **invisible** (без UX-трения), при подозрительном трафике сам показывает managed-чекбокс. Без VPN-блокировок (в отличие от reCAPTCHA), без вендор-лока на Google.

### Заведение виджета

1. Cloudflare Dashboard → **Turnstile** → **Add Site**.
2. Domain: production-домен сайта + `localhost` (для локальной разработки).
3. Widget Mode: **Managed** (рекомендуется — Cloudflare сам решает invisible/checkbox по риск-скору).
4. Скопировать **Site Key** (публичный) и **Secret Key** (серверный).
5. Если у заказчика уже есть Cloudflare-аккаунт под DNS/proxy — добавляй Turnstile-сайт там же. Если нет — отдельная регистрация (бесплатно).

### Клиент — `@marsidev/react-turnstile`

```bash
pnpm add @marsidev/react-turnstile
```

Обёртка над официальным Turnstile JS API: ленивая загрузка скрипта, ref для `reset()`, колбэки `onSuccess`/`onError`/`onExpire`. Полный пример — выше в разделе «Клиентская часть».

Ключевые моменты:

- Токен **одноразовый** — после успешного submit вызови `turnstileRef.current?.reset()` и обнули локальный state. Иначе следующий submit отправит тот же токен → 400 от Cloudflare.
- `siteKey` читай из `process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY`.
- На submit-кнопке проверь `if (!token) return` — без токена не идём на сервер вообще.

### Локальная разработка без виджета

Cloudflare предоставляет тестовые ключи (https://developers.cloudflare.com/turnstile/troubleshooting/testing/):

- Site key `1x00000000000000000000AA` — всегда проходит на клиенте.
- Secret key `1x0000000000000000000000000000000AA` — всегда возвращает `success: true` на сервере.

Полезно в `.env.local` пока не получили боевые ключи или в e2e-тестах.

## `useOptimistic` для UX-без-задержки (опционально)

Для **многошаговых сценариев** (квиз, мастер-настройки, чат поддержки) — пока Server Action летит, можно сразу показать предположительный итог через `useOptimistic`, а потом откатить если ошибка.

```typescript
"use client";
import { useOptimistic } from "react";

const [optimisticAnswers, addOptimistic] = useOptimistic(
  answers,
  (state, newAnswer: { stepId: string; value: string }) => [...state, newAnswer]
);

async function next(stepId: string, value: string) {
  addOptimistic({ stepId, value }); // UI обновился мгновенно
  const result = await saveAnswer(stepId, value); // Server Action
  if (result?.error) toast.error(result.error);
}
```

**Для лид-формы `useOptimistic` обычно не нужен.** `isPending` из `useActionState` показывает спиннер на кнопке — этого достаточно. `useOptimistic` оправдан там, где есть **осмысленный откат** (toast «не удалось сохранить»), не как украшательство.

## Глобальная модалка консультации

```typescript
// lib/consultation-context.tsx
"use client";
const ConsultationContext = createContext<{ open: boolean; setOpen: (v: boolean) => void }>(
  { open: false, setOpen: () => {} }
);

export const useConsultationDialog = () => useContext(ConsultationContext);

// app/layout.tsx — оборачиваем всё приложение
<ConsultationDialogProvider>
  {children}
  <ConsultationDialog />  {/* сама модалка с формой */}
</ConsultationDialogProvider>

// Любой CTA на сайте — внутри маленького client-компонента:
const { setOpen } = useConsultationDialog();
<Button onClick={() => setOpen(true)}>Записаться</Button>
```

> Извлекай CTA-кнопку в свой client-компонент (`ConsultationButton`), не делай контейнер целиком client. См. `docs/architecture.md` § Server/Client разделение.

## Уведомления

- **Sonner** для toast.
- Успех: зелёный «Заявка отправлена».
- Ошибка: красный с конкретным текстом.
- Loading state на кнопке (`disabled` + spinner) во время `isPending`.

## Обязательные блоки в любой форме на RU-сайте

1. Чекбокс «Я согласен на обработку персональных данных» с ссылкой на «Согласие на обработку ПДн».
2. Ссылка на «Политику конфиденциальности» рядом с кнопкой submit.
3. Cookie-баннер на сайте (один раз показывается, сохраняется выбор в `localStorage`).

Готовые тексты — `docs/legal-templates.md`.

## Мониторинг лидов в проде

Если вдруг лиды перестали приходить — checklist:

```bash
# 1. Sinks: проверить логи Server Action на VPS
ssh deploy@{vps-ip} "pm2 logs {site}-prod --lines 100" | grep -i "sink\|lead"

# 2. Fallback: посмотреть data/leads.json — если он растёт, значит все sinks падают
ssh deploy@{vps-ip} "tail ~/prod/{site}/current/data/leads.json"

# 3. Каждый канал — проверить независимо:
#    - Sheets: открой таблицу, есть ли свежие строки?
#    - Telegram: открой чат с ботом, приходят ли сообщения?
#    - CRM: интерфейс CRM, новые лиды?

# 4. Turnstile: посмотреть статистику в Cloudflare Dashboard → Turnstile.
#    Резкий рост блокировок = бот-атака; резкий рост legitimate = всё ок.
```

Если **один канал** упал — нормально, лид всё равно ушёл в другие. Если **все упали** — `data/leads.json` страхует, после починки можно ручным скриптом добить лиды в Sheets из JSON.

# Sink-рецепты: полные листинги и подключение каналов

Справочник к `docs/forms-and-crm.md` (ядро: архитектура, Server Action, fallback). **Читается точечно** — подключаешь канал → читаешь его раздел, остальные не грузишь.

Общий контракт каждого sink: файл `lib/sinks/<name>.ts`, экспорт `async function sendTo<Name>(data: LeadData): Promise<void>`, в начале — guard `SinkSkipped`, регистрация в `allSinks` (`lib/sinks/index.ts`). Env-переменные — в `.env.local`, `.env.example` (без значений) и в GitHub-секрет `PROD_ENV_FILE` через `gh secret set`.

## EMAIL — nodemailer + SMTP Яндекса (первый канал, дефолт)

Проверен боем (spk-nhs): заявки идут на почту в день запуска форм, без чужих API и квот.

```bash
pnpm add nodemailer
pnpm add -D @types/nodemailer
```

### `lib/sinks/email.ts`

```typescript
import nodemailer from "nodemailer";
import { SinkSkipped, type LeadData } from "./index";

export async function sendToEmail(data: LeadData): Promise<void> {
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!user || !pass) throw new SinkSkipped("EMAIL_NOT_CONFIGURED");

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST ?? "smtp.yandex.ru",
    port: 465,
    secure: true,
    auth: { user, pass },
  });

  await transporter.sendMail({
    from: `"Сайт" <${user}>`, // Яндекс требует From = авторизованный ящик, иначе 553
    to: process.env.LEAD_EMAIL_TO ?? user, // можно списком через запятую
    subject: `Заявка с сайта: ${data.source}`,
    text: [
      `Имя: ${data.name}`,
      `Телефон: ${data.phone}`,
      data.email ? `Email: ${data.email}` : null,
      data.message ? `Сообщение: ${data.message}` : null,
      `Источник: ${data.source}`,
      `Время: ${new Date().toLocaleString("ru-RU")}`,
    ].filter(Boolean).join("\n"),
  });
}
```

**Вложения** (если форма принимает файл — смету, бриф): в `sendMail` добавь `attachments: [{ filename, content: Buffer.from(await file.arrayBuffer()) }]`, где `file = formData.get("file") as File`. Ограничь размер на клиенте (≤10 МБ) и проверь `file.size` на сервере до отправки.

### Подготовка канала (один раз)

Делает человек (~5 минут, чужой GUI):

1. Ящик-отправитель: любой @yandex.ru или ящик на домене заказчика (Яндекс 360). Отдельный технический ящик лучше личного.
2. **Пароль приложения** (обычный пароль от почты НЕ подойдёт): id.yandex.ru → Безопасность → Пароли приложений → создать для «Почта» → скопировать. Это `SMTP_PASS`.
3. Почта → Настройки → «Почтовые программы»: включить доступ по IMAP/SMTP («пароли приложений и OAuth-токены»).
4. В `.env`:
   ```bash
   SMTP_USER=leads@yandex.ru        # полный адрес ящика-отправителя
   SMTP_PASS=abcdefghijklmnop       # пароль приложения (16 символов, без пробелов)
   LEAD_EMAIL_TO=owner@example.com  # куда слать; опц., дефолт = SMTP_USER
   # SMTP_HOST=smtp.yandex.ru       # опц., дефолт для Яндекса
   ```
5. Тест: `pnpm dev` → отправить форму → письмо в ящике. Первое письмо проверь в «Спаме».

> Другой SMTP (Mail.ru, корпоративный): меняется только `SMTP_HOST` (+ порт, если не 465/SSL). Логика та же.

## TELEGRAM — голый fetch на Bot API

Пакет не нужен: `sendMessage` — один POST.

### `lib/sinks/telegram.ts`

```typescript
import { SinkSkipped, type LeadData } from "./index";

export async function sendToTelegram(data: LeadData): Promise<void> {
  const token = process.env.TG_BOT_TOKEN;
  const chatId = process.env.TG_CHAT_ID;
  if (!token || !chatId) throw new SinkSkipped("TELEGRAM_NOT_CONFIGURED");

  const rawText = [
    "<b>Новая заявка</b>",
    `<b>Источник:</b> ${escapeHtml(data.source)}`,
    `<b>Имя:</b> ${escapeHtml(data.name)}`,
    `<b>Телефон:</b> ${escapeHtml(data.phone)}`,
    data.email ? `<b>Email:</b> ${escapeHtml(data.email)}` : null,
    data.message ? `<b>Сообщение:</b> ${escapeHtml(data.message)}` : null,
  ].filter(Boolean).join("\n");

  // Лимит Telegram — 4096 символов; длинное сообщение обрезаем (email/CRM получат полное).
  const text = rawText.length > 4000 ? rawText.slice(0, 4000) + "\n<i>...обрезано</i>" : rawText;

  const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: "HTML" }),
  });
  if (!res.ok) throw new Error(`Telegram ${res.status}: ${await res.text()}`);
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]!));
}
```

### Подготовка канала (один раз)

1. В Telegram: `@BotFather` → `/newbot` → имя + username → скопировать **HTTP API token** (`123456:AAEx...`) = `TG_BOT_TOKEN`.
2. Создать чат для лидов (личный / группа команды / канал), добавить туда бота.
3. Узнать `TG_CHAT_ID`:
   - Личный чат: написать `@userinfobot` → вернёт твой id (`123456789`).
   - Группа: отправить сообщение в группу → открыть `https://api.telegram.org/bot<TOKEN>/getUpdates` → `"chat":{"id":-100...}` (минусовое число).
   - Канал: бот — админ канала; id — `@channelusername` (public) или числовой из getUpdates.
4. В `.env`: `TG_BOT_TOKEN=...`, `TG_CHAT_ID=...` (с минусом для групп).
5. Тест: `pnpm dev` → форма → сообщение в чате с HTML-разметкой.

## SHEETS — Google Sheets

```bash
pnpm add googleapis
```

### `lib/sinks/sheets.ts`

```typescript
import { google } from "googleapis";
import { SinkSkipped, type LeadData } from "./index";

export async function sendToSheets(data: LeadData): Promise<void> {
  const email = process.env.GOOGLE_SHEETS_CLIENT_EMAIL;
  const key = process.env.GOOGLE_SHEETS_PRIVATE_KEY;
  const spreadsheetId = process.env.GOOGLE_SHEETS_SPREADSHEET_ID;
  if (!email || !key || !spreadsheetId) throw new SinkSkipped("GOOGLE_SHEETS_NOT_CONFIGURED");

  const auth = new google.auth.JWT({
    email,
    key: key.replace(/\\n/g, "\n"), // env экранирует "\n" — возвращаем настоящие переносы
    scopes: ["https://www.googleapis.com/auth/spreadsheets"],
  });

  const sheets = google.sheets({ version: "v4", auth });
  const tab = process.env.GOOGLE_SHEETS_TAB_NAME ?? "Leads";
  // Имя листа в кавычках — чтобы API принимал пробелы и кириллицу ("Лиды").
  const escapedTab = `'${tab.replace(/'/g, "''")}'`;

  await sheets.spreadsheets.values.append({
    spreadsheetId,
    range: `${escapedTab}!A:F`,
    valueInputOption: "USER_ENTERED",
    insertDataOption: "INSERT_ROWS",
    requestBody: {
      values: [[
        new Date().toISOString(),
        data.name, data.phone, data.email ?? "", data.message ?? "", data.source,
      ]],
    },
  });
}
```

### Подготовка канала (один раз)

1. Google Cloud Console → Create Project → APIs & Services → Enable **Google Sheets API**.
2. Credentials → Create Credentials → **Service Account** → скачать JSON-ключ.
3. Открыть таблицу → Share → добавить service-account-email из JSON как **Editor** (иначе 403).
4. Из JSON в `.env`:
   - `GOOGLE_SHEETS_CLIENT_EMAIL` = поле `client_email`.
   - `GOOGLE_SHEETS_PRIVATE_KEY` = поле `private_key`. **Обязательно в двойных кавычках с литеральными `\n`:**
     ```bash
     GOOGLE_SHEETS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
     ```
     Без двойных кавычек heredoc-парсер `PROD_ENV_FILE` на VPS обработает `\n` непредсказуемо → `PEM routines::no start line` / `invalid_grant: Invalid JWT Signature`.
5. `GOOGLE_SHEETS_SPREADSHEET_ID` — из URL: `docs.google.com/spreadsheets/d/<ВОТ-ЭТО>/edit`.
6. Опц. `GOOGLE_SHEETS_TAB_NAME` (дефолт `Leads`). В первой строке листа — заголовки: Дата, Имя, Телефон, Email, Сообщение, Источник.
7. Тест: `pnpm dev` → форма → свежая строка в таблице.

## AMOCRM — долгосрочный токен

Без OAuth-танца: server-to-server через **долгосрочный токен** (срок до 5 лет, лежит в `.env`, ротации не требует) — ровно под stateless-деплой.

### `lib/sinks/crm.ts`

```typescript
import { SinkSkipped, type LeadData } from "./index";

export async function sendToCRM(data: LeadData): Promise<void> {
  const url = process.env.AMO_CRM_URL;     // https://yourdomain.amocrm.ru (без / в конце)
  const token = process.env.AMO_CRM_TOKEN;
  if (!url || !token) throw new SinkSkipped("AMO_CRM_NOT_CONFIGURED");

  const pipelineId = process.env.AMO_CRM_PIPELINE_ID; // опц. — иначе первый этап главной воронки
  const statusId = process.env.AMO_CRM_STATUS_ID;

  // Preview сообщения в имени сделки — менеджер видит контекст без открытия.
  const preview = data.message ? ` — ${data.message.slice(0, 60)}${data.message.length > 60 ? "..." : ""}` : "";

  const lead: Record<string, unknown> = {
    name: `Заявка с сайта: ${data.source}${preview}`,
    _embedded: {
      contacts: [{
        name: data.name,
        custom_fields_values: [
          { field_code: "PHONE", values: [{ value: data.phone, enum_code: "WORK" }] },
          ...(data.email ? [{ field_code: "EMAIL", values: [{ value: data.email, enum_code: "WORK" }] }] : []),
        ],
      }],
    },
  };
  if (pipelineId) lead.pipeline_id = Number(pipelineId);
  if (statusId) lead.status_id = Number(statusId);

  const res = await fetch(`${url}/api/v4/leads/complex`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify([lead]),
  });
  if (!res.ok) throw new Error(`AmoCRM ${res.status}: ${await res.text()}`);

  // Полное сообщение — нотой к сделке. ВАЖНО: /leads/complex возвращает ПЛОСКИЙ
  // массив [{ id, contact_id, ... }], не { _embedded: { leads } }.
  if (data.message) {
    const created = (await res.json()) as Array<{ id: number }>;
    const leadId = created[0]?.id;
    if (leadId) {
      await fetch(`${url}/api/v4/leads/${leadId}/notes`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify([{ note_type: "common", params: { text: data.message } }]),
      }).catch(() => {/* нота не критична */});
    }
  }
}
```

### Подготовка канала (один раз)

1. amoCRM → amoMarket (в старых аккаунтах: Настройки → Интеграции) → «+ Создать интеграцию» → «Внешняя интеграция». Права — сделки + контакты на запись (или «Всё»).
2. Открыть интеграцию → «Ключи и доступы» → «Долгосрочный токен» → сгенерировать (срок — максимум, 5 лет) → скопировать = `AMO_CRM_TOKEN`.
3. `AMO_CRM_URL` = `https://yourdomain.amocrm.ru` (Kommo — `.kommo.com`), **без** слэша в конце.
4. Опц. маршрутизация: `AMO_CRM_PIPELINE_ID` / `AMO_CRM_STATUS_ID` — ID видны в настройках воронки (Сделки → шестерёнка) или `GET {URL}/api/v4/leads/pipelines` с тем же Bearer.
5. Тест: `pnpm dev` → форма → в amoCRM новая сделка с контактом и примечанием.

> **Безопасность.** Долгосрочный токен = доступ к аккаунту. Только `.env` / `PROD_ENV_FILE`, никогда в git и не `NEXT_PUBLIC_*`. Утёк — отозвать там же и сгенерировать новый.

## BITRIX24 — вебхук

### `lib/sinks/crm.ts`

```typescript
import { SinkSkipped, type LeadData } from "./index";

export async function sendToCRM(data: LeadData): Promise<void> {
  const hook = process.env.BITRIX_WEBHOOK_URL; // https://yourdomain.bitrix24.ru/rest/USER_ID/KEY/
  if (!hook) throw new SinkSkipped("BITRIX_NOT_CONFIGURED");

  const params = new URLSearchParams({
    "fields[TITLE]": `Заявка: ${data.source}`,
    "fields[NAME]": data.name,
    "fields[PHONE][0][VALUE]": data.phone,
    "fields[PHONE][0][VALUE_TYPE]": "WORK",
    "fields[SOURCE_ID]": "WEB",
  });
  if (data.email) params.append("fields[EMAIL][0][VALUE]", data.email);
  if (data.message) params.append("fields[COMMENTS]", data.message); // пустой COMMENTS не слать

  // POST, не GET: длинные комментарии (>2KB) упираются в URL-лимит у proxy.
  const res = await fetch(`${hook}crm.lead.add.json`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params,
  });
  if (!res.ok) throw new Error(`Bitrix ${res.status}: ${await res.text()}`);
}
```

### Подготовка канала (один раз)

1. Битрикс24 → Разработчикам → Другое → **Входящий вебхук** → права: CRM. Скопировать URL вида `https://yourdomain.bitrix24.ru/rest/USER_ID/WEBHOOK_KEY/` = `BITRIX_WEBHOOK_URL`.
2. Тест: `pnpm dev` → форма → лид в CRM → Лиды.

## Другие CRM (YClients, RetailCRM, кастомные)

Тот же паттерн: REST POST с `Authorization`-header или вебхук-URL, ключи в `.env`, guard `SinkSkipped`. Несколько CRM одновременно — раздели на `lib/sinks/<crm-name>.ts` и добавь все в `allSinks`.

## Turnstile — заведение и тест-ключи

Клиент: `pnpm add @marsidev/react-turnstile` (обёртка официального JS API: ленивая загрузка, ref для `reset()`).

Заведение (человек, один раз): Cloudflare Dashboard → Turnstile → Add Site → Domain: production-домен + `localhost` → Widget Mode: **Managed** → скопировать **Site Key** (публичный, `NEXT_PUBLIC_TURNSTILE_SITE_KEY`) и **Secret Key** (`TURNSTILE_SECRET_KEY`, только серверный).

Тестовые ключи Cloudflare (для `.env.local` до получения боевых и для e2e):

- Site key `1x00000000000000000000AA` — всегда проходит на клиенте.
- Secret key `1x0000000000000000000000000000000AA` — всегда `success: true` на сервере.

Грабли: токен одноразовый — забыл `reset()` после submit → `timeout-or-duplicate` (400) на втором сабмите.

# Forms & Leads

Архитектура форм: валидация → Server Action → антиспам → **multi-sink доставка** (Email / Telegram / Sheets / CRM) → fallback. Здесь — ядро. Полные листинги каналов и чек-листы подключения — `docs/forms-sink-recipes.md` (читай только раздел подключаемого канала).

## Архитектура

```
[Форма + useActionState + <Turnstile />] → <form action={formAction}> → [app/actions/submit-lead.ts ('use server')]
   ├─ Honeypot (скрытое поле заполнено → молча return { success: true })
   ├─ Rate limit (6 req / мин / IP)
   ├─ Zod 4 validate → Turnstile verify (siteverify) → fail → return { error }
   └─ Promise.allSettled([ sendToEmail, sendToTelegram, sendToSheets, sendToCRM ])
          ├─ хоть один success → лид доставлен
          ├─ все skipped (нет env) → appendFallback() + console.warn
          └─ все failed (env есть, API упали) → appendFallback() + console.error
   → пользователю ВСЕГДА { success: true } (fallback страхует)
```

Принципы:

- **Multi-sink через `Promise.allSettled`** — каналы независимы, вызываются параллельно.
- **Skip vs fail.** Нет ключей в env → sink бросает `SinkSkipped` (не ошибка). Ключи есть, API упал → failure (лог + fallback, если других success нет).
- **Server Action, не Route Handler.** Endpoint `/api/lead` не создаётся: меньше кода, `useActionState` типизирует ответ, `<form action>` работает без JS.
- **Секреты только в `process.env.*` внутри Server Action** — никогда в клиентском коде.
- **Turnstile verify ДО sinks** — бесплатный CAPTCHA-аналог Cloudflare, режим Managed — большинство посетителей проходит без интеракции; токен одноразовый (после submit — `reset()`). Заведение и тест-ключи — `forms-sink-recipes.md` § Turnstile.
- **Honeypot** — скрытое поле `company`: люди его не видят, боты заполняют. Заполнено → молча «успех».

## Какой sink когда

| Канал | Когда | Env |
|---|---|---|
| **Email** (nodemailer + SMTP Яндекса) | **Дефолт, подключается первым — в день запуска форм** | `SMTP_USER`, `SMTP_PASS`, `LEAD_EMAIL_TO` |
| Telegram (голый fetch на Bot API) | Уведомления в чат команды «не пропустить заявку» | `TG_BOT_TOKEN`, `TG_CHAT_ID` |
| Google Sheets | Заказчик хочет реестр лидов в таблице | `GOOGLE_SHEETS_*` |
| AmoCRM / Bitrix24 | У заказчика есть CRM и процессы в ней | `AMO_CRM_*` / `BITRIX_WEBHOOK_URL` |

## Структура `lib/`

```
lib/
├── fallback.ts         ← JSONL-fallback в LEADS_DIR
├── rate-limit.ts       ← in-memory, 6/мин/IP
└── sinks/
    ├── index.ts        ← LeadData, SinkSkipped, allSinks, classifySinkResults
    ├── email.ts        ← листинг: forms-sink-recipes.md § EMAIL
    ├── telegram.ts     ← § TELEGRAM
    ├── sheets.ts       ← § SHEETS
    └── crm.ts          ← stub (SinkSkipped) до подключения CRM; § AMOCRM / § BITRIX24
```

### `lib/sinks/index.ts` — диспетчер

```typescript
import { sendToEmail } from "./email";
import { sendToTelegram } from "./telegram";
import { sendToSheets } from "./sheets";
import { sendToCRM } from "./crm";

export type LeadData = { name: string; phone: string; email?: string; message?: string; source: string };

export class SinkSkipped extends Error {
  constructor(reason: string) { super(reason); this.name = "SinkSkipped"; }
}

export const allSinks = [sendToEmail, sendToTelegram, sendToSheets, sendToCRM] as const;

export function classifySinkResults(results: PromiseSettledResult<unknown>[]) {
  const successes = results.filter((r) => r.status === "fulfilled");
  const skips = results.filter((r) => r.status === "rejected" && r.reason instanceof SinkSkipped);
  const failures = results.filter((r) => r.status === "rejected" && !(r.reason instanceof SinkSkipped));
  return { successes, skips, failures };
}
```

### `lib/rate-limit.ts` — 6 запросов в минуту с IP

```typescript
// In-memory sliding window. Достаточно для single-instance PM2; при cluster-mode лимит нестрогий, но Turnstile + fallback страхуют.
const hits = new Map<string, number[]>();
const WINDOW_MS = 60_000, LIMIT = 6;

export function rateLimit(ip: string): boolean {
  const now = Date.now();
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (recent.length >= LIMIT) { hits.set(ip, recent); return false; }
  recent.push(now); hits.set(ip, recent);
  if (hits.size > 1000) for (const [k, v] of hits) if (v.every((t) => now - t >= WINDOW_MS)) hits.delete(k);
  return true;
}
```

### `lib/fallback.ts` — JSONL в `LEADS_DIR`

```typescript
import { promises as fs } from "fs";
import path from "path";
import type { LeadData } from "./sinks";

// LEADS_DIR: локально не задан → ./data; на VPS = /home/deploy/prod/{site}/shared/data (абсолютный путь ВНЕ releases/ — деплой её не трогает).
const DIR = process.env.LEADS_DIR ?? path.join(process.cwd(), "data");

export async function appendFallback(data: LeadData): Promise<void> {
  await fs.mkdir(DIR, { recursive: true });
  const line = JSON.stringify({ ...data, savedAt: new Date().toISOString() });
  await fs.appendFile(path.join(DIR, "leads.jsonl"), line + "\n", "utf-8");
}
```

- `appendFile` — одна строка на лид, без read-modify-write гонок; файл никогда не коммитится (в `.gitignore`: `data/` — там ПДн). Чтение на VPS: `ssh deploy@vps 'cat ~/prod/{site}/shared/data/leads.jsonl'`; перед декомиссией сервера — выгрузить (см. runbook, спека 12).

## Server Action

```typescript
// app/actions/submit-lead.ts
"use server";
import { headers } from "next/headers";
import { z } from "zod";
import { rateLimit } from "@/lib/rate-limit";
import { appendFallback } from "@/lib/fallback";
import { allSinks, classifySinkResults } from "@/lib/sinks";

const schema = z.object({
  name: z.string().min(2).max(200),
  phone: z.string().min(10).max(30),
  email: z.email({ error: "Некорректный email" }).optional(),
  message: z.string().max(3000).optional(),
  source: z.string().max(100),
  consent: z.literal(true, { error: "Требуется согласие" }),
  turnstileToken: z.string().min(1),
});

export type LeadState = { success: true } | { error: string } | null;

export async function submitLead(_prev: LeadState, formData: FormData): Promise<LeadState> {
  if (formData.get("company")) return { success: true }; // honeypot

  const ip = (await headers()).get("x-forwarded-for") ?? "unknown";
  if (!rateLimit(ip)) return { error: "Слишком много запросов. Подождите минуту." };

  const raw = Object.fromEntries(formData);
  const parsed = schema.safeParse({ ...raw, consent: raw.consent === "on" || raw.consent === "true", email: raw.email || undefined });
  if (!parsed.success) return { error: "Проверьте поля формы" };

  // Turnstile verify ДО sinks
  const verify = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ secret: process.env.TURNSTILE_SECRET_KEY!, response: parsed.data.turnstileToken, remoteip: ip }),
  });
  if (!((await verify.json()) as { success: boolean }).success) return { error: "Защита от спама не пройдена" };

  const { turnstileToken: _t, consent: _c, ...leadData } = parsed.data;
  const results = await Promise.allSettled(allSinks.map((sink) => sink(leadData)));
  const { successes, skips, failures } = classifySinkResults(results);

  if (failures.length > 0) console.error("Lead sink failures:", failures.map((f) => (f as PromiseRejectedResult).reason));
  if (successes.length === 0) {
    await appendFallback(leadData);
    if (skips.length === allSinks.length) console.warn("All lead sinks are not configured — leads go to LEADS_DIR/leads.jsonl only.");
  }
  return { success: true }; // пользователю всегда success — fallback страхует
}
```

## Клиентская часть (суть)

RHF — только inline-валидация полей (`mode: 'onBlur'`), submit обрабатывает Server Action.

```tsx
"use client";
const [state, formAction, isPending] = useActionState<LeadState, FormData>(submitLead, null);
// useEffect(state): success → toast.success + turnstileRef.current?.reset() + setToken(""); error → toast.error

<form action={formAction}>
  <input {...register("name")} name="name" />  {/* + phone и остальные поля */}
  {/* honeypot: вне вкладки и скринридера; класс НЕ "adv*" — режется адблоками */}
  <input name="company" tabIndex={-1} autoComplete="off" aria-hidden="true" className="absolute -left-[9999px]" />
  <input type="hidden" name="source" value="contact-form" />
  <input type="hidden" name="turnstileToken" value={token} />
  <Turnstile ref={turnstileRef} siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY!} onSuccess={setToken} />
  <label><Checkbox name="consent" required /> Согласен на <a href="/consent/">обработку ПДн</a></label>
  <button type="submit" disabled={isPending || !token}>{isPending ? "Отправляем..." : "Отправить"}</button>
</form>
```

Клиент не знает про sinks — это внутренняя кухня сервера. Toast — Sonner. Глобальная модалка консультации — context-паттерн, см. `docs/architecture.md` § Server/Client разделение (CTA-кнопку извлекай в свой client-компонент).

## Обязательные блоки формы (152-ФЗ)

1. Чекбокс согласия со ссылкой на `/consent/` (согласие на обработку ПДн).
2. Ссылка на `/privacy/` (политика конфиденциальности) рядом с submit.
3. Cookie-баннер на сайте (выбор в `localStorage`).

Тексты и канон страниц (`/privacy/`, `/consent/`, `/offer/` — только при оплате; внутренние ссылки — с trailing slash) — `docs/legal-templates.md`.

## Мониторинг лидов в проде

```bash
ssh deploy@{vps-ip} "pm2 logs {site}-prod --lines 100" | grep -i "sink\|lead"   # ошибки sinks
ssh deploy@{vps-ip} "tail ~/prod/{site}/shared/data/leads.jsonl"                # fallback растёт → все sinks падают
# каждый канал проверить независимо: ящик / чат / таблица / CRM; Turnstile-статистика — Cloudflare Dashboard → Turnstile
```

Один канал упал — нормально, лид ушёл в другие. Все упали — `leads.jsonl` страхует, после починки добить лиды в каналы вручную.

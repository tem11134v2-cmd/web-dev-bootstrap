# Forms & CRM

Архитектура форм, валидация, CRM-интеграции, fallback, согласие на ПДн.

## Архитектура

```
[React Hook Form + Zod + <Turnstile />]
        │  POST /api/lead { name, phone, email?, message?, consent: true, turnstileToken }
        ▼
[/api/lead/route.ts]
   ├─ Zod validate (server-side, дублирует клиент)
   ├─ Rate limit (1 req / 10s / IP)
   ├─ Turnstile verify (challenges.cloudflare.com/turnstile/v0/siteverify)
   │      └─ fail → 400 { error: "Captcha failed" }
   ├─ POST в CRM (try)
   │      └─ ok → 200 { success: true }
   └─ catch / CRM down
          └─ append data/leads.json → 200 { success: true, fallback: true }
```

Принципы:
- **Один endpoint** на все формы (`/api/lead`) — поле `source` различает откуда пришло.
- **Fallback в JSON** — если CRM упала, лиды не теряются. Файл `data/leads.json` в `.gitignore`.
- **Никаких ключей CRM в клиентском коде** — только в `process.env.*` на сервере.
- **Антиспам через Cloudflare Turnstile** — токен с клиента проверяется на сервере **до** обращения к CRM (см. ниже). Без валидного токена лид не уходит ни в CRM, ни в fallback.

## Клиентская часть

```typescript
// components/forms/ContactForm.tsx
"use client";
import { useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Turnstile, type TurnstileInstance } from "@marsidev/react-turnstile";

const schema = z.object({
  name: z.string().min(2, "Минимум 2 символа"),
  phone: z.string().min(10, "Некорректный телефон"),
  email: z.string().email("Некорректный email").optional(),
  message: z.string().optional(),
  consent: z.literal(true, { errorMap: () => ({ message: "Требуется согласие" }) }),
});

const turnstileRef = useRef<TurnstileInstance | null>(null);
const [token, setToken] = useState<string>("");

const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm({
  resolver: zodResolver(schema),
  mode: "onBlur",
});

const onSubmit = async (data) => {
  if (!token) {
    toast.error("Подтвердите, что вы не робот.");
    return;
  }
  const res = await fetch("/api/lead", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...data, source: "contact-form", turnstileToken: token }),
  });
  if (res.ok) toast.success("Заявка отправлена!");
  else toast.error("Ошибка отправки. Попробуйте ещё раз.");
  turnstileRef.current?.reset(); // одноразовый токен — переполучаем для следующего submit
  setToken("");
};

// Внутри JSX, рядом с submit:
<Turnstile
  ref={turnstileRef}
  siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY!}
  onSuccess={setToken}
  options={{ theme: "light", size: "flexible" }}
/>;
```

Чекбокс согласия на ПДн — обязателен (см. `docs/legal-templates.md`). Без него форма не отправляется.

## API Route

```typescript
// app/api/lead/route.ts
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { sendToCRM } from "@/lib/crm";
import { appendFallback } from "@/lib/fallback";
import { rateLimit } from "@/lib/rate-limit";

const schema = z.object({
  name: z.string().min(2),
  phone: z.string().min(10),
  email: z.string().email().optional(),
  message: z.string().optional(),
  source: z.string(),
  consent: z.literal(true),
  turnstileToken: z.string().min(1),
});

export async function POST(req: NextRequest) {
  const ip = req.headers.get("x-forwarded-for") ?? "unknown";
  if (!rateLimit(ip, 1, 10_000)) {
    return NextResponse.json({ error: "Too many requests" }, { status: 429 });
  }

  const body = await req.json();
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid data" }, { status: 400 });
  }

  // Turnstile verify ДО CRM, иначе бот успеет создать лид если CRM ляжет в fallback
  const verify = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      secret: process.env.TURNSTILE_SECRET_KEY!,
      response: parsed.data.turnstileToken,
      remoteip: ip,
    }),
  });
  const result = (await verify.json()) as { success: boolean; "error-codes"?: string[] };
  if (!result.success) {
    return NextResponse.json({ error: "Captcha failed" }, { status: 400 });
  }

  try {
    await sendToCRM(parsed.data);
  } catch (err) {
    console.error("CRM error", err);
    await appendFallback(parsed.data);
  }
  return NextResponse.json({ success: true });
}
```

## CRM-интеграции (готовые шаблоны)

### AmoCRM

```typescript
// lib/crm/amo.ts
const AMO_URL = process.env.AMO_CRM_URL!;     // https://yourdomain.amocrm.ru
const AMO_TOKEN = process.env.AMO_CRM_TOKEN!; // long-lived integration token

export async function createAmoLead(data: LeadData) {
  const res = await fetch(`${AMO_URL}/api/v4/leads/complex`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${AMO_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify([{
      name: `Заявка с сайта: ${data.source}`,
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
  if (!res.ok) throw new Error(`AmoCRM ${res.status}: ${await res.text()}`);
  return res.json();
}
```

### Bitrix24 (вебхук)

```typescript
// lib/crm/bitrix.ts
const BITRIX_HOOK = process.env.BITRIX_WEBHOOK_URL!;
// https://yourdomain.bitrix24.ru/rest/USER_ID/WEBHOOK_KEY/

export async function createBitrixLead(data: LeadData) {
  const params = new URLSearchParams({
    "fields[TITLE]": `Заявка: ${data.source}`,
    "fields[NAME]": data.name,
    "fields[PHONE][0][VALUE]": data.phone,
    "fields[PHONE][0][VALUE_TYPE]": "WORK",
    "fields[SOURCE_ID]": "WEB",
    "fields[COMMENTS]": data.message ?? "",
  });
  if (data.email) params.append("fields[EMAIL][0][VALUE]", data.email);

  const res = await fetch(`${BITRIX_HOOK}crm.lead.add.json?${params}`);
  if (!res.ok) throw new Error(`Bitrix ${res.status}`);
  return res.json();
}
```

### YClients, RetailCRM, кастомный

Похожие паттерны: REST POST с `Authorization` header или вебхук-URL. Ключ всегда в `.env`. При интеграции — сохрани соответствие полей в `lib/crm/<name>.ts` и точку входа в `lib/crm/index.ts` (`sendToCRM` диспетчер по `process.env.CRM_PROVIDER`).

## Антиспам — Cloudflare Turnstile

Turnstile — бесплатный CAPTCHA-аналог от Cloudflare. По умолчанию **invisible** (без UX-трения), при подозрительном трафике сам показывает managed-чекбокс. Без VPN-блокировок (в отличие от reCAPTCHA), без вендор-лока на Google.

### Заведение виджета

1. Cloudflare Dashboard → **Turnstile** → **Add Site**.
2. Domain: production-домен сайта + `localhost` (для локальной разработки).
3. Widget Mode: **Managed** (рекомендуется — Cloudflare сам решает invisible/checkbox по риск-скору). Альтернативы: «Non-Interactive» (всегда invisible) и «Invisible» (без чекбокса даже если трафик подозрительный).
4. Скопируй **Site Key** (публичный, идёт в клиент) и **Secret Key** (серверный).
5. Если у заказчика уже есть Cloudflare-аккаунт под DNS/proxy (см. `docs/domain-connect.md`) — добавляй Turnstile-сайт там же. Если нет — отдельная регистрация (бесплатно).

### Переменные окружения

```bash
# .env (на сервере, в .gitignore)
NEXT_PUBLIC_TURNSTILE_SITE_KEY=0x4AAAAAAAxxxxxxxxxxxx
TURNSTILE_SECRET_KEY=0x4AAAAAAAyyyyyyyyyyyy
```

```bash
# .env.example (в git, без значений)
NEXT_PUBLIC_TURNSTILE_SITE_KEY=
TURNSTILE_SECRET_KEY=
```

`NEXT_PUBLIC_*` — единственное `NEXT_PUBLIC_` значение в формах: site-key публичный по дизайну Cloudflare. Secret-key — **никогда** не `NEXT_PUBLIC_`.

### Клиент — `@marsidev/react-turnstile`

```bash
pnpm add @marsidev/react-turnstile
```

Обёртка над официальным Turnstile JS API: ленивая загрузка скрипта, ref для `reset()`/`getResponse()`, `onSuccess`/`onError`/`onExpire` колбэки. Полный пример встроен в `components/forms/ContactForm.tsx` выше.

Ключевые моменты:
- Токен **одноразовый** — после успешного submit вызови `turnstileRef.current?.reset()` и обнули локальный state. Иначе следующий submit отправит тот же токен → 400 от Cloudflare.
- `siteKey` читай из `process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY` (не хардкодь).
- На submit-кнопке проверь `if (!token) return` — без токена не идём на сервер вообще.

### Сервер — verify ДО CRM

Серверная проверка делается **до** отправки в CRM (см. полный код в разделе «API Route» выше). Почему до:
1. Если CRM лежит и срабатывает fallback в `data/leads.json` — без verify бот успеет насыпать туда мусора.
2. Семантика 400 «captcha failed» отличается от 500 «CRM down» — клиент покажет правильный toast.

Тело запроса к Cloudflare — **`application/x-www-form-urlencoded`** (не JSON!), это требование API. Параметр `remoteip` опционален, но Cloudflare использует его в риск-скоринге.

Ответ:
```json
{ "success": true, "challenge_ts": "...", "hostname": "...", "action": "..." }
// либо
{ "success": false, "error-codes": ["timeout-or-duplicate", ...] }
```

Список `error-codes`: https://developers.cloudflare.com/turnstile/get-started/server-side-validation/#error-codes — самая частая проблема в проде это `timeout-or-duplicate` (токен переиспользован — фикс на клиенте через `reset()`).

### Локальная разработка без виджета

В Cloudflare есть тестовые ключи (https://developers.cloudflare.com/turnstile/troubleshooting/testing/):
- Site key `1x00000000000000000000AA` всегда проходит на клиенте.
- Secret key `1x0000000000000000000000000000000AA` всегда возвращает `success: true` на сервере.
- Полезно в `.env.local` пока не получили боевые ключи или в e2e-тестах.

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
- Loading state на кнопке (`disabled` + spinner) во время `isSubmitting`.

## Обязательные блоки в любой форме на RU-сайте

1. Чекбокс «Я согласен на обработку персональных данных» с ссылкой на «Согласие на обработку ПДн».
2. Ссылка на «Политику конфиденциальности» рядом с кнопкой submit.
3. Cookie-баннер на сайте (один раз показывается, сохраняется выбор в `localStorage`).

Готовые тексты — `docs/legal-templates.md`.

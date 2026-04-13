# Forms & CRM

Архитектура форм, валидация, CRM-интеграции, fallback, согласие на ПДн.

## Архитектура

```
[React Hook Form + Zod]
        │  POST /api/lead { name, phone, email?, message?, consent: true }
        ▼
[/api/lead/route.ts]
   ├─ Zod validate (server-side, дублирует клиент)
   ├─ Rate limit (1 req / 10s / IP)
   ├─ POST в CRM (try)
   │      └─ ok → 200 { success: true }
   └─ catch / CRM down
          └─ append data/leads.json → 200 { success: true, fallback: true }
```

Принципы:
- **Один endpoint** на все формы (`/api/lead`) — поле `source` различает откуда пришло.
- **Fallback в JSON** — если CRM упала, лиды не теряются. Файл `data/leads.json` в `.gitignore`.
- **Никаких ключей CRM в клиентском коде** — только в `process.env.*` на сервере.

## Клиентская часть

```typescript
// components/forms/ContactForm.tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

const schema = z.object({
  name: z.string().min(2, "Минимум 2 символа"),
  phone: z.string().min(10, "Некорректный телефон"),
  email: z.string().email("Некорректный email").optional(),
  message: z.string().optional(),
  consent: z.literal(true, { errorMap: () => ({ message: "Требуется согласие" }) }),
});

const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm({
  resolver: zodResolver(schema),
  mode: "onBlur",
});

const onSubmit = async (data) => {
  const res = await fetch("/api/lead", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...data, source: "contact-form" }),
  });
  if (res.ok) toast.success("Заявка отправлена!");
  else toast.error("Ошибка отправки. Попробуйте ещё раз.");
};
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

# Spec 09: Формы, CRM, юридическое (152-ФЗ)

## KB files to read first

- docs/forms-and-crm.md (полностью, включая раздел «Антиспам — Cloudflare Turnstile»)
- docs/legal-templates.md (152-ФЗ: cookie-баннер, согласие на ПДн)
- docs/integrations.md (какая CRM, какие поля)
- docs/spec.md (контакты заказчика)
- docs/domain-connect.md (если у заказчика уже есть Cloudflare-аккаунт под DNS — Turnstile там же)
- `components/forms/ConsultationDialog.tsx` (заглушка из спеки 04)
- `components/service-page/ServicePageForms.tsx` (заглушки из спеки 05)

## Goal

Заменить заглушки форм реальной интеграцией: валидация → Server Action → Turnstile verify → CRM → fallback. Добавить юридическое: cookie-баннер по 152-ФЗ, согласие на обработку ПДн в формах, страницы политики/оферты с готовыми текстами от пользователя.

> **Про Server Action vs Route Handler.** Лиды отправляются через Server Action `app/actions/submit-lead.ts`, **не** через Route Handler `app/api/lead/route.ts`. Endpoint `/api/lead` не создаётся. Формы работают через `useActionState` + `<form action={formAction}>` — без `fetch`, с прогрессивным улучшением (форма работает даже при выключенном JS) и с CSRF-защитой Next из коробки. Полный пример — в `docs/forms-and-crm.md` § «Server Action».

## Tasks

### 1. Cloudflare Turnstile (антиспам — делается до подключения форм)

1. Cloudflare Dashboard → Turnstile → Add Site. Domain: production-домен + `localhost`. Widget Mode: **Managed**. Скопировать **Site Key** + **Secret Key**.
2. Положить ключи в `.env` на Mac (для `pnpm dev`) и в `.env` на сервере:
   ```
   NEXT_PUBLIC_TURNSTILE_SITE_KEY=...
   TURNSTILE_SECRET_KEY=...
   ```
   В `.env.example` (в git) — те же строки без значений. Site-key — единственное `NEXT_PUBLIC_` в формах (публичный по дизайну Cloudflare). Secret-key — **никогда** не `NEXT_PUBLIC_`.
3. Установить клиент: `pnpm add @marsidev/react-turnstile`. Документация — https://developers.cloudflare.com/turnstile/, паттерн интеграции — раздел «Антиспам — Cloudflare Turnstile» в `docs/forms-and-crm.md`.

### 2. Server Action

4. Создать `app/actions/submit-lead.ts` с директивой `"use server"`:
   - Сигнатура `submitLead(prevState, formData: FormData) → LeadState` (тип `LeadState = { success: true } | { error: string } | null`)
   - Rate limiting: 1 запрос / 10 секунд / IP (через `Map<ip, timestamp>` в памяти или `next-rate-limit`). IP читается из `(await headers()).get('x-forwarded-for')`
   - Парсинг FormData → объект → Zod-валидация (схема включает `turnstileToken: z.string().min(1)`). Чекбокс `consent` приходит как строка `"on"` — приводим к boolean **до** `safeParse`
   - **Turnstile verify ДО CRM** — POST на `https://challenges.cloudflare.com/turnstile/v0/siteverify` (тело `application/x-www-form-urlencoded`, не JSON), при `result.success === false` — `return { error: "Защита от спама не пройдена" }`. См. готовый код в `docs/forms-and-crm.md` § Server Action
   - Отправка в CRM (через `lib/crm.ts`)
   - Fallback: если CRM недоступна → запись в `data/leads.json`, всё равно `return { success: true }`
   - Возврат `{ success: true }` или `{ error: '...' }`. **Никаких** `NextResponse.json()` — это Server Action, не Route Handler
5. Создать `lib/crm.ts` под выбранную CRM:
   - **AMO CRM:** POST на `/api/v4/leads/complex` с Bearer токеном
   - **Bitrix24:** POST на webhook URL
   - **Другая:** уточнить у пользователя API
6. Все секреты — в `.env`:
   ```
   AMO_CRM_URL=...
   AMO_CRM_TOKEN=...
   ```

### 3. Подключение к формам

7. В `components/forms/ConsultationDialog.tsx`:
   - Реальная валидация (Zod-схема: name min 2, phone min 10, опционально email/message). Поскольку форма теперь идёт через `<form action={formAction}>`, RHF используется только для inline-валидации полей (`mode: 'onBlur'`) — submit обрабатывает Server Action.
   - `<Turnstile />` виджет (см. пример в `docs/forms-and-crm.md` § Клиентская часть): `siteKey` из `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `onSuccess={setToken}`, ref для `reset()` после успешного state (токен одноразовый — иначе `timeout-or-duplicate` от CF)
   - `useActionState(submitLead, null)` → `[state, formAction, isPending]`. `<form action={formAction}>`. Turnstile-токен и `source` идут как hidden-инпуты внутри формы.
   - Кнопка `disabled={isPending || !token}` — без токена submit невозможен.
   - Реакция на `state` через `useEffect`: `state.success` → toast зелёный + `turnstileRef.current?.reset()`, `state.error` → toast красный.
8. В `components/service-page/ServicePageForms.tsx` — то же для inline mid/final CTA (включая `<Turnstile />`)
9. Добавить в каждую форму **чекбокс согласия на обработку ПДн** (компонент `components/legal/PdnConsent.tsx`):
   ```tsx
   <Checkbox required />
   <span className="text-xs">Согласен с <a href="/privacy/">политикой конфиденциальности</a></span>
   ```

### 4. Cookie-баннер (152-ФЗ)

10. Создать `components/legal/CookieBanner.tsx` (client) — текст из `docs/legal-templates.md`:
    - Появляется снизу при первом визите
    - Кнопки «Принять» / «Подробнее» (ссылка на /privacy/)
    - localStorage-флаг чтобы не показывать повторно
    - Не блокирует контент (баннер, не модалка)
11. Подключить в `app/layout.tsx`

### 5. Юридические страницы

12. Создать `app/privacy/page.tsx` — текст политики конфиденциальности (пользователь приносит готовый из генератора, вставляем как есть, оборачиваем в `prose`)
13. Создать `app/terms/page.tsx` — оферта/условия (если применимо, иначе пропустить)
14. Обе страницы:
    - `metadata: { robots: { index: false, follow: true } }` — обычно не индексируются
    - Простой server component с prose-стилями
15. Обновить `components/layout/Footer.tsx` — добавить ссылки на `/privacy/` и `/terms/` (страницы только что созданы, и кука-баннер из шага 10 уже на них ссылается)

### 6. Тестирование

16. Локально — заполнить форму, отправить, проверить:
    - Turnstile-виджет показывается, после прохождения токен попадает в payload
    - Лид появился в CRM (если есть тестовый аккаунт)
    - При ошибке CRM — лид появился в `data/leads.json`
    - Toast показал результат
    - Чекбокс ПДн обязателен (без него submit blocked)
17. Turnstile-edge-кейсы:
    - Submit без прохождения виджета → toast «Подтвердите, что вы не робот», на сервер не идём
    - Двойной submit с одним токеном → 400 «Captcha failed» (`error-codes: timeout-or-duplicate`) — значит, `reset()` после успешного submit не вызывается, фикс в форме
18. Cookie-баннер появляется на чистом браузере, исчезает после «Принять», не возвращается
19. Rate limiting — два быстрых submit с одного IP → второй вернёт ошибку
20. `pnpm build` проходит, .env переменные не попали в клиентский бандл (не использовать `NEXT_PUBLIC_` для секретов, кроме `NEXT_PUBLIC_TURNSTILE_SITE_KEY` — он публичный по дизайну)

### 7. Деплой

21. На сервере — добавить `.env` с реальными секретами (если нет — создать). Включает `TURNSTILE_SECRET_KEY` и `NEXT_PUBLIC_TURNSTILE_SITE_KEY`.
22. `chmod 600 .env`, владелец `deploy`
23. Push в `dev` → проверка на preview → PR в `main` → автодеплой через GitHub Actions
24. На проде — отправить тестовую заявку, убедиться что доходит в CRM

## Boundaries

- **Always:** валидация И на клиенте И на сервере (Zod в обоих местах), секреты в .env, согласие на ПДн обязательно, Turnstile verify ДО CRM (не после — иначе бот успеет насыпать в fallback при падающей CRM)
- **Ask first:** если CRM требует нестандартного маппинга полей, если у заказчика нет готовой политики/оферты (предложить шаблонные генераторы)
- **Never:** коммитить .env, класть `TURNSTILE_SECRET_KEY` в `NEXT_PUBLIC_*`, отправлять данные без согласия на ПДн, делать exit-intent попап на мобильном

## Done when

- `app/actions/submit-lead.ts` существует, валидирует, проверяет Turnstile-токен, шлёт в CRM, имеет fallback. Файла `app/api/lead/route.ts` в проекте **нет**.
- Все формы (consultation dialog, mid/final CTA на странице услуги) работают на проде через Server Action с виджетом Turnstile
- Cookie-баннер показывается, юридические страницы доступны
- Согласие на ПДн обязательно во всех формах
- Тестовая заявка доехала до CRM на проде; submit без Turnstile-токена корректно отклоняется

## Memory updates

- `references.md` — название CRM, URL, контакт ответственного, путь к .env (без значений), Cloudflare-аккаунт где заведён Turnstile-сайт
- `pointers.md` — `app/actions/submit-lead.ts`, `lib/crm.ts`, `components/legal/*`, Turnstile-виджет в формах (где встроен)
- `decisions.md` — выбор CRM, нюансы маппинга, источник политики (генератор / юрист заказчика), Turnstile mode (Managed vs Invisible) если отступали от дефолта
- `lessons.md` — если что-то сломалось при интеграции (CRS, токены, `timeout-or-duplicate` от Turnstile, и т.д.)
- `project_state.md` — done, следующая `10-analytics`

# Spec 09: Формы, multi-sink доставка лидов, юридическое (152-ФЗ)

## KB files to read first

- docs/forms-and-crm.md (полностью — multi-sink архитектура, Server Action, Turnstile, готовые sinks)
- docs/legal-templates.md (152-ФЗ: cookie-баннер, согласие на ПДн)
- docs/integrations.md (какие sinks подключаем у этого заказчика)
- docs/spec.md (контакты заказчика)
- docs/domain-connect.md (если у заказчика уже есть Cloudflare-аккаунт под DNS — Turnstile там же)
- `components/forms/ConsultationDialog.tsx` (заглушка из спеки 04)
- `components/service-page/ServicePageForms.tsx` (заглушки из спеки 05)

## Goal

Заменить заглушки форм реальной интеграцией: валидация → Server Action → Turnstile verify → **multi-sink доставка** (Sheets / Telegram / CRM) с graceful skip каналов без credentials и fallback в JSON если все упали. Добавить юридическое: cookie-баннер по 152-ФЗ, согласие на обработку ПДн в формах, страницы политики/оферты.

> **Ключевая идея архитектуры.** Лид параллельно уходит во все настроенные каналы через `Promise.allSettled`. Каналы независимы: Telegram упал — Sheets всё равно записал. Канал не настроен (нет env) — silently skipped, не считается ошибкой. Все упали → fallback в `data/leads.json` (страховка). Подробности — в `docs/forms-and-crm.md`, читай этот файл целиком перед началом работы.

> **Про Server Action vs Route Handler.** Лиды отправляются через Server Action `app/actions/submit-lead.ts`, **не** через Route Handler `app/api/lead/route.ts`. Endpoint `/api/lead` не создаётся. Формы работают через `useActionState` + `<form action={formAction}>` — без `fetch`, с прогрессивным улучшением и CSRF-защитой Next из коробки.

## Tasks

### 1. Cloudflare Turnstile (антиспам — делается до подключения форм)

1. Cloudflare Dashboard → Turnstile → Add Site. Domain: production-домен + `localhost`. Widget Mode: **Managed**. Скопировать **Site Key** + **Secret Key**.
2. Положить ключи в `.env` на Mac:
   ```
   NEXT_PUBLIC_TURNSTILE_SITE_KEY=...
   TURNSTILE_SECRET_KEY=...
   ```
   В `.env.example` (в git) — те же строки без значений. Site-key — единственное `NEXT_PUBLIC_` в формах. Secret-key — **никогда** не `NEXT_PUBLIC_`.
3. Установить клиент: `pnpm add @marsidev/react-turnstile`. Документация — https://developers.cloudflare.com/turnstile/, паттерн интеграции — раздел «Антиспам — Cloudflare Turnstile» в `docs/forms-and-crm.md`.

### 2. Создать структуру `lib/sinks/`

4. Установить серверные зависимости:
   ```bash
   pnpm add googleapis node-telegram-bot-api
   pnpm add -D @types/node-telegram-bot-api
   ```

5. Создать `lib/sinks/index.ts` — диспетчер с `LeadData`-типом, классом `SinkSkipped`, массивом `allSinks` и helper'ом `classifySinkResults`. Полный код — в `docs/forms-and-crm.md` § «`lib/sinks/index.ts` — диспетчер».

6. Создать `lib/sinks/sheets.ts`, `lib/sinks/telegram.ts`, `lib/sinks/crm.ts` — каждая функция начинается с guard'а через `SinkSkipped` если ключи не настроены. Полные шаблоны — в `docs/forms-and-crm.md`.

   **Важно:** `crm.ts` создаётся как **stub** (всегда бросает `SinkSkipped("CRM_NOT_CONFIGURED")`). Реальная имплементация — в шаге 6 (или позже).

### 3. Server Action

7. Создать `app/actions/submit-lead.ts` с директивой `"use server"`:
   - Сигнатура `submitLead(prevState, formData: FormData) → LeadState` (тип `LeadState = { success: true } | { error: string } | null`)
   - Rate limiting: 1 запрос / 10 секунд / IP (через `Map<ip, timestamp>` в памяти или `next-rate-limit`)
   - Парсинг FormData → объект → Zod-валидация (схема включает `turnstileToken: z.string().min(1)`). Чекбокс `consent` приходит как строка `"on"` — приводим к boolean **до** `safeParse`
   - **Turnstile verify ДО sinks** — POST на `https://challenges.cloudflare.com/turnstile/v0/siteverify` (тело `application/x-www-form-urlencoded`). При `result.success === false` — `return { error: "Защита от спама не пройдена" }`
   - **Параллельная доставка во все sinks** через `Promise.allSettled(allSinks.map(...))` + `classifySinkResults`
   - **Логи:** `console.error` для real failures (есть env, упал API), `console.warn` если `skips.length === allSinks.length` (ни один канал не настроен)
   - **Fallback** в `data/leads.json` через `appendFallback(data)` — только если `successes.length === 0`
   - Возврат всегда `{ success: true }` — пользователю не пугаемся (fallback страхует). `{ error: '...' }` только для невалидной формы или капчи.

   Полный snippet — в `docs/forms-and-crm.md` § «Server Action».

### 4. Sinks: подключение каналов (по выбору заказчика)

8. **Google Sheets** (рекомендую первым — заказчик сразу видит лиды):
   - Google Cloud Console → создать project → enable Sheets API → Service Account → скачать JSON-ключ
   - Открыть таблицу заказчика → Share → добавить service account email как Editor
   - В `.env`: `GOOGLE_SHEETS_CLIENT_EMAIL`, `GOOGLE_SHEETS_PRIVATE_KEY` (с `\n` экранированием в env), `GOOGLE_SHEETS_SPREADSHEET_ID`. Опционально `GOOGLE_SHEETS_TAB_NAME`
   - Тест: отправь форму локально → лид должен появиться в первом пустом ряду таблицы
   - Подробности — `docs/forms-and-crm.md` § «`lib/sinks/sheets.ts`»

9. **Telegram** (вторым — уведомление в чат команды):
   - `@BotFather` → `/newbot` → получить `TG_BOT_TOKEN`
   - Создать чат для лидов (личный с ботом / групповой с командой / канал), добавить бота
   - Узнать `TG_CHAT_ID` (через `@userinfobot` или `getUpdates`)
   - В `.env`: `TG_BOT_TOKEN`, `TG_CHAT_ID`
   - Тест: форма → сообщение в чат с HTML-разметкой лида
   - Подробности — `docs/forms-and-crm.md` § «`lib/sinks/telegram.ts`»

10. **CRM** (опционально — если есть, иначе остаётся stub):
    - Спросить у заказчика какая CRM (AmoCRM / Bitrix24 / RetailCRM / другая)
    - Получить ключи (long-lived token / webhook URL)
    - Заменить тело `lib/sinks/crm.ts` на реальный POST. Готовые шаблоны для AmoCRM и Bitrix24 — `docs/forms-and-crm.md` § «CRM-интеграции (готовые шаблоны)»
    - Добавить env-переменные

   Если CRM не подключаем сейчас — `crm.ts` остаётся stub'ом (бросает `SinkSkipped`), Sheets+Telegram продолжают работать.

### 5. Подключение к формам

11. В `components/forms/ConsultationDialog.tsx`:
    - Реальная валидация (Zod-схема: name min 2, phone min 10, опционально email/message). RHF используется только для inline-валидации полей (`mode: 'onBlur'`) — submit обрабатывает Server Action.
    - `<Turnstile />` виджет: `siteKey` из `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `onSuccess={setToken}`, ref для `reset()` после успешного state (токен одноразовый — иначе `timeout-or-duplicate` от CF)
    - `useActionState(submitLead, null)` → `[state, formAction, isPending]`. `<form action={formAction}>`. Turnstile-токен и `source` идут как hidden-инпуты.
    - Кнопка `disabled={isPending || !token}`.
    - Реакция на `state` через `useEffect`: `state.success` → toast зелёный + `turnstileRef.current?.reset()`, `state.error` → toast красный.

12. В `components/service-page/ServicePageForms.tsx` — то же для inline mid/final CTA (включая `<Turnstile />`).

13. Добавить в каждую форму **чекбокс согласия на обработку ПДн** (компонент `components/legal/PdnConsent.tsx`):
    ```tsx
    <Checkbox name="consent" required />
    <span className="text-xs">Согласен с <a href="/privacy/">политикой конфиденциальности</a></span>
    ```

   Полный пример клиентской формы — `docs/forms-and-crm.md` § «Клиентская часть».

### 6. Cookie-баннер (152-ФЗ)

14. Создать `components/legal/CookieBanner.tsx` (client) — текст из `docs/legal-templates.md`:
    - Появляется снизу при первом визите
    - Кнопки «Принять» / «Подробнее» (ссылка на /privacy/)
    - localStorage-флаг чтобы не показывать повторно
    - Не блокирует контент (баннер, не модалка)
15. Подключить в `app/layout.tsx`.

### 7. Юридические страницы

16. Создать `app/privacy/page.tsx` — текст политики конфиденциальности (пользователь приносит готовый из генератора, вставляем как есть, оборачиваем в `prose`)
17. Создать `app/terms/page.tsx` — оферта/условия (если применимо, иначе пропустить)
18. Обе страницы:
    - `metadata: { robots: { index: false, follow: true } }` — обычно не индексируются
    - Простой server component с prose-стилями
19. Обновить `components/layout/Footer.tsx` — добавить ссылки на `/privacy/` и `/terms/`.

### 8. Тестирование

20. Локально с **полностью настроенным** `.env` — заполнить форму, отправить, проверить:
    - Turnstile-виджет показывается, после прохождения токен попадает в payload
    - Лид появился в **Sheets** (свежая строка в таблице)
    - Лид пришёл в **Telegram** (сообщение в чат)
    - Лид пришёл в **CRM** (если подключена) или skipped (если stub)
    - Toast показал результат
    - Чекбокс ПДн обязателен (без него submit blocked)

21. Локально с **частично настроенным** `.env` (например, только Sheets — без Telegram-ключей):
    - Лид всё равно проходит (Telegram-канал silently skipped)
    - В `pm2 logs` (или `console`) НЕ должно быть ошибок (skip — это не error)
    - Лид появился в Sheets, остальные каналы пропустились без шума

22. Локально с **пустым** `.env` (только Turnstile настроен) — все sinks skip:
    - Лид сохранился в `data/leads.json`
    - В `pm2 logs` warning: `All lead sinks are not configured. Set GOOGLE_SHEETS_*, TG_BOT_TOKEN, or AMO_CRM_* in .env to start receiving leads.`
    - Toast «Заявка отправлена!» (пользователь не должен видеть отсутствие настройки)

23. Turnstile-edge-кейсы:
    - Submit без прохождения виджета → toast «Подтвердите, что вы не робот», на сервер не идём
    - Двойной submit с одним токеном → 400 «Captcha failed» (`error-codes: timeout-or-duplicate`) — значит, `reset()` после успешного submit не вызывается, фикс в форме

24. Cookie-баннер появляется на чистом браузере, исчезает после «Принять», не возвращается.
25. Rate limiting — два быстрых submit с одного IP → второй вернёт ошибку.
26. `pnpm build` проходит, `.env` переменные не попали в клиентский бандл (не использовать `NEXT_PUBLIC_` для секретов, кроме `NEXT_PUBLIC_TURNSTILE_SITE_KEY`).

### 9. Деплой

27. Обновить локальный `~/projects/{site}/.env.production` — добавить все env-переменные подключённых каналов.

28. Загрузить весь `.env.production` в GitHub Environment Secret `PROD_ENV_FILE`:
    ```bash
    gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} \
      < ~/projects/{site}/.env.production
    ```

29. Push в `dev` → проверка на preview (если есть dev-поддомен) → PR в `main` → автодеплой через GitHub Actions.

30. На проде — отправить тестовую заявку, убедиться что доходит во все настроенные каналы.

## Boundaries

- **Always:** валидация И на клиенте И на сервере (Zod в обоих местах). Все секреты в `.env`. Согласие на ПДн обязательно. Turnstile verify ДО sinks (не после — иначе бот успеет насыпать в Sheets/Telegram/JSON если они приняли request). Skip vs fail различать через `SinkSkipped`-класс.
- **Ask first:** какие каналы подключаем у этого заказчика (если не указано в `docs/integrations.md`); если CRM требует нестандартного маппинга полей; если у заказчика нет готовой политики/оферты (предложить шаблонные генераторы).
- **Never:** коммитить `.env`. Класть `TURNSTILE_SECRET_KEY` или service-account JSON в `NEXT_PUBLIC_*`. Отправлять данные без согласия на ПДн. Делать exit-intent попап на мобильном. Возвращать `{ error: ... }` пользователю при упавшем sink (он не виноват, fallback страхует).

## Done when

- `app/actions/submit-lead.ts` существует, валидирует, проверяет Turnstile, использует `Promise.allSettled` поверх `allSinks`, имеет fallback в JSON. Файла `app/api/lead/route.ts` в проекте **нет**.
- `lib/sinks/index.ts` + `sheets.ts` + `telegram.ts` + `crm.ts` созданы. Каждый sink с `SinkSkipped`-guard'ом.
- Все формы (consultation dialog, mid/final CTA) работают на проде через Server Action с виджетом Turnstile.
- Подключённые каналы (минимум Sheets, обычно Sheets+Telegram) принимают тестовый лид с прода.
- Cookie-баннер показывается, юридические страницы доступны.
- Согласие на ПДн обязательно во всех формах.
- Тестовая заявка с прода доходит во все настроенные каналы; submit без Turnstile-токена корректно отклоняется; submit при отвалившемся канале не ломает другие.

## Memory updates

- `references.md` — какие sinks подключены (Sheets-таблица URL, TG-чат имя, CRM название), их аккаунты/owner'ы. **БЕЗ** ключей и токенов (только ссылки и факты).
- `pointers.md` — `app/actions/submit-lead.ts`, `lib/sinks/{index,sheets,telegram,crm}.ts`, `components/legal/*`, Turnstile-виджет в формах (где встроен).
- `decisions.md` — выбор каналов (почему Sheets+Telegram но не CRM, или наоборот), нюансы маппинга полей в CRM, источник политики (генератор / юрист заказчика), Turnstile mode (Managed vs Invisible) если отступали от дефолта.
- `lessons.md` — если что-то сломалось при интеграции (Sheets 403 на доступе, Telegram getChat invalid, `timeout-or-duplicate` от Turnstile, и т.д.).
- `project_state.md` — done, следующая `10-analytics`.

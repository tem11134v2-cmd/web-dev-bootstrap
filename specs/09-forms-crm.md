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

   **Важно:** `crm.ts` создаётся как **stub** (всегда бросает `SinkSkipped("CRM_NOT_CONFIGURED")`). Реальная имплементация — в шаге 10 (или позже, после релиза).

7. Создать helper-файлы `lib/rate-limit.ts` и `lib/fallback.ts` — Server Action импортирует их, без них `pnpm build` упадёт. Полные шаблоны — в `docs/forms-and-crm.md` § «Helpers — `lib/rate-limit.ts` и `lib/fallback.ts`».

### 3. Server Action

8. Создать `app/actions/submit-lead.ts` с директивой `"use server"`:
   - Сигнатура `submitLead(prevState, formData: FormData) → LeadState` (тип `LeadState = { success: true } | { error: string } | null`)
   - Rate limiting через `rateLimit(ip, 1, 10_000)` из `@/lib/rate-limit` (создан в шаге 7). 1 запрос в 10 секунд / IP
   - Парсинг FormData → объект → Zod-валидация (схема включает `turnstileToken: z.string().min(1)`). Чекбокс `consent` приходит как строка `"on"` — приводим к boolean **до** `safeParse`
   - **Turnstile verify ДО sinks** — POST на `https://challenges.cloudflare.com/turnstile/v0/siteverify` (тело `application/x-www-form-urlencoded`). При `result.success === false` — `return { error: "Защита от спама не пройдена" }`
   - **Параллельная доставка во все sinks** через `Promise.allSettled(allSinks.map(...))` + `classifySinkResults`
   - **Логи:** `console.error` для real failures (есть env, упал API), `console.warn` если `skips.length === allSinks.length` (ни один канал не настроен)
   - **Fallback** в `data/leads.json` через `appendFallback(data)` из `@/lib/fallback` (создан в шаге 7) — только если `successes.length === 0`
   - Возврат всегда `{ success: true }` — пользователю не пугаемся (fallback страхует). `{ error: '...' }` только для невалидной формы или капчи.

   Полный snippet — в `docs/forms-and-crm.md` § «Server Action».

### 4. Sinks: подключение каналов (по выбору заказчика)

> ⚠️ **Pause-and-wait pattern.** Каждый канал требует от пользователя зайти в **чужой веб-интерфейс** (Google Cloud Console, Telegram через `@BotFather`, CRM-админка) и нажать кнопки. Claude туда не ходит — он только адаптирует код под полученные ключи. Поэтому на каждом канале Claude должен:
>
> 1. **Спросить пользователя:** «подключаем сейчас или пропускаем?» Без ответа — не идти дальше.
> 2. Если подключаем — **зачитать в чате pre-req шаги** из `docs/forms-and-crm.md` § «Подготовка X (один раз)» (это инструкция для пользователя, ~5 минут кликов в чужом GUI).
> 3. **Дождаться** ключей в чате от пользователя.
> 4. Положить ключи в `~/projects/{site}/.env.production`, создать `lib/sinks/<name>.ts` по шаблону из `docs/forms-and-crm.md`, протестировать локально (отправить форму → проверить канал).
> 5. Записать в `.claude/memory/references.md`: URL/идентификатор ресурса (БЕЗ ключей).
> 6. Перейти к следующему каналу (или к следующему шагу спеки если каналы исчерпаны).
>
> Каждый канал = отдельный коммит и отдельный test. Между коммитами форма продолжает работать (skipped sinks ничего не ломают). Это намеренная архитектурная гарантия multi-sink.

9. **Google Sheets** (рекомендую первым — заказчик сразу видит лиды).
   - **[пауза]** Спроси у пользователя: подключаем Sheets сейчас? Если нет — переход к шагу 10.
   - **[зачитай пре-req пользователю]** Открой `docs/forms-and-crm.md` § «`lib/sinks/sheets.ts` — Google Sheets» → подраздел «Подготовка таблицы (один раз)» (6 шагов в Google Cloud Console + Sheets UI). Зачитай их пользователю в чате как чек-лист — это его ~5 минут работы. **Особо подчеркни шаг 4:** `GOOGLE_SHEETS_PRIVATE_KEY` в `.env.production` обернуть в **двойные кавычки** с литеральными `\n`, иначе на VPS через `PROD_ENV_FILE` heredoc newlines обработаются непредсказуемо.
   - **[жди]** от пользователя 3 значения: `GOOGLE_SHEETS_CLIENT_EMAIL`, `GOOGLE_SHEETS_PRIVATE_KEY`, `GOOGLE_SHEETS_SPREADSHEET_ID`. Опционально `GOOGLE_SHEETS_TAB_NAME` (дефолт `Leads`).
   - Положи в `.env.local` (для локальной разработки) и в `~/projects/{site}/.env.production` (для прода). Создай `lib/sinks/sheets.ts` по шаблону.
   - **[тест]** Отправь форму локально → строка должна появиться в таблице.
   - В `.claude/memory/references.md`: URL Google-таблицы, email service account.

10. **Telegram** (вторым — уведомление в чат команды).
    - **[пауза]** Спроси у пользователя: подключаем Telegram сейчас? Если нет — переход к шагу 11.
    - **[зачитай пре-req пользователю]** Открой `docs/forms-and-crm.md` § «`lib/sinks/telegram.ts` — Telegram-бот» → подраздел «Подготовка бота (один раз)» (5 шагов в Telegram-приложении). Зачитай как чек-лист.
    - **[жди]** от пользователя `TG_BOT_TOKEN` + `TG_CHAT_ID`.
    - Положи в `.env.local` и `.env.production`. Создай `lib/sinks/telegram.ts` по шаблону.
    - **[тест]** Отправь форму локально → сообщение должно прийти в чат с HTML-разметкой.
    - В `.claude/memory/references.md`: имя бота, тип чата (личный / групповой / канал), кто из команды получает уведомления.

11. **CRM** (опционально — обычно подключают позже, на этапе масштабирования воронки).
    - **[пауза]** Спроси у пользователя: подключаем CRM сейчас? Если нет — `lib/sinks/crm.ts` остаётся stub'ом, переход к шагу 12. Sheets+Telegram продолжают работать.
    - Если да — спроси какая CRM: AmoCRM / Bitrix24 / RetailCRM / другая.
    - **[зачитай пре-req пользователю]** Если AmoCRM/Bitrix24 — там готовые шаблоны кода в `docs/forms-and-crm.md` § «CRM-интеграции (готовые шаблоны)», а пользователю нужно получить только ключи (long-lived integration token для Amo / webhook URL для Bitrix). Если другая CRM — прочитай документацию провайдера, спроси у пользователя auth-формат и endpoint.
    - **[жди]** от пользователя ключи (формат зависит от CRM).
    - Замени **тело** `lib/sinks/crm.ts` (был stub `throw new SinkSkipped`) на реальный POST по шаблону, оставив `SinkSkipped`-guard в начале на случай если ключи не положили.
    - Положи в `.env.local` и `.env.production` нужные переменные.
    - **[тест]** Отправь форму локально → лид появится в CRM (открой её UI и убедись).
    - В `.claude/memory/references.md`: название CRM, URL аккаунта, контакт ответственного.

### 5. Подключение к формам

12. В `components/forms/ConsultationDialog.tsx`:
    - Реальная валидация (Zod-схема: name min 2, phone min 10, опционально email/message). RHF используется только для inline-валидации полей (`mode: 'onBlur'`) — submit обрабатывает Server Action.
    - `<Turnstile />` виджет: `siteKey` из `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `onSuccess={setToken}`, ref для `reset()` после успешного state (токен одноразовый — иначе `timeout-or-duplicate` от CF)
    - `useActionState(submitLead, null)` → `[state, formAction, isPending]`. `<form action={formAction}>`. Turnstile-токен и `source` идут как hidden-инпуты.
    - Кнопка `disabled={isPending || !token}`.
    - Реакция на `state` через `useEffect`: `state.success` → toast зелёный + `turnstileRef.current?.reset()`, `state.error` → toast красный.

13. В `components/service-page/ServicePageForms.tsx` — то же для inline mid/final CTA (включая `<Turnstile />`).

14. Добавить в каждую форму **чекбокс согласия на обработку ПДн** (компонент `components/legal/PdnConsent.tsx`):
    ```tsx
    <Checkbox name="consent" required />
    <span className="text-xs">Согласен с <a href="/privacy/">политикой конфиденциальности</a></span>
    ```

   Полный пример клиентской формы — `docs/forms-and-crm.md` § «Клиентская часть».

### 6. Cookie-баннер (152-ФЗ)

15. Создать `components/legal/CookieBanner.tsx` (client) — текст из `docs/legal-templates.md`:
    - Появляется снизу при первом визите
    - Кнопки «Принять» / «Подробнее» (ссылка на /privacy/)
    - localStorage-флаг чтобы не показывать повторно
    - Не блокирует контент (баннер, не модалка)
16. Подключить в `app/layout.tsx`.

### 7. Юридические страницы

17. Создать `app/privacy/page.tsx` — текст политики конфиденциальности (пользователь приносит готовый из генератора, вставляем как есть, оборачиваем в `prose`)
18. Создать `app/terms/page.tsx` — оферта/условия (если применимо, иначе пропустить)
19. Обе страницы:
    - `metadata: { robots: { index: false, follow: true } }` — обычно не индексируются
    - Простой server component с prose-стилями
20. Обновить `components/layout/Footer.tsx` — добавить ссылки на `/privacy/` и `/terms/`.

### 8. Тестирование

21. Локально с **полностью настроенным** `.env` — заполнить форму, отправить, проверить:
    - Turnstile-виджет показывается, после прохождения токен попадает в payload
    - Лид появился в **Sheets** (свежая строка в таблице)
    - Лид пришёл в **Telegram** (сообщение в чат)
    - Лид пришёл в **CRM** (если подключена) или skipped (если stub)
    - Toast показал результат
    - Чекбокс ПДн обязателен (без него submit blocked)

22. Локально с **частично настроенным** `.env` (например, только Sheets — без Telegram-ключей):
    - Лид всё равно проходит (Telegram-канал silently skipped)
    - В `pm2 logs` (или `console`) НЕ должно быть ошибок (skip — это не error)
    - Лид появился в Sheets, остальные каналы пропустились без шума

23. Локально с **пустым** `.env` (только Turnstile настроен) — все sinks skip:
    - Лид сохранился в `data/leads.json`
    - В `pm2 logs` warning: `All lead sinks are not configured. Set GOOGLE_SHEETS_*, TG_BOT_TOKEN, or AMO_CRM_* in .env to start receiving leads.`
    - Toast «Заявка отправлена!» (пользователь не должен видеть отсутствие настройки)

24. Turnstile-edge-кейсы:
    - Submit без прохождения виджета → toast «Подтвердите, что вы не робот», на сервер не идём
    - Двойной submit с одним токеном → 400 «Captcha failed» (`error-codes: timeout-or-duplicate`) — значит, `reset()` после успешного submit не вызывается, фикс в форме

25. Cookie-баннер появляется на чистом браузере, исчезает после «Принять», не возвращается.
26. Rate limiting — два быстрых submit с одного IP → второй вернёт ошибку.
27. `pnpm build` проходит, `.env` переменные не попали в клиентский бандл (не использовать `NEXT_PUBLIC_` для секретов, кроме `NEXT_PUBLIC_TURNSTILE_SITE_KEY`).

### 9. Деплой

28. Обновить локальный `~/projects/{site}/.env.production` — добавить все env-переменные подключённых каналов.

29. Загрузить весь `.env.production` в GitHub Environment Secret `PROD_ENV_FILE`:
    ```bash
    gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} \
      < ~/projects/{site}/.env.production
    ```

30. Push в `dev` → проверка на preview (если есть dev-поддомен) → PR в `main` → автодеплой через GitHub Actions.

31. На проде — отправить тестовую заявку, убедиться что доходит во все настроенные каналы.

## Boundaries

- **Always:** валидация И на клиенте И на сервере (Zod в обоих местах). Все секреты в `.env`. Согласие на ПДн обязательно. Turnstile verify ДО sinks. Skip vs fail различать через `SinkSkipped`-класс. **На каждом канале (шаги 9-11) сначала спросить пользователя «подключаем сейчас?», зачитать pre-req из `docs/forms-and-crm.md`, дождаться ключей, и только потом писать код** — Claude не ходит в Google Cloud Console / `@BotFather` / CRM-админку, эти действия только за пользователем.
- **Ask first:** какие каналы подключаем у этого заказчика (если не указано в `docs/integrations.md`); если CRM требует нестандартного маппинга полей; если у заказчика нет готовой политики/оферты (предложить шаблонные генераторы).
- **Never:** коммитить `.env`. Класть `TURNSTILE_SECRET_KEY` или service-account JSON в `NEXT_PUBLIC_*`. Отправлять данные без согласия на ПДн. Делать exit-intent попап на мобильном. Возвращать `{ error: ... }` пользователю при упавшем sink (он не виноват, fallback страхует). **Создавать `lib/sinks/<name>.ts` с реальной логикой до получения ключей от пользователя** — без env-переменных в `.env.local` тест локально не пройдёт, и время потратится зря.

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

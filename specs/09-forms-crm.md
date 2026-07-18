# Spec 09: Формы, multi-sink доставка лидов, юридическое (152-ФЗ)

> Оркестрация: 09a (код) — builder-opus, subagent-ready | 09b (каналы) — human-gated, ведёт оркестратор; параллель: с 08 запрещена (обе правят layout.tsx) — последовательно; verifier: после пары 08+09

## KB files to read first

- docs/forms-and-crm.md (целиком — архитектура, Server Action, антиспам, fallback)
- docs/forms-sink-recipes.md (**только секции подключаемых каналов** — не грузи всё)
- docs/legal-templates.md (152-ФЗ: cookie-баннер, /privacy, /consent, /offer)
- docs/integrations.md (какие каналы у этого заказчика)
- `components/forms/ConsultationDialog.tsx` + `components/service-page/ServicePageForms.tsx` (заглушки из спек 04–05)

## Goal

Заменить заглушки форм рабочей воронкой: валидация → Server Action → honeypot + rate-limit + Turnstile → **multi-sink доставка** с graceful skip неподключённых каналов и JSONL-fallback в `LEADS_DIR`. Добавить юридическое: cookie-баннер, чекбокс согласия, страницы `/privacy` + `/consent`.

> **Минимальный трек (официальный дефолт).** Email-sink (nodemailer + SMTP Яндекса) подключается **сегодня** — заявки идут на почту в день запуска форм. Остальные каналы (Telegram / Sheets / CRM) — по запросу заказчика, хоть через месяц: архитектура multi-sink позволяет включать их без правок форм (env + один файл).

> **Server Action, не Route Handler.** Лиды идут через `app/actions/submit-lead.ts`, endpoint `/api/lead` не создаётся. Формы — `useActionState` + `<form action={formAction}>`.

## Разделение для оркестратора

- **09a (код)** — subagent-ready: шаги 1–14 не требуют человека (Turnstile — на тест-ключах). Билдер: builder-opus.
- **09b (каналы)** — human-gated: ключи и чужие GUI. Ведёт оркестратор (или интерактивная сессия), субагенту не отдаётся.

## Tasks

### Часть A (09a): код — без человека

1. Установить: `pnpm add @marsidev/react-turnstile nodemailer && pnpm add -D @types/nodemailer`. В `.env.local` — **тестовые ключи Turnstile** (см. `docs/forms-sink-recipes.md` § Turnstile): код и тесты работают до получения боевых.

2. Создать `lib/sinks/index.ts` — `LeadData`, `SinkSkipped`, `allSinks`, `classifySinkResults`. Листинг — `docs/forms-and-crm.md` § Структура lib/.

3. Создать sinks:
   - `lib/sinks/email.ts` — полный листинг из `forms-sink-recipes.md` § EMAIL (работает сразу после env в 09b).
   - `lib/sinks/telegram.ts` — полный листинг из § TELEGRAM (голый fetch, зависимостей нет).
   - `lib/sinks/sheets.ts` и `lib/sinks/crm.ts` — **stubs** (`throw new SinkSkipped(...)` первой строкой, без внешних импортов). Реальные листинги и `pnpm add googleapis` — только при подключении канала в 09b.

4. Создать `lib/rate-limit.ts` (6/мин/IP) и `lib/fallback.ts` (JSONL в `LEADS_DIR`) — листинги в `docs/forms-and-crm.md`. Убедиться, что `data/` в `.gitignore`.

5. Создать `app/actions/submit-lead.ts` по листингу `docs/forms-and-crm.md` § Server Action: honeypot → rate-limit → Zod 4 (`z.email()`, `.max()` на полях, `{ error }` вместо errorMap) → Turnstile verify ДО sinks → `Promise.allSettled(allSinks)` → classify → fallback при нуле success → всегда `{ success: true }` пользователю.

6. Подключить к формам (`ConsultationDialog.tsx`, `ServicePageForms.tsx`):
   - `useActionState(submitLead, null)`, `<form action={formAction}>`; RHF — только inline-валидация (`mode: 'onBlur'`).
   - `<Turnstile />` + hidden `turnstileToken`/`source`, honeypot-поле `company`, кнопка `disabled={isPending || !token}`, `reset()` токена после ответа.
   - Чекбокс согласия (компонент `components/legal/PdnConsent.tsx`): «Согласен на [обработку персональных данных](/consent/)» + ссылка на `/privacy/` рядом с кнопкой.

7. Cookie-баннер `components/legal/CookieBanner.tsx` (client, текст из `docs/legal-templates.md` § 1): снизу при первом визите, «Принять» / «Отклонить» / «Подробнее» (→ /privacy/), localStorage-флаг `cookieConsent` (`accepted` / `rejected`), не блокирует контент. Подключить в `app/layout.tsx`. На «Принять» — `window.dispatchEvent(new Event('cookie-consent'))` (спека 10 подвесит на это счётчики); при `cookieConsent=rejected` счётчики не грузятся.

8. Юр-страницы (канон — `docs/legal-templates.md`):
   - `app/privacy/page.tsx` — политика конфиденциальности.
   - `app/consent/page.tsx` — согласие на обработку ПДн (на неё ссылается чекбокс).
   - `app/offer/page.tsx` — **только если на сайте оплата**, иначе не создавать.
   - Все — простые server components с prose-стилями. **Индексируются** (никаких `robots: { index: false }` — юр-страницы это коммерческий фактор ранжирования).
   - Тексты приносит заказчик (или генератор + реквизиты) → пункт в `CLIENT-TODO.md`.

9. `components/layout/Footer.tsx` — ссылки на `/privacy/` и `/consent/` (+ `/offer/` если есть).

### Локальные тесты 09a (Turnstile на тест-ключах, sinks пустые)

10. Пустой `.env` (только тест-ключи Turnstile): отправить форму → лид в `data/leads.jsonl`, в консоли `pnpm dev` — warning «All lead sinks are not configured», toast «Заявка отправлена!».
11. Honeypot: заполнить поле `company` через DevTools → «успех» без строки в `leads.jsonl` и без вызова sinks.
12. Rate-limit: 7 быстрых submit → седьмой получает ошибку «Слишком много запросов».
13. Turnstile-кейсы: submit без токена — кнопка заблокирована; повторный submit тем же токеном → ошибка `timeout-or-duplicate` (значит, забыт `reset()`).
14. `pnpm build` проходит; секреты не в клиентском бандле (`NEXT_PUBLIC_` — только Turnstile site key). Cookie-баннер: появляется на чистом браузере, после «Принять» не возвращается.

### Часть B (09b): каналы — human-gated

15. **Один батч-вопрос человеку** (не пауза на каждый канал!). Спросить сразу всё списком:
    - Боевые ключи Turnstile (Cloudflare → Add Site; чек-лист — `forms-sink-recipes.md` § Turnstile).
    - **Email (дефолт, подключаем сегодня):** ящик-отправитель + пароль приложения Яндекса + адрес получателя (чек-лист «Подготовка канала» § EMAIL).
    - Telegram — подключаем? Если да: `TG_BOT_TOKEN` + `TG_CHAT_ID` (чек-лист § TELEGRAM).
    - Sheets — подключаем? Если да: 3 значения `GOOGLE_SHEETS_*` (чек-лист § SHEETS; подчеркнуть двойные кавычки + литеральные `\n` у private key).
    - CRM — подключаем? Какая? Если AmoCRM: `AMO_CRM_URL` + `AMO_CRM_TOKEN` (§ AMOCRM); Bitrix24: `BITRIX_WEBHOOK_URL` (§ BITRIX24).

    Всё, что заказчик не может дать сейчас, — строками в `CLIENT-TODO.md` («Доступы»: SMTP-пароль приложения, вебхук CRM и т.д.). Каналы без ключей остаются stubs — форма работает.

16. По мере получения ключей — на каждый канал: env в `.env.local` + `~/projects/{site}/.env.production` → полный листинг sink'а из `forms-sink-recipes.md` (для sheets/crm — заменить stub, для sheets ещё `pnpm add googleapis`) → локальный тест (форма → канал принял) → запись в `.claude/memory/references.md` (URL/ID ресурса, БЕЗ ключей). **Каждый канал = отдельный коммит.** Порядок не блокирует: неподключённые каналы — `SinkSkipped`.

17. Частично настроенный `.env` (например, только email): лид проходит, в консоли `pnpm dev` нет ошибок (skip ≠ error), письмо пришло.

### Деплой

18. В `~/projects/{site}/.env.production` — все env подключённых каналов + `LEADS_DIR=/home/deploy/prod/{site}/shared/data` (папка вне releases/ — деплой её не трогает; создание — `docs/server-add-site.md`).
19. Загрузить секрет:
    ```bash
    gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} < ~/projects/{site}/.env.production
    ```
20. Push в `dev` → preview → PR в `main` → автодеплой. На проде — тестовая заявка: доходит во все подключённые каналы, `pm2 logs {site}-prod` без sink-ошибок.

## Boundaries

- **Always:** валидация и на клиенте, и на сервере (Zod 4 в обоих). Turnstile verify ДО sinks. Skip vs fail — через `SinkSkipped`. Email-канал — первый. Ключи и чужие GUI (Cloudflare, Яндекс ID, `@BotFather`, Google Cloud Console, CRM-админки) — только человек; Claude собирает потребности в один батч-вопрос и пункты в `CLIENT-TODO.md`.
- **Ask first:** какие каналы подключаем (если нет в `docs/integrations.md`) — в составе батч-вопроса шага 15; нестандартный маппинг полей CRM; если у заказчика нет текстов юр-страниц (предложить шаблоны из `docs/legal-templates.md`).
- **Never:** коммитить `.env` или `data/`. Секреты в `NEXT_PUBLIC_*`. Отправка без согласия на ПДн. `robots: { index: false }` на юр-страницах. Exit-intent попап на мобильном. `{ error }` пользователю при упавшем sink (fallback страхует). Писать реальную логику sheets/crm-sink-ов до получения ключей (email и telegram пишутся полными в 09a — локально тестируются без env как `SinkSkipped`).

## Done when

- `app/actions/submit-lead.ts`: honeypot + rate-limit 6/мин + Zod 4 + Turnstile + `Promise.allSettled` + JSONL-fallback. Файла `app/api/lead/route.ts` **нет**.
- `lib/sinks/` создан; email.ts и telegram.ts — полные, неподключённые каналы — stubs с `SinkSkipped`.
- Все формы работают через Server Action; тесты 10–14 и 17 пройдены.
- **Email-канал принимает лид с прода** (минимальный трек); остальные подключённые — тоже.
- `/privacy` + `/consent` (+ `/offer` при оплате) доступны и индексируемы; cookie-баннер работает; согласие обязательно во всех формах.
- Недостающее от заказчика — строками в `CLIENT-TODO.md`.

## Memory updates

- `references.md` — подключённые каналы (ящик получателя, имя TG-бота/чата, URL таблицы, CRM), owner'ы. БЕЗ ключей.
- `pointers.md` — `app/actions/submit-lead.ts`, `lib/sinks/*`, `lib/{rate-limit,fallback}.ts`, `components/legal/*`.
- `decisions.md` — выбор каналов и почему; источник текстов юр-страниц; отступления от дефолтов Turnstile.
- `lessons.md` — грабли интеграций (Sheets 403, `timeout-or-duplicate`, 553 от SMTP Яндекса и т.п.).
- `project_state.md` — done (отметить, какие каналы отложены), следующая `10-analytics`.

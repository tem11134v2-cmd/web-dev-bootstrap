# Changelog

## v3.3 — 2026-05-05 · Rolling migration + meta cleanup

Чистка после самостоятельного аудита: устранены P0 в описаниях и расхождения между файлами после v3.1 / v3.2 sweeps. Архитектурно ничего не менялось — стек тот же, только описания приведены к реальности.

- **Миграция переключена на rolling-main.** До этого `_BUILD/v3/02-migrate-existing-project.md` хардкодил `BOOTSTRAP_TAG=v3.0` и URL'ы `/v3.0/` (плюс один битый `/v3.2/`, тег которого не существует). После v3.2 пользователи, мигрирующие старые проекты, получали v3.0-замороженные шаги без multi-sink. Теперь `BOOTSTRAP_TAG` по дефолту `main`, все хардкод-ссылки в migration-ТЗ и `_BUILD/HOW-TO-START.md` § 10 переведены на `/main/`. Пояснительный текст переписан: «миграция использует актуальный main, фиксы подхватятся автоматически; для долгой миграции в несколько дней можно зафиксировать на конкретный sha через `BOOTSTRAP_TAG=<sha>`». `git clone --branch v3.0` в § 10.6 убран — клонируется default main.
- **Build-описание в CLAUDE.md.** В `## Commands` корневого `CLAUDE.md` и `_BUILD/claude-md-template.md` строка `pnpm build — production build (собирается на VPS после git pull)` устарела с Phase 5 (push-based deploy перенёс build на GitHub-runner). Шаблон копируется в новые сайты — каждая Claude-сессия в новом проекте получала устаревшее описание в context. Заменено на `собирается на GitHub-runner, rsync-ится на VPS как standalone-артефакт`.
- **CLAUDE.md Rules — site-mode guard.** Добавлена вводная строка к `## Rules`, явно указывающая, что правила (включая `Work on dev branch`) применяются только в site-режиме. В bootstrap-режиме (placeholder `# Project: [Name]`) — следуй META-инструкции в HTML-комментарии, где другая ветка `feature/{тема}`. Это снимает внутреннее противоречие, отложенное в v3.1 «как отдельное обсуждение», без расщепления файла на два.
- **`docs/automation.md` догнал `docs/INDEX.md`.** INDEX обещал в automation.md пять хуков и три slash-команды, фактически были описаны только четыре хука (без `stop-reminder.sh`) и ноль slash-команд. Добавлен раздел про `stop-reminder.sh` (Stop event, PPID-isolation, sha-diff фильтр от спама, never-blocks). Добавлен раздел `## Slash-команды` — таблица `/resume` / `/handoff` / `/catchup` с when-to-call и what-they-do.
- **`docs/INDEX.md` строка про bootstrap-vps.sh.** Заканчивалась `…deploy-ключ`. Phase 5 удалила генерацию deploy-keypair из `bootstrap-vps.sh` (приватный ключ теперь живёт только в GitHub Secrets, на VPS ssh-copy-id'ится только публичный). Заменено на актуальную форму: `Node runtime + Caddy + PM2`, без pnpm/git на VPS.
- **Sync устаревших версий.** README H1 `v3.0 → v3.2`, блок «Версия» переписан под актуальный стек (включает multi-sink). README «pnpm через corepack на VPS» убран (Phase 5 убрала pnpm с VPS как класс). `CLAUDE.md` BOOTSTRAP META `v2.0 → v3.0` → `v2.0 → v3.2`. HOW-TO-START заголовок `v3.1 → v3.2`. `claude-md-template.md` `Дефолт v3.0 → Дефолт v3.2`.
- **Tag-policy переоформлен под rolling.** В `CLAUDE.md` правило про теги переформулировано: rolling-main, теги ставятся только для major-вех (v4.0, v3.5 и т.п.), patch-уровень — без тегов. Снимает накопленный долг (в changelog есть v3.1 и v3.2 без соответствующих git-тегов — это норма при rolling-схеме).

### Что НЕ затронуто

- Архитектурно ничего: стек v3.2 (Caddy / push-deploy / Biome / pnpm / mise / Server Actions / Turnstile / Content Collections / multi-sink / multi-Claude протокол) сохранён без изменений.
- Файлы скриптов (`scripts/*.sh`), хуков (`.claude/hooks/*.sh`), spec'ов (`specs/*.md`), KB-доков кроме `docs/INDEX.md` и `docs/automation.md`.
- Существующие проекты на v3.0/v3.1/v3.2 ничего не теряют — это правки описаний bootstrap'а самого, не изменения копируемых артефактов (кроме `claude-md-template.md`, который применится только при следующем `gh repo create --template`).

## v3.2 — 2026-04-29 · Multi-sink lead architecture (Sheets + Telegram + CRM)

Архитектурный апгрейд воронки лидов в шаблоне. До v3.2 дефолтный `submitLead` отправлял лид через **один абстрактный канал** (`sendToCRM`) с fallback в `data/leads.json`. Это было адекватно для проектов с одной CRM, но не покрывало реальный сценарий «лид одновременно в Google Sheets + Telegram + CRM», который владелец ведёт сам или с командой.

С v3.2 шаблон по умолчанию проектирует Server Action под **multi-sink доставку** через `Promise.allSettled`: каналы независимы, упавший Telegram не ломает Sheets, неподключённый канал silently skipped, fallback в JSON срабатывает только когда **все** sinks не приняли лид. Подключать каналы можно постепенно — добавил env-переменные для Sheets, поработал, добавил Telegram, потом подключил CRM.

- **`docs/forms-and-crm.md` переписан** под multi-sink архитектуру. Новая ASCII-схема показывает поток: `Promise.allSettled([sheets, telegram, crm])` → `classifySinkResults` → fallback в JSON только если `successes.length === 0`. Полные шаблоны кода для четырёх файлов: `lib/sinks/index.ts` (диспетчер с `LeadData` + `SinkSkipped`-классом + `allSinks`-массивом + `classifySinkResults`-helper'ом), `lib/sinks/sheets.ts` (через `googleapis` + JWT service account), `lib/sinks/telegram.ts` (через `node-telegram-bot-api` с `polling: false`), `lib/sinks/crm.ts` (stub до реального подключения, всегда бросает `SinkSkipped("CRM_NOT_CONFIGURED")`). Включены инструкции pre-req для каждого канала: как создать service account в Google Cloud → расшарить таблицу, как получить `TG_BOT_TOKEN`/`TG_CHAT_ID` через `@BotFather` и `@userinfobot`/`getUpdates`. Готовые шаблоны CRM (AmoCRM, Bitrix24) теперь как drop-in замена для `lib/sinks/crm.ts` stub'а.
- **Server Action snippet обновлён.** Импорт `allSinks`, `classifySinkResults`, `SinkSkipped` из `@/lib/sinks` вместо `sendToCRM` из `@/lib/crm`. Поток: rate-limit → валидация → Turnstile verify (как было) → `Promise.allSettled(allSinks.map(...))` → разделение результатов на successes/skips/failures → `console.error` для real failures, `console.warn` если все skipped (env пустой), `appendFallback` только если `successes.length === 0`. Возвращает `{ success: true }` пользователю всегда — fallback страхует, паниковать незачем.
- **`specs/09-forms-crm.md` переписан** — Goal сменился с «Server Action + CRM-интеграция + fallback в JSON» на «multi-sink доставка лидов + юридическое». Tasks теперь: §2 Создать `lib/sinks/`-структуру (новое), §3 Server Action с `Promise.allSettled` (новое), §4 Подключение каналов в порядке Sheets → Telegram → CRM (новое), §8 Тестирование расширено на три сценария — full env / partial env / empty env (всё через JSON fallback). Boundaries добавили правила «skip vs fail различать через `SinkSkipped`» и «не возвращать `error` при упавшем sink — fallback страхует».
- **`docs/stack.md` обновлён** — `googleapis` и `node-telegram-bot-api` (+ `@types/node-telegram-bot-api` devDep) добавлены во вспомогательные пакеты. Ставятся в spec 09 при подключении каналов, не входят в дефолтный init step (потому что не каждый сайт подключает все каналы).
- **`CLAUDE.md` и `_BUILD/claude-md-template.md` Forms-строка обновлена** на `Server Action submitLead → multi-sink (Google Sheets / Telegram / CRM) через Promise.allSettled, с JSON-fallback если все упали`. Эта строка попадает в context каждой Claude-сессии при старте — несоответствие создавало бы ложную картину архитектуры.
- **`_BUILD/v3/02-migrate-existing-project.md` § 3.2 расширен** с 6 подшагов до 7 (а-ж): добавлены установка `googleapis`/`node-telegram-bot-api` в подшаг (а), создание `lib/sinks/`-структуры в новом подшаге (б), Server Action с `Promise.allSettled` в подшаге (в). Подшаг (ж) «Проверить локально» уточняет: на этом этапе ни один sink ещё не настроен → лид сохраняется в `data/leads.json` через fallback с понятным warning, **это ожидаемо** — каналы подключаются после миграции отдельными коммитами. Дополнительная секция «Подключение каналов после миграции» описывает порядок Sheets → Telegram → CRM. Если у проекта был старый `lib/crm.ts` — его содержимое переезжает в `lib/sinks/crm.ts` (заменяя stub) с добавлением `SinkSkipped`-guard'а.

### Что НЕ затронуто

- Клиентские формы (`useActionState` + Turnstile + `<form action={formAction}>`) — multi-sink это серверная кухня, клиенту не видна.
- Архитектура Turnstile-верификации — без изменений.
- `data/leads.json` fallback — остаётся как был, только теперь срабатывает реже (только когда **все** sinks не приняли лид, а не «когда CRM упала»).
- Существующие проекты на v3.0/v3.1 продолжают работать без изменений (один `sendToCRM` + JSON fallback). Миграция на multi-sink — точечная и описана в `_BUILD/v3/02-migrate-existing-project.md` § 3.2.

## v3.1 — 2026-04-29 · Unified HOW-TO + fetch-env helper

UX-доводка после полного аудита v3.0 свежим взглядом. Главные изменения — для **человека**, не для Claude: вся практическая инструкция теперь в одном файле, а ритуал «новый Mac → рабочий проект» сжат до одной команды.

- **Единый `_BUILD/HOW-TO-START.md` (1100+ строк)** для двух ролей. Покрывает всё: установку Mac, получение проекта (новый сайт владельца / перенос на новый Mac / коллаборатор после invite), работу в Claude, Multi-Claude protocol, секреты, откат, миграцию v2.x → v3, подключение домена, troubleshooting, обновление шаблона. Секции, специфичные для одной роли, помечены `[владельцу]` / `[коллаборатору]`. До v3.1 эта же информация была разбросана по `HOW-TO-START.md` + `docs/team-onboarding.md` + `_BUILD/HANDBOOK.md` (сборка через `scripts/build-handbook.sh`) + `specs/00.5-new-project-init.md` — с дубликатами и расхождениями. Теперь один источник истины для людей; `docs/troubleshooting.md` и `docs/domain-connect.md` остались как Claude-KB (фокусированно грузятся в спеках 01b/12/14).
- **Удалены** `_BUILD/HANDBOOK.md` (1685 строк), `scripts/build-handbook.sh` (заменены единым HOW-TO), `docs/team-onboarding.md` (контент в HOW-TO §1.C / §3 / §4 / §8 / §9), `specs/00.5-new-project-init.md` (контент в HOW-TO §0-§3, плюс она дублировала и противоречила HOW-TO с тремя альтернативными путями копирования bootstrap'а). Все живые ссылки на удалённые файлы обновлены в `README.md`, `CLAUDE.md`, `_BUILD/claude-md-template.md`, `docs/INDEX.md`, `specs/INDEX.md`, `specs/14-migrate.md`, `specs/01a-local-setup.md`. Исторические записи в этом changelog и `_BUILD/v3/01-bootstrap-refactor.md` оставлены как есть.
- **`scripts/fetch-env.sh`** — зеркало `sync-env.sh` в обратную сторону: тянет активный `.env` с VPS в локальный `~/projects/{site}/.env.production`. Используется ровно один раз при настройке свежего устройства (новый Mac владельца, потерянный ноут, второй компьютер). Бэкапит существующий локальный файл, `chmod 600`, печатает имена переменных без значений, даёт понятную ошибку с инструкцией если SSH к VPS не настроен. HOW-TO §1.B переписан вокруг этого скрипта — вместо трёх альтернативных вариантов («1Password / ssh+cat / gh secret list») теперь одна команда, остальное — fallback на крайний случай.
- **Точечные фиксы аудита** (вошли в этот же релиз через PR #20): «порчинг» → «uncommitted-изменения» в HOW-TO/HANDBOOK/changelog (3 места); оборванный фрагмент «— был раньше» в заголовках `docs/automation.md` (2 места); описание `troubleshooting.md` в `docs/INDEX.md` обновлено под v3-реальность (deploy_key permission denied → SSH permission denied + новые сценарии после Phase 5); `specs/01b` первый деплой развёл на два варианта (PR-merge для protected main vs прямой push для private+free); P1 race condition в `_BUILD/v3/02-migrate-existing-project.md` (Server Action и Turnstile теперь один шаг, чтобы между коммитами форма не валилась на пустом turnstileToken); прочие косметические правки (`npm` убран из prereqs spec 00.5/01a, banner про pre-v3 контекст в `specs/examples/`, актуализирован `_BUILD/` listing в README, закрыт устаревший Outstanding в changelog v3.0).

### Что НЕ затронуто

- Архитектура лидов (`sendToCRM` + JSON fallback) пока не переписывалась под multi-sink. Желаемая будущая архитектура — `Promise.allSettled([sendToSheets, sendToTelegram, sendToCRM])` — заплана как отдельная задача / minor-bump.
- `_BUILD/v3/02-migrate-existing-project.md` — самостоятельный промт миграции v2.x → v3, остаётся как есть (точечные правки уже включены).
- `CLAUDE.md` BOOTSTRAP META vs `## Rules` про ветки — внутреннее противоречие (bootstrap-mode vs site-mode) отложено как отдельное обсуждение.

## v3.0 — 2026-04-29 · Multi-Claude handoff protocol + final bootstrap-refactor release

Финальная Phase 6 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Закрывает sequential multi-Claude протокол (одна сессия = одна задача, передача состояния через память), синхронизирует `_BUILD/claude-md-template.md` с актуальным `CLAUDE.md`, обновляет HOW-TO-START под slash-команды и новые секции, ставит тег `v3.0` — конец большого рефакторинга bootstrap'а. Сам bootstrap-репо ничего не билдит — изменения проявятся только в новых проектах из шаблона.

- **Sequential multi-Claude протокол.** Одна Claude-сессия = одна задача (одна спека). Параллельные сессии на ОДНУ папку проекта запрещены — они не видят друг друга и поломают `.claude/memory/project_state.md`. Передача между сессиями — через три новые slash-команды, лежащие в `.claude/commands/` (Claude Code Desktop сканирует папку автоматически, регистрация в `settings.json` не нужна): `/handoff` финализирует сессию (запись в `Session log` файла `project_state.md` с Done/Open/Uncommitted/Resume hint, обновление `Active phase` + `Next steps`, спрашивает про uncommitted-изменения), `/resume` стартует следующую (читает память, сверяет с git-state — uncommitted-изменения + last commits + HEAD sha; при расхождении стопает и просит решения), `/catchup` даёт быструю ориентацию по `git log main..HEAD` + diff stat. В корневой `CLAUDE.md` и в `_BUILD/claude-md-template.md` добавлен раздел `## Multi-Claude protocol` — новые сайты сразу получают правило.
- **Stop-хук как мягкое напоминание.** `.claude/hooks/stop-reminder.sh` срабатывает на Stop-event Claude'а (после каждого ответа). Без фильтра пользователь получал бы спам — поэтому хук сравнивает текущий `git rev-parse HEAD` с зафиксированным на `SessionStart` (запись в `/tmp/.claude-session-start-sha-$PPID`, `$PPID` изолирует параллельные Claude-инстансы). Совпало — silent exit. HEAD сменился — печатает в stderr напоминание про `/handoff`. `.claude/hooks/session-start.sh` дополнен строкой записи sha; `.claude/settings.json` зарегистрировал Stop-хук.
- **Шаблон `_BUILD/claude-md-template.md` пересинхронизирован с `CLAUDE.md`.** До Phase 6 шаблон отставал: в живом `CLAUDE.md` была секция `Automation rules` (session-start, before-push, secrets через `PROD_ENV_FILE` GitHub Environment Secret, симлинк-rollback), а шаблон, который копируется в новые сайты — нет. Теперь `diff CLAUDE.md _BUILD/claude-md-template.md` показывает только различия в header-комментариях (BOOTSTRAP META auto-loader vs инструкция шаблона) и встроенных placeholder-подсказках (Stack default, dev port). Stack-комментарий в шаблоне обновлён на `Дефолт v3.0`.
- **`.claude/memory/project_state.md` структурирован.** Новый формат: `Active phase` / `Active spec` / `Blockers` / `Next 1-3 steps` / `Session log` (заполняется `/handoff`) / `Completed phases history` (или `Completed specs history` для site-проектов). Развёрнутые описания фаз 0–5 переехали в этот changelog как источник истины — в `project_state.md` остались одностроки + ссылки на PR. Файл двойного назначения: для bootstrap-refactor отслеживает фазы; для сайтов после `gh repo create --template` пользователь стирает содержимое и заполняет под свой проект (инструкция в HTML-комментарии в начале файла).
- **`_BUILD/HOW-TO-START.md` финиш.** Phase 5 ранее переписала §§ 8–9 (секреты + откат) под push-deploy; Phase 6 закрывает остаток. §4 «Работа изо дня в день» описывает полный цикл с `/handoff` и упоминает stop-reminder. §5 «Вернуться к уже начатому сайту» — промпт заменён на `/resume`, запасной длинный промпт оставлен на случай ранних версий Claude Desktop без сканирования `.claude/commands/`. §10 (новый) — миграция старого сайта (v2.x) на v3.0 через `_BUILD/v3/02-migrate-existing-project.md`. §11 (новый) — обновление самого bootstrap (для разработчика). «Частые косяки» — добавлены пункты «Claude залип / повторяет круги → /clear → /resume» и «После /resume Claude в другой фазе → поправь project_state.md руками». Шапка — версия v3.0, заметка про `~/Downloads/HOW-TO-START.docx` (синхронизирован с v2.2.1, регенерация через pandoc — post-v3.0 outstanding task).
- **Severity-A финал.** `README.md` H1 v2.3-dx → v3.0, блок «## Версия» переписан под v3.0 (Caddy / push-deploy / standalone / Biome / pnpm-mise / Turnstile / Content Collections / Server Actions / use cache + PPR + OKLCH / multi-Claude). `CLAUDE.md` BOOTSTRAP META: «v2.0 → v2.3.x» → «v2.0 → v3.0», пример semver-тегов «v2.3-dx, v2.4.0» → «v3.0.1, v3.1, v4.0». `docs/INDEX.md` строка про `automation.md` дополнена stop-reminder + slash-командами. В `_BUILD/v3/01-bootstrap-refactor.md` добавлен подраздел «Outstanding после v3.0 (не блокируют тег)» с двумя пунктами: pandoc-регенерация .docx + первый реальный push-deploy на live-VPS (Phase 5 покрыта только письменной верификацией, не обкатывалась).

**8 атомарных коммитов в ветке `feat/v3.0-handoff-protocol`** (от старого к новому): `feat(memory-template)`, `feat(commands)`, `feat(stop-reminder)`, `docs(how-to-start)`, `docs(claude-md-template)`, `docs(claude-md)`, `chore(final-check)`, `chore(memory)` (этот коммит — changelog + project_state финал).

### Что в итоге в bootstrap v3.0 (vs v2.2.1)

- **Caddy** заменил nginx + certbot + cron renewal — auto-HTTPS из коробки (Let's Encrypt + ZeroSSL fallback), multi-site через `import /etc/caddy/Caddyfile.d/*.caddy` (Phase 1).
- **Push-based deploy** через GitHub Actions: build standalone-артефакта на `ubuntu-latest` runner → upload artifact → deploy job rsync'ит `releases/<github.sha>/` → `ln -sfn current/` → `pm2 reload`. На VPS больше не нужен Node toolchain (только runtime + PM2), git с VPS убран (Phase 5).
- **Раздельные SSH-ключи**: приватный — только в GitHub Secrets, на VPS — публичный в `authorized_keys`. Старый `~/.ssh/deploy_key` на VPS убран как класс — git pull больше не нужен (Phase 5).
- **`output: 'standalone'`** в Next.js 16 шаблоне `next.config.ts` — компактный rsync-артефакт без `node_modules` целиком (Phase 5).
- **`.env`** через GitHub Environment Secret `PROD_ENV_FILE` (multiline = всё содержимое `.env.production`) — приходит в момент деплоя, не лежит постоянно на VPS. `scripts/sync-env.sh` остаётся как fallback (Phase 5).
- **Атомарный rollback** через `ln -sfn` на предыдущий релиз в `releases/<previous-sha>/` — миллисекунды, без пересборки. `scripts/rollback.sh` сигнатура `[site] [ssh_alias]` без `<commit-hash>` (Phase 5).
- **Server Actions** для лид-форм (`useActionState` + `<form action={...}>`) — endpoint `/api/lead` больше не создаётся в новых проектах (прогрессивное улучшение, CSRF из коробки, типизированный `LeadState`). Phase 4.
- **`use cache`** директива (опционально, для тяжёлых server-функций / server-компонентов; критерии когда НЕ применять — per-request state, cookies/headers/searchParams). Phase 4.
- **Partial Prerendering** (`experimental.ppr: 'incremental'`, opt-in per-route через `experimental_ppr = true`) — для лендингов с гибридным static+dynamic. Phase 4.
- **OKLCH** в Tailwind v4 (`@theme { --color-primary: oklch(0.45 0.15 250); }`) — предсказуемое осветление через `L`, перцептивно ровный hover через `color-mix in oklch`, поддержка широких гамм P3/Rec2020. HEX из брифа в комментариях рядом как source of truth от заказчика. Phase 4.
- **Cloudflare Turnstile** в формах — бесплатный invisible CAPTCHA от Cloudflare, проверка токена ДО CRM в Server Action, `@marsidev/react-turnstile` на клиенте. Phase 3.
- **Content Collections** для MDX — типобезопасный стек, frontmatter валидируется Zod-схемой в `content-collections.ts`, импорт типизированного `allPosts` (вместо `next-mdx-remote` + ручного `gray-matter`). Phase 3.
- **Biome** заменил ESLint + Prettier — один бинарник, ~10× быстрее, встроенная сортировка Tailwind-классов через `useSortedClasses`. Phase 2.
- **pnpm** через corepack/mise — hardlinks вместо копирования при multi-site, экономия диска на VPS (5–10 сайтов на одном VPS). Phase 2.
- **mise** заменил nvm — единый менеджер версий для Node + pnpm + любого тулинга, читает `.tool-versions` автоматически на `cd`. Phase 2.
- **schema-dts** для типобезопасных JSON-LD — `WithContext<Service>`, `WithContext<BreadcrumbList>`, опечатка в `@type` ловится `tsc --noEmit` на билде. Phase 2.
- **Sequential multi-Claude протокол** через `/handoff` + `/resume` + `/catchup` slash-команды + stop-reminder hook. Phase 6.

### Breaking changes для проектов на v2.x

- `npm` → `pnpm` (нужен `corepack enable` или `mise use pnpm`)
- `nginx` + `certbot` → `Caddy` на VPS (миграция через `_BUILD/v3/02-migrate-existing-project.md`, раздел «nginx → Caddy»)
- Pull-based deploy (git pull + build на VPS) → push-based (build на runner + rsync артефакта). На VPS больше не нужен Node toolchain.
- Route Handler `app/api/lead/route.ts` → Server Action `app/actions/submit-lead.ts` (миграция точечная — старые проекты на Route Handler продолжают работать).
- ESLint + Prettier → Biome (один конфиг `biome.json`).
- `next-mdx-remote` + `gray-matter` → Content Collections (если в проекте есть MDX-блог).

### Миграция старых проектов

См. `_BUILD/v3/02-migrate-existing-project.md` — точечная по разделам, можно делать любое подмножество. Не обязательная: старые проекты на v2.x могут оставаться на v2.x неограниченно.

### Outstanding после v3.0 (не блокируют тег)

- ⏳ Первый реальный push-based деплой на live-VPS — Phase 5 покрыта только письменной верификацией + rollback-планом, не обкатывалась.

### Done после v3.0

- ✅ Регенерация `_BUILD/HOW-TO-START.docx` под v3.0 (PR #16 + #18: §1.5/§3.5/§4/§10 fixes), команда регенерации зафиксирована в шапке `_BUILD/HOW-TO-START.md`.
- ✅ `_BUILD/HANDBOOK.md` (PR #19) — сборный owner-документ из 6 источников через `scripts/build-handbook.sh`.

## v3.0-deploy — 2026-04-28 · Push-based deploy + standalone + раздельные SSH-ключи

Фаза 5 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Самая рискованная фаза: переход с **pull-based** деплоя (Actions → SSH → `git pull` + `pnpm install` + `pnpm build` на VPS → `pm2 restart`) на **push-based** (build на GitHub-runner → `rsync` standalone-артефакта → атомарный switch симлинка `current → releases/<sha>` → `pm2 reload`). Билд больше не идёт на проде, VPS превращён в тонкий runtime (Node + Caddy + PM2, без git и pnpm), приватный SSH-ключ живёт исключительно в GitHub Secrets, а откат — это `ln -sfn` + `pm2 reload` за миллисекунды без пересборки.

Заодно закрыт C-level backlog после Фазы 1: `specs/01b` (генератор артефактов) и `specs/14-migrate` под Caddy, `docs/performance.md` § 6–9 + `specs/11-performance.md` § 9 переписаны с nginx на Caddy `encode gzip zstd` + `header @static`.

- **`output: 'standalone'` в шаблоне `next.config.ts`.** В `specs/02-project-init.md` `next.config.ts` теперь стартует с `output: 'standalone'` — Next кладёт минимально-достаточный сервер (`server.js` + встроенные `node_modules`) в `.next/standalone/`. Артефакт — ~30 MB, упаковывается на runner-е (`.next/standalone/.` + `.next/static/` + `public/` → `deploy/`), uploads as artifact `app`, deploy job скачивает и rsync-ит. Стары блок «Почему без standalone» в `docs/stack.md` переписан на положительный с пояснением, что под push-based это нужно. Done when обновлено.
- **Шаблоны workflow в `_BUILD/v3/templates/`.** Канонические `deploy-prod.yml.example` (build + deploy на environment `production`) и `deploy-dev.yml.example` (триггер на dev, environment `dev`, last-3 cleanup). Структура: build job собирает standalone-артефакт; deploy job скачивает artifact, ssh-keygen из `SSH_PRIVATE_KEY`, `rsync -az --delete` в `releases/<github.sha>/`, пишет `.env` из `PROD_ENV_FILE` heredoc-ом, `ln -sfn current`, `pm2 reload --update-env` (или `pm2 start current/server.js` при первом деплое), cleanup `ls -1tr | head -n -5 | xargs rm -rf`. `concurrency: deploy-prod-${{ vars.SITE_NAME }}` + `cancel-in-progress: false` — параллельные деплои встают в очередь.
- **Раздельные SSH-ключи + git/pnpm с VPS убраны.** Под push-based приватный ключ живёт **только** в GitHub Environment Secret `SSH_PRIVATE_KEY`; на VPS — только публичная часть в `/home/deploy/.ssh/authorized_keys`. Single-purpose ключ генерируется на Mac разработчика (`ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy`), публичная часть докладывается через `ssh-copy-id`, приватная загружается через `gh secret set SSH_PRIVATE_KEY` и удаляется с Mac. Из `scripts/bootstrap-vps.sh` удалён шаг [7/8] (генерация `~/.ssh/deploy_key`); шаги перенумерованы [N/7]; из `apt install` убраны `git` и pnpm-через-corepack; PM2 ставится через `npm install -g`. `docs/server-manual-setup.md` и `server-add-site.md` обновлены: VPS не клонирует репо, не билдит — только принимает `rsync`.
- **Структура `releases/<sha>/` + симлинк `current/` на VPS.** Каждый билд кладётся в `/home/deploy/prod/{site}/releases/<sha>/`, `current` атомарно переключается через `ln -sfn`. PM2 живёт на `current/server.js` — путь стабильный, переключается симлинком, `pm2 reload --update-env` подхватывает новый код без даунтайма. `.env` пишется в `releases/<sha>/.env` рядом со standalone-сборкой (изолирован per-release — старые env в старых релизах не мешают). Cleanup-шаг workflow держит last 5 для prod, last 3 для dev. Документация — новый раздел «Структура релизов на VPS» в `docs/deploy.md` + расширенный § 3 в `docs/server-add-site.md` с tree-визуализацией.
- **`scripts/rollback.sh` атомарный.** Старая логика (`git fetch + git reset --hard + pnpm install + pnpm build + pm2 restart`) умерла вместе с pull-based deploy — на VPS нет ни git, ни pnpm. Новая: скрипт ssh-ит на VPS, `readlink current` → берёт sha, `ls -1tr releases | grep -vx "$current_sha" | tail -1` → берёт предыдущий, `ln -sfn releases/$prev current`, `pm2 reload {site}-prod --update-env`, `pm2 save`. Миллисекунды, без пересборки. Сигнатура упростилась до `scripts/rollback.sh [site] [ssh_alias]` (был `<commit-hash> [site] [ssh_alias]`). Если в `releases/` лежит только один релиз — отказывается, отката нет.
- **`.env` через GitHub Environment Secrets, `sync-env.sh` — fallback.** В штатном flow `.env` пишет workflow на каждом деплое из multiline-секрета `PROD_ENV_FILE` (`gh secret set --env production PROD_ENV_FILE < ~/projects/{site}/.env.production` + push в main). `scripts/sync-env.sh` остаётся как fallback для трёх ситуаций: Actions недоступны (GitHub outage), env поменялся mid-cycle (не хочется ждать следующего push), recovery после ручных правок на VPS. Скрипт теперь пишет в `current/.env` (через симлинк попадает в активный `releases/<sha>/.env`), делает `pm2 reload` вместо restart, и сразу предупреждает что следующий push перезапишет файл из секрета. `_BUILD/HOW-TO-START.md` § 8 переписан под `gh secret set` + триггер пустым коммитом; § 9 «Сломал прод» под симлинк-rollback.
- **Спеки 01b/12/14 переписаны.** `specs/01b-server-handoff.md` — Tasks ссылаются на канонические шаблоны из `_BUILD/v3/templates/`, `deploy/{site}.caddy.example` вместо `nginx.conf.example`, `deploy/README.md` теперь включает шаги генерации SSH-ключа, `ssh-copy-id` на VPS, `gh secret set` для всех Environment-секретов; добавлено Boundary «Never генерировать ~/.ssh/{site}-deploy сам — Claude не должен видеть приватные ключи». `specs/12-handoff.md` — runbook «Откат», «Обновления не приехали», «Лиды не доходят», «Сайт работает медленно» обновлены под push-based реальность (`scripts/rollback.sh` вместо ручного git reset, `gh secret set PROD_ENV_FILE` вместо ручного `.env` на VPS, fallback через локальный rsync standalone-сборки если Actions полностью лежат). `specs/14-migrate.md` (M1–M4) — все Tasks под push-based + Caddy: `mkdir releases/` + `ssh-copy-id` + триггер workflow пустым коммитом вместо `git clone + pnpm build` на новом VPS; SSL автоматически Caddy после DNS switch вместо `certbot --nginx -d`; decom — `sudo rm /etc/caddy/Caddyfile.d/{site}.caddy + caddy reload` вместо nginx sites-enabled. Имена секретов везде заменены на новые (`SSH_PRIVATE_KEY/SSH_HOST/SSH_USER/SSH_PORT/PROD_ENV_FILE` вместо `DEPLOY_SSH_KEY/SERVER_IP`).
- **`docs/deploy.md` + `docs/troubleshooting.md` + perf-доки.** Полностью переписана ASCII-схема в `docs/deploy.md` под push-based pipeline (Mac → GitHub → runner → rsync → VPS); раздел «Как выглядит GitHub Actions» теперь описывает два job-а через шаблон в `_BUILD/v3/templates/`, secrets описаны таблицей под Environment-секреты. В `docs/troubleshooting.md` секция «deploy_key permission denied» переписана на «SSH permission denied в deploy job» (диагностика парности ключей через `ssh-keygen -y -f`); добавлены три новых сценария: «Симлинк current не переключился», «rsync завершился с ошибкой», «PM2 не находит server.js в current/». `docs/performance.md` § 6–9 + `specs/11-performance.md` § 9 переведены с nginx на Caddy: `encode gzip zstd` вместо `gzip on + gzip_static`, `@static path + header Cache-Control` вместо `location ~* \.(js|css|...)`, таблица «что Caddy включает по умолчанию» вместо ручного nginx-блока с `ssl_protocols`/`ssl_session_cache`/`keepalive_timeout` (Caddy всё это даёт из коробки + HTTP/3). Шаблон `next.config.ts` в обоих файлах стартует с `output: 'standalone'` и комментарием «сжатие — на Caddy».

9 атомарных коммитов в ветке `feat/v3.0-push-deploy`: `feat(standalone)`, `feat(workflow)`, `feat(ssh-keys)`, `feat(releases-dir)`, `refactor(rollback)`, `feat(env-secrets)`, `refactor(specs)`, `docs(deploy)`, `chore(memory)`. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Существующие проекты на pull-based deploy (с git pull + pnpm build на VPS) продолжают работать; миграция на push-based — точечная и описана в `_BUILD/v3/02-migrate-existing-project.md` (раздел «pull-based → push-based deploy»).

⚠️ **Без обкатки на тестовом VPS.** Эта фаза целенаправленно сделана с большой долей письменной верификации (все workflow-шаги расписаны, troubleshooting сценарии добавлены), но первый реальный push-based деплой на live-VPS — это всё ещё предстоит. Rollback фазы (`git tag pre-phase-5; git reset --hard pre-phase-5`) задокументирован; Артефакт 2 (миграция реального сайта) — в `_BUILD/v3/02-migrate-existing-project.md`.

## v3.0-next16 — 2026-04-28 · Next.js 16 patterns: Server Actions + use cache + PPR + OKLCH

Фаза 4 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Шаблон обновлён под современные паттерны Next.js 16: формы лидов мигрированы на **Server Actions** (вместо Route Handler `/api/lead`), добавлены опциональные паттерны **`use cache`**, **Partial Prerendering**, **`useOptimistic`** и переход на **OKLCH** в Tailwind v4. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Существующие проекты на Route Handler продолжают работать; миграция точечная (`_BUILD/v3/02-migrate-existing-project.md`, раздел «Server Action вместо `/api/lead`»).

- **Server Actions для лид-форм.** Endpoint `app/api/lead/route.ts` **больше не создаётся** в новых проектах. Лиды идут через Server Action `app/actions/submit-lead.ts` (`'use server'` + `submitLead(prevState, formData)`), та же цепочка шагов (rate-limit → Zod-валидация → Turnstile verify → CRM → fallback в `data/leads.json`), но возвращает типизированный `LeadState = { success: true } | { error: string } | null` вместо `NextResponse.json()`. Клиентская форма — через `useActionState(submitLead, null)` + `<form action={formAction}>`: без `fetch`, без ручного `e.preventDefault()`, `isPending` идёт прямо на `disabled` кнопки. Бонусы: **прогрессивное улучшение** (форма работает даже при выключенном JS — Next отправит multipart/form-data, Server Action отработает на сервере), **CSRF-защита из коробки** (Next добавляет `next-action` header автоматически), **один меньше публичный endpoint** (нет `/api/lead`, который нужно защищать от прямых POST с Postman). `docs/forms-and-crm.md` полностью переписан: ASCII-схема, клиентская часть, бывший раздел «API Route» → «Server Action». `specs/09-forms-crm.md` Goal + секция «API endpoint» → «Server Action», шаги 4–8 переписаны под `useActionState`. `docs/architecture.md` структура папок (`app/actions/` вместо `api/lead/`), раздел SSG упоминает Server Actions для форм. Обновлены `CLAUDE.md`, `_BUILD/claude-md-template.md` (stack-строка форм; шаблон поднят до `v3.0-next16`), `docs/INDEX.md`, `specs/INDEX.md`, `specs/12-handoff.md` (runbook «Лиды не доходят»), `specs/optional/opt-quiz.md` (KB-файл и финальный submit), `.claude/memory/pointers.md` (явная пометка «Endpoint `/api/lead` не существует»).
- **Директива `use cache` для server-функций и компонентов.** В `docs/performance.md` § 7 новый ###-подраздел «Next.js: директива `use cache`» — что это (штатная замена `unstable_cache`/`cache()`, перенесённая в директиву уровня функции), два примера (server-функция `getServicesPricing(region)` и server-компонент `<HeavyServerSection />`), явные критерии когда применять (тяжёлые server-компоненты, fetch к редко-меняющимся API, детерминированные расчёты) и когда **не** применять (per-request state — личный кабинет/корзина/авторизация — будет шарить ответ между пользователями = security-баг; компоненты, читающие `cookies()`/`headers()`/`searchParams` — Next ругается на билде). Заметка про `cacheTag()`/`cacheLife()` для точечной инвалидации и про необходимость флага `experimental.useCache: true` в `next.config.ts` на момент Next.js 16.0. В `specs/05-subpages-template.md` — секция «Опционально: `use cache` для тяжёлых server-компонентов» с примером `ComparisonSection` и явной заметкой не применять для статичных Hero/Steps/FAQ. В `specs/07-blog-optional.md` — callout, что `use cache` поверх Content Collections обычно избыточен (CC уже build-time), нужен только для тяжёлой фильтрации/поиска по тегам.
- **Partial Prerendering (опционально).** В `docs/architecture.md` новый раздел с примером гибридной страницы (статичный hero/description + `<Suspense fallback>` вокруг `<SeatsCounter>` для динамики) и явные критерии где оправдано (лендинги услуг с `live`-счётчиками, A/B-варианты, персонализация по cookie) и где не нужно (полностью статичные страницы → стандартный SSG быстрее; полностью динамические → обычный SSR; динамика ниже первого экрана → проще `dynamic({ ssr: false })` без всей PPR-машинерии). В `specs/02-project-init.md` шаблон `next.config.ts` получил `experimental.ppr: 'incremental'` — это режим opt-in: страницы остаются обычными SSG/ISR, PPR активируется только там, где явно прописан `export const experimental_ppr = true`. Если в проекте PPR не пригодится — флаг можно убрать без последствий. Сам PPR на момент Next.js 16 — `experimental`, поэтому по умолчанию в шаблоне выключен через `incremental`, не `'auto'`.
- **`useOptimistic` как опциональный паттерн.** В `docs/forms-and-crm.md` новый раздел «`useOptimistic` для UX-без-задержки (опционально)» с примером многошагового сценария (квиз). Явная заметка, что **для лид-формы паттерн обычно не нужен** — лид и так считается успешным благодаря fallback в `data/leads.json` (даже при падении CRM пользователь видит «отправлено»), `isPending` из `useActionState` достаточно. `useOptimistic` оправдан там, где есть **осмысленный откат** (toast «не удалось сохранить»), а не как украшательство.
- **OKLCH в Tailwind v4.** В `docs/design-system.md` § «Цветовая палитра» новый ###-подраздел «OKLCH вместо HEX/HSL/RGB» — пример `@theme { --color-primary: oklch(0.45 0.15 250); ... }`, четыре причины почему OKLCH лучше для дизайна (предсказуемое осветление при изменении `L`, плавные градиенты без проседания серого, перцептивно ровные hover-варианты через `color-mix in oklch`, поддержка широких гамм P3/Rec2020 на современных дисплеях). Заметка про ~95% browser support (с лета 2023) и автофоллбек Tailwind v4 в RGB. В `specs/03-design-system.md` шаги 1–3 обновлены: HEX-токены заменены на OKLCH-токены внутри `@theme` (Tailwind v4 не требует `:root` + `tailwind.config.ts` — всё через `@theme` в `globals.css`), HEX из брифа остаётся в комментариях рядом с OKLCH-значением как «source of truth от заказчика», проверка через `bg-primary/90` (`color-mix in oklch`).

5 атомарных коммитов в ветке `feat/v3.0-next16-patterns`: `feat(server-actions)` (Subtask 1+4 — Server Action и `useOptimistic` сделан попутно в том же файле), `feat(use-cache)`, `feat(ppr)`, `feat(oklch)`, `chore(memory)` (changelog + project_state). Сам bootstrap-репо ничего не билдит. Существующие проекты, использующие `/api/lead` Route Handler, продолжают работать; миграция точечная и описана в `_BUILD/v3/02-migrate-existing-project.md`.

## v2.4 — 2026-04-28 · Cloudflare Turnstile + Content Collections

Фаза 3 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Закрыты две функциональные дыры в шаблоне: **антиспам форм** через Cloudflare Turnstile и **типобезопасный MDX-стек** через Content Collections (вместо `next-mdx-remote` + ручного `gray-matter`). Обе правки — в спеках и доке, существующие проекты на старом стеке продолжают работать; миграция точечная (`_BUILD/v3/02-migrate-existing-project.md`).

- **Cloudflare Turnstile в формах.** Бесплатный CAPTCHA-аналог от Cloudflare с invisible-режимом по умолчанию (без VPN-блокировок reCAPTCHA, без вендор-лока на Google). Клиент через официальную обёртку `@marsidev/react-turnstile` (ленивая загрузка скрипта, ref для `reset()` после submit — токен одноразовый, иначе `timeout-or-duplicate` от CF). Сервер проверяет токен на `challenges.cloudflare.com/turnstile/v0/siteverify` (`application/x-www-form-urlencoded`, не JSON) **до** обращения к CRM — иначе при падающей CRM бот успеет насыпать в `data/leads.json`. Site-key (`NEXT_PUBLIC_TURNSTILE_SITE_KEY`) — единственное `NEXT_PUBLIC_` в формах (публичный по дизайну Cloudflare); secret-key (`TURNSTILE_SECRET_KEY`) — только серверный. Если у заказчика уже есть Cloudflare-аккаунт под DNS — Turnstile заводится там же, иначе отдельная регистрация (бесплатно). В `docs/forms-and-crm.md` — новый раздел «Антиспам — Cloudflare Turnstile» с готовым кодом для клиента и сервера, пояснением одноразовости токена и тестовыми ключами для localhost. В `specs/09-forms-crm.md` — отдельная секция «1. Cloudflare Turnstile», шаги установки/env/виджета и Turnstile-edge-кейсы в тестировании. В `docs/stack.md` — `@marsidev/react-turnstile` в вспомогательных пакетах + в init-команду как универсальная form-зависимость. В `specs/02-project-init.md` — `@marsidev/react-turnstile` в дефолтный install шаг 4.
- **Content Collections вместо `next-mdx-remote` + `gray-matter`.** Типобезопасный MDX-стек: Zod-схема в `content-collections.ts` — единая точка истины для frontmatter всех `.mdx` в `content/`. На билде Content Collections парсит, валидирует, компилирует и кладёт в `.content-collections/generated`. В коде — `import { allPosts } from 'content-collections'` (типизированный массив, IDE-автокомплит). Опечатка в `@type` или невалидный `date` — TypeScript-ошибка / понятный лог на билде, не runtime-500. Спека `specs/07-blog-optional.md` полностью переписана: установка (`content-collections @content-collections/core @content-collections/mdx @content-collections/next` + `@tailwindcss/typography`), `withContentCollections(nextConfig)`, `tsconfig.json paths` алиас, Zod-схема с draft-полями и `readingTime` в transform, `generateStaticParams` через `allPosts.filter(p => !p.draft)`, рендер через `<MDXContent code={post.mdx} />`. Добавлена сравнительная таблица «next-mdx-remote vs Content Collections». В `docs/architecture.md` — раздел «MDX через Content Collections» переписан, в схему папок добавлены `content-collections.ts` (root) и `.content-collections/` (gitignored). В `docs/stack.md` — MDX-row обновлён, в вспомогательных пакетах строка про CC + плагины. CC ставится **опционально** в spec/07 (только если в `docs/pages.md` запланирован блог) — поэтому из дефолтного init в `docs/stack.md` и `specs/02-project-init.md` пакеты CC убраны вместе со старыми `next-mdx-remote gray-matter`. В `.claude/memory/pointers.md` — новый раздел «Контент (MDX через Content Collections)».

3 атомарных коммита в ветке `feat/v2.4-turnstile-content-collections`: `feat(turnstile)`, `feat(content-collections)`, `chore(memory)`. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Для существующих проектов на `next-mdx-remote` шаги миграции — в `_BUILD/v3/02-migrate-existing-project.md` (раздел «next-mdx-remote → Content Collections»).

## v2.3-dx — 2026-04-28 · DX win: Biome, pnpm, mise, schema-dts

Фаза 2 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Четыре локальных DX-замены тулинга на Mac разработчика, без архитектурных изменений в рантайме сайтов. Каждый пункт по отдельности — мелкая правка; вместе они дают ощутимый ежедневный win: один линтер вместо двух, единый менеджер версий, экономия диска при multi-site, типобезопасный JSON-LD.

- **Biome вместо ESLint+Prettier.** Один бинарник, один конфиг, ~10× быстрее на типичном Next-проекте. Tailwind-классы сортируются встроенным правилом `useSortedClasses` (с распознаванием `clsx`/`cva`/`cn`/`tw`) — `prettier-plugin-tailwindcss` убран. `package.json scripts` теперь: `lint: biome check`, `format: biome check --write`, `typecheck: tsc --noEmit` (отдельно, потому что Biome не делает type-checking). В корне bootstrap'а появился `biome.json.example` (linter+a11y recommended, lineWidth 100, single quotes, no semicolons). Хук `.claude/hooks/format.sh` переключён с Prettier на Biome. Установка в `specs/02`: `pnpm add -D --save-exact @biomejs/biome && pnpm exec biome init`. Флаг `--no-eslint` добавлен в `create-next-app` — иначе он по умолчанию ставит ESLint, который мы тут же удаляем.
- **pnpm вместо npm.** Hardlinks вместо копирования при multi-site дают экономию диска на VPS (5–10 сайтов на одном VPS — типичный сценарий, см. `docs/server-multisite.md`). Полный sweep по spec'ам, доке и хелперам: `npm install` → `pnpm add`, `npm install -D` → `pnpm add -D`, `npm ci` → `pnpm install --frozen-lockfile`, `npm run X` → `pnpm X`, `package-lock.json` → `pnpm-lock.yaml`. На VPS pnpm активируется через `corepack` (идёт в комплекте с Node 16.13+) — отдельный apt-пакет не нужен. PM2 на VPS теперь ставится через `pnpm add -g` для консистентности. На Mac в `_BUILD/HOW-TO-START.md` тоже `corepack enable && corepack prepare pnpm@latest --activate` — а после Phase 2 это делает уже mise (см. ниже). `scripts/rollback.sh` обновлён.
- **mise вместо nvm.** Единый version manager для всего тулинга проекта (Node, pnpm, при необходимости Python/Go и т.д.). Читает `.tool-versions` автоматически на `cd` в папку — никакого ручного `nvm use`. В корне bootstrap'а появился пример `.tool-versions` (`node 22` + `pnpm latest`). `_BUILD/HOW-TO-START.md` § 0.4 переписан: `brew install gh mise` + `eval "$(mise activate zsh)"` в zshrc + `mise use --global node@22 pnpm@latest`. `specs/01a-local-setup.md` переключён с `.nvmrc` на `.tool-versions`; toolchain-проверка теперь `pnpm -v ≥ 9` вместо `npm -v`. `docs/team-onboarding.md` инструкция установки — `mise install && pnpm install`.
- **schema-dts для типобезопасного JSON-LD.** Типы Schema.org от Google. В `lib/schema.ts` функции теперь возвращают `WithContext<Service>`, `WithContext<BreadcrumbList>`, `WithContext<FAQPage>`, `WithContext<Organization>`, `WithContext<Article>` и т.д. Опечатка в `@type` или поле — TypeScript-ошибка на билде (`tsc --noEmit`), а не «странный warning в Yandex Validator уже на проде». Добавлен в `docs/stack.md` (helpers), в `specs/02` install (`pnpm add -D schema-dts`), в примеры `lib/schema.ts` в `specs/05` (Service/BreadcrumbList/FAQPage) и `specs/08` (Organization/LocalBusiness/Article).
- **Severity-A sweep по стек-строкам.** `CLAUDE.md` Stack-секция, `_BUILD/claude-md-template.md` (тот, что копируется в новые проекты), `README.md` H1 + Версия + Требования — все обновлены под v2.3-dx. `pnpm dev`/`pnpm build` теперь видны в Commands при старте каждой Claude-сессии, иначе модель работала бы по устаревшему `npm run`-стеку. README поднят с v2.2.2 до v2.3-dx (Phase 1 Caddy не обновил его — закрыли вместе).

8 атомарных коммитов в ветке `feat/v2.3-dx-biome-pnpm-mise`. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Существующие проекты, уже сидящие на ESLint+Prettier+npm+nvm, продолжают работать; миграция точечная (см. `_BUILD/v3/02-migrate-existing-project.md`, который покрывает в том числе nvm → mise).

## v2.3-caddy — 2026-04-28 · Caddy вместо nginx+certbot

Фаза 1 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Заменили связку `nginx + certbot + cron renewal` на **Caddy** — встроенный ACME (Let's Encrypt + ZeroSSL fallback), автоматический HTTPS, multi-site через `import /etc/caddy/Caddyfile.d/*.caddy`. ~30 строк nginx-конфига на сайт превратились в ~6 строк Caddyfile, ручной certbot и его системный таймер больше не нужны.

- **`scripts/bootstrap-vps.sh`** — apt-репо Caddy (cloudsmith) с GPG-ключом, `apt install caddy` вместо `nginx + certbot + python3-certbot-nginx`. Базовый `/etc/caddy/Caddyfile` с глобальным `email` + `import Caddyfile.d/*.caddy`. Папка `/etc/caddy/Caddyfile.d/` создаётся пустой с `00-placeholder.caddy` на `:8080`, чтобы `caddy validate` не падал на пустом glob'е до первого сайта. `caddy validate` перед `systemctl reload caddy`. Параметр `CADDY_ADMIN_EMAIL` — обязательный (без email ACME у Caddy не работает).
- **`docs/server-manual-setup.md`** — шаги 5 и 8 переписаны под Caddy. Команды запуска передают `CADDY_ADMIN_EMAIL` через env. Верификация: `caddy validate` + `systemctl is-active caddy`. Раздел «Обслуживание» — `journalctl -u caddy` для аудита SSL-ошибок вместо `certbot certificates`. Добавлены частые проблемы: placeholder `:8080`, ACME не выпускается (DNS / ufw).
- **`docs/server-add-site.md`** — полностью переписан § «положить конфиг» под Caddy: один файл на сайт в `/etc/caddy/Caddyfile.d/{site}.caddy`, шаблон с `reverse_proxy` + `encode gzip zstd` + `Cache-Control` (immutable 1y для статики, must-revalidate для HTML), опциональный dev-поддомен с `basicauth`. Удаление `00-placeholder.caddy` при первом сайте. § SSL: ничего делать не нужно — Caddy сам пройдёт HTTP-01 challenge при первом запросе. § Автопродление: Caddy за 30 дней до истечения, без cron.
- **`docs/server-multisite.md`** — multi-site через `Caddyfile.d/*.caddy` вместо `sites-available/sites-enabled`-symlink'ов. SSL-лимит Let's Encrypt — упомянут ZeroSSL fallback и DNS-01 wildcard через Caddy plugin.
- **`docs/deploy.md`** — ASCII-схема: «nginx + SSL» → «Caddy + ACME». Cloudflare-секция: добавлен подводный камень с HTTP-01 через CF proxy и обходные пути (DNS-01 через `caddy-dns/cloudflare` plugin), `trusted_proxies cloudflare` для логов реального IP.
- **`docs/troubleshooting.md`** — добавлены два раздела. «Caddy не стартует / падает после правки» — диагностика `systemctl status` + `journalctl` + `caddy validate`, типичные причины (typo, port conflict со старым nginx, права на `/var/lib/caddy`). «SSL не выписывается (Caddy)» — четыре причины по частоте (DNS, ufw 80, CF proxy, Let's Encrypt rate limit). Анти-совет: не делать `systemctl restart caddy` при ACME-проблемах, чтобы не сбить экспоненциальный бэкофф.
- **`specs/12-handoff.md`** — в runbook'е «SSL-сертификат истёк» команды `certbot renew` + `systemctl reload nginx` заменены на диагностику Caddy. В «Раз в месяц» — `systemctl status caddy` вместо `certbot certificates`.
- **Severity-A: stack strings.** `CLAUDE.md`, `_BUILD/claude-md-template.md`, `.claude/memory/references.md` — stack-строка проекта (`PM2 + Nginx + Let's Encrypt` → `PM2 + Caddy (встроенный ACME)`), путь к конфигу (`/etc/nginx/sites-available/[project]` → `/etc/caddy/Caddyfile.d/[project].caddy`), описание SSL (`auto-renew через certbot` → `автообновляется Caddy`). Эти строки попадают в context новой Claude-сессии при старте — несоответствие создавало бы ложную картину инфры.
- **Severity-B: descriptions sweep.** Точечные упоминания в `README.md` (01b генерит «Caddy-шаблон»), `docs/INDEX.md` (таблица KB-файлов и поинтер «Caddy-шаблон → server-add-site.md»), `scripts/README.md` (стек bootstrap-vps.sh + verify inline пример), `docs/domain-connect.md` (Cloudflare proxy + ACME, Caddy-симптомы вместо certbot), `docs/seo.md` (X-Robots-Tag через `curl -I`, склейки через Caddy `redir`), `specs/02-project-init.md` (комментарий `compress: false`), `specs/08-seo-schema.md` (§ редиректы переведён на Caddyfile.d/), `specs/optional/opt-i18n.md` (поддомен через блок в Caddyfile.d), `specs/optional/opt-migrate-from-existing.md` (`nginx upstream` → `reverse_proxy` upstream).

11 атомарных коммитов в ветке `feat/v2.3-caddy`. Сам bootstrap-репо ничего не билдит — изменения проявятся только при следующем запуске `bootstrap-vps.sh` на свежем VPS или при миграции существующего (см. `_BUILD/v3/02-migrate-existing-project.md` § «nginx → Caddy»). Существующие prod-VPS на nginx+certbot продолжают работать как раньше — миграция точечная.

**Отложено на отдельные задачи (C-level, ~4 файла, требуют структурной переработки):**
- `specs/01b-server-handoff.md` — спека генерирует артефакт `deploy/nginx.conf.example`. Под Caddy это становится `deploy/{site}.caddy.example` с другим шаблоном; меняется и сам код-генератор внутри спеки, и acceptance criteria.
- `specs/14-migrate.md` — миграционный runbook (M1–M4), несколько мест с `certbot --nginx -d` и `nginx -t` в командах для VPS-cutover.
- `docs/performance.md` (§ 7–8 «Серверная оптимизация (nginx)») и `specs/11-performance.md` (§ 9 «Nginx-уровень») — целые секции про gzip/brotli/Cache-Control в nginx. Caddy делает большую часть этого через `encode gzip zstd` + `header @static Cache-Control` (уже в шаблоне `server-add-site.md` после Фазы 1) — секции нужно сильно сократить или превратить в «как проверить, что Caddy всё это уже делает». Это де-факто ревизия performance-методики, попадает в Фазу 4 / отдельный pass.

## v2.2.2 — 2026-04-28 · P0 hotfix bundle

Фаза 0 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. 12 точечных правок поверх v2.2.1, без архитектурных изменений — закрываем накопившиеся противоречия и битые ссылки перед переходом на v3.0.

- **P0-1 (compress-images.mjs).** Скрипт никогда не существовал. Убрано из `package.json scripts`, описаний папок, `npm run build`, упоминаний в перформанс-доках. `next/image` сам ресайзит и оптимизирует на лету (sharp подключается как `optionalDependency` Next.js 15+).
- **P0-2 (localhost:4000 → :3000).** Три места в `specs/02`, `specs/03`, `docs/team-onboarding.md` отстали от единого порта 3000. Легитимный `:4010` в `docs/deploy.md` (dev-поддомен на VPS) не трогали.
- **P0-3 (синхронизация версий).** `README.md` H1 = `v2.2.2`, блок «Версия» переписан под актуальную дату. `_BUILD/claude-md-template.md` — дефолт стека `v2.2.2`. В meta-шапке `CLAUDE.md` — история версий «v2.0 → v2.2.x», пример тегов «v2.2.3 / v2.3.0».
- **P0-4 (`_BUILD/migration-map.md` ссылки).** Файла нет и не будет (содержание в changelog). Убраны упоминания из `README.md` ×2, `specs/00-brief.md`, `_BUILD/changelog.md`.
- **P0-5 (схемы A/B деплоя).** Остатки в `specs/13-extend-site.md` и `specs/06-subpages-rollout.md` приведены к единому push-flow `git push origin dev → PR в main → автодеплой через Actions` (схему B убрали в v2.1, но местами осталась).
- **P0-6 (ConsultationDialog spec).** В `specs/02-project-init.md:71` указано, что Provider добавляется в спеке 09 — на самом деле в 04 (вместе с первой формой на главной).
- **P0-7 (footer ссылки на /privacy /terms).** В спеке 03 убрали эти ссылки из Footer (страниц ещё нет — будут битые). Добавили шаг 12 в `specs/09-forms-crm.md` — обновить Footer.tsx после создания юр-страниц.
- **P0-8 (`hooks.json` → `settings.json`).** В `docs/workflow.md` исправлено название файла с хуками — реально это `.claude/settings.json`.
- **N1 (`scripts/README.md`).** Добавлены строки про `rollback.sh` и `sync-env.sh` в таблицу скриптов (появились в v2.2, но в README не попали).
- **N2 (Zod → Valibot совет).** Решение проекта: Zod остаётся (на лендинге ~100 KB незаметны, экосистема RHF + Zod зрелая). Совет «замени на valibot» убран из `specs/11`, `docs/performance.md`, `docs/stack.md`. В таблицу красных флагов вместо Zod — `react-icons` целиком (где tree-shake реально критичен).
- **N3 (`IDEAS.md`).** Файла нет, упоминание из meta-шапки `CLAUDE.md` убрано.
- **N4.** Эта запись.

12 атомарных коммитов в ветке `fix/v2.2.2-p0-bundle`. Архитектура без изменений — большой рефакторинг (Caddy / pnpm / Biome / push-deploy / Next 16 паттерны / multi-Claude handoff) идёт отдельным треком, см. `_BUILD/v3/01-bootstrap-refactor.md`.

## v2.2.1 — 2026-04-27 · HOW-TO-START clarity pass

Доводка инструкции после первой эксплуатации — стало понятнее для тех, кто видит её впервые (а не только для меня).

- **Новый §0.0 «Аккаунт на GitHub».** Что делать если аккаунта ещё нет, как узнать свой логин, чёткий словарик плейсхолдеров (`<твой-логин>`, `<твой-email>`, `{site}`) и правило «угловые/фигурные скобки заменяешь целиком, двойные кавычки — оставляешь».
- **§0.4** — пример успешного вывода `node --version` с пометкой «нужно v22 или новее, иначе `brew upgrade node`».
- **§0.5 (Git identity)** и **§0.6 (SSH-ключ)** перестроены на пару «шаблон + пример». Email теперь личный (раньше был placeholder `твой-email@example.com`, легко принять за инструкцию).
- **§0.7** — пример успешного `gh auth status`, чтобы не путать с ошибкой.
- **§1 (gh repo create)** — явное пояснение про два разных GitHub-имени в команде («первое имя — куда положить, второе — откуда взять, не перепутай»). Конкретный пример с `tem11134v2/migrator`. Блок «что произойдёт» после команды.
- **§2** — заметка про разовый macOS-промпт «Claude wants access to folder».
- **§9** — пояснение что такое `<hash>` (короткий идентификатор коммита, видно в `git log` или в URL).

`.docx` перегенерирован, ZIP-целостность валидна. Контент: 1×H1, 13×H2, 10×H3.

## v2.2 — 2026-04-26 · Automation layer

Сняли с человека всё, что Claude может делать сам: проверки перед сессией, переключение gh-аккаунтов, синхронизацию `.env` на VPS, откат прода, чистку старого swap до bootstrap. Теперь `HOW-TO-START` гораздо короче — длинных ручных ритуалов в нём почти не осталось.

- **Хуки `.claude/hooks/`:**
  - `session-start.sh` — `git fetch` + проверки в начале каждой сессии (отставание ветки, uncommitted, gh ↔ remote owner mismatch). Информирует, не блокирует.
  - `before-push.sh` — блокирует Claude-side `git push` / `gh pr` / `gh repo` при несовпадении активного gh-аккаунта с владельцем remote-а (exit 2). Caveat: не ловит терминальный push пользователя — это страховка от ошибок Claude, не immutable защита.
  - `format.sh` (prettier autoformat на изменённые файлы) и `guard-rm.sh` (блок `rm -rf /|~|*` и `git push --force`) — добавлены в шаблон (раньше были только проектным артефактом).
- **Скрипты `scripts/`:**
  - `sync-env.sh` — копирует `~/projects/{site}/.env.production` (gitignored) на VPS в `/home/deploy/prod/{site}/.env`, `chmod 600`, `pm2 restart --update-env`. Один канонический путь, без вопросов.
  - `rollback.sh` — `ssh + git reset --hard <hash> + npm ci + build + pm2 restart` на проде. Подсказывает корректный `git revert` (включая `-m 1` для merge-коммитов — частая ловушка после PR-merge).
  - `bootstrap-vps.sh` — pre-clean: пересоздаёт `/swapfile`, если его размер не совпадает с `SWAP_SIZE` (фикс для Timeweb default 512M).
- **Документация:**
  - `docs/automation.md` — описание четырёх хуков и двух скриптов: что делают, как локально отключить, как добавить новый.
  - `docs/troubleshooting.md` — gh auth mismatch, DDoS-Guard 301 до cutover, deploy_key denied, branch protection 403 на private+free, swap не пересоздаётся, prod 404 после билда.
  - `docs/team-onboarding.md` — для нового collaborator-а: clone, `npm install`, Claude Code, `feature → dev → main`. Чётко перечислено, что **не** дают (SSH, deploy_key, secrets).
- **`CLAUDE.md` — секция «Automation rules»:** session-start, before-push, secrets, rollback. Шаблонные формулировки без проектных аліасов.
- **`_BUILD/HOW-TO-START.md` + `.docx`:** переписаны. Сокращены §3 (доверяем session-start hook), `gh auth status` сжат в «Частые косяки». Добавлены §7 (collaborator), §8 (секреты), §9 (откат) — каждая по 1–2 строки промпта Claude'у. Entry-point для миграции живого сайта.
- **Branch protection:** включена на `main` шаблона (он public — бесплатно). Require PR, no force push, no deletions.
- **Тег `v2.2` после merge.**

## v2.1.3 — 2026-04-24 · Handoff and migration playbooks

Закрыли белое пятно: что делать когда сайт передаётся заказчику или переезжает на другой VPS. Спеки `12-handoff` и новая `14-migrate` покрывают все сценарии, которые Timur использует на практике.

- **`specs/12-handoff.md` переписан под три модели handoff'а:** H1 (full transfer — дефолт), H2 (client-owned, dev operates), H3 (read-only). HANDOFF.md-шаблон теперь содержит runbook + monthly maintenance + инструкцию по самостоятельному отзыву прав разработчика.
- **Новая `specs/14-migrate.md`** с четырьмя сценариями: M1 (scaling), M2 (handoff), M3 (emergency), M4 (clone to new domain). Scp runtime-данных, DNS switch, **7-day soak** перед decommission.
- **Зафиксированы дефолтные правила:**
  - `data/leads.json` — fallback, не источник истины (источник — CRM).
  - 7 дней между DNS switch и выключением старого VPS.
  - Single-Claude модель — мульти-разработчик не поддерживается; при handoff'е Claude заказчика заменяет Claude разработчика, а не идёт параллельно.
- `specs/INDEX.md` — спека `14-migrate` добавлена в основной поток (опциональная, после 12 или между 10/11 при масштабировании).

## v2.1.2 — 2026-04-24 · Security hardening pass

Добавили разумные дефолты поверх базового bootstrap. Применены и проверены на том же Timeweb VPS.

- **Non-standard SSH port (default 2222).** Параметризуемо через `SSH_PORT`. Критичный нюанс Ubuntu 22.04+: надо `systemctl disable ssh.socket && systemctl enable ssh.service` — иначе socket activation игнорирует `Port` из `sshd_config`.
- **fail2ban строже:** 3 попытки / 10 минут / бан 24 часа. `backend=systemd` (на Ubuntu 24.04 auth-логи идут в journald, не в `/var/log/auth.log`).
- **unattended-upgrades.** Security patches применяются автоматически ежедневно, без auto-reboot. Ставит `apt-listchanges` для журнала изменений.
- **Mac-side `~/.ssh/config`** с алиасом `vps1` — `ssh deploy@IP` работает без `-p 2222`. Инструкция в `docs/server-manual-setup.md`.

## v2.1.1 — 2026-04-24 · Claude-driven server bootstrap

Второй proход после живого тестирования на Ubuntu 24.04 Timeweb VPS. Обнаружили delta между чек-листом и реальностью, переписали под скрипт.

- **Добавлен `scripts/bootstrap-vps.sh`** — идемпотентный скрипт, делает всё что раньше было чек-листом. Проверен на Timeweb VPS.
- **Роль серверных доков инвертирована:** `server-manual-setup.md` теперь **для Claude**, не для человека. Разработчик один раз делает `ssh-copy-id root@{ip}`, дальше Claude рулит по SSH.
- **CLAUDE.md:** снято правило «Never SSH into the VPS from Claude Code», заменено на «run batched idempotent scripts, not ad-hoc interactive edits».
- **Deltas между v2.1 чек-листом и реальностью:**
  - `adduser` интерактивный → `adduser --gecos "" --disabled-password`.
  - `ufw enable` интерактивный → `ufw --force enable`.
  - `apt` висит на конфиг-prompt'ах → `DEBIAN_FRONTEND=noninteractive`.
  - На cloud-образах Ubuntu (Timeweb, Hetzner) `/etc/ssh/sshd_config.d/50-cloud-init.conf` перекрывает drop-in'ы — нужно затереть. Ещё и в главном `sshd_config` бывает `PermitRootLogin yes` на 42-й строке.
  - `pm2 startup` + пустой dump → systemd валится с `failed (Result: protocol)`. Сервис включается только после первого `pm2 save` с реальным процессом (делается в `server-add-site.md`).
- `scripts/README.md` — принципы написания серверных скриптов (idempotency, non-interactive, verify inline, secrets out of band).

## v2.1.0 — 2026-04-24 · Desktop-first workflow

**Что это.** Переход с серверной разработки (Claude Code внутри VPS через SSH) на **локальную десктопную**: Claude Desktop на Mac → `git push` в GitHub → GitHub Actions катит на VPS. Сервер разработчик настраивает руками по чек-листам — Claude в эти операции не лезет.

**Почему.** Десктопная модель убирает риски автономного изменения сервера, сокращает цикл правки (локальный hot-reload быстрее SSH+билд), и лучше подходит к кейсу «один разработчик ведёт несколько проектов».

### Ключевые изменения v2.0 → v2.1

- **Убрали схемы деплоя A/B.** Осталась одна единая модель: Mac → GitHub → VPS.
- **`docs/deploy-server-setup.md` удалён.** Разделён на четыре специализированных файла:
  - `docs/server-manual-setup.md` — разовая настройка свежего VPS (**для человека**).
  - `docs/server-add-site.md` — подключение нового сайта на готовый VPS (**для человека**).
  - `docs/server-multisite.md` — как уживаются несколько сайтов.
  - `docs/domain-connect.md` — A-записи и проверка `dig` (**для человека**).
- **Файлы «для человека» (`server-*`, `domain-connect`) помечены в `docs/INDEX.md`.** Claude на них ссылается, но не исполняет.
- **`specs/01-infrastructure.md` разделён на два:**
  - `specs/01a-local-setup.md` — проверка тулчейна на Mac, git, SSH, память.
  - `specs/01b-server-handoff.md` — Claude генерит в репо `.github/workflows/deploy-*.yml`, `deploy/nginx.conf.example`, `deploy/README.md`. Пользователь применяет на VPS сам.
- **Добавлен `specs/00.5-new-project-init.md`** — ритуал разработчика при старте каждого нового сайта (создание папки, репо, открытие Claude Desktop).
- **Убран `output: "standalone"` из стека.** Был лишним при PM2 + `next start`; подробности — в `docs/stack.md`.
- **Скрипты `package.json`:** `dev` теперь на 3000 (совпадает с дефолтным prod-портом на VPS). На VPS порт задаётся через `PORT=...` при `pm2 start` по реестру `~/ports.md`.
- **`CLAUDE.md`:** добавлено правило «Never push to main directly. Never SSH into the VPS from Claude Code».
- **Обновлены:** `README.md`, `docs/INDEX.md`, `specs/INDEX.md`, `specs/02/04/09/11/12/13`, `specs/templates/spec-template.md`, `docs/workflow.md`, `docs/architecture.md`, `.claude/memory/pointers.md`, `.claude/memory/references.md`, `.claude/memory/project_state.md`.

### Breaking changes v2.0 → v2.1

1. **Нельзя работать в `main` напрямую.** Всегда через ветку `dev` + PR. Старые проекты с разработкой на `main` нужно перевести — настроить protected branch и переключить workflow.
2. **Dev-сервер на Mac, не на VPS.** Если раньше запускали `npm run dev` по SSH — теперь локально. VPS только для prod (+ опционального dev-preview).
3. **Нет больше схемы A.** Проекты «dev=prod на одном VPS, без GitHub» больше не поддерживаются как отдельная ветвь. Для одиночных проектов всё равно ставим GitHub — это цена консистентности и безопасности.
4. **`next.config.ts` без standalone.** Если где-то в проекте закодирован `output: 'standalone'` — убрать. PM2 запускает `next start`, standalone лишний.
5. **Спека 01 переименована.** Промпты «run spec 01-infrastructure» нужно заменить на «run spec 01a-local-setup» (или `01b-server-handoff`).

---

## v2.0.0 — 2026-04-13 · Major restructure

**Что это.** Полная переработка bootstrap-промпта. Раньше был один файл `web-dev-bootstrap.md` на 2128 строк — теперь папка с `docs/` (KB) + `specs/` (последовательность задач) + `CLAUDE.md` (вход) + `.claude/memory/` (проектная память).

**Почему разбили.** Один большой `.md` съедал контекст Claude при любой задаче. В v2.0 Claude читает только то, что нужно для текущей спеки — через `docs/INDEX.md`. Поддержка проще: правка одного модуля не требует перетряхивать весь файл.

### Что переехало v1.7 → v2.0

Коротко:

| Модуль v1.7 | Стало в v2.0 |
|---|---|
| WORKFLOW | `docs/workflow.md` |
| STACK | `docs/stack.md` |
| ARCHITECTURE | `docs/architecture.md` |
| DESIGN-SYSTEM | `docs/design-system.md` |
| CONTENT-LAYOUT (44 секции) | `docs/content-layout.md` |
| FORMS-AND-CRM | `docs/forms-and-crm.md` |
| DEPLOY | `docs/deploy.md` + `docs/deploy-server-setup.md` |
| SEO | `docs/seo.md` |
| PERFORMANCE | `docs/performance.md` |
| CONVERSION-PATTERNS | `docs/conversion-patterns.md` |
| ШАБЛОНЫ ПРОЕКТНЫХ ФАЙЛОВ | `specs/00-brief.md` (как входной формат) |
| ШАБЛОН CLAUDE.md | `CLAUDE.md` (live) + `_BUILD/claude-md-template.md` (пустой) |

### Новое в v2.0

- **`docs/INDEX.md`** — карта KB с колонкой «когда читать», чтобы Claude не грузил всё подряд
- **`docs/legal-templates.md`** — 152-ФЗ cookie-баннер, согласие на ПДн, заглушки политики/оферты, чек-лист РКН
- **`docs/deploy-server-setup.md`** — отделён от `deploy.md`: VPS-bootstrap, nginx-шаблон, SSL, Cloudflare, GitHub Actions, troubleshooting
- **`specs/INDEX.md`** — 14 основных спек 00→13 с графом зависимостей
- **`specs/00-brief.md`** — приём материалов заказчика (тексты, бренд, страницы) в `docs/spec.md` + `content.md` + `pages.md` + `integrations.md`
- **`specs/01-13`** — каждая как одна сессия = один коммит-набор, с явным списком «KB files to read first»
- **`specs/optional/`** — 4 опциональные спеки: quiz, ecommerce, i18n, migrate-from-existing
- **`specs/templates/`** — `spec-template.md` + `page-spec-template.md`
- **`specs/examples/`** — 2 живых примера зрелых спек из реального проекта (референс формата, не задачи)
- **`.claude/memory/`** — 6 шаблонов проектной памяти (project_state, decisions, feedback, references, lessons, pointers) + INDEX с триггерами обновления
- **Деплой — две схемы:** A (dev=prod на одном VPS, без remote) и B (GitHub Actions + dev/prod папки). Раньше описывалась только B.

### Выброшенные дубли

Зафиксированы единые источники истины (см. `docs/INDEX.md` раздел «Источник истины»):

- `console.log` удалить — только в `performance.md § 4`
- WCAG AA контраст — только в `performance.md § 11`
- Lighthouse 90+ / PSI методика — только в `performance.md § 13`
- «Вирусный client» антипаттерн — короткая заметка в `architecture.md`, развёрнуто в `performance.md § 13.4`
- nginx-шаблон — только в `deploy-server-setup.md`
- Cookie-баннер / согласие на ПДн — только в `legal-templates.md`

### Breaking changes для тех, кто работал по v1.7

1. **Вместо одного `.md` — папка.** Старая схема «скопировал файл в проект → работаем» больше не работает. Нужна вся структура `docs/` + `specs/` + `CLAUDE.md` + `.claude/memory/`.
2. **Новый вход.** Раньше Claude читал `web-dev-bootstrap.md` целиком. Теперь вход — `CLAUDE.md` в корне, дальше `docs/INDEX.md` и спеки по требованию. Старые промпты типа «прочитай bootstrap» нужно заменить на «прочитай `CLAUDE.md` и `specs/INDEX.md`, начни со спеки `00-brief`».
3. **Деплой.** Если работали по v1.7 и использовали «папки dev + prod + GitHub Actions» — это теперь схема B (`docs/deploy.md` + `docs/deploy-server-setup.md`). Всё ещё поддерживается. Если деплой другой (solo dev=prod) — появилась схема A, переключаться не обязательно.
4. **Cookie-banner / 152-ФЗ стали обязательны** в `specs/09-forms-crm.md`. Если сайт работал без них по v1.7 — при следующем расширении (спека 13) добавь по `docs/legal-templates.md`.
5. **Workflow-дисциплина усилилась.** `CLAUDE.md` теперь явно требует plan mode перед кодом и обновление `.claude/memory/` по триггерам. В v1.7 это было «рекомендацией».

### v1.7 и ниже

Полной истории не ведём — предыдущая версия жила в одном файле. Архив старого `web-dev-bootstrap.md` остался локально у автора. В v2.0 миграция «один файл → структура» считается нулевой точкой.

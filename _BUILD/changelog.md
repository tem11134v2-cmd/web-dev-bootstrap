# Changelog

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

Детальная карта — в `_BUILD/migration-map.md`. Коротко:

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

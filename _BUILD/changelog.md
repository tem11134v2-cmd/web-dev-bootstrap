# Changelog

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

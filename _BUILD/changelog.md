# Changelog

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

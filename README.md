# web-dev-bootstrap v3.0

Промпт-пакет для Claude Code Desktop, который превращает его в дисциплинированного
frontend-разработчика конверсионных сайтов на Next.js. Не зависимость, не
библиотека — просто набор `.md` файлов, которые Claude читает по требованию
и по которым выстраивает работу над проектом.

**Воркфлоу:** разработка локально на Mac через Claude Desktop → `git push` в GitHub
→ GitHub Actions катит на VPS. Сервер разработчик настраивает руками по чек-листам
в `docs/server-*.md` — Claude в эту часть не лезет.

## Что внутри

```
CLAUDE.md                  — вход для Claude: правила, стек, триггеры памяти
docs/                      — Knowledge Base (≤200 строк каждый)
  INDEX.md                   → карта: какой файл когда читать (начни здесь)
  # Для Claude:
  workflow.md, stack.md, architecture.md, design-system.md,
  content-layout.md, forms-and-crm.md, legal-templates.md,
  seo.md, performance.md, conversion-patterns.md, deploy.md
  # Для человека (чек-листы):
  server-manual-setup.md     → разовая настройка свежего VPS
  server-add-site.md         → подключение сайта на готовый VPS
  server-multisite.md        → несколько сайтов на одном VPS
  domain-connect.md          → A-записи, Cloudflare
specs/                     — последовательность задач
  INDEX.md                   → граф зависимостей, как запускать спеку
  00-brief.md
  01a-local-setup.md         → Mac: тулчейн, память
  01b-server-handoff.md      → Claude генерит deploy workflows + Caddy-шаблон
  02-project-init.md … 13-extend-site.md
  optional/                  → quiz, ecommerce, i18n, migrate-from-existing
  templates/                 → spec-template, page-spec-template
  examples/                  → живые образцы зрелых спек (референс формата)
.claude/memory/            — шаблоны проектной памяти (INDEX + 6 файлов)
_BUILD/                    — служебное: HOW-TO-START.md (+.docx) — единый owner-guide,
                             claude-md-template.md, changelog.md, v3/ (refactor-ТЗ + миграционный промт + workflow-шаблоны)
```

## Как использовать

1. **Разовая подготовка Mac (первый раз в жизни):** установи `mise` (`brew install gh mise`), активируй в zshrc, потом `mise use --global node@22 pnpm@latest`, залогинься в `gh auth login`, прокинь SSH-ключ на GitHub. Полный пошаговый чек-лист — `_BUILD/HOW-TO-START.md`.
2. **Разовая подготовка VPS (первый раз для этого сервера):** пройди
   `docs/server-manual-setup.md` — создай пользователя, поставь стек, swap.
3. **Старт нового сайта** — следуй `_BUILD/HOW-TO-START.md` §1.A (новый сайт из шаблона):
   - Создай `~/projects/{site}/` на Mac.
   - Раскатай template: `gh repo create {owner}/{site} --template tem11134v2-cmd/web-dev-bootstrap --private --clone`.
   - Открой Claude Desktop, `Select folder` → эту папку.
   - Первая команда в чате:
     ```
     Read CLAUDE.md and specs/INDEX.md. Then open specs/00-brief.md.
     ```
4. **Идём по спекам 00 → 13.** Одна спека = одна сессия Claude = один
   коммит-набор. Между спеками — `/clear` и новая сессия.
5. **Сервер:** после `01b-server-handoff` Claude положит в репо workflow и Caddy-шаблон.
   Ты проходишь `docs/server-add-site.md` и `docs/domain-connect.md` — сайт подключается
   за ~30 минут.
6. **После каждой спеки** Claude обновляет `.claude/memory/project_state.md`
   (триггеры описаны в `CLAUDE.md`).

## Требования

- Claude Code Desktop (macOS/Windows)
- Node.js 22+ + pnpm (через `mise` на Mac, через `corepack` на VPS — обе ставятся в bootstrap'ах)
- `gh` CLI на Mac (для `gh repo create --template` и авторизации)
- VPS с Ubuntu 22.04+ для деплоя (см. `docs/server-manual-setup.md`)

## Навигация

- **[CLAUDE.md](CLAUDE.md)** — правила проекта + указатели на KB и спеки
- **[docs/INDEX.md](docs/INDEX.md)** — карта Knowledge Base
- **[specs/INDEX.md](specs/INDEX.md)** — последовательность спек + граф
- **[_BUILD/changelog.md](_BUILD/changelog.md)** — история версий (v2.0 → v3.0)

## Философия

- **Читай только нужное.** Claude не грузит весь `docs/` — только те файлы,
  которые спека явно перечислила в «KB files to read first». Это экономит
  контекст и держит фокус.
- **Одна спека = одна сессия.** Прыгать через спеки нежелательно, каждая
  опирается на артефакты предыдущей.
- **Plan mode перед кодом.** Спека — это требования, план — это путь
  реализации. Сначала согласуй план с заказчиком, потом пиши код.
- **Memory переживает `/clear`.** Живёт в `.claude/memory/*` — решения,
  фидбек заказчика, поинтеры на код. Читается в начале каждой сессии.

## Версия

v3.0 (2026-04-29). Финал большого рефакторинга `_BUILD/v3/01-bootstrap-refactor.md` (7 фаз). Стек: **Caddy** (auto-HTTPS) вместо nginx+certbot, **push-based deploy** (build на GitHub runner → rsync → атомарный switch симлинком, миллисекунды, без пересборки на VPS), `output: 'standalone'` в Next 16, **Biome** вместо ESLint+Prettier, **pnpm** через mise/corepack, **schema-dts** для типобезопасных JSON-LD, **Cloudflare Turnstile** в формах, **Content Collections** для MDX, **Server Actions** + `useActionState` (вместо Route Handler `/api/lead`), опциональные **`use cache`** + **PPR** + **OKLCH** в Tailwind v4. Sequential **multi-Claude протокол** через `/handoff` + `/resume` + `/catchup` + stop-reminder hook. Полная история — `_BUILD/changelog.md`.

## Лицензия

Внутренний инструмент, используйте свободно. При форке оставь ссылку на
источник — интересно посмотреть, как другие приспосабливают структуру.

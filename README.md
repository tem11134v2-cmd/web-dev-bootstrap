# web-dev-bootstrap v4.0

Промпт-пакет для Claude Code Desktop, который превращает его в дисциплинированного
frontend-разработчика конверсионных сайтов на Next.js. Не зависимость, не
библиотека — просто набор `.md` файлов, которые Claude читает по требованию
и по которым выстраивает работу над проектом.

**Воркфлоу:** разработка локально на Mac через Claude Desktop → `git push` в GitHub
→ GitHub Actions катит на VPS. Серверную часть Claude выполняет сам по SSH — ключом
разработчика, батчированными идемпотентными скриптами, предупредив что собирается
сделать (канон — SSH-политика в `CLAUDE.md`). Человеку остаётся только чужие GUI:
DNS у регистратора, оплата VPS, верификации, выдача ключей.

## Что внутри

```
CLAUDE.md                  — вход для Claude: правила, стек, SSH-политика, триггеры памяти
docs/                      — Knowledge Base (≤200 строк каждый)
  INDEX.md                   → карта: какой файл когда читать (начни здесь)
  workflow.md, stack.md, architecture.md, design-system.md,
  content-layout.md, design-motion.md, conversion-patterns.md,
  forms-and-crm.md, forms-sink-recipes.md, legal-templates.md,
  seo.md, performance.md, deploy.md, orchestration.md,
  automation.md, troubleshooting.md, ai-assets.md
  # Серверные чек-листы (исполняет Claude по SSH):
  server-manual-setup.md     → разовая настройка свежего VPS
  server-add-site.md         → подключение сайта на готовый VPS
  server-multisite.md        → несколько сайтов на одном VPS
  domain-connect.md          → A-записи у регистратора (человек), dig-проверки (Claude)
specs/                     — последовательность задач
  INDEX.md                   → граф зависимостей, как запускать спеку
  00-brief.md
  01a-local-setup.md         → Mac: тулчейн, память
  01b-server-handoff.md      → Claude генерит deploy workflows + Caddy-шаблон
  02-project-init.md … 14-migrate.md
  optional/                  → quiz, ecommerce, i18n, migrate, recreate, design-first входы
  templates/                 → spec-template, page-spec-template, client-todo-template
  examples/                  → живые образцы зрелых спек (референс формата)
.claude/
  agents/                    → субагенты оркестратора: builder-sonnet, builder-opus, verifier, integrator
  commands/                  → /orchestrate, /handoff, /resume, /catchup
  hooks/                     → session-start, guard-rm, before-push (typecheck-гейт), format, subagent-stop (гейт после субагентов), stop-reminder
  memory/                    → шаблоны проектной памяти (INDEX + 6 файлов + archive/)
_BUILD/                    — служебное: HOW-TO-START.md — единый owner-guide,
                             claude-md-template.md, changelog.md,
                             templates/ (deploy-yml, deploy-readme, handoff, claude-md-lite),
                             archive/ (старые ТЗ), v3/ (миграционный промт)
```

## Как использовать

1. **Разовая подготовка Mac (первый раз в жизни):** установи `mise` (`brew install gh mise`), активируй в zshrc, потом `mise use --global node@22 pnpm@latest`, залогинься в `gh auth login`, прокинь SSH-ключ на GitHub. Полный пошаговый чек-лист — `_BUILD/HOW-TO-START.md`.
2. **Разовая подготовка VPS (первый раз для этого сервера):** Claude проходит
   `docs/server-manual-setup.md` по SSH (`scripts/bootstrap-vps.sh`) — от тебя
   `ssh-copy-id root@{ip}` и подтверждения.
3. **Старт нового сайта** — следуй `_BUILD/HOW-TO-START.md` §1.A (новый сайт из шаблона):
   - Создай `~/projects/{site}/` на Mac.
   - Раскатай template: `gh repo create {owner}/{site} --template tem11134v2-cmd/web-dev-bootstrap --private --clone`.
   - Открой Claude Desktop, `Select folder` → эту папку.
   - Первая команда в чате:
     ```
     Read CLAUDE.md and specs/INDEX.md. Then open specs/00-brief.md.
     ```
4. **Идём по спекам 00 → 14.** Одна спека = одна сессия Claude = один
   коммит-набор. Между спеками — `/clear` и новая сессия. Крупные пласты
   (сайт целиком, rollout страниц) — оркестраторной волной: `/orchestrate`
   (см. `docs/orchestration.md`).
5. **Сервер:** после `01b-server-handoff` Claude положит в репо workflow и Caddy-шаблон,
   затем сам пройдёт `docs/server-add-site.md` по SSH. Тебе — DNS у регистратора
   (`docs/domain-connect.md`, dig-проверки делает Claude). Сайт подключается
   за ~30 минут.
6. **После каждой спеки** Claude обновляет `.claude/memory/project_state.md`
   (триггеры описаны в `CLAUDE.md`).

## Требования

- Claude Code Desktop (macOS/Windows)
- Node.js 22+ + pnpm на Mac (через `mise`). На VPS — только Node runtime + Caddy + PM2 (build идёт на GitHub-runner, pnpm на VPS не нужен)
- `gh` CLI на Mac (для `gh repo create --template` и авторизации)
- VPS с Ubuntu 22.04+ для деплоя (см. `docs/server-manual-setup.md`)

## Навигация

- **[CLAUDE.md](CLAUDE.md)** — правила проекта + указатели на KB и спеки
- **[docs/INDEX.md](docs/INDEX.md)** — карта Knowledge Base
- **[specs/INDEX.md](specs/INDEX.md)** — последовательность спек + граф
- **[_BUILD/changelog.md](_BUILD/changelog.md)** — история версий (v2.0 → v4.0)

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
- **Оркестратор + субагенты для крупных пластов.** Полный сайт, rollout,
  recreate — волнами: оркестратор планирует и раздаёт брифы, билдеры строят
  параллельно, verifier принимает по «Done when». Интерактив остаётся
  дефолтом для точечных задач.
- **Дизайн-first вход.** Четыре маршрута: готовый макет (Claude Design /
  HTML / скрины), референсы конкурентов, с нуля по брифу, и маршрут D —
  перенос действующего сайта 1:1 (`specs/optional/opt-visual-recreate.md`) —
  развилка в 00-brief.

## Версия

v4.0 (2026-07-17). Главное: **оркестраторный слой** (`.claude/agents/` — builder-sonnet / builder-opus / verifier / integrator, команда `/orchestrate`, `docs/orchestration.md`: волны, брифы, гейты, task ledger), **встроенный браузер** Claude Code Desktop вместо связки Chrome-плагин + Claude_Preview (Claude сам скриншотит 375/768/1280 и читает консоль), **design-first вход** (готовый макет / референсы / с нуля + `docs/design-motion.md` против шаблонности), **SSH-канон** (серверную часть исполняет Claude, человеку — только чужие GUI), **починенные хуки** (jq fail-closed, состояние в `.claude/state/` вместо `/tmp`, typecheck-гейт перед push), **актуализация Next 16** (Turbopack-дефолт, без PPR/optimizeCss, канонический `next.config.ts` в `docs/stack.md`), **распил forms** (ядро `forms-and-crm.md` + `forms-sink-recipes.md`, email-канал — первый), **CLIENT-TODO.md** (первоклассный артефакт «что нужно от заказчика»), **полевые уроки 5 боевых проектов** (deploy-yml, pm2 delete&start, tar-проверки, адблок-классы, cyrillic-шрифты). Полная история — `_BUILD/changelog.md`.

## Лицензия

Внутренний инструмент, используйте свободно. При форке оставь ссылку на
источник — интересно посмотреть, как другие приспосабливают структуру.

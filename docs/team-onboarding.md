# Onboarding для нового разработчика

Если владелец репо добавил вас как `Collaborator` с правами Write — этот документ для вас.

Bootstrap проекта на v3.0+ (push-based deploy, Caddy, Server Actions, Multi-Claude). Если читаете на старом проекте (v2.x) — workflow тот же, но детали инфры могут отличаться, спросите владельца.

## Что вам **не дадут** (намеренно)

- SSH-доступ к VPS, root-пароль, deploy-ключ.
- GitHub **Environment Secrets** (`SSH_PRIVATE_KEY`, `PROD_ENV_FILE` в Environment `production`) — это деплой-credentials, владелец держит у себя.
- Доступ к `.env.production` (gitignored, живёт только на Mac владельца + приезжает на VPS через workflow при каждом деплое).
- Прямой push в `main` (deploy-ветка). Хук `before-push.sh` блокирует чужой push, но дисциплина прежде всего.

Это нормально: вы пишете код, Actions деплоит, владелец держит инфру.

## Шаги onboarding-а

### 1. Принять invitation на GitHub

Получите email от GitHub `[GitHub] @<owner> invited you to <owner>/<repo>` → **Accept invitation**.

### 2. Клонировать репо

```bash
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:<owner>/<repo>.git
cd <repo>
```

(Если SSH к GitHub ещё не настроен — `gh auth login`, выберите `SSH`, далее по подсказкам.)

### 3. Установить зависимости

```bash
mise install   # подхватит версию из .tool-versions (если используется mise)
pnpm install
```

### 4. Запустить локально

```bash
pnpm dev
# → http://localhost:3000
```

Без `.env.production` формы пишут лиды в `data/leads.json` (fallback) — это нормально для локальной разработки.

### 5. Открыть в Claude Code Desktop

Откройте папку проекта в Claude Desktop (`+ New chat` → `Select folder` → `~/projects/<repo>`).

Первый промпт в чате — `/resume`. Это slash-команда: Claude прочитает `.claude/memory/INDEX.md`, `project_state.md`, сверится с git и резюмирует, на чём остановилась команда. Если `/resume` не сработает (старая версия Claude Desktop, не сканирует `.claude/commands/`):

```
Прочитай CLAUDE.md, docs/INDEX.md, .claude/memory/INDEX.md, .claude/memory/project_state.md
и кратко резюмируй где сейчас проект. Жди ОК перед работой.
```

### Опция «worktree» при открытии папки

Claude Desktop может предложить worktree (изолированная копия в отдельной папке/ветке). Для коллабораторов рекомендация — **не использовать worktree**, работайте в основной папке: ваши feature-ветки и так изолированы по принципу `git checkout -b feat/my-change`.

## Workflow

```
git checkout dev && git pull           # синхронизироваться с dev
git checkout -b feat/my-change         # ваша feature-ветка от dev
# … работа, коммиты …
git push -u origin feat/my-change
gh pr create --base dev                # PR в dev (не в main!)
```

Владелец ревьюит и мерджит в `dev`. Дальше владелец сам мерджит `dev → main` через PR — это триггерит deploy на VPS через Actions.

**Никогда:**

- не делайте PR напрямую в `main`
- не пытайтесь `git push origin main` или `git push -f` (хуки `before-push` и `guard-rm` заблокируют, но дисциплина — основная страховка)
- не коммитьте `.env*` (gitignored, но проверяйте `git status` перед commit)
- не открывайте параллельную Claude-сессию на ту же папку, пока другой разработчик там работает (см. ниже про Multi-Claude)

## Slash-команды Claude

В проекте настроены три slash-команды (живут в `.claude/commands/`):

- **`/resume`** — стартуйте каждую сессию с этого. Claude прочитает память, сверится с git, резюмирует.
- **`/handoff`** — заканчивайте каждую сессию этим. Claude обновит `.claude/memory/project_state.md` (Session log + Active phase + Next steps), спросит про uncommitted-изменения. Это нужно даже если в сессии вы ничего не закоммитили — следующий разработчик (или вы завтра) увидит контекст.
- **`/catchup`** — если непонятно где остановились и `/resume` мало (например, после долгого перерыва). Claude глубже копнёт `git log`, последние PR, активные ветки.

Stop-хук (`.claude/hooks/stop-reminder.sh`) мягко напомнит про `/handoff`, если в сессии были коммиты, — это просто текстовое напоминание, не блок.

## Multi-Claude protocol

**Одна Claude-сессия = одна папка проекта = один разработчик за раз.** Параллельные сессии на ОДНУ папку (даже если вы на разных Mac'ах) запрещены — поломают `.claude/memory/project_state.md`.

Практика:
- Прежде чем стартовать `/resume` — убедитесь, что владелец и другие коллабораторы сейчас не в проекте (созвонитесь / напишите в чат).
- Закончили — `/handoff` + push своей feature-ветки. Теперь следующий может стартовать.
- На разные проекты можно работать параллельно — без ограничений.

## Memory-файлы (`.claude/memory/`) и git

Memory-файлы (`project_state.md`, `decisions.md`, `lessons.md`, `feedback.md`, `pointers.md`, `references.md`) **коммитятся в git**. Это значит:

- При работе в feature-ветке — коммитьте обновления memory вместе с кодом (Claude через `/handoff` сделает это сам).
- Перед стартом — `git pull origin dev` подтягивает memory от других разработчиков.
- При мердже PR могут быть **merge-конфликты в memory-файлах** (особенно `project_state.md` — оба добавили запись в Session log). Решаются вручную:

```bash
# При rebase или merge видите конфликт в .claude/memory/project_state.md
# Это log-файл, оба разработчика правы — просто объедините записи
git status                              # увидеть конфликтные файлы
# Открыть project_state.md в редакторе, объединить обе записи в Session log
git add .claude/memory/project_state.md
git rebase --continue                   # или git commit, если был обычный merge
```

**Не делайте `git checkout --ours` или `--theirs` слепо** на memory-файлах — потеряете часть журнала. Объединять руками 30 секунд, оно того стоит.

## Если вам нужен новый секрет в .env

Не пытайтесь добавить его сами — у вас нет доступа ни к Mac владельца, ни к Environment Secrets. Напишите владельцу:
- какая переменная нужна (`FOO_API_KEY`)
- что она делает (CRM, аналитика, etc.)
- где её получить (URL личного кабинета сервиса)

Владелец:
1. Добавит ключ в свой локальный `~/projects/<repo>/.env.production`
2. Перепишет GitHub Environment-секрет: `gh secret set --env production PROD_ENV_FILE < .env.production`
3. Триггерит деплой пустым коммитом или повторным запуском workflow — секрет приедет на VPS в рамках следующего push'а.

Для **сборочного времени** (вам нужна публичная переменная типа `NEXT_PUBLIC_FEATURE_FLAG_X` чтобы локально протестить) — попросите владельца добавить её также в repo-level Secrets (она используется в build-job до того, как Environment подтягивается). Локально вы можете прописать её в свой `.env.local` (gitignored) на время разработки.

## Если вы сломали prod

Не пытайтесь чинить через Actions сами. Напишите владельцу с указанием:
- какой PR замерджен,
- какие симптомы,
- скриншот / curl-вывод если есть.

Владелец откатит через `scripts/rollback.sh` — атомарный switch симлинка `current` на предыдущий релиз, миллисекунды без пересборки. Затем попросит вас сделать `git revert <bad-commit>` (или `git revert -m 1 <merge-hash>` если плохой коммит — merge) в `dev`-ветке, PR в `dev`, мердж в `main` — Actions передеплоит починку.

## Где что искать

| Вопрос | Ответ |
|---|---|
| Структура папок, App Router | `docs/architecture.md` |
| Цвета, шрифт, spacing | `docs/design-system.md` |
| Типы секций сайта | `docs/content-layout.md` |
| Как устроены формы / CRM | `docs/forms-and-crm.md` |
| Карта страниц | `docs/pages.md` |
| Что куда деплоится | `docs/deploy.md` |
| Как откатить прод | `docs/automation.md` |
| Текущая активная задача | `.claude/memory/project_state.md` |
| Бизнес-контекст, бренд | `docs/spec.md` |

## Безопасность

- `.env*` не коммитьте.
- Лиды в `data/leads.json` (fallback) — содержат email/телефон. Не пушьте этот файл (он в `.gitignore`).
- Не запускайте незнакомые скрипты, особенно с sudo.
- При подозрении на компрометацию (странные коммиты в истории, неизвестные деплои) — сразу пишите владельцу.

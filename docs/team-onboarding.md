# Onboarding для нового разработчика

Если владелец репо добавил вас как `Collaborator` с правами Write — этот документ для вас.

## Что вам **не дадут** (намеренно)

- SSH-доступ к VPS, root-пароль, deploy key.
- GitHub Secrets (`DEPLOY_SSH_KEY`).
- Доступ к `.env.production` (живёт только на Mac владельца + на VPS).
- Прямой push в `main` (deploy-ветка).

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
nvm use         # подхватит версию из .nvmrc
npm install
```

### 4. Запустить локально

```bash
npm run dev
# → http://localhost:3000
```

Без `.env.production` формы пишут лиды в `data/leads.json` (fallback) — это нормально для локальной разработки.

### 5. Открыть в Claude Code Desktop

```bash
claude     # внутри ~/projects/<repo>
```

Прочитайте `CLAUDE.md`, `docs/INDEX.md` и `.claude/memory/INDEX.md`.

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
- не пытайтесь `git push origin main` (хук `before-push` заблокирует, но всё равно)
- не коммитьте `.env*` (gitignored, но проверяйте `git status` перед commit)

## Если вам нужен новый секрет в .env

Не пытайтесь добавить его сами. Напишите владельцу:
- какая переменная нужна (`FOO_API_KEY`)
- что она делает (CRM, аналитика, etc.)
- где её получить (URL личного кабинета сервиса)

Владелец добавит её локально и через `scripts/sync-env.sh` зальёт на VPS.

## Если вы сломали prod

Не пытайтесь чинить через Actions сами. Напишите владельцу с указанием:
- какой PR замерджен,
- какие симптомы,
- скриншот / curl-вывод если есть.

Владелец откатит через `scripts/rollback.sh` (см. `docs/automation.md`) и попросит вас сделать `git revert` в `dev`-ветке.

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

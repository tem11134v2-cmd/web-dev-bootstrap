# Как начинать новый сайт

Короткая инструкция: от пустой папки до «Claude уже пишет код».

Если Mac совершенно свежий (новый ноутбук, ничего не настроено) — сначала пройди раздел «0. Первичная настройка Mac» ниже. Это делается один раз на каждый Mac, потом только раздел 1 и дальше на каждый новый сайт.

---

## 0. Первичная настройка Mac (один раз)

### 0.0. Аккаунт на GitHub

GitHub — где будет жить код всех твоих сайтов.

- **Если аккаунта ещё нет** — заведи на github.com (бесплатный план подходит). Запомни логин и пароль.
- **Если аккаунт уже есть** — посмотри свой логин в правом верхнем углу github.com (клик на аватарку → Your profile, в URL после `github.com/` будет твой логин).

Дальше во всех командах:

- `<твой-логин>` — твой GitHub-логин. Например: `tem11134v2`.
- `<твой-email>` — твоя почта.
- `{site}` — название конкретного сайта. Например: `migrator`, `clinic-landing`.

**Как читать команды-шаблоны:**

- Угловые `< >` и фигурные `{ }` скобки — плейсхолдеры от меня. Заменяешь их **целиком вместе со скобками** на свои данные.
- Двойные кавычки `" "` — это синтаксис shell, оставляешь как есть.

**Пример замены:**

```
git config --global user.name "<твой-логин>"   ← шаблон
git config --global user.name "tem11134v2"     ← после замены
```

### 0.1. Claude Code Desktop

Зайди на claude.com → в меню сверху найди **Claude Code → Download for Mac**. Скачается .dmg файл. Открой → перетащи иконку Claude в папку Applications. Запусти — попросит войти через браузер (Google / Anthropic аккаунт).

После первого запуска — Claude Code готов принимать чаты и открывать папки через **Select folder**.

### 0.2. Terminal + Xcode Command Line Tools (включают git)

- Открой **Terminal** (Cmd+Space → набери «Terminal» → Enter).
- Запусти одну команду:

```bash
xcode-select --install
```

Откроется системное окошко — нажми Install. Ждёшь 5–10 минут, пока скачаются инструменты разработчика.

Проверка: `git --version`

### 0.3. Homebrew (пакетный менеджер Mac)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Попросит пароль Mac. Длится ~3 минуты. После — выполни три echo/eval команды, которые brew напечатает (добавляет brew в PATH).

Проверка: `brew --version`

### 0.4. GitHub CLI (gh) + mise (Node + pnpm)

```bash
brew install gh mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc

mise use --global node@22
mise use --global pnpm@latest
```

`mise` — единый менеджер версий: ставит и Node, и pnpm, и любой другой тул, который понадобится. В каждом проекте читает `.tool-versions` и подменяет версии под локальный проект автоматически — никакого `nvm use` руками.

Проверка: `gh --version && node --version && pnpm --version`

Должно вывести что-то вроде:

```
gh version 2.x.x ...
v22.x.x         ← важно: 22 или новее (Next.js 16 требует)
9.x.x           ← pnpm
```

Если `node --version` показывает меньше `v22` — `mise use --global node@22` ещё раз (mise сам перекачает).

### 0.5. Git identity

Имя и email, которыми будут подписываться твои коммиты.

```bash
# Шаблон — замени плейсхолдеры на свои, кавычки оставь:
git config --global user.name "<твой-логин>"
git config --global user.email "<твой-email>"
```

```bash
# Пример (мои данные):
git config --global user.name "tem11134v2"
git config --global user.email "tem11134v2@gmail.com"
```

Проверка: `git config --get user.name && git config --get user.email` — должны вывестись твои значения.

### 0.6. SSH-ключ

```bash
# Шаблон:
ssh-keygen -t ed25519 -C "<твой-email>"
```

```bash
# Пример:
ssh-keygen -t ed25519 -C "tem11134v2@gmail.com"
```

Жми Enter три раза (выбираем дефолтный путь и пустой passphrase).

### 0.7. Авторизация в GitHub через gh

```bash
gh auth login
```

Диалог: GitHub.com → HTTPS → Y → Login with a web browser → код в браузер → Authorize.

Проверка: `gh auth status` — должно вывести что-то вроде:

```
github.com
  ✓ Logged in to github.com account <твой-логин> (keyring)
  - Active account: true
```

### 0.8. Создать папку ~/projects/

```bash
mkdir -p ~/projects
```

Всё. Mac готов.

### Словарик (на один раз)

- `~` — твоя home-папка на Mac (`/Users/{твой-логин}/`).
- `~/projects/` — общая папка под все твои сайты.
- `{site}` в командах ниже — название сайта в kebab-case. Примеры: `migrator`, `clinic-landing`. Замени на своё каждый раз.

---

## 1. Создать репо из шаблона

```bash
cd ~/projects
gh repo create <твой-логин>/{site} --template tem11134v2-cmd/web-dev-bootstrap --private --clone
cd {site}
```

**В команде два разных GitHub-имени — не перепутай:**

- `<твой-логин>` — куда **положить** новый репо. Это **ВАШ** аккаунт.
- `tem11134v2-cmd/web-dev-bootstrap` — откуда **взять** шаблон. Это МОЙ публичный шаблон, оставляешь как есть.

**Пример** (если ваш логин — `tem11134v2`, а сайт называется `migrator`):

```bash
cd ~/projects
gh repo create tem11134v2/migrator --template tem11134v2-cmd/web-dev-bootstrap --private --clone
cd migrator
```

**Что произойдёт:**

- На GitHub появится новый приватный репозиторий `<твой-логин>/{site}`.
- На Mac в `~/projects/{site}` склонируется свежая копия шаблона со всеми правилами и хуками внутри.
- Терминал перейдёт в эту папку — ты готов к шагу 2.

Если ругается `already exists` — репо с таким именем уже есть в твоём аккаунте, выбери другое имя.

> Если переезжаешь с уже работающего сайта (Tilda, WordPress, …) — **не используй `--template`**. Создай пустой репо и читай `specs/optional/opt-migrate-from-existing.md` или `specs/14-migrate.md`.

## 2. Открыть в Claude Desktop

- Claude Desktop → **+ New chat** (Cmd+N).
- **Select folder** → `~/projects/{site}`.

При первом открытии папки macOS может спросить разрешение «Claude wants access to folder» — нажми **Allow** (разово, дальше не спрашивает).

## 3. Первое сообщение Claude

```
Прочитай CLAUDE.md и specs/INDEX.md. Затем открой specs/00-brief.md и проведи меня по нему — спроси у меня бриф по проекту.
```

При старте каждой сессии Claude запускает `.claude/hooks/session-start.sh`, который сам делает `git fetch` и подсказывает если ветка отстала. Поэтому ритуал «не забудь pull» больше не на тебе.

## 4. Работа изо дня в день

Одна спека = одна сессия чата. После — `/clear` или новый чат. Claude сохраняет прогресс в `.claude/memory/project_state.md`.

## 5. Вернуться к уже начатому сайту

- New chat → Select folder → `~/projects/{site}`.
- Промпт: `Прочитай .claude/memory/INDEX.md и продолжи с того места, на котором мы остановились.`

## 6. Несколько сайтов одновременно

```
~/projects/
├── migrator/              ← сайт 1, один чат Claude
├── clinic-landing/        ← сайт 2, другой чат Claude
└── neon-bike-store/       ← сайт 3, ещё чат
```

Один сайт = один чат. Не смешивай в одном чате — Claude путается.

---

## 7. Подключить второго разработчика

1. Узнай GitHub-логин коллеги (например, `alice`).
2. Открой Claude в проекте, скажи: «добавь `alice` как collaborator с правами Write».
3. Дай ей ссылку на `docs/team-onboarding.md` в репо.

**Не давай:** SSH к VPS, deploy_key, root-пароли, GitHub Secrets. Это намеренная граница.

## 8. Секреты на VPS

`.env.production` живёт у тебя локально (`~/projects/{site}/.env.production`, gitignored).

Промпт Claude'у: «**синхронизируй .env на прод**» — Claude прогонит `scripts/sync-env.sh`, scp + `pm2 restart --update-env`. Не коммитим, не лезем в Actions Secrets для рантайма.

## 9. Сломал прод?

Промпт Claude'у: «**откати прод на коммит `<hash>`**» — Claude прогонит `scripts/rollback.sh <hash>` (ssh + git reset + rebuild + pm2 restart) и подскажет команду для `git revert + push`, чтобы починка пошла через Actions поверх.

`<hash>` — короткий идентификатор коммита, обычно 7 символов вроде `abc1234`. Видно в `git log` или в URL GitHub-коммита (последние 7 символов после `/commit/`).

Если плохой коммит — это PR-merge (виден как «Merge pull request #N»), Claude подскажет `git revert -m 1 <hash>` (без `-m 1` git упадёт «commit has more than one parent»).

---

## Частые косяки

- **`gh: command not found`** — открой новое окно Terminal или `source ~/.zprofile`.
- **«Папка проекта не видна в Claude Desktop»** — `Select folder` (не `Select file`), и проверь что выбрал `~/projects/{site}`, а не родитель.
- **Claude пишет «я не вижу файлов»** — он ещё не прочитал `CLAUDE.md`. Отправь промпт из §3.
- **`gh repo create` → «already exists»** — выбери другое имя или удали старый в Settings репо.
- **Хук блокирует push: «BLOCKED by before-push: gh account mismatch»** — у тебя залогинено несколько gh-аккаунтов, активный — не тот. Команда из сообщения хука: `gh auth switch -h github.com -u <owner>`. После — повтори push.
- **Smoke-тест домена возвращает 301 от ddos-guard до DNS cutover** — middlebox перехватывает Host-header. Используй `Host: <IP>` или `/etc/hosts` override. Подробно в `docs/troubleshooting.md` в шаблоне.
- **`git revert` падает «commit has more than one parent»** — это merge-коммит (PR merge). Используй `git revert -m 1 <hash>`.
- **Branch protection возвращает 403 «Upgrade to GitHub Pro»** — на private + free она недоступна. Либо `gh auth switch` на public-репо, либо смирись с дисциплиной (один разработчик = ок).

---

## Где что лежит на Mac

| Путь | Что |
|---|---|
| `~/projects/{site}/` | Код сайта, локальная разработка |
| `~/projects/{site}/.env.production` | Локальные секреты (gitignored, синкаются на VPS через `scripts/sync-env.sh`) |
| `~/Downloads/HOW-TO-START.docx` | Этот файл (docx-версия для печати) |
| `~/ClaudeCode/web-dev-bootstrap/` | Исходный шаблон (редактируется когда улучшаешь сам алгоритм) |
| `~/.ssh/config` | Алиасы SSH к серверам (`{site}-new` и т.п.) |
| `~/.ssh/id_ed25519` | Твой личный SSH-ключ (не удалять, не показывать никому) |

## Что делать дальше (после запуска первого сайта)

- **Сайт готов к релизу** → спека `12-handoff.md` (передача заказчику, 3 модели H1/H2/H3).
- **Подключить второго разработчика** → §7 выше + `docs/team-onboarding.md`.
- **Сломал прод** → §9 выше.
- **Сайт надо переехать на другой VPS** → спека `14-migrate.md` (4 сценария M1–M4, 7-day soak).
- **Миграция с живого сайта** (Tilda/WP) → `specs/optional/opt-migrate-from-existing.md`.
- **Обычные правки уже живого сайта** → спека `13-extend-site.md` (циклическая).

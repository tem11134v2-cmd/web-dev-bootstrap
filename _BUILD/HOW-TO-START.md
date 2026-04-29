# Как начинать новый сайт

Короткая инструкция: от пустой папки до «Claude уже пишет код».

Если Mac совершенно свежий (новый ноутбук, ничего не настроено) — сначала пройди раздел «0. Первичная настройка Mac» ниже. Это делается один раз на каждый Mac, потом только раздел 1 и дальше на каждый новый сайт.

> **Версия инструкции:** v3.0 (актуально для bootstrap'а на этом теге).
> Печатная `.docx`-версия в `_BUILD/HOW-TO-START.docx` синхронизирована с этим `.md`-файлом. Если правишь `.md` — регенерируй командой ниже:
> ```bash
> pandoc _BUILD/HOW-TO-START.md -o _BUILD/HOW-TO-START.docx \
>   --toc --toc-depth=2 \
>   --metadata title="Как работать с web-dev-bootstrap v3.0" \
>   --metadata lang=ru-RU
> ```
> Pandoc ставится через `brew install pandoc`. Опционально — скопируй итог в `~/Downloads/HOW-TO-START.docx` для печати.

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

> **Если переезжаешь с уже работающего сайта (Tilda, WordPress, самописа…)** — `--template` команду из §1 ты всё равно используешь. Шаблон даёт `CLAUDE.md`, `docs/`, `specs/`, хуки — без них Claude не работает. А вот **до или параллельно** со спекой `00-brief.md` запусти `specs/optional/opt-migrate-from-existing.md` — она извлечёт со старого сайта тексты, медиа, URL-карту с 301-редиректами и заполнит `docs/spec.md` / `content.md` / `pages.md` за тебя (вместо ручного брифа). Дальше идёшь обычным потоком (02 → 03 → 04 → ...).
>
> `specs/14-migrate.md` — **другое** (миграция между VPS-серверами). К переезду с Tilda не относится.

## 1.5. Клонировать СВОЙ существующий проект (новый Mac / второй компьютер владельца)

Это сценарий: **ты владелец сайта**, проект уже лежит на твоём GitHub-аккаунте, и ты хочешь поднять его на новой машине (купил новый Mac, или работаешь с двух — на работе и дома).

> ⚠️ **Если ты не владелец, а второй разработчик** (получил Invite от владельца) — этот раздел не для тебя. Тебе нужно: открыть `docs/team-onboarding.md` (полный гид с учётом твоих ограничений по доступу) + читать §7 ниже, где описан весь collaborator-флоу.

Прошёл §0 (Mac готов), теперь:

```bash
cd ~/projects
gh repo clone <твой-логин>/{site}    # тот же GitHub-аккаунт, что создал репо
cd {site}
mise install                          # подхватит версии из .tool-versions
pnpm install                          # установит зависимости из pnpm-lock.yaml
pnpm dev                              # → http://localhost:3000
```

**Чего не приедет с git'а** (и придётся достать отдельно):

- **`.env.production`** — gitignored. Сайт запустится в **fallback-режиме** (формы пишут лиды в `data/leads.json`), для прода нужен реальный `.env`. Варианты:
  - Принести с предыдущего Mac через 1Password / iCloud Drive
  - Достать с VPS: `ssh deploy@{vps-ip} "cat /home/deploy/prod/{site}/current/.env" > .env.production` (workflow деплоя сам пишет туда `PROD_ENV_FILE` секрет на каждом push'е, так что там всегда актуальная версия)
  - Узнать имена ключей: `gh secret list --env production --repo <твой-логин>/{site}` — но **значения** GitHub не отдаёт даже тебе как владельцу (только в момент деплоя). Список нужен только чтобы свериться «не забыл ли я какую переменную»
- **SSH-ключ к GitHub** (`~/.ssh/id_ed25519`) — на новом Mac ты сгенерил его в §0.6, теперь надо зарегистрировать на GitHub: `gh auth login` (он автоматически добавит публичную часть нового ключа в твой GitHub-аккаунт)
- **SSH-доступ к VPS** — публичную часть твоего нового `~/.ssh/id_ed25519.pub` надо добавить в `authorized_keys` пользователя `deploy` на VPS. Со старого Mac (где доступ есть) или через панель провайдера: `ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@{vps-ip}`. После — пропиши алиас в `~/.ssh/config`:
  ```
  Host {site}
    HostName {vps-ip}
    User deploy
    IdentityFile ~/.ssh/id_ed25519
  ```
- **`.claude/state/`** и **`.claude/cache/`** — gitignored, локальные кеши Claude Code, восстановятся сами в первой сессии.

**Что приедет** (этого достаточно для работы): актуальный код, `docs/`, `specs/`, `.claude/memory/` (project_state, decisions, lessons и т.д.), хуки в `.claude/hooks/`, slash-команды в `.claude/commands/`, скрипты `scripts/`, `biome.json`, `.tool-versions`, `pnpm-lock.yaml`.

После `pnpm dev` — открывай Claude Desktop в этой папке и работай по §5 («Вернуться к уже начатому сайту») — `/resume` восстановит контекст из памяти проекта.

## 2. Открыть в Claude Desktop

- Claude Desktop → **+ New chat** (Cmd+N).
- **Select folder** → `~/projects/{site}`.

При первом открытии папки macOS может спросить разрешение «Claude wants access to folder» — нажми **Allow** (разово, дальше не спрашивает).

### Что делать с выбором ветки и worktree

Claude Desktop при открытии может предложить:

- **Branch:** какая ветка стартовать. По умолчанию — `main`. Если ты сразу знаешь, что будешь работать в feature-ветке — можно выбрать её, или оставить `main` и Claude сам её создаст когда нужно.
- **Worktree:** изолировать Claude в отдельный git worktree (отдельная папка `_BUILD/.claude/worktrees/<auto-name>/` со своей веткой `claude/<auto-name>`).

**Что такое worktree** — это стандартный git-механизм: несколько рабочих деревьев одного репо в разных папках, на разных ветках одновременно. У всех общий `.git`, но разные checkouts.

**Что выбирать** (правило большого пальца):

| Ситуация | Worktree? |
|---|---|
| Простая задача (правка текста, добавить компонент) | **Нет** — основная папка |
| Большой эксперимент (рефакторинг, миграция, риск что-то сломать) | **Да** — изолированный worktree |
| Параллельно правишь файлы руками + просишь Claude что-то параллельно | **Да** — чтобы не конкурировать за рабочее дерево |
| Новый сайт из шаблона (§1) | **Нет** — там нечего изолировать |
| Не знаешь что выбрать | **Нет** — основная папка по умолчанию |

**Минус worktree** — изменения Claude'а в worktree не видны в основной папке, пока не сольются через PR. Если хочешь сразу видеть правки в `~/projects/{site}/` — основная папка проще.

**Важно про worktree + multi-Claude:** даже на разных Mac'ах (или в разных worktree на одном Mac) **только одна Claude-сессия за раз** должна писать в `.claude/memory/project_state.md` — иначе git-merge сломает журнал. Сначала закончи одну сессию (`/handoff`) — потом начинай вторую (`/resume`). См. §7 про multi-developer и Multi-Claude protocol в `CLAUDE.md`.

## 3. Первое сообщение Claude

```
Прочитай CLAUDE.md и specs/INDEX.md. Затем открой specs/00-brief.md и проведи меня по нему — спроси у меня бриф по проекту.
```

При старте каждой сессии Claude запускает `.claude/hooks/session-start.sh`, который сам делает `git fetch` и подсказывает если ветка отстала. Поэтому ритуал «не забудь pull» больше не на тебе.

## 3.5. Первый деплой на сервер

Когда сайт минимально готов (главная страница рендерится, бриф заполнен) — пора поднимать VPS.

**Если у тебя ещё нет VPS под этот сайт:**

```
В Claude (продолжая ту же сессию или в новой):
Прочитай specs/01b-server-handoff.md и проведи меня по нему.
```

Спека `01b` пошагово:
1. Проверит, что у тебя готов VPS (если нет — отправит на `01a` + `bootstrap-vps.sh` для свежего Ubuntu)
2. Сгенерирует SSH-ключ деплоя (`~/.ssh/{site}-deploy`), положит публичную часть в `authorized_keys` пользователя `deploy` на VPS
3. Создаст в GitHub репо Environment `production` и положит туда секреты:
   - `SSH_PRIVATE_KEY` (приватный из Mac)
   - `SSH_HOST`, `SSH_USER`, `SSH_PORT`
   - `PROD_ENV_FILE` (всё содержимое `.env.production`)
4. Создаст `.github/workflows/deploy-prod.yml` (push-based: build на runner → rsync → симлинк-релиз)
5. **Подскажет тебе** что делать с доменом (см. `docs/domain-connect.md`) — регистрация у регистратора и проставление A-записи на IP VPS это **твоя ручная работа в панели Reg.ru / GoDaddy / Cloudflare**, у Claude нет туда доступа. После того как пропишешь записи — Claude проверит через `dig +short {domain}`, что DNS распространился.
6. Сделает первый push в `main` → Actions запустит первый деплой → Caddy получит сертификат при первом HTTPS-запросе (только когда A-запись уже работает — иначе Caddy упадёт на ACME-challenge).

**Если VPS уже есть** (на нём работают другие сайты, и ты хочешь подселить новый):

```
В Claude:
Пройди по docs/server-add-site.md — у меня уже есть VPS, на нём работают другие сайты,
надо подключить новый сайт {site}. Выдели свободный порт из ~/ports.md, добавь блок
в /etc/caddy/Caddyfile.d/{site}.caddy, подними PM2-процесс {site}-prod.
После этого пройди specs/01b-server-handoff.md для настройки GitHub Actions
(SSH-ключ деплоя, Environment 'production' с секретами, .github/workflows/deploy-prod.yml).
```

Замени `{site}` на имя сайта (то же что в `package.json#name`).

После первого зелёного workflow:
```bash
curl -I https://{domain}/      # должен вернуть 200 OK
```

Если упало — открой Actions tab в GitHub, посмотри какой шаг красный. Чаще всего: `SSH_PRIVATE_KEY` не в Environment (а в repo-level), или DNS ещё не распространился. См. «Известные грабли» в `_BUILD/v3/02-migrate-existing-project.md`.

## 4. Работа изо дня в день

**Главное правило:** одна спека = одна Claude-сессия = один чат. Между задачами `/clear` или новый чат.

### Что такое slash-команды

В чате Claude Desktop ты вводишь обычные сообщения, но есть короткие команды, которые **начинаются со слэша** (`/`) и выполняют заранее заданную инструкцию. Они лежат в папке `.claude/commands/` репо как обычные `.md` файлы — Claude Desktop сканирует папку при старте сессии и предлагает их в auto-complete (когда ты начинаешь печатать `/` в чате — выпадает список).

В нашем bootstrap'е v3 настроены **три** slash-команды:

| Команда | Когда вызывать | Что делает |
|---|---|---|
| **`/resume`** | В **начале** новой сессии (после `/clear` или нового чата) | Прочитает `.claude/memory/INDEX.md` и `project_state.md`, сверится с git (uncommitted, последние коммиты), кратко резюмирует где остановились — и **подождёт твоего ОК** перед работой. Если git и память разошлись — стопнет и спросит, не действует сам. |
| **`/handoff`** | В **конце** сессии — перед `/clear`, перед закрытием чата, особенно если уходишь надолго | Обновит `.claude/memory/project_state.md`: добавит запись в Session log (что сделано), пересоберёт Active phase и Next steps, спросит про uncommitted-изменения (коммитить или сохранить как stash). Без `/handoff` следующая сессия **не будет знать контекст** — придётся разбираться с нуля. |
| **`/catchup`** | После **долгого перерыва** (несколько дней/недель), когда `/resume` дал короткое резюме, но хочется глубже понять что произошло | Глубже копнёт `git log`, последние PR, сравнит с памятью. Полезно когда в проекте параллельно работали другие разработчики и ты хочешь увидеть «что нового». |

Подробное содержимое команд — в `.claude/commands/{handoff,resume,catchup}.md`. Их можно править под себя (например, добавить в `/handoff` свою привычку коммитить только после ревью).

### Цикл одной задачи

```
[стартуешь чат, открываешь папку]
       ↓
[session-start хук: git fetch + проверка отставания ветки]
       ↓
   /resume                ← Claude резюмирует где остановились
       ↓
[обсуждаешь / планируешь / ждёшь plan mode]
       ↓
[Claude работает по спеке: коммитит после каждой подзадачи]
       ↓
   /handoff               ← Claude обновляет project_state.md
       ↓
[stop-хук напомнит про /handoff если забыл и были коммиты]
       ↓
   /clear                 ← очистка контекста перед новой задачей
       ↓
[новая задача → новый /resume или новый чат]
```

### Если первая сессия в новом проекте

В новом проекте `.claude/memory/project_state.md` ещё пустой шаблон, `/resume` ничего полезного не покажет. Используй промпт из §3 (`Прочитай CLAUDE.md и specs/INDEX.md...`). С следующей сессии — уже `/resume`.

### Если `/resume` или `/handoff` не работают

Старые версии Claude Desktop могут не сканировать `.claude/commands/`. Тогда вручную (длинные эквиваленты):

- Вместо `/resume`:
  ```
  Прочитай .claude/memory/INDEX.md, .claude/memory/project_state.md.
  Сверь с git status и последними коммитами. Кратко резюмируй где остановились.
  Жди ОК перед работой.
  ```
- Вместо `/handoff`:
  ```
  Обнови .claude/memory/project_state.md: добавь запись в Session log про эту сессию
  (что сделано, какие файлы тронуты), обнови Active phase и Next steps.
  Спроси меня про uncommitted-изменения если есть.
  ```

## 5. Вернуться к уже начатому сайту

- New chat → Select folder → `~/projects/{site}`.
- Промпт: `/resume`

`/resume` прочитает `.claude/memory/project_state.md`, сверится с git-состоянием (порчинг, последние коммиты), кратко резюмирует где остановились и подождёт твоего ОК на старт работы. Если git и память разошлись — Claude стопает и спрашивает как продолжить, не делает ничего сам.

Если `/resume` по какой-то причине не сработает (кеш слетел, ранние версии Claude Desktop не сканируют `.claude/commands/`) — длинный вариант: `Прочитай .claude/memory/INDEX.md, .claude/memory/project_state.md и кратко резюмируй где мы остановились. Жди ОК.`

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

### 7.1. Подготовка репо (один раз)

До приглашения коллеги — убедись, что:

```bash
# Ветка dev существует (это рабочая ветка коллабораторов; main защищён)
git ls-remote --heads origin dev | grep -q dev || \
  (git checkout -b dev && git push -u origin dev && git checkout main)

# (Опционально, если у тебя GitHub Pro / public репо) включить branch protection на main
gh api -X PUT repos/{owner}/{repo}/branches/main/protection \
  -F required_pull_request_reviews.required_approving_review_count=1 \
  -F enforce_admins=false 2>&1 || echo "Skipping protection (private repo on free plan)"
```

### 7.2. Пригласить коллегу

1. Узнай GitHub-логин коллеги (например, `alice`).
2. Открой Claude в проекте, скажи: «добавь `alice` как collaborator с правами Write».
3. Дай ей ссылку на `docs/team-onboarding.md` в репо.

### 7.3. Граница доступа

**Не давай:** SSH к VPS, `deploy_key` (он же `SSH_PRIVATE_KEY` в Environment), root-пароли, GitHub Environment Secrets. Это намеренная граница: коллабораторы пишут код, Actions деплоит, владелец держит инфру.

**Что коллеге доступно:**
- Read/Write на код (через PR в `dev`)
- `.claude/memory/` файлы — да, синхронизируются через git (см. ниже про конфликты)
- `data/leads.json` — нет, это runtime data, gitignored
- `.env.production` — нет, gitignored

### 7.4. Multi-Claude protocol для коллабораторов

Каждый разработчик работает в своей feature-ветке от `dev`. Это **изолирует код**, но `.claude/memory/project_state.md` всё равно один на проект — поэтому правило:

- **Параллельные Claude-сессии на ОДИН проект (даже с разных Mac'ов) запрещены.** Один пишет в `project_state.md` → другой не должен открывать `/resume` пока первый не сделал `/handoff` + push своей ветки.
- На практике достаточно: «один разработчик в проекте за раз», свободно созваниваться или писать в чат.
- Для **разных проектов** (alice работает над сайтом A, я над сайтом B) — никаких ограничений, параллелим свободно.

### 7.5. Memory-файлы и git-merge

`.claude/memory/*.md` коммитятся вместе с feature-ветками. На PR это **может вызвать merge-конфликт**, чаще всего в `project_state.md` (он active, оба пишут). Как разруливать:

```bash
# В feature-ветке после rebase'а на dev (или при merge'е PR):
# Конфликты в .claude/memory/project_state.md — это log-файл, оба правы.

git status                                    # увидишь файлы с конфликтом
# Открой project_state.md, объедини обе записи в Session log вручную
# (это просто текст — оба разработчика добавили свою запись в журнал)
git add .claude/memory/project_state.md
git rebase --continue  # или git commit, если был merge

# Для decisions.md / lessons.md / feedback.md (append-only журналы)
# — то же самое: открыл, объединил записи, добавил.
```

**Чтобы конфликтов было меньше**:
- Каждый перед началом работы: `git pull origin dev` + `/resume` (Claude увидит свежий `project_state.md`)
- В конце сессии: `/handoff` (Claude обновит memory) → коммит + push в свою feature-ветку
- В PR — мердж в `dev` через GitHub UI (UI часто умеет merge простых конфликтов сам)

## 8. Секреты на VPS

`.env.production` живёт у тебя локально (`~/projects/{site}/.env.production`, gitignored). На прод его доставляет **GitHub Actions** на каждом деплое — не ты.

**Как это работает.** В GitHub → Settings → Environments → `production` лежит один multiline-секрет `PROD_ENV_FILE` = всё содержимое твоего `.env.production`. Каждый push в `main` запускает workflow, тот пишет файл в `releases/<sha>/.env` рядом со standalone-сборкой и переключает симлинк `current/`. PM2 видит свежие env через `pm2 reload --update-env`.

**Когда поменялись секреты** (новый TG-токен, ротация SMTP-пароля, ...):

```bash
# 1. Поправь локально:
nano ~/projects/{site}/.env.production

# 2. Загрузи весь файл одним секретом (заменит существующий):
gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} \
  < ~/projects/{site}/.env.production

# 3. Триггерни деплой пустым коммитом или повторным запуском workflow:
git commit --allow-empty -m "chore: bump env" && git push origin main
```

**Fallback (когда Actions недоступны или надо быстро).** Промпт Claude'у: «**синхронизируй .env на прод как fallback**» — он прогонит `scripts/sync-env.sh`, патчит `current/.env` через симлинк и делает `pm2 reload`. Это **временно**: следующий push в main перезапишет файл из `PROD_ENV_FILE` секрета, поэтому `gh secret set` всё равно нужен, чтобы изменение пережило деплой.

## 9. Сломал прод?

Промпт Claude'у: «**откати прод на предыдущий релиз**» — Claude прогонит `scripts/rollback.sh` (атомарный switch симлинка `current → releases/<previous-sha>` + `pm2 reload`, миллисекунды, без пересборки) и подскажет команду для `git revert + push`, чтобы починка пошла через Actions поверх.

`<hash>` — короткий идентификатор коммита, обычно 7 символов вроде `abc1234`. Видно в `git log` или в URL GitHub-коммита (последние 7 символов после `/commit/`).

Если плохой коммит — это PR-merge (виден как «Merge pull request #N»), Claude подскажет `git revert -m 1 <hash>` (без `-m 1` git упадёт «commit has more than one parent»).

## 10. Мигрировать старый сайт (v2.x) на v3

Если у тебя есть сайт, поднятый из bootstrap'а старой версии (v2.0–v2.4) и хочется переехать на v3.0 — это отдельная задача, не обязательная.

### Как это работает (без локальной копии bootstrap'а)

Bootstrap-репо (`tem11134v2-cmd/web-dev-bootstrap`) **публичный** — все его файлы можно читать с любого Mac через GitHub raw URL без аутентификации и без локального клона. То есть **миграция работает с любой машины**: твой основной Mac, новый ноут, ноут друга — везде одинаково.

ТЗ-2 (`_BUILD/v3/02-migrate-existing-project.md`) внутри использует helper-функцию, которая автоматически определяет:
- Есть ли локально `~/ClaudeCode/web-dev-bootstrap/` → берёт файлы оттуда (быстрее, offline)
- Нет → скачивает через `curl https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/v3.0/...`

Тебе ничего настраивать не надо — Claude сам разберётся.

### Запуск

В папке старого сайта — новый Claude-чат. Стартовый промпт:

```
Прочитай файл ТЗ миграции по URL:
https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/v3.0/_BUILD/v3/02-migrate-existing-project.md

Затем выполни его на этом проекте. Сначала покажи план миграции с учётом текущей
версии этого проекта, жди подтверждения перед любыми правками.
```

Claude через `WebFetch` или `curl` прочитает ТЗ-2, дальше:

1. Определит текущую версию проекта (по `_BUILD/changelog.md` или признакам)
2. Сделает pre-flight: `git status`, поставит `pre-v3-migration-YYYYMMDD` тег для отката
3. Покажет **персональный план миграции** под этот конкретный проект — жди ОК
4. Только после твоего подтверждения начнёт правки

### Если миграция не вся, а точечная

Миграция модульная: можно делать **любое подмножество** этапов, не обязательно всё сразу. Например, только tooling (pnpm + Biome + mise) без deploy-миграции. Скажи Claude в начале:

```
Хочу мигрировать только этапы 2 (tooling: mise + pnpm + Biome) и 5 (.claude/ обновления).
Этапы 3 (код), 4 (deploy) и 6 (Caddy) пропусти.
```

Claude построит план только под выбранные этапы.

### Опционально: локальная копия bootstrap'а

Если хочешь работать offline или просто чтобы быстрее (без сетевых запросов к GitHub на каждый `cp`) — клонируй bootstrap локально один раз:

```bash
mkdir -p ~/ClaudeCode
git clone --branch v3.0 https://github.com/tem11134v2-cmd/web-dev-bootstrap.git \
  ~/ClaudeCode/web-dev-bootstrap
```

Дальше ТЗ-2 автоматически использует локальные файлы. Обновлять локальную копию: `cd ~/ClaudeCode/web-dev-bootstrap && git fetch --tags && git checkout v3.0` (или другой свежий тег, когда выйдет v3.x).

Подробности всех 6 этапов миграции — в самом ТЗ-2 (`_BUILD/v3/02-migrate-existing-project.md` в репо bootstrap'а).

## 11. Обновить сам bootstrap (для меня, разработчика)

В папке `~/ClaudeCode/web-dev-bootstrap` — новый чат.

- **Если рефакторишь bootstrap по большому ТЗ** (типа `_BUILD/v3/01-bootstrap-refactor.md`) — стартовый промпт описан в начале самого ТЗ. Память bootstrap'а сама помнит активную фазу через `.claude/memory/project_state.md`.
- **Если просто точечная правка** — `/resume` или прямой промпт «улучшить шаблон в [файл]: [описание]».

Изменения коммитятся в feature-ветку, мёрджатся PR в `main` через `gh pr merge --squash`, ставится семвер-тег (`v3.0.x`, `v3.1` и т.д.) и запись в `_BUILD/changelog.md` сверху.

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
- **«Claude залип / повторяет круги»** — `/clear` → `/resume`. Свежий 200K-контекст обычно лучше чем починка отравленного.
- **«После `/resume` Claude думает что мы в другой фазе»** — открой `.claude/memory/project_state.md`, поправь руками раздел `Active phase` под реальность, перезапусти `/resume`. Это редко случается, обычно когда несколько worktree-сессий писали в один файл (запрещено протоколом, см. §6).

---

## Где что лежит на Mac

| Путь | Что |
|---|---|
| `~/projects/{site}/` | Код сайта, локальная разработка |
| `~/projects/{site}/.env.production` | Локальные секреты (gitignored). Источник истины для `PROD_ENV_FILE` GitHub-секрета — после правки делай `gh secret set --env production PROD_ENV_FILE < ...` и пуш в main |
| `~/Downloads/HOW-TO-START.docx` | Этот файл (docx-версия для печати) |
| `~/ClaudeCode/web-dev-bootstrap/` | Исходный шаблон (редактируется когда улучшаешь сам алгоритм) |
| `~/.ssh/config` | Алиасы SSH к серверам (`Host {site}` → IP, ключ; см. `docs/server-add-site.md`) |
| `~/.ssh/id_ed25519` | Твой личный SSH-ключ для GitHub и для входа на VPS как root/sudo |
| `~/.ssh/{site}-deploy` | Per-site deploy-ключ (опционально). Публичная часть в `authorized_keys` пользователя `deploy` на VPS, приватная — в GitHub Environment Secret `SSH_PRIVATE_KEY` |

## Что делать дальше (после запуска первого сайта)

- **Сайт готов к релизу** → спека `12-handoff.md` (передача заказчику, 3 модели H1/H2/H3).
- **Подключить второго разработчика** → §7 выше + `docs/team-onboarding.md`.
- **Сломал прод** → §9 выше.
- **Сайт надо переехать на другой VPS** → спека `14-migrate.md` (4 сценария M1–M4, 7-day soak).
- **Миграция с живого сайта** (Tilda/WP) → `specs/optional/opt-migrate-from-existing.md`.
- **Обычные правки уже живого сайта** → спека `13-extend-site.md` (циклическая).
- **Перевести старый сайт (v2.x bootstrap) на v3.0** → §10 выше + `_BUILD/v3/02-migrate-existing-project.md`.

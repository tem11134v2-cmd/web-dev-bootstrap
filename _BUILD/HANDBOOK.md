# web-dev-bootstrap — Руководство владельца

**Версия:** v3.0
**Собрано:** 2026-04-29

> Это **сборный** документ из 6 источников в репо. Не правь HANDBOOK напрямую — правь исходные `.md` и пересобирай через `bash scripts/build-handbook.sh`.

## Что внутри

| Часть | Содержание | Источник |
|---|---|---|
| I | Старт и работа с проектом (главный workflow) | `_BUILD/HOW-TO-START.md` |
| II | Подключение второго разработчика (для коллаборатора) | `docs/team-onboarding.md` |
| III | Подключение домена (DNS у регистратора) | `docs/domain-connect.md` |
| IV | Юридические тексты для RU-сайтов (152-ФЗ) | `docs/legal-templates.md` |
| V | Если что-то сломалось (троублшутинг) | `docs/troubleshooting.md` |
| Прил. A | История версий | `_BUILD/changelog.md` |

> **Что НЕ вошло** (по дизайну): инструкции для Claude (`docs/architecture.md`, `design-system.md`, `content-layout.md`, `performance.md`, `seo.md`, `forms-and-crm.md`, `automation.md`, `server-*.md`, `workflow.md`, `stack.md`, `conversion-patterns.md`), spec-файлы для Claude (`specs/\*`), миграционный промт (`_BUILD/v3/02-migrate-existing-project.md`). Все они доступны в репо как самостоятельные файлы и читаются Claude'ом по запросу.

---

## Часть I. Старт и работа с проектом

_Источник: [`_BUILD/HOW-TO-START.md`](../_BUILD/HOW-TO-START.md)_

## Как начинать новый сайт

Короткая инструкция: от пустой папки до «Claude уже пишет код».

Если Mac совершенно свежий (новый ноутбук, ничего не настроено) — сначала пройди раздел «0. Первичная настройка Mac» ниже. Это делается один раз на каждый Mac, потом только раздел 1 и дальше на каждый новый сайт.

> **Версия инструкции:** v3.0 (актуально для bootstrap'а на этом теге).
>
> **Хочешь полный документ со всеми связанными разделами в одном файле?** Открой `_BUILD/HANDBOOK.md` — это **сборка** этого HOW-TO + `team-onboarding.md` + `domain-connect.md` + `legal-templates.md` + `troubleshooting.md` + `changelog.md`. Регенерируется командой `bash scripts/build-handbook.sh` после правок любого исходника.
>
> Печатная `.docx`-версия именно этого HOW-TO-START в `_BUILD/HOW-TO-START.docx`. Регенерируется через `pandoc _BUILD/HOW-TO-START.md -o _BUILD/HOW-TO-START.docx --toc --toc-depth=2 --metadata title="Как работать с web-dev-bootstrap v3.0" --metadata lang=ru-RU` (требует `brew install pandoc`).

---

### 0. Первичная настройка Mac (один раз)

#### 0.0. Аккаунт на GitHub

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

#### 0.1. Claude Code Desktop

Зайди на claude.com → в меню сверху найди **Claude Code → Download for Mac**. Скачается .dmg файл. Открой → перетащи иконку Claude в папку Applications. Запусти — попросит войти через браузер (Google / Anthropic аккаунт).

После первого запуска — Claude Code готов принимать чаты и открывать папки через **Select folder**.

#### 0.2. Terminal + Xcode Command Line Tools (включают git)

- Открой **Terminal** (Cmd+Space → набери «Terminal» → Enter).
- Запусти одну команду:

```bash
xcode-select --install
```

Откроется системное окошко — нажми Install. Ждёшь 5–10 минут, пока скачаются инструменты разработчика.

Проверка: `git --version`

#### 0.3. Homebrew (пакетный менеджер Mac)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Попросит пароль Mac. Длится ~3 минуты. После — выполни три echo/eval команды, которые brew напечатает (добавляет brew в PATH).

Проверка: `brew --version`

#### 0.4. GitHub CLI (gh) + mise (Node + pnpm)

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

#### 0.5. Git identity

Имя и email, которыми будут подписываться твои коммиты.

```bash
## Шаблон — замени плейсхолдеры на свои, кавычки оставь:
git config --global user.name "<твой-логин>"
git config --global user.email "<твой-email>"
```

```bash
## Пример (мои данные):
git config --global user.name "tem11134v2"
git config --global user.email "tem11134v2@gmail.com"
```

Проверка: `git config --get user.name && git config --get user.email` — должны вывестись твои значения.

#### 0.6. SSH-ключ

```bash
## Шаблон:
ssh-keygen -t ed25519 -C "<твой-email>"
```

```bash
## Пример:
ssh-keygen -t ed25519 -C "tem11134v2@gmail.com"
```

Жми Enter три раза (выбираем дефолтный путь и пустой passphrase).

#### 0.7. Авторизация в GitHub через gh

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

#### 0.8. Создать папку ~/projects/

```bash
mkdir -p ~/projects
```

Всё. Mac готов.

#### Словарик (на один раз)

- `~` — твоя home-папка на Mac (`/Users/{твой-логин}/`).
- `~/projects/` — общая папка под все твои сайты.
- `{site}` в командах ниже — название сайта в kebab-case. Примеры: `migrator`, `clinic-landing`. Замени на своё каждый раз.

---

### 1. Создать репо из шаблона

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

### 1.5. Клонировать СВОЙ существующий проект (новый Mac / второй компьютер владельца)

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

### 2. Открыть в Claude Desktop

- Claude Desktop → **+ New chat** (Cmd+N).
- **Select folder** → `~/projects/{site}`.

При первом открытии папки macOS может спросить разрешение «Claude wants access to folder» — нажми **Allow** (разово, дальше не спрашивает).

#### Что делать с выбором ветки и worktree

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

### 3. Первое сообщение Claude

```
Прочитай CLAUDE.md и specs/INDEX.md. Затем открой specs/00-brief.md и проведи меня по нему — спроси у меня бриф по проекту.
```

При старте каждой сессии Claude запускает `.claude/hooks/session-start.sh`, который сам делает `git fetch` и подсказывает если ветка отстала. Поэтому ритуал «не забудь pull» больше не на тебе.

### 3.5. Первый деплой на сервер

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

### 4. Работа изо дня в день

**Главное правило:** одна спека = одна Claude-сессия = один чат. Между задачами `/clear` или новый чат.

#### Что такое slash-команды

В чате Claude Desktop ты вводишь обычные сообщения, но есть короткие команды, которые **начинаются со слэша** (`/`) и выполняют заранее заданную инструкцию. Они лежат в папке `.claude/commands/` репо как обычные `.md` файлы — Claude Desktop сканирует папку при старте сессии и предлагает их в auto-complete (когда ты начинаешь печатать `/` в чате — выпадает список).

В нашем bootstrap'е v3 настроены **три** slash-команды:

| Команда | Когда вызывать | Что делает |
|---|---|---|
| **`/resume`** | В **начале** новой сессии (после `/clear` или нового чата) | Прочитает `.claude/memory/INDEX.md` и `project_state.md`, сверится с git (uncommitted, последние коммиты), кратко резюмирует где остановились — и **подождёт твоего ОК** перед работой. Если git и память разошлись — стопнет и спросит, не действует сам. |
| **`/handoff`** | В **конце** сессии — перед `/clear`, перед закрытием чата, особенно если уходишь надолго | Обновит `.claude/memory/project_state.md`: добавит запись в Session log (что сделано), пересоберёт Active phase и Next steps, спросит про uncommitted-изменения (коммитить или сохранить как stash). Без `/handoff` следующая сессия **не будет знать контекст** — придётся разбираться с нуля. |
| **`/catchup`** | После **долгого перерыва** (несколько дней/недель), когда `/resume` дал короткое резюме, но хочется глубже понять что произошло | Глубже копнёт `git log`, последние PR, сравнит с памятью. Полезно когда в проекте параллельно работали другие разработчики и ты хочешь увидеть «что нового». |

Подробное содержимое команд — в `.claude/commands/{handoff,resume,catchup}.md`. Их можно править под себя (например, добавить в `/handoff` свою привычку коммитить только после ревью).

#### Цикл одной задачи

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

#### Если первая сессия в новом проекте

В новом проекте `.claude/memory/project_state.md` ещё пустой шаблон, `/resume` ничего полезного не покажет. Используй промпт из §3 (`Прочитай CLAUDE.md и specs/INDEX.md...`). С следующей сессии — уже `/resume`.

#### Если `/resume` или `/handoff` не работают

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

### 5. Вернуться к уже начатому сайту

- New chat → Select folder → `~/projects/{site}`.
- Промпт: `/resume`

`/resume` прочитает `.claude/memory/project_state.md`, сверится с git-состоянием (uncommitted-изменения, последние коммиты), кратко резюмирует где остановились и подождёт твоего ОК на старт работы. Если git и память разошлись — Claude стопает и спрашивает как продолжить, не делает ничего сам.

Если `/resume` по какой-то причине не сработает (кеш слетел, ранние версии Claude Desktop не сканируют `.claude/commands/`) — длинный вариант: `Прочитай .claude/memory/INDEX.md, .claude/memory/project_state.md и кратко резюмируй где мы остановились. Жди ОК.`

### 6. Несколько сайтов одновременно

```
~/projects/
├── migrator/              ← сайт 1, один чат Claude
├── clinic-landing/        ← сайт 2, другой чат Claude
└── neon-bike-store/       ← сайт 3, ещё чат
```

Один сайт = один чат. Не смешивай в одном чате — Claude путается.

---

### 7. Подключить второго разработчика

#### 7.1. Подготовка репо (один раз)

До приглашения коллеги — убедись, что:

```bash
## Ветка dev существует (это рабочая ветка коллабораторов; main защищён)
git ls-remote --heads origin dev | grep -q dev || \
  (git checkout -b dev && git push -u origin dev && git checkout main)

## (Опционально, если у тебя GitHub Pro / public репо) включить branch protection на main
gh api -X PUT repos/{owner}/{repo}/branches/main/protection \
  -F required_pull_request_reviews.required_approving_review_count=1 \
  -F enforce_admins=false 2>&1 || echo "Skipping protection (private repo on free plan)"
```

#### 7.2. Пригласить коллегу

1. Узнай GitHub-логин коллеги (например, `alice`).
2. Открой Claude в проекте, скажи: «добавь `alice` как collaborator с правами Write».
3. Дай ей ссылку на `docs/team-onboarding.md` в репо.

#### 7.3. Граница доступа

**Не давай:** SSH к VPS, `deploy_key` (он же `SSH_PRIVATE_KEY` в Environment), root-пароли, GitHub Environment Secrets. Это намеренная граница: коллабораторы пишут код, Actions деплоит, владелец держит инфру.

**Что коллеге доступно:**
- Read/Write на код (через PR в `dev`)
- `.claude/memory/` файлы — да, синхронизируются через git (см. ниже про конфликты)
- `data/leads.json` — нет, это runtime data, gitignored
- `.env.production` — нет, gitignored

#### 7.4. Multi-Claude protocol для коллабораторов

Каждый разработчик работает в своей feature-ветке от `dev`. Это **изолирует код**, но `.claude/memory/project_state.md` всё равно один на проект — поэтому правило:

- **Параллельные Claude-сессии на ОДИН проект (даже с разных Mac'ов) запрещены.** Один пишет в `project_state.md` → другой не должен открывать `/resume` пока первый не сделал `/handoff` + push своей ветки.
- На практике достаточно: «один разработчик в проекте за раз», свободно созваниваться или писать в чат.
- Для **разных проектов** (alice работает над сайтом A, я над сайтом B) — никаких ограничений, параллелим свободно.

#### 7.5. Memory-файлы и git-merge

`.claude/memory/*.md` коммитятся вместе с feature-ветками. На PR это **может вызвать merge-конфликт**, чаще всего в `project_state.md` (он active, оба пишут). Как разруливать:

```bash
## В feature-ветке после rebase'а на dev (или при merge'е PR):
## Конфликты в .claude/memory/project_state.md — это log-файл, оба правы.

git status                                    # увидишь файлы с конфликтом
## Открой project_state.md, объедини обе записи в Session log вручную
## (это просто текст — оба разработчика добавили свою запись в журнал)
git add .claude/memory/project_state.md
git rebase --continue  # или git commit, если был merge

## Для decisions.md / lessons.md / feedback.md (append-only журналы)
## — то же самое: открыл, объединил записи, добавил.
```

**Чтобы конфликтов было меньше**:
- Каждый перед началом работы: `git pull origin dev` + `/resume` (Claude увидит свежий `project_state.md`)
- В конце сессии: `/handoff` (Claude обновит memory) → коммит + push в свою feature-ветку
- В PR — мердж в `dev` через GitHub UI (UI часто умеет merge простых конфликтов сам)

### 8. Секреты на VPS

`.env.production` живёт у тебя локально (`~/projects/{site}/.env.production`, gitignored). На прод его доставляет **GitHub Actions** на каждом деплое — не ты.

**Как это работает.** В GitHub → Settings → Environments → `production` лежит один multiline-секрет `PROD_ENV_FILE` = всё содержимое твоего `.env.production`. Каждый push в `main` запускает workflow, тот пишет файл в `releases/<sha>/.env` рядом со standalone-сборкой и переключает симлинк `current/`. PM2 видит свежие env через `pm2 reload --update-env`.

**Когда поменялись секреты** (новый TG-токен, ротация SMTP-пароля, ...):

```bash
## 1. Поправь локально:
nano ~/projects/{site}/.env.production

## 2. Загрузи весь файл одним секретом (заменит существующий):
gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} \
  < ~/projects/{site}/.env.production

## 3. Триггерни деплой пустым коммитом или повторным запуском workflow:
git commit --allow-empty -m "chore: bump env" && git push origin main
```

**Fallback (когда Actions недоступны или надо быстро).** Промпт Claude'у: «**синхронизируй .env на прод как fallback**» — он прогонит `scripts/sync-env.sh`, патчит `current/.env` через симлинк и делает `pm2 reload`. Это **временно**: следующий push в main перезапишет файл из `PROD_ENV_FILE` секрета, поэтому `gh secret set` всё равно нужен, чтобы изменение пережило деплой.

### 9. Сломал прод?

Промпт Claude'у: «**откати прод на предыдущий релиз**» — Claude прогонит `scripts/rollback.sh` (атомарный switch симлинка `current → releases/<previous-sha>` + `pm2 reload`, миллисекунды, без пересборки) и подскажет команду для `git revert + push`, чтобы починка пошла через Actions поверх.

`<hash>` — короткий идентификатор коммита, обычно 7 символов вроде `abc1234`. Видно в `git log` или в URL GitHub-коммита (последние 7 символов после `/commit/`).

Если плохой коммит — это PR-merge (виден как «Merge pull request #N»), Claude подскажет `git revert -m 1 <hash>` (без `-m 1` git упадёт «commit has more than one parent»).

### 10. Мигрировать старый сайт (v2.x) на v3

Если у тебя есть сайт, поднятый из bootstrap'а старой версии (v2.0–v2.4) и хочется переехать на v3.0 — это отдельная задача, не обязательная.

#### Как это работает (без локальной копии bootstrap'а)

Bootstrap-репо (`tem11134v2-cmd/web-dev-bootstrap`) **публичный** — все его файлы можно читать с любого Mac через GitHub raw URL без аутентификации и без локального клона. То есть **миграция работает с любой машины**: твой основной Mac, новый ноут, ноут друга — везде одинаково.

ТЗ-2 (`_BUILD/v3/02-migrate-existing-project.md`) внутри использует helper-функцию, которая автоматически определяет:
- Есть ли локально `~/ClaudeCode/web-dev-bootstrap/` → берёт файлы оттуда (быстрее, offline)
- Нет → скачивает через `curl https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/v3.0/...`

Тебе ничего настраивать не надо — Claude сам разберётся.

#### Запуск

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

#### Если миграция не вся, а точечная

Миграция модульная: можно делать **любое подмножество** этапов, не обязательно всё сразу. Например, только tooling (pnpm + Biome + mise) без deploy-миграции. Скажи Claude в начале:

```
Хочу мигрировать только этапы 2 (tooling: mise + pnpm + Biome) и 5 (.claude/ обновления).
Этапы 3 (код), 4 (deploy) и 6 (Caddy) пропусти.
```

Claude построит план только под выбранные этапы.

#### Опционально: локальная копия bootstrap'а

Если хочешь работать offline или просто чтобы быстрее (без сетевых запросов к GitHub на каждый `cp`) — клонируй bootstrap локально один раз:

```bash
mkdir -p ~/ClaudeCode
git clone --branch v3.0 https://github.com/tem11134v2-cmd/web-dev-bootstrap.git \
  ~/ClaudeCode/web-dev-bootstrap
```

Дальше ТЗ-2 автоматически использует локальные файлы. Обновлять локальную копию: `cd ~/ClaudeCode/web-dev-bootstrap && git fetch --tags && git checkout v3.0` (или другой свежий тег, когда выйдет v3.x).

Подробности всех 6 этапов миграции — в самом ТЗ-2 (`_BUILD/v3/02-migrate-existing-project.md` в репо bootstrap'а).

### 11. Обновить сам bootstrap (для меня, разработчика)

В папке `~/ClaudeCode/web-dev-bootstrap` — новый чат.

- **Если рефакторишь bootstrap по большому ТЗ** (типа `_BUILD/v3/01-bootstrap-refactor.md`) — стартовый промпт описан в начале самого ТЗ. Память bootstrap'а сама помнит активную фазу через `.claude/memory/project_state.md`.
- **Если просто точечная правка** — `/resume` или прямой промпт «улучшить шаблон в [файл]: [описание]».

Изменения коммитятся в feature-ветку, мёрджатся PR в `main` через `gh pr merge --squash`, ставится семвер-тег (`v3.0.x`, `v3.1` и т.д.) и запись в `_BUILD/changelog.md` сверху.

---

### Частые косяки

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

### Где что лежит на Mac

| Путь | Что |
|---|---|
| `~/projects/{site}/` | Код сайта, локальная разработка |
| `~/projects/{site}/.env.production` | Локальные секреты (gitignored). Источник истины для `PROD_ENV_FILE` GitHub-секрета — после правки делай `gh secret set --env production PROD_ENV_FILE < ...` и пуш в main |
| `~/Downloads/HOW-TO-START.docx` | Этот файл (docx-версия для печати) |
| `~/ClaudeCode/web-dev-bootstrap/` | Исходный шаблон (редактируется когда улучшаешь сам алгоритм) |
| `~/.ssh/config` | Алиасы SSH к серверам (`Host {site}` → IP, ключ; см. `docs/server-add-site.md`) |
| `~/.ssh/id_ed25519` | Твой личный SSH-ключ для GitHub и для входа на VPS как root/sudo |
| `~/.ssh/{site}-deploy` | Per-site deploy-ключ (опционально). Публичная часть в `authorized_keys` пользователя `deploy` на VPS, приватная — в GitHub Environment Secret `SSH_PRIVATE_KEY` |

### Что делать дальше (после запуска первого сайта)

- **Сайт готов к релизу** → спека `12-handoff.md` (передача заказчику, 3 модели H1/H2/H3).
- **Подключить второго разработчика** → §7 выше + `docs/team-onboarding.md`.
- **Сломал прод** → §9 выше.
- **Сайт надо переехать на другой VPS** → спека `14-migrate.md` (4 сценария M1–M4, 7-day soak).
- **Миграция с живого сайта** (Tilda/WP) → `specs/optional/opt-migrate-from-existing.md`.
- **Обычные правки уже живого сайта** → спека `13-extend-site.md` (циклическая).
- **Перевести старый сайт (v2.x bootstrap) на v3.0** → §10 выше + `_BUILD/v3/02-migrate-existing-project.md`.

---

## Часть II. Подключение второго разработчика

_Источник: [`docs/team-onboarding.md`](../docs/team-onboarding.md)_

## Onboarding для нового разработчика

Если владелец репо добавил вас как `Collaborator` с правами Write — этот документ для вас.

Bootstrap проекта на v3.0+ (push-based deploy, Caddy, Server Actions, Multi-Claude). Если читаете на старом проекте (v2.x) — workflow тот же, но детали инфры могут отличаться, спросите владельца.

### Что вам **не дадут** (намеренно)

- SSH-доступ к VPS, root-пароль, deploy-ключ.
- GitHub **Environment Secrets** (`SSH_PRIVATE_KEY`, `PROD_ENV_FILE` в Environment `production`) — это деплой-credentials, владелец держит у себя.
- Доступ к `.env.production` (gitignored, живёт только на Mac владельца + приезжает на VPS через workflow при каждом деплое).
- Прямой push в `main` (deploy-ветка). Хук `before-push.sh` блокирует чужой push, но дисциплина прежде всего.

Это нормально: вы пишете код, Actions деплоит, владелец держит инфру.

### Шаги onboarding-а

#### 1. Принять invitation на GitHub

Получите email от GitHub `[GitHub] @<owner> invited you to <owner>/<repo>` → **Accept invitation**.

#### 2. Клонировать репо

```bash
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:<owner>/<repo>.git
cd <repo>
```

(Если SSH к GitHub ещё не настроен — `gh auth login`, выберите `SSH`, далее по подсказкам.)

#### 3. Установить зависимости

```bash
mise install   # подхватит версию из .tool-versions (если используется mise)
pnpm install
```

#### 4. Запустить локально

```bash
pnpm dev
## → http://localhost:3000
```

Без `.env.production` формы пишут лиды в `data/leads.json` (fallback) — это нормально для локальной разработки.

#### 5. Открыть в Claude Code Desktop

Откройте папку проекта в Claude Desktop (`+ New chat` → `Select folder` → `~/projects/<repo>`).

Первый промпт в чате — `/resume`. Это slash-команда: Claude прочитает `.claude/memory/INDEX.md`, `project_state.md`, сверится с git и резюмирует, на чём остановилась команда. Если `/resume` не сработает (старая версия Claude Desktop, не сканирует `.claude/commands/`):

```
Прочитай CLAUDE.md, docs/INDEX.md, .claude/memory/INDEX.md, .claude/memory/project_state.md
и кратко резюмируй где сейчас проект. Жди ОК перед работой.
```

#### Опция «worktree» при открытии папки

Claude Desktop может предложить worktree (изолированная копия в отдельной папке/ветке). Для коллабораторов рекомендация — **не использовать worktree**, работайте в основной папке: ваши feature-ветки и так изолированы по принципу `git checkout -b feat/my-change`.

### Workflow

```
git checkout dev && git pull           # синхронизироваться с dev
git checkout -b feat/my-change         # ваша feature-ветка от dev
## … работа, коммиты …
git push -u origin feat/my-change
gh pr create --base dev                # PR в dev (не в main!)
```

Владелец ревьюит и мерджит в `dev`. Дальше владелец сам мерджит `dev → main` через PR — это триггерит deploy на VPS через Actions.

**Никогда:**

- не делайте PR напрямую в `main`
- не пытайтесь `git push origin main` или `git push -f` (хуки `before-push` и `guard-rm` заблокируют, но дисциплина — основная страховка)
- не коммитьте `.env*` (gitignored, но проверяйте `git status` перед commit)
- не открывайте параллельную Claude-сессию на ту же папку, пока другой разработчик там работает (см. ниже про Multi-Claude)

### Slash-команды Claude

В проекте настроены три slash-команды (живут в `.claude/commands/`):

- **`/resume`** — стартуйте каждую сессию с этого. Claude прочитает память, сверится с git, резюмирует.
- **`/handoff`** — заканчивайте каждую сессию этим. Claude обновит `.claude/memory/project_state.md` (Session log + Active phase + Next steps), спросит про uncommitted-изменения. Это нужно даже если в сессии вы ничего не закоммитили — следующий разработчик (или вы завтра) увидит контекст.
- **`/catchup`** — если непонятно где остановились и `/resume` мало (например, после долгого перерыва). Claude глубже копнёт `git log`, последние PR, активные ветки.

Stop-хук (`.claude/hooks/stop-reminder.sh`) мягко напомнит про `/handoff`, если в сессии были коммиты, — это просто текстовое напоминание, не блок.

### Multi-Claude protocol

**Одна Claude-сессия = одна папка проекта = один разработчик за раз.** Параллельные сессии на ОДНУ папку (даже если вы на разных Mac'ах) запрещены — поломают `.claude/memory/project_state.md`.

Практика:
- Прежде чем стартовать `/resume` — убедитесь, что владелец и другие коллабораторы сейчас не в проекте (созвонитесь / напишите в чат).
- Закончили — `/handoff` + push своей feature-ветки. Теперь следующий может стартовать.
- На разные проекты можно работать параллельно — без ограничений.

### Memory-файлы (`.claude/memory/`) и git

Memory-файлы (`project_state.md`, `decisions.md`, `lessons.md`, `feedback.md`, `pointers.md`, `references.md`) **коммитятся в git**. Это значит:

- При работе в feature-ветке — коммитьте обновления memory вместе с кодом (Claude через `/handoff` сделает это сам).
- Перед стартом — `git pull origin dev` подтягивает memory от других разработчиков.
- При мердже PR могут быть **merge-конфликты в memory-файлах** (особенно `project_state.md` — оба добавили запись в Session log). Решаются вручную:

```bash
## При rebase или merge видите конфликт в .claude/memory/project_state.md
## Это log-файл, оба разработчика правы — просто объедините записи
git status                              # увидеть конфликтные файлы
## Открыть project_state.md в редакторе, объединить обе записи в Session log
git add .claude/memory/project_state.md
git rebase --continue                   # или git commit, если был обычный merge
```

**Не делайте `git checkout --ours` или `--theirs` слепо** на memory-файлах — потеряете часть журнала. Объединять руками 30 секунд, оно того стоит.

### Если вам нужен новый секрет в .env

Не пытайтесь добавить его сами — у вас нет доступа ни к Mac владельца, ни к Environment Secrets. Напишите владельцу:
- какая переменная нужна (`FOO_API_KEY`)
- что она делает (CRM, аналитика, etc.)
- где её получить (URL личного кабинета сервиса)

Владелец:
1. Добавит ключ в свой локальный `~/projects/<repo>/.env.production`
2. Перепишет GitHub Environment-секрет: `gh secret set --env production PROD_ENV_FILE < .env.production`
3. Триггерит деплой пустым коммитом или повторным запуском workflow — секрет приедет на VPS в рамках следующего push'а.

Для **сборочного времени** (вам нужна публичная переменная типа `NEXT_PUBLIC_FEATURE_FLAG_X` чтобы локально протестить) — попросите владельца добавить её также в repo-level Secrets (она используется в build-job до того, как Environment подтягивается). Локально вы можете прописать её в свой `.env.local` (gitignored) на время разработки.

### Если вы сломали prod

Не пытайтесь чинить через Actions сами. Напишите владельцу с указанием:
- какой PR замерджен,
- какие симптомы,
- скриншот / curl-вывод если есть.

Владелец откатит через `scripts/rollback.sh` — атомарный switch симлинка `current` на предыдущий релиз, миллисекунды без пересборки. Затем попросит вас сделать `git revert <bad-commit>` (или `git revert -m 1 <merge-hash>` если плохой коммит — merge) в `dev`-ветке, PR в `dev`, мердж в `main` — Actions передеплоит починку.

### Где что искать

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

### Безопасность

- `.env*` не коммитьте.
- Лиды в `data/leads.json` (fallback) — содержат email/телефон. Не пушьте этот файл (он в `.gitignore`).
- Не запускайте незнакомые скрипты, особенно с sudo.
- При подозрении на компрометацию (странные коммиты в истории, неизвестные деплои) — сразу пишите владельцу.

---

## Часть III. Подключение домена

_Источник: [`docs/domain-connect.md`](../docs/domain-connect.md)_

## Domain: Connect

**Инструкция для человека.** Подключение домена к серверу. Делается один раз на домен.

### Вход

- Домен у регистратора (Reg.ru, GoDaddy, Namecheap, Cloudflare Registrar и т.п.).
- VPS с известным публичным IP, прошедший `server-manual-setup.md`.

### 1. Решить: Cloudflare или прямые A-записи

- **Прямые A-записи у регистратора** — проще, хватает для большинства проектов. DNS управляешь через панель регистратора.
- **Cloudflare** — добавляется если нужны CDN / DDoS-защита / edge-кэш / WAF или просто удобная DNS-панель. Подробности и подводные камни — `docs/deploy.md` § Cloudflare.

Ниже — оба варианта.

### Вариант A: прямые A-записи у регистратора

Зайди в панель регистратора → DNS-записи домена.

Добавь:

| Тип | Имя         | Значение         | TTL     |
|-----|-------------|------------------|---------|
| A   | `@`         | `{server-ip}`    | 300–3600|
| A   | `www`       | `{server-ip}`    | 300–3600|
| A   | `dev`       | `{server-ip}`    | 300–3600| ← только если нужен preview-поддомен

`@` означает сам корень домена (`example.com`), `www` — алиас, `dev` — поддомен для preview.

### Вариант B: Cloudflare

1. Заведи сайт в Cloudflare → получи два их NS-сервера.
2. У регистратора поменяй NS-серверы домена на cloudflare-ские. Подожди 1–24 часа (обычно 10 минут).
3. В Cloudflare → DNS → добавь те же A-записи что в варианте A. На время первого выпуска сертификата Caddy'ем **включи DNS-only (серое облачко) на `@` и `www`** — иначе CF перехватит HTTP-01 challenge на `/.well-known/acme-challenge/` и выпуск зациклится. После того как `journalctl -u caddy | grep "certificate obtained"` покажет успех — можно вернуть оранжевое облачко (proxy). На `dev` обычно держат серое облачко всегда.
4. SSL/TLS → **Full (strict)** после того, как Caddy выпустит Let's Encrypt-сертификат (см. `docs/server-add-site.md` § 5).

### 2. Проверить распространение

На Mac или на VPS:

```bash
dig +short {domain}                 # должен вернуть {server-ip}
dig +short www.{domain}             # то же
dig +short dev.{domain}             # если добавлял dev
```

Если `dig` пусто или возвращает другой IP — подожди ещё 10 минут, в панели регистратора DNS распространяется не мгновенно. TTL=300 помогает сократить ожидание.

На Cloudflare proxied (оранжевое облачко) `dig` вернёт IP Cloudflare, не твой VPS — это нормально, но HTTP-01 challenge с такого облачка к Caddy не дойдёт. Для первого выпуска временно переключи в DNS-only (см. п.3 выше).

### 3. Дальше — SSL (автоматически) и Caddy

Идёт в `docs/server-add-site.md` § 4–5. Без правильных A-записей Caddy не сможет пройти HTTP-01 challenge — лог будет крутить `obtain: ...`.

### Частые проблемы

- **`dig` пустой через 30 минут** → проверь, точно ли в панели сохранилась запись и нет ли CAA-записи, которая запрещает Let's Encrypt.
- **Caddy крутит «obtain: solving HTTP-01 challenge»** → A-запись ведёт не на этот VPS, или домен proxied через Cloudflare. `dig +short {domain}` должен показать IP сервера; для CF — DNS-only на время выпуска.
- **Cертификат выписался, но HTTPS отдаёт self-signed / handshake fails** → Caddy кладёт сертификаты в `/var/lib/caddy/.local/share/caddy/certificates/...`. Проверь `journalctl -u caddy --since "1 hour ago" | grep -iE "certificate|tls"`. Часто причина — между Caddy и клиентом стоит CF в Flexible mode (нужен Full strict).
- **Почтовые MX-записи пропали при переносе на Cloudflare** → Cloudflare импортирует не все типы. Проверь MX, SPF, DKIM, DMARC вручную по старой панели.

### Записать в память проекта

В `.claude/memory/references.md` зафиксируй:
- Где зарегистрирован домен (регистратор, аккаунт).
- Используется ли Cloudflare (да/нет, какой аккаунт).
- Дата истечения домена — поставь календарный reminder за 30 дней.

**Никогда не клади сюда** пароли, API-ключи, секреты. Только ссылки и факты.

---

## Часть IV. Юридические тексты для RU-сайтов (152-ФЗ)

_Источник: [`docs/legal-templates.md`](../docs/legal-templates.md)_

## Legal Templates (RU 152-ФЗ)

Заглушки для обязательных юридических блоков на российских сайтах с формами. Тексты — стартовая точка, **обязательно** валидируются юристом перед публикацией. Реквизиты и ФИО оператора — от заказчика.

### 1. Cookie-баннер

**Когда показывать:** один раз при первом визите. После клика «Принимаю» — сохранить выбор в `localStorage` (`cookieConsent: "accepted" | "rejected"`). Не показывать повторно.

#### Минимальный шаблон (текст)

> Этот сайт использует cookie-файлы для аналитики и улучшения работы сервиса. Продолжая использовать сайт, вы соглашаетесь с [Политикой обработки cookie-файлов]. [Принять] [Отклонить]

#### Расширенный (если есть Метрика/GA)

> Мы используем cookie-файлы и метрические системы (Яндекс.Метрика, Google Analytics) для анализа посещаемости и улучшения сайта. Подробнее — в [Политике конфиденциальности]. [Принять все] [Только необходимые]

**Реализация:** `components/CookieBanner.tsx` — client-компонент, fixed bottom, `z-50`, появляется через ~1с после маунта, закрывается по клику. Не блокирует контент.

### 2. Согласие на обработку персональных данных

**Когда:** обязательный чекбокс в каждой форме сбора контактов. Без галочки форма не отправляется (валидация: `z.literal(true)`).

#### Текст рядом с чекбоксом

> Я даю [согласие на обработку персональных данных](/consent) и принимаю условия [Политики конфиденциальности](/privacy).

#### Полный текст «Согласие на обработку ПДн» (страница `/consent`)

```
СОГЛАСИЕ НА ОБРАБОТКУ ПЕРСОНАЛЬНЫХ ДАННЫХ

Я, заполняя форму на сайте {DOMAIN}, в соответствии с Федеральным
законом от 27.07.2006 № 152-ФЗ «О персональных данных», свободно,
своей волей и в своём интересе даю согласие {ОПЕРАТОР: ФИО ИП / название ООО, ИНН, адрес}
(далее — Оператор) на обработку моих персональных данных:

— фамилия, имя, отчество;
— номер телефона;
— адрес электронной почты;
— иные сведения, добровольно сообщённые мной в форме обратной связи.

Цели обработки:
— связь со мной для ответа на запрос;
— оказание услуг, информацию о которых я запросил;
— направление информационных сообщений (с моего согласия).

Перечень действий: сбор, запись, систематизация, накопление, хранение,
уточнение, извлечение, использование, передача (в случаях, предусмотренных
законом), обезличивание, блокирование, удаление, уничтожение.

Способы обработки: с использованием средств автоматизации и без них.

Срок действия согласия: бессрочно, до момента отзыва в письменной форме
по адресу {EMAIL ОПЕРАТОРА}. Согласие может быть отозвано в любой момент
без объяснения причин.
```

Заменяемые плейсхолдеры: `{DOMAIN}`, `{ОПЕРАТОР}`, `{EMAIL ОПЕРАТОРА}`.

### 3. Политика конфиденциальности (страница `/privacy`)

Структура (плейсхолдер — заполняется юристом или генератором типа Тильда/КонсультантПлюс):

```
1. Общие положения
   — наименование Оператора, ИНН, адрес
   — сайт {DOMAIN}
   — основание: 152-ФЗ, GDPR (если работаете с ЕС)

2. Какие данные собираем
   — контактные (имя, телефон, email)
   — технические (IP, cookie, user-agent)
   — поведенческие (Метрика, GA)

3. Цели обработки
4. Правовые основания обработки
5. Передача третьим лицам
   — Яндекс.Метрика, Google Analytics
   — CRM-провайдер (AmoCRM / Bitrix24 / ...)
   — облачные провайдеры (Cloudflare / VPS-хостинг)

6. Сроки хранения
7. Права субъекта ПДн (запрос, изменение, удаление)
8. Контакты Оператора для запросов
9. Дата вступления в силу, порядок обновления
```

**Не пиши свой текст с нуля.** Используй шаблоны:
- Тильда / Битрикс — встроенные генераторы.
- Сервисы: privacypolicies.com, freeprivacypolicy.com (с локализацией).
- Юридические агентства — единоразовая услуга 5–15 тыс. руб., отбивается одной проверкой РКН.

### 4. Уведомление в Роскомнадзор

С 01.09.2022 (изменения в 152-ФЗ) операторы ПДн **обязаны** уведомить РКН до начала обработки. Подаётся через [Госуслуги](https://www.gosuslugi.ru) или [сайт РКН](https://pd.rkn.gov.ru/operators-registry/notification/form/).

**Сроки:** до запуска формы. Срок рассмотрения — до 30 дней. После подтверждения оператор появляется в [реестре РКН](https://pd.rkn.gov.ru/operators-registry/operators-list/).

В footer сайта рекомендуется указать: «{ОПЕРАТОР} зарегистрирован в Реестре операторов персональных данных, рег. № {NUMBER}».

### 5. Публичная оферта (если приём оплат на сайте)

Только если на сайте есть оплата (Эквайринг, ЮKassa, CloudPayments). Для лидогенерации (форма → менеджер → договор офлайн) — не требуется.

Заглушка-страница `/offer` со структурой:
```
1. Стороны (Исполнитель, Заказчик)
2. Предмет договора
3. Стоимость и порядок оплаты
4. Сроки оказания услуг
5. Права и обязанности сторон
6. Ответственность и форс-мажор
7. Конфиденциальность
8. Порядок разрешения споров
9. Реквизиты Исполнителя
```

Заполняется юристом под конкретный бизнес. Платёжный шлюз требует ссылку на оферту в момент оплаты.

### 6. Disclaimer для медицинских / юридических / финансовых ниш

Эти ниши требуют дополнительных дисклеймеров (есть лицензия / не реклама / возрастные ограничения). В рамках бутстрапа — не покрывается. Для таких проектов подключай профильного юриста на этапе `00-brief`.

### Чек-лист «Я готов запустить форму на RU-сайте»

- [ ] Cookie-баннер на сайте (с возможностью отклонить)
- [ ] Чекбокс «Согласие на обработку ПДн» в каждой форме (валидация на сервере)
- [ ] Страница `/privacy` (политика конфиденциальности) опубликована
- [ ] Страница `/consent` (текст согласия) опубликована
- [ ] Ссылки на политику и согласие — в footer и рядом с каждой формой
- [ ] Уведомление в РКН подано (или на стороне заказчика — зафиксирован срок)
- [ ] Если есть оплата — `/offer` опубликована
- [ ] Юрист или сервис-генератор валидировал тексты (не только AI/шаблон)

---

## Часть V. Если что-то сломалось

_Источник: [`docs/troubleshooting.md`](../docs/troubleshooting.md)_

## Troubleshooting

Частые косяки и способы их решения. Источник — реальные инциденты проекта (`.claude/memory/lessons.md`).

### gh auth mismatch — push блокируется хуком

**Симптом:**

```
BLOCKED by before-push: gh account mismatch.
  active gh account: bob
  origin owner:      alice
```

**Причина:** на Mac залогинено несколько gh-аккаунтов одновременно. Активным может быть «не тот».

**Фикс:**

```bash
gh auth status                             # посмотреть кто Active
gh auth switch -h github.com -u <owner>  # переключить
```

После — повторить `git push`. Если push без хука уже прошёл и попал в чужой репо — связаться с владельцем чужого репо и попросить закрыть PR / удалить ветку.

### DDoS-Guard 301 при smoke-тесте до DNS cutover

**Симптом:** `curl -H "Host: example.com" http://NEW_VPS_IP/` возвращает `301` от `Server: ddos-guard` с заголовком `x-tilda-server: 29`.

**Причина:** A-запись домена ещё указывает на старый IP (Tilda → DDoS-Guard). Middlebox (РКН/ISP) видит Host-header и перенаправляет на DDoS-Guard, **даже если TCP идёт на нужный IP**.

**Фикс:** не использовать доменное имя в Host-header до cutover.

```bash
## Плохо:
curl -H "Host: example.com" http://NEW_VPS_IP/

## Хорошо (IP-only):
curl -H "Host: NEW_VPS_IP" http://NEW_VPS_IP/

## Или через /etc/hosts override:
echo "NEW_VPS_IP example.com" | sudo tee -a /etc/hosts
curl -I https://example.com/
## не забыть откатить /etc/hosts после теста
```

### SSH permission denied в deploy job

**Симптом:** Actions падает на шаге `Setup SSH` или `Rsync to release dir` с `Permission denied (publickey)` от VPS.

**Причина (любая из):**
1. Public-часть `~/.ssh/{site}-deploy.pub` не добавлена в `/home/deploy/.ssh/authorized_keys` на VPS.
2. В `secrets.SSH_PRIVATE_KEY` лежит другой ключ (не парный к `authorized_keys` на VPS).
3. `secrets.SSH_USER` не `deploy`, или `SSH_PORT` не совпадает с реальным портом sshd.
4. `secrets.SSH_HOST` показывает на старый IP (после миграции).

**Фикс:**

```bash
## На Mac — проверить, что приватный ключ парный к публичному, который ты копировал на VPS:
ssh-keygen -y -f ~/.ssh/{site}-deploy   # печатает публичную часть из приватного
ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{ip}  # перезаливает public на VPS

## Если приватный ключ удалил с Mac после загрузки в Secrets — сгенерируй новый:
ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy -N "" -C "{site}-deploy"
ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{ip}
gh secret set SSH_PRIVATE_KEY --env production --repo {owner}/{site} \
  < ~/.ssh/{site}-deploy

## Re-run upавший workflow:
gh run rerun <run-id> --failed
```

### Симлинк current не переключился

**Симптом:** workflow зелёный, но `https://{domain}` отдаёт старую версию. На VPS `readlink ~/prod/{site}/current` показывает прошлый sha.

**Причины:**
1. Шаг `Activate release` упал тихо — посмотри `gh run view <run-id> --log` в этой секции.
2. Симлинк существует и `ln -sfn` ничего не делает: `current` — это **папка** (не симлинк) после ручных правок. Проверь `ls -la ~/prod/{site}/ | grep current` — должно быть `current -> releases/<sha>`.
3. PM2-процесс закэшировал путь: `pm2 reload --update-env` дёрнули, но процесс падает на старте и идёт `restart loop` со старым кодом. `pm2 logs {site}-prod` покажет.

**Фикс (вручную на VPS):**
```bash
ssh deploy@{ip}
cd ~/prod/{site}
ls -1 releases/                                     # где новый sha?
ln -sfn releases/<new-sha> current
pm2 reload {site}-prod --update-env
readlink current && pm2 list                         # симлинк и процесс OK?
```

### rsync завершился с ошибкой

**Симптом:** Шаг `Rsync to release dir` падает с одним из:
- `rsync: failed to connect to host` — сетевой issue или wrong `SSH_HOST`.
- `rsync: mkdir failed: Permission denied` — `~/prod/{site}/` не существует или принадлежит не `deploy`.
- `rsync: write failed: No space left on device` — забит диск.
- `rsync: change_dir … failed` — на runner-е пустой `deploy/` (билд не положил artefact).

**Фикс:**
```bash
## На Mac или с VPS:
ssh deploy@{ip} 'df -h ~ && ls -ld ~/prod/{site}/releases'
## Если диск > 90% — почистить старые релизы (workflow держит last 5, иначе можно вручную):
ssh deploy@{ip} 'cd ~/prod/{site}/releases && ls -1tr | head -n -3 | xargs -r rm -rf'

## Если папки нет — создать:
ssh deploy@{ip} 'mkdir -p ~/prod/{site}/releases'

## Если build на runner-е положил пустой deploy/ — посмотри лог build job, обычно
## проблема в том, что output: 'standalone' не включён в next.config.ts.
```

### PM2 не находит server.js в current/

**Симптом:** Шаг `Activate release` падает на `pm2 start current/server.js` с `ENOENT` или `not such file`.

**Причины:**
1. Это первый деплой — `current/` ещё не существует, симлинк надо поставить **до** `pm2 start`. Workflow уже это делает (`ln -sfn` идёт раньше `pm2 start`), но если порядок шагов в кастомизированном workflow поломан — фейл.
2. Standalone-сборка не положила `server.js`: либо `output: 'standalone'` не включён в `next.config.ts`, либо `pnpm build` упал и upload-artifact затащил пустой `deploy/`.
3. Шаг «Pack standalone bundle» в build job не скопировал `.next/standalone/.` в `deploy/` (опечатка в путях).

**Фикс на VPS вручную (если первый деплой):**
```bash
ssh deploy@{ip}
ls -la ~/prod/{site}/current ~/prod/{site}/releases/<sha>/server.js
## Если symlink есть, server.js нет — проблема в build job, не на VPS.
## Если symlink нет — поставь руками и запусти PM2:
ln -sfn ~/prod/{site}/releases/<sha> ~/prod/{site}/current
pm2 start ~/prod/{site}/current/server.js --name {site}-prod --update-env
pm2 save
```

### Workflow logs через gh

Если деплой упал, не лезьте в Actions UI — быстрее:

```bash
gh run list --limit 5
gh run view <run-id> --log
gh run view <run-id> --log-failed   # только упавшие шаги
```

### Branch protection 403 на private + free

**Симптом:** `gh api -X PUT repos/.../branches/main/protection` возвращает `403 Upgrade to GitHub Pro or make this repository public`.

**Причина:** GitHub в 2024+ убрал protection из бесплатного плана для приватных репозиториев. Public repo + free — protection доступна. Private + free — нет.

**Фикс:** для one-dev — пропустить protection, держать дисциплину PR-flow. Альтернативы: GitHub Pro ($4/мес) или сделать репо public. Так настроен `<owner>/<repo>` (см. `.claude/memory/feedback.md`).

### Swap не пересоздаётся при повторном bootstrap

**Симптом:** На VPS уже был `/swapfile` 512 MB (Timeweb default). После `bootstrap-vps.sh` swap остался 512 MB вместо 2 GB.

**Причина:** старая версия скрипта пропускала шаг, если swapfile уже был.

**Фикс:** с v2.2 скрипт сам пересоздаёт swapfile, если размер не совпадает с `SWAP_SIZE`. Если у вас старая версия — вручную:

```bash
ssh root@VPS
swapoff /swapfile
rm /swapfile
## затем перезапустить bootstrap или вручную:
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
```

### Prod отдаёт 404 на новой странице после билда

**Симптом:** на новой странице `curl https://{domain}/uslugi/foo` отдаёт 404, хотя в `app/uslugi/foo/page.tsx` файл есть и в локальном `pnpm build` страница появляется.

**Причины (push-based):**
1. PM2 показывает на старый релиз через симлинк `current` — workflow прошёл, но `Activate release` шаг по какой-то причине не переключил `current`. Проверь `readlink ~/prod/{site}/current` — последний ли это sha?
2. Page-маршрут с динамическим сегментом (`[slug]`) и `generateStaticParams` не вернул нужный slug — он не попал в `.next/server/app/`. Это не VPS-проблема, а билд-проблема.
3. PM2 застрял в crashloop на старте нового релиза и продолжает обслуживать старый код. `pm2 logs {site}-prod --lines 50` покажет.

**Фикс:**
```bash
ssh deploy@{ip}
readlink ~/prod/{site}/current                                  # совпадает с github.sha из последнего workflow?
ls ~/prod/{site}/current/.next/server/app/uslugi/                # есть foo.html?
pm2 reload {site}-prod --update-env                              # форсированный reload
pm2 list                                                         # status: online?
```

Если `current` указывает на свежий sha, а 404 остаётся — проверь `pnpm build` локально и убери проблему на стороне кода / `generateStaticParams`.

### Caddy не стартует / падает после правки

**Симптом:** `systemctl status caddy` показывает `failed`, или сайты возвращают 502 после `systemctl reload caddy`.

**Диагностика:**

```bash
sudo systemctl status caddy --no-pager
sudo journalctl -u caddy -n 50 --no-pager
sudo caddy validate --config /etc/caddy/Caddyfile
```

`caddy validate` покажет точный файл и строку с ошибкой. Типичные причины:
- Опечатка в Caddyfile (забытая `}`, пробел перед `{`, неверная директива).
- Конфликт портов: ещё что-то слушает 80/443 (старый nginx/Apache не выключен после миграции — `sudo systemctl stop nginx; sudo systemctl disable nginx`).
- Caddy не может писать в `/var/lib/caddy/` (проверь `ls -la /var/lib/caddy`, владелец должен быть `caddy:caddy`).

**Фикс:** правишь файл → `sudo caddy validate` → `sudo systemctl reload caddy`. Если сломал не один сайт, а сразу все — последний рабочий конфиг виден в `journalctl -u caddy --since "1 hour ago"`.

### SSL не выписывается (Caddy)

**Симптом:** HTTPS на новом домене возвращает `connection refused` или сертификат self-signed; в логах `obtain: ...`, `solving: HTTP-01 challenge ...`.

**Причины (по частоте):**
1. **DNS не указывает на VPS** — `dig +short {domain}` возвращает чужой IP или ничего. ACME-серверу некуда стучаться. Дождись пропагации или поправь A-запись.
2. **Порт 80 закрыт** — HTTP-01 challenge идёт на 80, не на 443. `sudo ufw status` должен показывать `80/tcp ALLOW`. Без 80 ACME не пройдёт никогда.
3. **Cloudflare proxy включён (оранжевое облачко)** — CF перехватывает `/.well-known/acme-challenge/`. Временно выключи proxy (серое облачко), дождись `certificate obtained`, включи обратно. Альтернатива — DNS-01 через Caddy plugin (отдельная сборка `xcaddy`).
4. **Лимит Let's Encrypt** — 5 неудачных попыток на домен в час, 50 успешных в неделю. Если упёрся — Caddy сам фолбэчит на ZeroSSL (если в Caddyfile не зафиксирован issuer).

**Что обычно НЕ нужно делать:** `sudo systemctl restart caddy`, `caddy reload`. Caddy сам ретраится с экспоненциальным бэкоффом. Рестарт сбрасывает счётчик попыток и может ускорить упирание в лимит.

### Pre-push checklist (Mac)

Перед серьёзным push в main:

```bash
gh auth status                # active = <owner>?
git status                    # working tree clean?
git log origin/main..HEAD     # что именно уезжает?
pnpm lint && pnpm build       # локально билд проходит?
```

### Откат прода

См. `docs/automation.md` → `scripts/rollback.sh`. Кратко:

```bash
scripts/rollback.sh                              # атомарный switch симлинка current → previous
git revert <bad-commit> && git push origin main  # на Mac — починка через Actions
## для merge-коммита: git revert -m 1 <hash>
```

---

## Часть Приложение A. История версий

_Источник: [`_BUILD/changelog.md`](../_BUILD/changelog.md)_

## Changelog

### v3.0 — 2026-04-29 · Multi-Claude handoff protocol + final bootstrap-refactor release

Финальная Phase 6 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Закрывает sequential multi-Claude протокол (одна сессия = одна задача, передача состояния через память), синхронизирует `_BUILD/claude-md-template.md` с актуальным `CLAUDE.md`, обновляет HOW-TO-START под slash-команды и новые секции, ставит тег `v3.0` — конец большого рефакторинга bootstrap'а. Сам bootstrap-репо ничего не билдит — изменения проявятся только в новых проектах из шаблона.

- **Sequential multi-Claude протокол.** Одна Claude-сессия = одна задача (одна спека). Параллельные сессии на ОДНУ папку проекта запрещены — они не видят друг друга и поломают `.claude/memory/project_state.md`. Передача между сессиями — через три новые slash-команды, лежащие в `.claude/commands/` (Claude Code Desktop сканирует папку автоматически, регистрация в `settings.json` не нужна): `/handoff` финализирует сессию (запись в `Session log` файла `project_state.md` с Done/Open/Uncommitted/Resume hint, обновление `Active phase` + `Next steps`, спрашивает про uncommitted-изменения), `/resume` стартует следующую (читает память, сверяет с git-state — uncommitted-изменения + last commits + HEAD sha; при расхождении стопает и просит решения), `/catchup` даёт быструю ориентацию по `git log main..HEAD` + diff stat. В корневой `CLAUDE.md` и в `_BUILD/claude-md-template.md` добавлен раздел `## Multi-Claude protocol` — новые сайты сразу получают правило.
- **Stop-хук как мягкое напоминание.** `.claude/hooks/stop-reminder.sh` срабатывает на Stop-event Claude'а (после каждого ответа). Без фильтра пользователь получал бы спам — поэтому хук сравнивает текущий `git rev-parse HEAD` с зафиксированным на `SessionStart` (запись в `/tmp/.claude-session-start-sha-$PPID`, `$PPID` изолирует параллельные Claude-инстансы). Совпало — silent exit. HEAD сменился — печатает в stderr напоминание про `/handoff`. `.claude/hooks/session-start.sh` дополнен строкой записи sha; `.claude/settings.json` зарегистрировал Stop-хук.
- **Шаблон `_BUILD/claude-md-template.md` пересинхронизирован с `CLAUDE.md`.** До Phase 6 шаблон отставал: в живом `CLAUDE.md` была секция `Automation rules` (session-start, before-push, secrets через `PROD_ENV_FILE` GitHub Environment Secret, симлинк-rollback), а шаблон, который копируется в новые сайты — нет. Теперь `diff CLAUDE.md _BUILD/claude-md-template.md` показывает только различия в header-комментариях (BOOTSTRAP META auto-loader vs инструкция шаблона) и встроенных placeholder-подсказках (Stack default, dev port). Stack-комментарий в шаблоне обновлён на `Дефолт v3.0`.
- **`.claude/memory/project_state.md` структурирован.** Новый формат: `Active phase` / `Active spec` / `Blockers` / `Next 1-3 steps` / `Session log` (заполняется `/handoff`) / `Completed phases history` (или `Completed specs history` для site-проектов). Развёрнутые описания фаз 0–5 переехали в этот changelog как источник истины — в `project_state.md` остались одностроки + ссылки на PR. Файл двойного назначения: для bootstrap-refactor отслеживает фазы; для сайтов после `gh repo create --template` пользователь стирает содержимое и заполняет под свой проект (инструкция в HTML-комментарии в начале файла).
- **`_BUILD/HOW-TO-START.md` финиш.** Phase 5 ранее переписала §§ 8–9 (секреты + откат) под push-deploy; Phase 6 закрывает остаток. §4 «Работа изо дня в день» описывает полный цикл с `/handoff` и упоминает stop-reminder. §5 «Вернуться к уже начатому сайту» — промпт заменён на `/resume`, запасной длинный промпт оставлен на случай ранних версий Claude Desktop без сканирования `.claude/commands/`. §10 (новый) — миграция старого сайта (v2.x) на v3.0 через `_BUILD/v3/02-migrate-existing-project.md`. §11 (новый) — обновление самого bootstrap (для разработчика). «Частые косяки» — добавлены пункты «Claude залип / повторяет круги → /clear → /resume» и «После /resume Claude в другой фазе → поправь project_state.md руками». Шапка — версия v3.0, заметка про `~/Downloads/HOW-TO-START.docx` (синхронизирован с v2.2.1, регенерация через pandoc — post-v3.0 outstanding task).
- **Severity-A финал.** `README.md` H1 v2.3-dx → v3.0, блок «## Версия» переписан под v3.0 (Caddy / push-deploy / standalone / Biome / pnpm-mise / Turnstile / Content Collections / Server Actions / use cache + PPR + OKLCH / multi-Claude). `CLAUDE.md` BOOTSTRAP META: «v2.0 → v2.3.x» → «v2.0 → v3.0», пример semver-тегов «v2.3-dx, v2.4.0» → «v3.0.1, v3.1, v4.0». `docs/INDEX.md` строка про `automation.md` дополнена stop-reminder + slash-командами. В `_BUILD/v3/01-bootstrap-refactor.md` добавлен подраздел «Outstanding после v3.0 (не блокируют тег)» с двумя пунктами: pandoc-регенерация .docx + первый реальный push-deploy на live-VPS (Phase 5 покрыта только письменной верификацией, не обкатывалась).

**8 атомарных коммитов в ветке `feat/v3.0-handoff-protocol`** (от старого к новому): `feat(memory-template)`, `feat(commands)`, `feat(stop-reminder)`, `docs(how-to-start)`, `docs(claude-md-template)`, `docs(claude-md)`, `chore(final-check)`, `chore(memory)` (этот коммит — changelog + project_state финал).

#### Что в итоге в bootstrap v3.0 (vs v2.2.1)

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

#### Breaking changes для проектов на v2.x

- `npm` → `pnpm` (нужен `corepack enable` или `mise use pnpm`)
- `nginx` + `certbot` → `Caddy` на VPS (миграция через `_BUILD/v3/02-migrate-existing-project.md`, раздел «nginx → Caddy»)
- Pull-based deploy (git pull + build на VPS) → push-based (build на runner + rsync артефакта). На VPS больше не нужен Node toolchain.
- Route Handler `app/api/lead/route.ts` → Server Action `app/actions/submit-lead.ts` (миграция точечная — старые проекты на Route Handler продолжают работать).
- ESLint + Prettier → Biome (один конфиг `biome.json`).
- `next-mdx-remote` + `gray-matter` → Content Collections (если в проекте есть MDX-блог).

#### Миграция старых проектов

См. `_BUILD/v3/02-migrate-existing-project.md` — точечная по разделам, можно делать любое подмножество. Не обязательная: старые проекты на v2.x могут оставаться на v2.x неограниченно.

#### Outstanding после v3.0 (не блокируют тег)

- ⏳ Первый реальный push-based деплой на live-VPS — Phase 5 покрыта только письменной верификацией + rollback-планом, не обкатывалась.

#### Done после v3.0

- ✅ Регенерация `_BUILD/HOW-TO-START.docx` под v3.0 (PR #16 + #18: §1.5/§3.5/§4/§10 fixes), команда регенерации зафиксирована в шапке `_BUILD/HOW-TO-START.md`.
- ✅ `_BUILD/HANDBOOK.md` (PR #19) — сборный owner-документ из 6 источников через `scripts/build-handbook.sh`.

### v3.0-deploy — 2026-04-28 · Push-based deploy + standalone + раздельные SSH-ключи

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

### v3.0-next16 — 2026-04-28 · Next.js 16 patterns: Server Actions + use cache + PPR + OKLCH

Фаза 4 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Шаблон обновлён под современные паттерны Next.js 16: формы лидов мигрированы на **Server Actions** (вместо Route Handler `/api/lead`), добавлены опциональные паттерны **`use cache`**, **Partial Prerendering**, **`useOptimistic`** и переход на **OKLCH** в Tailwind v4. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Существующие проекты на Route Handler продолжают работать; миграция точечная (`_BUILD/v3/02-migrate-existing-project.md`, раздел «Server Action вместо `/api/lead`»).

- **Server Actions для лид-форм.** Endpoint `app/api/lead/route.ts` **больше не создаётся** в новых проектах. Лиды идут через Server Action `app/actions/submit-lead.ts` (`'use server'` + `submitLead(prevState, formData)`), та же цепочка шагов (rate-limit → Zod-валидация → Turnstile verify → CRM → fallback в `data/leads.json`), но возвращает типизированный `LeadState = { success: true } | { error: string } | null` вместо `NextResponse.json()`. Клиентская форма — через `useActionState(submitLead, null)` + `<form action={formAction}>`: без `fetch`, без ручного `e.preventDefault()`, `isPending` идёт прямо на `disabled` кнопки. Бонусы: **прогрессивное улучшение** (форма работает даже при выключенном JS — Next отправит multipart/form-data, Server Action отработает на сервере), **CSRF-защита из коробки** (Next добавляет `next-action` header автоматически), **один меньше публичный endpoint** (нет `/api/lead`, который нужно защищать от прямых POST с Postman). `docs/forms-and-crm.md` полностью переписан: ASCII-схема, клиентская часть, бывший раздел «API Route» → «Server Action». `specs/09-forms-crm.md` Goal + секция «API endpoint» → «Server Action», шаги 4–8 переписаны под `useActionState`. `docs/architecture.md` структура папок (`app/actions/` вместо `api/lead/`), раздел SSG упоминает Server Actions для форм. Обновлены `CLAUDE.md`, `_BUILD/claude-md-template.md` (stack-строка форм; шаблон поднят до `v3.0-next16`), `docs/INDEX.md`, `specs/INDEX.md`, `specs/12-handoff.md` (runbook «Лиды не доходят»), `specs/optional/opt-quiz.md` (KB-файл и финальный submit), `.claude/memory/pointers.md` (явная пометка «Endpoint `/api/lead` не существует»).
- **Директива `use cache` для server-функций и компонентов.** В `docs/performance.md` § 7 новый ###-подраздел «Next.js: директива `use cache`» — что это (штатная замена `unstable_cache`/`cache()`, перенесённая в директиву уровня функции), два примера (server-функция `getServicesPricing(region)` и server-компонент `<HeavyServerSection />`), явные критерии когда применять (тяжёлые server-компоненты, fetch к редко-меняющимся API, детерминированные расчёты) и когда **не** применять (per-request state — личный кабинет/корзина/авторизация — будет шарить ответ между пользователями = security-баг; компоненты, читающие `cookies()`/`headers()`/`searchParams` — Next ругается на билде). Заметка про `cacheTag()`/`cacheLife()` для точечной инвалидации и про необходимость флага `experimental.useCache: true` в `next.config.ts` на момент Next.js 16.0. В `specs/05-subpages-template.md` — секция «Опционально: `use cache` для тяжёлых server-компонентов» с примером `ComparisonSection` и явной заметкой не применять для статичных Hero/Steps/FAQ. В `specs/07-blog-optional.md` — callout, что `use cache` поверх Content Collections обычно избыточен (CC уже build-time), нужен только для тяжёлой фильтрации/поиска по тегам.
- **Partial Prerendering (опционально).** В `docs/architecture.md` новый раздел с примером гибридной страницы (статичный hero/description + `<Suspense fallback>` вокруг `<SeatsCounter>` для динамики) и явные критерии где оправдано (лендинги услуг с `live`-счётчиками, A/B-варианты, персонализация по cookie) и где не нужно (полностью статичные страницы → стандартный SSG быстрее; полностью динамические → обычный SSR; динамика ниже первого экрана → проще `dynamic({ ssr: false })` без всей PPR-машинерии). В `specs/02-project-init.md` шаблон `next.config.ts` получил `experimental.ppr: 'incremental'` — это режим opt-in: страницы остаются обычными SSG/ISR, PPR активируется только там, где явно прописан `export const experimental_ppr = true`. Если в проекте PPR не пригодится — флаг можно убрать без последствий. Сам PPR на момент Next.js 16 — `experimental`, поэтому по умолчанию в шаблоне выключен через `incremental`, не `'auto'`.
- **`useOptimistic` как опциональный паттерн.** В `docs/forms-and-crm.md` новый раздел «`useOptimistic` для UX-без-задержки (опционально)» с примером многошагового сценария (квиз). Явная заметка, что **для лид-формы паттерн обычно не нужен** — лид и так считается успешным благодаря fallback в `data/leads.json` (даже при падении CRM пользователь видит «отправлено»), `isPending` из `useActionState` достаточно. `useOptimistic` оправдан там, где есть **осмысленный откат** (toast «не удалось сохранить»), а не как украшательство.
- **OKLCH в Tailwind v4.** В `docs/design-system.md` § «Цветовая палитра» новый ###-подраздел «OKLCH вместо HEX/HSL/RGB» — пример `@theme { --color-primary: oklch(0.45 0.15 250); ... }`, четыре причины почему OKLCH лучше для дизайна (предсказуемое осветление при изменении `L`, плавные градиенты без проседания серого, перцептивно ровные hover-варианты через `color-mix in oklch`, поддержка широких гамм P3/Rec2020 на современных дисплеях). Заметка про ~95% browser support (с лета 2023) и автофоллбек Tailwind v4 в RGB. В `specs/03-design-system.md` шаги 1–3 обновлены: HEX-токены заменены на OKLCH-токены внутри `@theme` (Tailwind v4 не требует `:root` + `tailwind.config.ts` — всё через `@theme` в `globals.css`), HEX из брифа остаётся в комментариях рядом с OKLCH-значением как «source of truth от заказчика», проверка через `bg-primary/90` (`color-mix in oklch`).

5 атомарных коммитов в ветке `feat/v3.0-next16-patterns`: `feat(server-actions)` (Subtask 1+4 — Server Action и `useOptimistic` сделан попутно в том же файле), `feat(use-cache)`, `feat(ppr)`, `feat(oklch)`, `chore(memory)` (changelog + project_state). Сам bootstrap-репо ничего не билдит. Существующие проекты, использующие `/api/lead` Route Handler, продолжают работать; миграция точечная и описана в `_BUILD/v3/02-migrate-existing-project.md`.

### v2.4 — 2026-04-28 · Cloudflare Turnstile + Content Collections

Фаза 3 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Закрыты две функциональные дыры в шаблоне: **антиспам форм** через Cloudflare Turnstile и **типобезопасный MDX-стек** через Content Collections (вместо `next-mdx-remote` + ручного `gray-matter`). Обе правки — в спеках и доке, существующие проекты на старом стеке продолжают работать; миграция точечная (`_BUILD/v3/02-migrate-existing-project.md`).

- **Cloudflare Turnstile в формах.** Бесплатный CAPTCHA-аналог от Cloudflare с invisible-режимом по умолчанию (без VPN-блокировок reCAPTCHA, без вендор-лока на Google). Клиент через официальную обёртку `@marsidev/react-turnstile` (ленивая загрузка скрипта, ref для `reset()` после submit — токен одноразовый, иначе `timeout-or-duplicate` от CF). Сервер проверяет токен на `challenges.cloudflare.com/turnstile/v0/siteverify` (`application/x-www-form-urlencoded`, не JSON) **до** обращения к CRM — иначе при падающей CRM бот успеет насыпать в `data/leads.json`. Site-key (`NEXT_PUBLIC_TURNSTILE_SITE_KEY`) — единственное `NEXT_PUBLIC_` в формах (публичный по дизайну Cloudflare); secret-key (`TURNSTILE_SECRET_KEY`) — только серверный. Если у заказчика уже есть Cloudflare-аккаунт под DNS — Turnstile заводится там же, иначе отдельная регистрация (бесплатно). В `docs/forms-and-crm.md` — новый раздел «Антиспам — Cloudflare Turnstile» с готовым кодом для клиента и сервера, пояснением одноразовости токена и тестовыми ключами для localhost. В `specs/09-forms-crm.md` — отдельная секция «1. Cloudflare Turnstile», шаги установки/env/виджета и Turnstile-edge-кейсы в тестировании. В `docs/stack.md` — `@marsidev/react-turnstile` в вспомогательных пакетах + в init-команду как универсальная form-зависимость. В `specs/02-project-init.md` — `@marsidev/react-turnstile` в дефолтный install шаг 4.
- **Content Collections вместо `next-mdx-remote` + `gray-matter`.** Типобезопасный MDX-стек: Zod-схема в `content-collections.ts` — единая точка истины для frontmatter всех `.mdx` в `content/`. На билде Content Collections парсит, валидирует, компилирует и кладёт в `.content-collections/generated`. В коде — `import { allPosts } from 'content-collections'` (типизированный массив, IDE-автокомплит). Опечатка в `@type` или невалидный `date` — TypeScript-ошибка / понятный лог на билде, не runtime-500. Спека `specs/07-blog-optional.md` полностью переписана: установка (`content-collections @content-collections/core @content-collections/mdx @content-collections/next` + `@tailwindcss/typography`), `withContentCollections(nextConfig)`, `tsconfig.json paths` алиас, Zod-схема с draft-полями и `readingTime` в transform, `generateStaticParams` через `allPosts.filter(p => !p.draft)`, рендер через `<MDXContent code={post.mdx} />`. Добавлена сравнительная таблица «next-mdx-remote vs Content Collections». В `docs/architecture.md` — раздел «MDX через Content Collections» переписан, в схему папок добавлены `content-collections.ts` (root) и `.content-collections/` (gitignored). В `docs/stack.md` — MDX-row обновлён, в вспомогательных пакетах строка про CC + плагины. CC ставится **опционально** в spec/07 (только если в `docs/pages.md` запланирован блог) — поэтому из дефолтного init в `docs/stack.md` и `specs/02-project-init.md` пакеты CC убраны вместе со старыми `next-mdx-remote gray-matter`. В `.claude/memory/pointers.md` — новый раздел «Контент (MDX через Content Collections)».

3 атомарных коммита в ветке `feat/v2.4-turnstile-content-collections`: `feat(turnstile)`, `feat(content-collections)`, `chore(memory)`. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Для существующих проектов на `next-mdx-remote` шаги миграции — в `_BUILD/v3/02-migrate-existing-project.md` (раздел «next-mdx-remote → Content Collections»).

### v2.3-dx — 2026-04-28 · DX win: Biome, pnpm, mise, schema-dts

Фаза 2 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Четыре локальных DX-замены тулинга на Mac разработчика, без архитектурных изменений в рантайме сайтов. Каждый пункт по отдельности — мелкая правка; вместе они дают ощутимый ежедневный win: один линтер вместо двух, единый менеджер версий, экономия диска при multi-site, типобезопасный JSON-LD.

- **Biome вместо ESLint+Prettier.** Один бинарник, один конфиг, ~10× быстрее на типичном Next-проекте. Tailwind-классы сортируются встроенным правилом `useSortedClasses` (с распознаванием `clsx`/`cva`/`cn`/`tw`) — `prettier-plugin-tailwindcss` убран. `package.json scripts` теперь: `lint: biome check`, `format: biome check --write`, `typecheck: tsc --noEmit` (отдельно, потому что Biome не делает type-checking). В корне bootstrap'а появился `biome.json.example` (linter+a11y recommended, lineWidth 100, single quotes, no semicolons). Хук `.claude/hooks/format.sh` переключён с Prettier на Biome. Установка в `specs/02`: `pnpm add -D --save-exact @biomejs/biome && pnpm exec biome init`. Флаг `--no-eslint` добавлен в `create-next-app` — иначе он по умолчанию ставит ESLint, который мы тут же удаляем.
- **pnpm вместо npm.** Hardlinks вместо копирования при multi-site дают экономию диска на VPS (5–10 сайтов на одном VPS — типичный сценарий, см. `docs/server-multisite.md`). Полный sweep по spec'ам, доке и хелперам: `npm install` → `pnpm add`, `npm install -D` → `pnpm add -D`, `npm ci` → `pnpm install --frozen-lockfile`, `npm run X` → `pnpm X`, `package-lock.json` → `pnpm-lock.yaml`. На VPS pnpm активируется через `corepack` (идёт в комплекте с Node 16.13+) — отдельный apt-пакет не нужен. PM2 на VPS теперь ставится через `pnpm add -g` для консистентности. На Mac в `_BUILD/HOW-TO-START.md` тоже `corepack enable && corepack prepare pnpm@latest --activate` — а после Phase 2 это делает уже mise (см. ниже). `scripts/rollback.sh` обновлён.
- **mise вместо nvm.** Единый version manager для всего тулинга проекта (Node, pnpm, при необходимости Python/Go и т.д.). Читает `.tool-versions` автоматически на `cd` в папку — никакого ручного `nvm use`. В корне bootstrap'а появился пример `.tool-versions` (`node 22` + `pnpm latest`). `_BUILD/HOW-TO-START.md` § 0.4 переписан: `brew install gh mise` + `eval "$(mise activate zsh)"` в zshrc + `mise use --global node@22 pnpm@latest`. `specs/01a-local-setup.md` переключён с `.nvmrc` на `.tool-versions`; toolchain-проверка теперь `pnpm -v ≥ 9` вместо `npm -v`. `docs/team-onboarding.md` инструкция установки — `mise install && pnpm install`.
- **schema-dts для типобезопасного JSON-LD.** Типы Schema.org от Google. В `lib/schema.ts` функции теперь возвращают `WithContext<Service>`, `WithContext<BreadcrumbList>`, `WithContext<FAQPage>`, `WithContext<Organization>`, `WithContext<Article>` и т.д. Опечатка в `@type` или поле — TypeScript-ошибка на билде (`tsc --noEmit`), а не «странный warning в Yandex Validator уже на проде». Добавлен в `docs/stack.md` (helpers), в `specs/02` install (`pnpm add -D schema-dts`), в примеры `lib/schema.ts` в `specs/05` (Service/BreadcrumbList/FAQPage) и `specs/08` (Organization/LocalBusiness/Article).
- **Severity-A sweep по стек-строкам.** `CLAUDE.md` Stack-секция, `_BUILD/claude-md-template.md` (тот, что копируется в новые проекты), `README.md` H1 + Версия + Требования — все обновлены под v2.3-dx. `pnpm dev`/`pnpm build` теперь видны в Commands при старте каждой Claude-сессии, иначе модель работала бы по устаревшему `npm run`-стеку. README поднят с v2.2.2 до v2.3-dx (Phase 1 Caddy не обновил его — закрыли вместе).

8 атомарных коммитов в ветке `feat/v2.3-dx-biome-pnpm-mise`. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Существующие проекты, уже сидящие на ESLint+Prettier+npm+nvm, продолжают работать; миграция точечная (см. `_BUILD/v3/02-migrate-existing-project.md`, который покрывает в том числе nvm → mise).

### v2.3-caddy — 2026-04-28 · Caddy вместо nginx+certbot

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

### v2.2.2 — 2026-04-28 · P0 hotfix bundle

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

### v2.2.1 — 2026-04-27 · HOW-TO-START clarity pass

Доводка инструкции после первой эксплуатации — стало понятнее для тех, кто видит её впервые (а не только для меня).

- **Новый §0.0 «Аккаунт на GitHub».** Что делать если аккаунта ещё нет, как узнать свой логин, чёткий словарик плейсхолдеров (`<твой-логин>`, `<твой-email>`, `{site}`) и правило «угловые/фигурные скобки заменяешь целиком, двойные кавычки — оставляешь».
- **§0.4** — пример успешного вывода `node --version` с пометкой «нужно v22 или новее, иначе `brew upgrade node`».
- **§0.5 (Git identity)** и **§0.6 (SSH-ключ)** перестроены на пару «шаблон + пример». Email теперь личный (раньше был placeholder `твой-email@example.com`, легко принять за инструкцию).
- **§0.7** — пример успешного `gh auth status`, чтобы не путать с ошибкой.
- **§1 (gh repo create)** — явное пояснение про два разных GitHub-имени в команде («первое имя — куда положить, второе — откуда взять, не перепутай»). Конкретный пример с `tem11134v2/migrator`. Блок «что произойдёт» после команды.
- **§2** — заметка про разовый macOS-промпт «Claude wants access to folder».
- **§9** — пояснение что такое `<hash>` (короткий идентификатор коммита, видно в `git log` или в URL).

`.docx` перегенерирован, ZIP-целостность валидна. Контент: 1×H1, 13×H2, 10×H3.

### v2.2 — 2026-04-26 · Automation layer

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

### v2.1.3 — 2026-04-24 · Handoff and migration playbooks

Закрыли белое пятно: что делать когда сайт передаётся заказчику или переезжает на другой VPS. Спеки `12-handoff` и новая `14-migrate` покрывают все сценарии, которые Timur использует на практике.

- **`specs/12-handoff.md` переписан под три модели handoff'а:** H1 (full transfer — дефолт), H2 (client-owned, dev operates), H3 (read-only). HANDOFF.md-шаблон теперь содержит runbook + monthly maintenance + инструкцию по самостоятельному отзыву прав разработчика.
- **Новая `specs/14-migrate.md`** с четырьмя сценариями: M1 (scaling), M2 (handoff), M3 (emergency), M4 (clone to new domain). Scp runtime-данных, DNS switch, **7-day soak** перед decommission.
- **Зафиксированы дефолтные правила:**
  - `data/leads.json` — fallback, не источник истины (источник — CRM).
  - 7 дней между DNS switch и выключением старого VPS.
  - Single-Claude модель — мульти-разработчик не поддерживается; при handoff'е Claude заказчика заменяет Claude разработчика, а не идёт параллельно.
- `specs/INDEX.md` — спека `14-migrate` добавлена в основной поток (опциональная, после 12 или между 10/11 при масштабировании).

### v2.1.2 — 2026-04-24 · Security hardening pass

Добавили разумные дефолты поверх базового bootstrap. Применены и проверены на том же Timeweb VPS.

- **Non-standard SSH port (default 2222).** Параметризуемо через `SSH_PORT`. Критичный нюанс Ubuntu 22.04+: надо `systemctl disable ssh.socket && systemctl enable ssh.service` — иначе socket activation игнорирует `Port` из `sshd_config`.
- **fail2ban строже:** 3 попытки / 10 минут / бан 24 часа. `backend=systemd` (на Ubuntu 24.04 auth-логи идут в journald, не в `/var/log/auth.log`).
- **unattended-upgrades.** Security patches применяются автоматически ежедневно, без auto-reboot. Ставит `apt-listchanges` для журнала изменений.
- **Mac-side `~/.ssh/config`** с алиасом `vps1` — `ssh deploy@IP` работает без `-p 2222`. Инструкция в `docs/server-manual-setup.md`.

### v2.1.1 — 2026-04-24 · Claude-driven server bootstrap

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

### v2.1.0 — 2026-04-24 · Desktop-first workflow

**Что это.** Переход с серверной разработки (Claude Code внутри VPS через SSH) на **локальную десктопную**: Claude Desktop на Mac → `git push` в GitHub → GitHub Actions катит на VPS. Сервер разработчик настраивает руками по чек-листам — Claude в эти операции не лезет.

**Почему.** Десктопная модель убирает риски автономного изменения сервера, сокращает цикл правки (локальный hot-reload быстрее SSH+билд), и лучше подходит к кейсу «один разработчик ведёт несколько проектов».

#### Ключевые изменения v2.0 → v2.1

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

#### Breaking changes v2.0 → v2.1

1. **Нельзя работать в `main` напрямую.** Всегда через ветку `dev` + PR. Старые проекты с разработкой на `main` нужно перевести — настроить protected branch и переключить workflow.
2. **Dev-сервер на Mac, не на VPS.** Если раньше запускали `npm run dev` по SSH — теперь локально. VPS только для prod (+ опционального dev-preview).
3. **Нет больше схемы A.** Проекты «dev=prod на одном VPS, без GitHub» больше не поддерживаются как отдельная ветвь. Для одиночных проектов всё равно ставим GitHub — это цена консистентности и безопасности.
4. **`next.config.ts` без standalone.** Если где-то в проекте закодирован `output: 'standalone'` — убрать. PM2 запускает `next start`, standalone лишний.
5. **Спека 01 переименована.** Промпты «run spec 01-infrastructure» нужно заменить на «run spec 01a-local-setup» (или `01b-server-handoff`).

---

### v2.0.0 — 2026-04-13 · Major restructure

**Что это.** Полная переработка bootstrap-промпта. Раньше был один файл `web-dev-bootstrap.md` на 2128 строк — теперь папка с `docs/` (KB) + `specs/` (последовательность задач) + `CLAUDE.md` (вход) + `.claude/memory/` (проектная память).

**Почему разбили.** Один большой `.md` съедал контекст Claude при любой задаче. В v2.0 Claude читает только то, что нужно для текущей спеки — через `docs/INDEX.md`. Поддержка проще: правка одного модуля не требует перетряхивать весь файл.

#### Что переехало v1.7 → v2.0

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

#### Новое в v2.0

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

#### Выброшенные дубли

Зафиксированы единые источники истины (см. `docs/INDEX.md` раздел «Источник истины»):

- `console.log` удалить — только в `performance.md § 4`
- WCAG AA контраст — только в `performance.md § 11`
- Lighthouse 90+ / PSI методика — только в `performance.md § 13`
- «Вирусный client» антипаттерн — короткая заметка в `architecture.md`, развёрнуто в `performance.md § 13.4`
- nginx-шаблон — только в `deploy-server-setup.md`
- Cookie-баннер / согласие на ПДн — только в `legal-templates.md`

#### Breaking changes для тех, кто работал по v1.7

1. **Вместо одного `.md` — папка.** Старая схема «скопировал файл в проект → работаем» больше не работает. Нужна вся структура `docs/` + `specs/` + `CLAUDE.md` + `.claude/memory/`.
2. **Новый вход.** Раньше Claude читал `web-dev-bootstrap.md` целиком. Теперь вход — `CLAUDE.md` в корне, дальше `docs/INDEX.md` и спеки по требованию. Старые промпты типа «прочитай bootstrap» нужно заменить на «прочитай `CLAUDE.md` и `specs/INDEX.md`, начни со спеки `00-brief`».
3. **Деплой.** Если работали по v1.7 и использовали «папки dev + prod + GitHub Actions» — это теперь схема B (`docs/deploy.md` + `docs/deploy-server-setup.md`). Всё ещё поддерживается. Если деплой другой (solo dev=prod) — появилась схема A, переключаться не обязательно.
4. **Cookie-banner / 152-ФЗ стали обязательны** в `specs/09-forms-crm.md`. Если сайт работал без них по v1.7 — при следующем расширении (спека 13) добавь по `docs/legal-templates.md`.
5. **Workflow-дисциплина усилилась.** `CLAUDE.md` теперь явно требует plan mode перед кодом и обновление `.claude/memory/` по триггерам. В v1.7 это было «рекомендацией».

#### v1.7 и ниже

Полной истории не ведём — предыдущая версия жила в одном файле. Архив старого `web-dev-bootstrap.md` остался локально у автора. В v2.0 миграция «один файл → структура» считается нулевой точкой.

---


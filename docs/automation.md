# Automation layer

Что Claude Code делает за вас автоматически — и как это отключить, если мешает.

## Требования и принципы

- **jq обязателен.** Guard-хуки (`guard-rm.sh`, `before-push.sh`, `subagent-stop.sh`) без jq работают **fail-closed**: блокируют любую команду с сообщением «guard disabled: install jq». Это осознанно: сломанный guard не должен молча пропускать всё. Установка: `winget install jqlang.jq` / `brew install jq`.
- **Windows-совместимость.** В `settings.json` все хуки зовутся явно через `bash "$CLAUDE_PROJECT_DIR/.claude/hooks/x.sh"` — голый путь `.claude/hooks/x.sh` на Windows уходит в cmd.exe и не исполняется. Скрипты хуков должны быть с LF-переводами строк.
- **Matcher `Bash|PowerShell`.** PreToolUse-хуки перехватывают команды обоих тулов — деструктивные команды PowerShell (`Remove-Item -Recurse -Force`) без этого шли мимо guard-ов.
- **Состояние — в `.claude/state/`** (gitignored), не в `/tmp`: на Windows `/tmp` git-bash-а живёт своей жизнью, а файлы на `session_id` изолируют параллельные сессии.

## Кто что видит (важно — не путать каналы)

| Хук | Канал | Кто видит |
|---|---|---|
| SessionStart, stdout, exit 0 | попадает в контекст сессии | Claude |
| PreToolUse, stderr, exit 2 | команда блокируется, текст возвращается Claude | Claude (и реагирует) |
| Stop, JSON `{"systemMessage": "..."}` в stdout | показывается в UI | человек |
| Любой хук, stderr при exit 0 | **никто** | — |

Из этого следствие: информационные предупреждения SessionStart печатаются в **stdout**; напоминание Stop-хука — только через `systemMessage`. Утверждение «stderr виден как system-reminder» из прошлых версий — неправда.

## Разрешения (`permissions.deny`)

В `settings.json` запрещено чтение env-файлов с секретами:

```json
"deny": ["Read(./.env)", "Read(./.env.local)", "Read(./.env.development)",
         "Read(./.env.production)", "Read(./.env.*.local)"]
```

Паттерны перечислены явно, а не глобом `Read(./.env.*)` — глоб зацепил бы и `.env.example`, который читать как раз нужно (в нём имена переменных без значений).

## Хуки (`.claude/hooks/`)

### `session-start.sh` — SessionStart

Один раз при старте чата. Информирует, не блокирует (всегда `exit 0`), весь вывод — в stdout.

1. Пишет текущий HEAD в `.claude/state/session-start-sha-<session_id>` (session_id — из stdin-JSON хука; без jq — fallback на `$PPID`). По нему stop-reminder ловит коммиты сессии.
2. `git fetch origin` — под `timeout 10` и с `GIT_TERMINAL_PROMPT=0`: за прокси или без сети старт сессии не виснет. Если ветка отстала — «Branch X is behind Y by N commit(s). Suggest: git pull».
3. Uncommitted changes — перечисляет.
4. Активный gh-аккаунт vs владелец origin — при mismatch подсказывает `gh auth switch`.

### `guard-rm.sh` — PreToolUse (Bash|PowerShell)

Блокирует деструктивные команды (`exit 2`). Кавычки в команде снимаются до матчинга, флаги ловятся в любом порядке и форме (`-rf`, `-fr`, `-f -r`, `--recursive --force`):

- `rm` по опасной цели: `/`, `/*`, `~`, `$HOME` (в т.ч. в кавычках), `*`, `./*`
- `git push --force` и `-f` (в т.ч. в связке флагов), `git push origin +main` (+refspec). **`--force-with-lease` разрешён** — это безопасная альтернатива
- `git clean -fd`/`-fdx`, `git reset --hard`, `git checkout -- .`, `find ... -delete`
- PowerShell: `Remove-Item -Recurse -Force` (и алиасы `rm`/`ri` с этими флагами), `rd /s`, `Clear-Content` на `.env`

### `before-push.sh` — PreToolUse (Bash|PowerShell)

Срабатывает на `git push`, `gh pr <verb>`, `gh repo <verb>`:

1. **gh-аккаунт vs владелец remote** — при mismatch блок с подсказкой `gh auth switch -h github.com -u <owner>`. Страховка от push не в тот аккаунт при нескольких gh-логинах.
2. **Гейт перед `git push`**: если в `package.json` есть скрипт `typecheck` — прогоняет `pnpm typecheck` (и `pnpm lint`, если есть), при провале блокирует push и показывает хвост ошибок. Обход осознанно: `SKIP_PUSH_GATE=1 git push ...` (хук ищет `SKIP_PUSH_GATE=1` в тексте команды и в окружении). В `settings.json` у хука `timeout: 300` — typecheck бывает небыстрым.

**Ограничение:** PreToolUse перехватывает только команды Claude в сессии. Ваш `git push` в обычном терминале идёт мимо. Полную защиту даёт branch protection (недоступна на private + free плане, см. `docs/troubleshooting.md`).

### `subagent-stop.sh` — SubagentStop

Гейт оркестраторного режима (`docs/orchestration.md` § Гейты): срабатывает, когда субагент завершает работу. Если в корне проекта есть `package.json` со скриптом `typecheck` — прогоняет `pnpm typecheck` (и `pnpm lint`, если скрипт есть); провал → блок (`exit 2`) с хвостом ошибок — субагент чинит их до передачи отчёта оркестратору. Нет `package.json` или `pnpm` — тихий `exit 0` (bootstrap-репо, не-Node проект). Обход осознанно: `SKIP_SUBAGENT_GATE=1`. В `settings.json` у хука `timeout: 300`. Работает и в интерактиве — вне оркестрации субагентов просто нет, хук молчит.

### `format.sh` — PostToolUse (Edit|Write|MultiEdit)

`biome check --write` на изменённый `.ts/.tsx/.js/.jsx/.mjs/.cjs/.json/.md/.mdx/.css`. Молча. Нет Biome или jq — пропускает (информационный хук, fail-closed не нужен).

### `stop-reminder.sh` — Stop

После **каждого** ответа Claude. Сравнивает HEAD с зафиксированным в `.claude/state/session-start-sha-<session_id>`:

- Совпало → тишина (коммитов не было).
- HEAD сдвинулся → `{"systemMessage": "В этой сессии были коммиты (a1b2c3 → d4e5f6). Если уходишь надолго — /handoff..."}` — человек видит это в UI.

Никогда не блокирует.

### `test-hooks.sh` — штатная проверка «обвязка жива»

Не хук, а smoke-тест обвязки: `bash .claude/hooks/test-hooks.sh`. Подаёт фикстурные JSON (опасные и безопасные команды, Bash и PowerShell) на stdin каждого хука и сверяет exit-коды; в конце сводка PASS/FAIL. Без jq ожидает fail-closed exit 2 от guard-хуков и помечает это PASS с предупреждением. Гонять: после правки хуков, на свежей машине, при подозрении «хуки молчат».

## Slash-команды (`.claude/commands/`)

В отличие от хуков, slash-команды вызывает **пользователь** — это .md-инструкции, Claude Code подхватывает их в auto-complete по `/`.

| Команда | Когда | Что делает |
|---|---|---|
| **`/resume`** | В начале новой сессии | Читает память, сверяет с git, проверяет осиротевшие worktree/ветки `claude/*`, резюмирует — и ждёт ОК. При расхождении памяти и git — стоп. |
| **`/handoff`** | В конце сессии | Пишет запись в Session log `project_state.md` (для оркестраторных сессий — в формате task ledger), обновляет Active phase / Next steps, спрашивает про uncommitted. |
| **`/catchup`** | После долгого перерыва | Копает `git log` глубже, сравнивает с памятью. Полезно после параллельной работы других. |
| **`/orchestrate`** | Крупный пласт: сайт целиком, rollout, recreate | План волны, батч-вопрос человеку, брифы субагентам, ledger. Правила — `docs/orchestration.md`. |

Sha сессии команды берут из `.claude/state/session-start-sha-*` (свежайший по mtime). Stop-reminder мягко подталкивает к `/handoff`, если были коммиты.

## Скрипты (`scripts/`)

Bash-утилиты, запускаются руками или по команде. Все: `set -euo pipefail`, идемпотентны, подтверждение `[y/N]` на всё чувствительное.

### `scripts/sync-env.sh [site] [ssh_alias]` — fallback

Штатно `.env` на VPS пишет GitHub Actions из Environment-секрета `PROD_ENV_FILE`. Скрипт нужен только когда: (1) Actions недоступны, а сайт лежит; (2) env поменялся mid-cycle и ждать push нельзя; (3) recovery после ручных правок на VPS. Делает scp `~/projects/{site}/.env.production` → `current/.env`, `chmod 600`, `pm2 restart {site}-prod --update-env`. Следующий push в main перезапишет значение из секрета — скрипт об этом предупреждает.

### `scripts/fetch-env.sh [site] [ssh_alias]` — для свежего устройства

Обратное зеркало: тянет активный `.env` с VPS в локальный `.env.production` (VPS — единственная актуальная plain-text копия: GitHub Secrets обратно не читаются, `.env.production` gitignored). Бэкапит существующий файл, `chmod 600`, в финале печатает только **имена** переменных.

### `scripts/rollback.sh [site] [ssh_alias] [port]`

Реализация отката прода (основное описание — `docs/deploy.md` § «Откат прода»): атомарный switch симлинка `current` на предыдущий релиз (с проверкой `server.js` в нём), затем `pm2 delete {site}-prod` + `PORT={port} HOSTNAME=127.0.0.1 pm2 start current/server.js` + `pm2 save` + healthcheck. Секунды, без build. Порт — третьим аргументом или `PROD_PORT=...`; без него скрипт останавливается с подсказкой, где порт взять (`~/ports.md` на VPS, repo variable `PROD_PORT`, `references.md`). После отката обязательно `git revert <bad-commit> && git push` — иначе следующий деплой вернёт сломанный код.

**Правило перезапуска PM2 — не путать два случая:**

- **Сменился симлинк `current`** (деплой, rollback) → **только** `pm2 delete` + `pm2 start`: `restart`/`reload` кэширует resolved-путь симлинка и продолжает крутить старый релиз.
- **Симлинк не менялся, патчился только env** (`sync-env.sh`) → достаточно `pm2 restart {site}-prod --update-env`; просто `restart` без `--update-env` env не перечитает.

### `scripts/bootstrap-vps.sh`

Разовая настройка свежего Ubuntu VPS. См. `docs/server-manual-setup.md`.

## Как локально отключить хук

Убрать регистрацию из `.claude/settings.json` (локально, не коммитить). Учтите: хуки из `settings.local.json` **добавляются** к хукам из `settings.json`, а не заменяют их — «переопределить» хук локальным файлом нельзя. `chmod -x` тоже не поможет: хуки зовутся через `bash file.sh`, exec-бит не проверяется.

## Как добавить новый хук

1. Положите `.sh` в `.claude/hooks/` (LF, не CRLF).
2. Зарегистрируйте в `.claude/settings.json`: команда — через `bash "$CLAUDE_PROJECT_DIR/..."`, для командных перехватов matcher `Bash|PowerShell`.
3. Guard-хук → jq fail-closed (`exit 2` без jq); информационный → молчаливый пропуск и `exit 0` всегда.
4. Помните про каналы видимости (таблица выше) — stderr при exit 0 не видит никто.
5. `bash -n` для синтаксиса, кейсы — в `test-hooks.sh`, прогнать его целиком.
6. Документируйте здесь.

См. также: `docs/troubleshooting.md` про gh auth mismatch и другие частые косяки.

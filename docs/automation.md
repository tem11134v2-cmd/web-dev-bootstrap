# Automation layer

Что Claude Code делает за вас автоматически — и как это отключить, если мешает.

## Хуки (`.claude/hooks/`)

Хуки — shell-скрипты, которые Claude Code вызывает в определённые моменты сессии. Регистрируются в `.claude/settings.json`. Все четыре хука идемпотентны и быстры (< 1 c).

### `session-start.sh` — SessionStart

Запускается один раз при старте каждого нового чата. Информирует, **не блокирует** (всегда `exit 0`).

Проверяет:

1. `git fetch origin` → если ветка отстаёт от upstream на N коммитов, печатает «Branch X is behind Y by N commit(s). Suggest: git pull».
2. `git status --porcelain` → если есть uncommitted changes, перечисляет их.
3. `gh api user --jq .login` vs owner из `git remote get-url origin` → mismatch = warning «Push will fail. Switch: gh auth switch -h github.com -u <owner>».

Вывод идёт в stderr с префиксом `[session-start hook]` — Claude видит как system-reminder и автоматически реагирует.

### `before-push.sh` — PreToolUse (matcher: Bash)

Запускается перед каждой Bash-командой. Если команда — это `git push`, `gh pr <verb>` или `gh repo <verb>`, проверяет: совпадает ли активный gh-аккаунт с владельцем remote-а. При mismatch — `exit 2` с сообщением, push блокируется.

Зачем: на Mac бывает залогинено несколько gh-аккаунтов одновременно (`alice`, `bob`). Без хука легко случайно push-нуть в чужой репо или получить отказ от GitHub без понятной причины.

**Ограничение (важно):** `PreToolUse` хук перехватывает **только то, что Claude делает через Bash-tool** в активной сессии. Прямой `git push` пользователя в обычном терминале — мимо хука. Это страховка от ошибок Claude, **не** immutable защита репо. Полную защиту даёт branch protection, но она недоступна на private + free GitHub плане (см. `docs/troubleshooting.md`).

### `guard-rm.sh` — PreToolUse (matcher: Bash)

Блокирует деструктивные команды:
- `rm -rf /`, `rm -rf ~`, `rm -rf $HOME`, `rm -rf *`
- `git push --force` (любой)

### `format.sh` — PostToolUse (matcher: Edit|Write|MultiEdit)

Запускает `biome check --write` на каждый изменённый `.ts/.tsx/.js/.jsx/.mjs/.cjs/.json/.md/.mdx/.css` файл. Молча, без вывода. Если Biome не установлен (нет `node_modules/.bin/biome`) — пропускает.

## Скрипты (`scripts/`)

Скрипты — bash-утилиты, которые Claude (или вы) запускаете руками или по команде. Все: `set -euo pipefail`, идемпотентны, требуют подтверждения для деструктивных операций.

### `scripts/sync-env.sh [site] [ssh_alias]` — **fallback**

В штатном flow `.env` на VPS пишет сам GitHub Actions workflow на каждом деплое — берёт содержимое из Environment-секрета `PROD_ENV_FILE` и кладёт в `releases/<sha>/.env` рядом с standalone-сборкой. Менять секреты — через `gh secret set --env production PROD_ENV_FILE < ~/projects/{site}/.env.production` или GitHub UI.

`sync-env.sh` нужен только в трёх ситуациях:
1. **Actions недоступны** (GitHub outage, сеть режет коннект к runners) — а сайт лежит, и надо подкинуть env прямо сейчас.
2. **Env поменялся mid-cycle**, ждать следующего push в main не хочется — патчим текущий релиз руками, потом всё равно обновляем `PROD_ENV_FILE` секрет (иначе следующий деплой откатит правку).
3. **Recovery после ручных правок на VPS** — выровнять env по локальному `.env.production` как источнику истины.

Скрипт делает: scp `~/projects/{site}/.env.production` → `/home/deploy/prod/{site}/current/.env` (через симлинк, попадает в активный `releases/<sha>/.env`), `chmod 600`, `pm2 reload {site}-prod --update-env`. По дефолту site берётся из `package.json#name`, ssh_alias — `${site}` (т.е. в `~/.ssh/config` нужен `Host {site}`).

Спрашивает подтверждение `[y/N]` перед scp. Сразу предупреждает, что следующий push в main перезапишет значение из `PROD_ENV_FILE` секрета.

### `scripts/rollback.sh [site] [ssh_alias]`

Откатывает прод на VPS на **предыдущий релиз** через атомарный switch симлинка `current → releases/<previous-sha>` + `pm2 reload`. Никакого git fetch, никакого pnpm install, никакого build — миллисекунды.

Скрипт сам находит предыдущий sha (последний по mtime в `releases/`, исключая текущий) и переключает симлинк. Если в `releases/` лежит только один релиз — отказывается, отката нет.

Спрашивает подтверждение `[y/N]`. Это **не** деструктивная операция (старые папки релизов остаются на месте, чистит их workflow по правилу last-5/last-3), но трогает прод-трафик — поэтому подтверждение обязательно.

**После rollback** — обязательно на Mac: `git revert <bad-commit> && git push origin main`. Иначе следующий push в main соберёт и rsync-нет тот же сломанный коммит поверх отката.

### `scripts/bootstrap-vps.sh`

Разовая настройка свежего Ubuntu VPS. См. `docs/server-manual-setup.md`. С v2.2 умеет пересоздавать swapfile, если его размер не совпадает с `SWAP_SIZE` (по дефолту 2G).

## Как локально отключить хук

Если хук мешает (отлаживаете что-то, нужно push-нуть в обход):

```bash
chmod -x .claude/hooks/before-push.sh
# или удалить из .claude/settings.json и закоммитить .claude/settings.local.json (gitignored)
```

После — не забудьте вернуть `chmod +x` обратно.

`session-start.sh` отключить можно так же. Имеет смысл если работаете offline и `git fetch` подвисает.

## Как добавить новый хук

1. Положите `.sh` в `.claude/hooks/`, `chmod +x`.
2. Зарегистрируйте в `.claude/settings.json` под нужным trigger (`SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `Notification`).
3. Для `PreToolUse` — обязательно `set -uo pipefail` и `exit 0` по умолчанию (не блокировать без причины).
4. `bash -n` для синтаксической проверки. `shellcheck` если установлен.
5. Документируйте здесь.

См. также: `docs/troubleshooting.md` про gh auth mismatch и другие частые косяки.

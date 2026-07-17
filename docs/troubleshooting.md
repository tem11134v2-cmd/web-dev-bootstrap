# Troubleshooting

Частые косяки и способы их решения. Источник — реальные инциденты проекта (`.claude/memory/lessons.md`).

## gh auth mismatch — push блокируется хуком

**Симптом:** `BLOCKED by before-push: gh account mismatch` — активный gh-аккаунт не совпадает с владельцем origin.

**Причина:** на Mac залогинено несколько gh-аккаунтов одновременно. Активным может быть «не тот».

**Фикс:** `gh auth status` (посмотреть кто Active) → `gh auth switch -h github.com -u <owner>`. После — повторить `git push`. Если push без хука уже прошёл и попал в чужой репо — связаться с владельцем чужого репо и попросить закрыть PR / удалить ветку.

## Любая команда блокируется с «guard disabled: install jq»

**Симптом:** каждая Bash/PowerShell-команда Claude падает с сообщением вида `guard-rm: guard disabled: install jq (fail-closed — команда заблокирована)`.

**Причина:** guard-хуки (`guard-rm.sh`, `before-push.sh`, `subagent-stop.sh`) без jq работают **fail-closed** — сломанный guard не должен молча пропускать всё (см. `docs/automation.md`).

**Фикс:** установить jq и продолжить работу: `winget install jqlang.jq` (Windows) / `brew install jq` (macOS).

## `\r: command not found` в .sh-хуках

**Симптом:** хук падает с `$'\r': command not found` или `syntax error near unexpected token` на валидной строке.

**Причина:** файл хука сохранён с CRLF-переводами строк (Windows-редактор, git-настройка `autocrlf`). bash понимает только LF.

**Фикс:** переконвертировать в LF (`dos2unix .claude/hooks/*.sh`, либо в редакторе «LF» в статус-баре) и закрепить в `.gitattributes`: `*.sh text eol=lf`. После — `bash .claude/hooks/test-hooks.sh` для проверки обвязки.

## DDoS-Guard 301 при smoke-тесте до DNS cutover

> Узкопроектный пример (миграция с Tilda, сидящей за DDoS-Guard). Оставлен как иллюстрация класса проблем «middlebox вмешивается в трафик по Host-header».

**Симптом:** `curl -H "Host: example.com" http://NEW_VPS_IP/` возвращает `301` от `Server: ddos-guard` с заголовком `x-tilda-server: 29`.

**Причина:** A-запись домена ещё указывает на старый IP (Tilda → DDoS-Guard). Middlebox (РКН/ISP) видит Host-header и перенаправляет на DDoS-Guard, **даже если TCP идёт на нужный IP**.

**Фикс:** не использовать доменное имя в Host-header до cutover:

```bash
curl -H "Host: NEW_VPS_IP" http://NEW_VPS_IP/    # ok: IP-only
# либо /etc/hosts override (откатить после теста):
echo "NEW_VPS_IP example.com" | sudo tee -a /etc/hosts && curl -I https://example.com/
```

## SSH permission denied в deploy job

**Симптом:** Actions падает на шаге `Setup SSH` или `Upload and unpack release` с `Permission denied (publickey)` от VPS.

**Причина (любая из):** public-часть `~/.ssh/{site}-deploy.pub` не добавлена в `/home/deploy/.ssh/authorized_keys` на VPS; в `secrets.SSH_PRIVATE_KEY` лежит другой ключ (не парный); `SSH_USER` не `deploy` или `SSH_PORT` не совпадает с реальным портом sshd; `SSH_HOST` показывает на старый IP (после миграции).

**Фикс:**

```bash
ssh-keygen -y -f ~/.ssh/{site}-deploy                              # печатает public из приватного — сверь
ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{ip}  # перезаливает public на VPS
# Если приватный ключ удалён с Mac после загрузки в Secrets — сгенерируй новую пару
# (ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy -N "" -C "{site}-deploy"), перезалей public и обнови секрет:
gh secret set SSH_PRIVATE_KEY --env production --repo {owner}/{site} < ~/.ssh/{site}-deploy
gh run rerun <run-id> --failed
```

## Симлинк current переключился, а сайт отдаёт старую версию

**Симптом:** workflow зелёный, `readlink ~/prod/{site}/current` показывает новый sha, но сайт — старый. Либо симлинк вовсе не переключился.

**Причины:**
1. **PM2 кэширует resolved-путь скрипта** — после `pm2 restart`/`reload` процесс продолжает исполнять `releases/<old-sha>/server.js`. Это боевой урок: после смены симлинка годится **только** `pm2 delete` + `pm2 start`.
2. Шаг `Activate release` упал тихо — посмотри `gh run view <run-id> --log` в этой секции.
3. `current` — это **папка** (не симлинк) после ручных правок, и `ln -sfn` кладёт линк внутрь неё. Проверь `ls -la ~/prod/{site}/ | grep current` — должно быть `current -> releases/<sha>`.
4. Процесс падает на старте и крутится в `restart loop` со старым кодом — `pm2 logs {site}-prod` покажет.

**Фикс (вручную на VPS):**
```bash
ssh deploy@{ip} && cd ~/prod/{site} && ls -1 releases/   # где новый sha?
ln -sfn releases/<new-sha> current
pm2 delete {site}-prod
PORT={port} HOSTNAME=127.0.0.1 pm2 start current/server.js --name {site}-prod
pm2 save && readlink current && curl -sf -I http://127.0.0.1:{port}
```

## Шаг `Upload and unpack release` упал

**Симптом / сигнатуры в логе шага:**
- `scp: Permission denied` — ключ/права, см. § «SSH permission denied» выше.
- `scp: connect ... failed` / `Connection refused` — сетевой issue или wrong `SSH_HOST`/`SSH_PORT`.
- `gzip: unexpected end of file` / `tar: short read` — архив побился при передаче; re-run. Если повторяется — смотри лог шага Build/Pack (битым уехал с runner-а).
- `No space left on device` — забит диск на VPS.
- `server.js отсутствует в релизе — стоп до симлинка` — упаковка собрала неполный `deploy/`; обычно `output: 'standalone'` не включён в `next.config.ts`.

**Фикс:**
```bash
ssh deploy@{ip} 'df -h ~ && ls -ld ~/prod/{site}/releases'
# Если диск > 90% — почистить старые релизы (workflow держит last 5, вручную можно жёстче):
ssh deploy@{ip} 'cd ~/prod/{site}/releases && ls -1tr | head -n -3 | xargs -r rm -rf'
# Если папки нет — создать: ssh deploy@{ip} 'mkdir -p ~/prod/{site}/releases'
```

## PM2 не находит server.js в current/

**Симптом:** Шаг `Activate release` падает на `pm2 start current/server.js` с `ENOENT` или `not such file`.

**Причины:**
1. Это первый деплой — `current/` ещё не существует, симлинк надо поставить **до** `pm2 start`. Workflow уже это делает (`ln -sfn` идёт раньше `pm2 start`), но если порядок шагов в кастомизированном workflow поломан — фейл.
2. Standalone-сборка не положила `server.js`: либо `output: 'standalone'` не включён в `next.config.ts`, либо `pnpm build` упал и pack-шаг собрал пустой `deploy/`.
3. Шаг «Pack standalone bundle» не скопировал `.next/standalone/.` в `deploy/` (опечатка в путях).

**Фикс на VPS вручную (если первый деплой):**
```bash
ssh deploy@{ip}
ls -la ~/prod/{site}/current ~/prod/{site}/releases/<sha>/server.js
# Если symlink есть, server.js нет — проблема в шаге Build/Pack на runner-е, не на VPS.
# Если symlink нет — поставь руками и запусти PM2:
ln -sfn ~/prod/{site}/releases/<sha> ~/prod/{site}/current
PORT={port} HOSTNAME=127.0.0.1 pm2 start ~/prod/{site}/current/server.js --name {site}-prod
pm2 save
```

## Workflow logs через gh

Если деплой упал, не лезьте в Actions UI — быстрее:

```bash
gh run list --limit 5
gh run view <run-id> --log
gh run view <run-id> --log-failed   # только упавшие шаги
```

## Branch protection 403 на private + free

**Симптом:** `gh api -X PUT repos/.../branches/main/protection` возвращает `403 Upgrade to GitHub Pro or make this repository public`.

**Причина:** GitHub в 2024+ убрал protection из бесплатного плана для приватных репозиториев. Public repo + free — protection доступна. Private + free — нет.

**Фикс:** для one-dev — пропустить protection, держать дисциплину PR-flow. Альтернативы: GitHub Pro ($4/мес) или сделать репо public. Так настроен `<owner>/<repo>` (см. `.claude/memory/feedback.md`).

## Swap не пересоздаётся при повторном bootstrap

**Симптом:** На VPS уже был `/swapfile` 512 MB (Timeweb default). После `bootstrap-vps.sh` swap остался 512 MB вместо 2 GB.

**Причина:** старая версия скрипта пропускала шаг, если swapfile уже был.

**Фикс:** с v2.2 скрипт сам пересоздаёт swapfile, если размер не совпадает с `SWAP_SIZE`. Если у вас старая версия — вручную:

```bash
ssh root@VPS 'swapoff /swapfile && rm /swapfile && fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile'
```

## Prod отдаёт 404 на новой странице после билда

**Симптом:** на новой странице `curl https://{domain}/uslugi/foo` отдаёт 404, хотя в `app/uslugi/foo/page.tsx` файл есть и в локальном `pnpm build` страница появляется.

**Причины (push-based):**
1. PM2 показывает на старый релиз через симлинк `current` — workflow прошёл, но шаг `Activate release` по какой-то причине не переключил `current`. Проверь `readlink ~/prod/{site}/current` — последний ли это sha?
2. Page-маршрут с динамическим сегментом (`[slug]`) и `generateStaticParams` не вернул нужный slug — он не попал в `.next/server/app/`. Это не VPS-проблема, а билд-проблема.
3. PM2 застрял в crashloop на старте нового релиза и продолжает обслуживать старый код. `pm2 logs {site}-prod --lines 50` покажет.

**Фикс:**
```bash
ssh deploy@{ip}
readlink ~/prod/{site}/current                                  # совпадает с github.sha из последнего workflow?
ls ~/prod/{site}/current/.next/server/app/uslugi/                # есть foo.html?
pm2 delete {site}-prod && PORT={port} HOSTNAME=127.0.0.1 \
  pm2 start ~/prod/{site}/current/server.js --name {site}-prod   # перезапуск с чистым путём
pm2 list                                                         # status: online?
```

Если `current` указывает на свежий sha, а 404 остаётся — проверь `pnpm build` локально и убери проблему на стороне кода / `generateStaticParams`.

## Caddy не стартует / падает после правки

**Симптом:** `systemctl status caddy` показывает `failed`, или сайты возвращают 502 после `systemctl reload caddy`.

**Диагностика:**

```bash
sudo systemctl status caddy --no-pager && sudo journalctl -u caddy -n 50 --no-pager
sudo caddy validate --config /etc/caddy/Caddyfile
```

`caddy validate` покажет точный файл и строку с ошибкой. Типичные причины:
- Опечатка в Caddyfile (забытая `}`, пробел перед `{`, неверная директива).
- Конфликт портов: ещё что-то слушает 80/443 (старый nginx/Apache не выключен после миграции — `sudo systemctl stop nginx; sudo systemctl disable nginx`).
- Caddy не может писать в `/var/lib/caddy/` (проверь `ls -la /var/lib/caddy`, владелец должен быть `caddy:caddy`).

**Фикс:** правишь файл → `sudo caddy validate` → `sudo systemctl reload caddy`. Если сломал не один сайт, а сразу все — последний рабочий конфиг виден в `journalctl -u caddy --since "1 hour ago"`.

## SSL не выписывается (Caddy)

**Симптом:** HTTPS на новом домене возвращает `connection refused` или сертификат self-signed; в логах `obtain: ...`, `solving: HTTP-01 challenge ...`.

**Причины (по частоте):**
1. **DNS не указывает на VPS** — `dig +short {domain}` возвращает чужой IP или ничего. ACME-серверу некуда стучаться. Дождись пропагации или поправь A-запись.
2. **Порт 80 закрыт** — HTTP-01 challenge идёт на 80. `sudo ufw status` должен показывать `80/tcp ALLOW`. Caddy умеет и TLS-ALPN-01 по 443, так что при закрытом 80 выпуск возможен, но медленнее и капризнее — держи 80 открытым.
3. **Cloudflare proxy включён (оранжевое облачко)** — CF перехватывает `/.well-known/acme-challenge/`. Временно выключи proxy (серое облачко), дождись `certificate obtained`, включи обратно. Альтернатива — DNS-01 через Caddy plugin (отдельная сборка `xcaddy`).
4. **Лимит Let's Encrypt** — 5 неудачных попыток на домен в час, 50 успешных в неделю. Если упёрся — Caddy сам фолбэчит на ZeroSSL (если в Caddyfile не зафиксирован issuer).

**Что обычно НЕ нужно делать:** `sudo systemctl restart caddy`, `caddy reload`. Caddy сам ретраится с экспоненциальным бэкоффом. Рестарт сбрасывает счётчик попыток и может ускорить упирание в лимит.

## Усечённый tar / битые симлинки при ручной упаковке на Windows

**Симптом:** артефакт, упакованный вручную на Windows и распакованный на VPS, неполный: `tar: Unexpected EOF`, junction-папки пустые, `server.js` отсутствует.

**Причина:** Windows-симлинки (junction) не разыменовываются штатным tar; оборванная передача даёт усечённый архив, который распаковывается «частично успешно».

**Фикс:** паковать `bsdtar -L` (разыменовывает симлинки); проверять целостность `gzip -t archive.tar.gz` **на обеих сторонах**; перед переключением симлинка `current` убедиться, что `releases/<sha>/server.js` существует. В штатном пайплайне проблема не возникает — паковка идёт на GitHub-runner.

## Краш `@swc/helpers` в standalone на pnpm

**Симптом:** локальный `pnpm build` зелёный, а `node server.js` из standalone-сборки падает с `Cannot find module '@swc/helpers/...'`.

**Причина:** symlink-структура `node_modules` у pnpm — `output: 'standalone'` не дотаскивает транзитивные зависимости.

**Фикс:** `.npmrc` в корне проекта со строкой `node-linker=hoisted` (см. `docs/stack.md` § Инициализация). Поймано дважды — шаг обязательный, не опция.

## Блок «Преимущества» пропадает у части посетителей

**Симптом:** секция есть в коде и на localhost, но у части пользователей не отображается.

**Причина:** классы/id с префиксом `adv` (`advantages`, `adv-card`) режутся адблоками по косметическим фильтрам — блок реально пропадал.

**Фикс:** не использовать префиксы `ad`/`adv`/`banner` в классах и id видимых блоков. Безопасные имена: `benefits`, `features`, `why-us`.

## Tailwind v4: утилиты «не применяются» после кастомного CSS

**Симптом:** utility-классы перестают работать на отдельных элементах после добавления собственного CSS.

**Причины:**
1. Кастомный класс `.container` конфликтует со встроенной утилитой Tailwind v4 — назови иначе (`.page-shell`).
2. Element-стили (`h2 { ... }`, `p { ... }`) объявлены вне `@layer base` — по каскаду бьют утилиты.

**Фикс:** собственные element-стили — только внутри `@layer base`; кастомные классы не должны совпадать с именами утилит Tailwind.

## Сетевые проверки врут: DNS машины перехвачен

**Симптом:** `dig`/`curl` с рабочей машины показывают не то, что видят пользователи — провайдер/корп-DNS перехватывает запросы, отдаёт заглушки или устаревшие записи.

**Фикс:** сетевые проверки (DNS-пропагация, доступность, ACME) прогонять с VPS: `ssh deploy@{ip} 'dig +short {domain}; curl -I https://{domain}'` — у VPS чистый резолвер.

## Pre-push checklist (Mac)

Перед серьёзным push в main:

```bash
gh auth status                # active = <owner>?
git status                    # working tree clean?
git log origin/main..HEAD     # что именно уезжает?
pnpm lint && pnpm build       # локально билд проходит?
```

## Откат прода

Основное описание — `docs/deploy.md` § «Откат прода» (реализация — `scripts/rollback.sh`, см. `docs/automation.md`). Кратко:

```bash
scripts/rollback.sh                              # switch симлинка current → previous + pm2 delete/start
git revert <bad-commit> && git push origin main  # на Mac — починка через Actions
# для merge-коммита: git revert -m 1 <hash>
```

# Troubleshooting

Частые косяки и способы их решения. Источник — реальные инциденты проекта (`.claude/memory/lessons.md`).

## gh auth mismatch — push блокируется хуком

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

## DDoS-Guard 301 при smoke-тесте до DNS cutover

**Симптом:** `curl -H "Host: example.com" http://NEW_VPS_IP/` возвращает `301` от `Server: ddos-guard` с заголовком `x-tilda-server: 29`.

**Причина:** A-запись домена ещё указывает на старый IP (Tilda → DDoS-Guard). Middlebox (РКН/ISP) видит Host-header и перенаправляет на DDoS-Guard, **даже если TCP идёт на нужный IP**.

**Фикс:** не использовать доменное имя в Host-header до cutover.

```bash
# Плохо:
curl -H "Host: example.com" http://NEW_VPS_IP/

# Хорошо (IP-only):
curl -H "Host: NEW_VPS_IP" http://NEW_VPS_IP/

# Или через /etc/hosts override:
echo "NEW_VPS_IP example.com" | sudo tee -a /etc/hosts
curl -I https://example.com/
# не забыть откатить /etc/hosts после теста
```

## SSH permission denied в deploy job

**Симптом:** Actions падает на шаге `Setup SSH` или `Rsync to release dir` с `Permission denied (publickey)` от VPS.

**Причина (любая из):**
1. Public-часть `~/.ssh/{site}-deploy.pub` не добавлена в `/home/deploy/.ssh/authorized_keys` на VPS.
2. В `secrets.SSH_PRIVATE_KEY` лежит другой ключ (не парный к `authorized_keys` на VPS).
3. `secrets.SSH_USER` не `deploy`, или `SSH_PORT` не совпадает с реальным портом sshd.
4. `secrets.SSH_HOST` показывает на старый IP (после миграции).

**Фикс:**

```bash
# На Mac — проверить, что приватный ключ парный к публичному, который ты копировал на VPS:
ssh-keygen -y -f ~/.ssh/{site}-deploy   # печатает публичную часть из приватного
ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{ip}  # перезаливает public на VPS

# Если приватный ключ удалил с Mac после загрузки в Secrets — сгенерируй новый:
ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy -N "" -C "{site}-deploy"
ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{ip}
gh secret set SSH_PRIVATE_KEY --env production --repo {owner}/{site} \
  < ~/.ssh/{site}-deploy

# Re-run upавший workflow:
gh run rerun <run-id> --failed
```

## Симлинк current не переключился

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

## rsync завершился с ошибкой

**Симптом:** Шаг `Rsync to release dir` падает с одним из:
- `rsync: failed to connect to host` — сетевой issue или wrong `SSH_HOST`.
- `rsync: mkdir failed: Permission denied` — `~/prod/{site}/` не существует или принадлежит не `deploy`.
- `rsync: write failed: No space left on device` — забит диск.
- `rsync: change_dir … failed` — на runner-е пустой `deploy/` (билд не положил artefact).

**Фикс:**
```bash
# На Mac или с VPS:
ssh deploy@{ip} 'df -h ~ && ls -ld ~/prod/{site}/releases'
# Если диск > 90% — почистить старые релизы (workflow держит last 5, иначе можно вручную):
ssh deploy@{ip} 'cd ~/prod/{site}/releases && ls -1tr | head -n -3 | xargs -r rm -rf'

# Если папки нет — создать:
ssh deploy@{ip} 'mkdir -p ~/prod/{site}/releases'

# Если build на runner-е положил пустой deploy/ — посмотри лог build job, обычно
# проблема в том, что output: 'standalone' не включён в next.config.ts.
```

## PM2 не находит server.js в current/

**Симптом:** Шаг `Activate release` падает на `pm2 start current/server.js` с `ENOENT` или `not such file`.

**Причины:**
1. Это первый деплой — `current/` ещё не существует, симлинк надо поставить **до** `pm2 start`. Workflow уже это делает (`ln -sfn` идёт раньше `pm2 start`), но если порядок шагов в кастомизированном workflow поломан — фейл.
2. Standalone-сборка не положила `server.js`: либо `output: 'standalone'` не включён в `next.config.ts`, либо `pnpm build` упал и upload-artifact затащил пустой `deploy/`.
3. Шаг «Pack standalone bundle» в build job не скопировал `.next/standalone/.` в `deploy/` (опечатка в путях).

**Фикс на VPS вручную (если первый деплой):**
```bash
ssh deploy@{ip}
ls -la ~/prod/{site}/current ~/prod/{site}/releases/<sha>/server.js
# Если symlink есть, server.js нет — проблема в build job, не на VPS.
# Если symlink нет — поставь руками и запусти PM2:
ln -sfn ~/prod/{site}/releases/<sha> ~/prod/{site}/current
pm2 start ~/prod/{site}/current/server.js --name {site}-prod --update-env
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
ssh root@VPS
swapoff /swapfile
rm /swapfile
# затем перезапустить bootstrap или вручную:
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
```

## Prod отдаёт 404 на новой странице после билда

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

## Caddy не стартует / падает после правки

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

## SSL не выписывается (Caddy)

**Симптом:** HTTPS на новом домене возвращает `connection refused` или сертификат self-signed; в логах `obtain: ...`, `solving: HTTP-01 challenge ...`.

**Причины (по частоте):**
1. **DNS не указывает на VPS** — `dig +short {domain}` возвращает чужой IP или ничего. ACME-серверу некуда стучаться. Дождись пропагации или поправь A-запись.
2. **Порт 80 закрыт** — HTTP-01 challenge идёт на 80, не на 443. `sudo ufw status` должен показывать `80/tcp ALLOW`. Без 80 ACME не пройдёт никогда.
3. **Cloudflare proxy включён (оранжевое облачко)** — CF перехватывает `/.well-known/acme-challenge/`. Временно выключи proxy (серое облачко), дождись `certificate obtained`, включи обратно. Альтернатива — DNS-01 через Caddy plugin (отдельная сборка `xcaddy`).
4. **Лимит Let's Encrypt** — 5 неудачных попыток на домен в час, 50 успешных в неделю. Если упёрся — Caddy сам фолбэчит на ZeroSSL (если в Caddyfile не зафиксирован issuer).

**Что обычно НЕ нужно делать:** `sudo systemctl restart caddy`, `caddy reload`. Caddy сам ретраится с экспоненциальным бэкоффом. Рестарт сбрасывает счётчик попыток и может ускорить упирание в лимит.

## Pre-push checklist (Mac)

Перед серьёзным push в main:

```bash
gh auth status                # active = <owner>?
git status                    # working tree clean?
git log origin/main..HEAD     # что именно уезжает?
pnpm lint && pnpm build       # локально билд проходит?
```

## Откат прода

См. `docs/automation.md` → `scripts/rollback.sh`. Кратко:

```bash
scripts/rollback.sh                              # атомарный switch симлинка current → previous
git revert <bad-commit> && git push origin main  # на Mac — починка через Actions
# для merge-коммита: git revert -m 1 <hash>
```

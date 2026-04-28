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

## deploy_key permission denied

**Симптом:** Actions падает на `git pull` с `Permission denied (publickey). fatal: Could not read from remote repository`.

**Причина (любая из):**
1. Deploy key не добавлен в репо (Settings → Deploy keys).
2. Public ключ на VPS не совпадает с тем, что в Settings.
3. SSH-агент на VPS не использует `~/.ssh/deploy_key` (нет конфига `Host github.com IdentityFile ...`).

**Фикс:**

```bash
# На VPS:
sudo -u deploy ssh -T git@github.com
# Должно: "Hi <owner>/<repo>! You've successfully authenticated, but GitHub does not provide shell access."

# Если нет — проверить ~/.ssh/config у deploy:
cat ~/.ssh/config
# Должно содержать:
# Host github.com
#   IdentityFile ~/.ssh/deploy_key
#   IdentitiesOnly yes

# И сравнить публичный ключ с тем, что в репо:
cat ~/.ssh/deploy_key.pub
gh repo view <owner>/<repo> --json deployKeys
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

**Симптом:** `.next/server/app/uslugi/foo.html` существует, `curl` отдаёт 404 с `x-nextjs-prerender: 1`.

**Причина:** `next start` читает route manifest при старте процесса. Сделали `pnpm build`, но `pm2 restart` забыли — pm2 продолжает отдавать старый манифест.

**Фикс:** деплой = **двухшаговый** всегда: `pnpm build && pm2 restart {site}-prod --update-env`. Никогда только build.

**Диагностика:** если prod 404 на заведомо существующий файл в `.next/server/app/`, **первая гипотеза** — pm2 работает со старого билда. Проверка: сравнить `pm2 info {site}-prod` (uptime) и `stat -c '%y' .next/BUILD_ID` (mtime). Если build моложе uptime — нужен restart.

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
scripts/rollback.sh <good-commit-hash>           # на VPS катит указанный коммит
git revert <bad-commit> && git push origin main   # на Mac — починка через Actions
```

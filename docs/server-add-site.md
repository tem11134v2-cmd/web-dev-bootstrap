# Server: Add Site (подключение нового сайта на готовый VPS)

**Это инструкция для человека.** Проходится один раз на **каждый новый сайт**. Предполагается, что VPS уже прошёл `server-manual-setup.md`.

## Вход

Claude Code в репозитории уже сгенерировал (спека `01b-server-handoff`):
- `.github/workflows/deploy-prod.yml` (+ опционально `deploy-dev.yml`)
- `deploy/{site}.caddy.example` — шаблон Caddy-конфига с подставленным доменом и портами

Твоя задача ниже — положить это на сервер и связать всё по портам / доменам. SSL Caddy выпустит автоматически.

## 1. Зарезервировать порты

Открой `~/ports.md` на VPS, выбери свободную пару по правилу:

- prod: `3000 + N*10` (3000, 3010, 3020, ...)
- dev: `4000 + N*10` (4000, 4010, 4020, ...) — только если нужен preview

Добавь новую строку в таблицу сразу, до всех действий ниже. Это источник истины от конфликтов.

## 2. Подключить домен (до SSL)

См. `docs/domain-connect.md`. Нужно: A-запись `{domain}` → IP сервера, и если нужен preview — A-запись `dev.{domain}` → тот же IP. Дождись распространения (`dig +short {domain}` должен вернуть IP).

## 3. Создать папку и клонировать репо

На VPS под `deploy`:

```bash
mkdir -p ~/prod/{site}
cd ~/prod/{site}
git clone git@github.com:{owner}/{repo}.git .
git checkout main
pnpm install --frozen-lockfile
pnpm build
PORT={prod-port} pm2 start npm --name {site}-prod -- start
pm2 save
```

Если нужен dev-preview:

```bash
mkdir -p ~/dev/{site}
cd ~/dev/{site}
git clone git@github.com:{owner}/{repo}.git .
git checkout dev
pnpm install --frozen-lockfile
pnpm build
PORT={dev-port} pm2 start npm --name {site}-dev -- start
pm2 save
```

> **Note про git clone через SSH:** у `deploy`-пользователя должен быть ключ, добавленный в GitHub под аккаунтом заказчика/разработчика. Можно переиспользовать тот же `~/.ssh/deploy_key` (добавить его публичную часть в GitHub → Settings → SSH keys или как Deploy key в конкретном репо). Проверь: `ssh -T git@github.com` должно приветствовать.

## 4. Положить Caddy-конфиг

Один файл на сайт в `/etc/caddy/Caddyfile.d/{site}.caddy`. Базовый шаблон:

```caddyfile
{site}.com, www.{site}.com {
    reverse_proxy localhost:{prod-port}
    encode gzip zstd

    @static path *.css *.js *.woff2 *.png *.jpg *.jpeg *.webp *.avif *.svg *.ico
    header @static Cache-Control "public, max-age=31536000, immutable"

    @html path / *.html
    header @html Cache-Control "public, max-age=0, must-revalidate"
}

# Опционально — dev-поддомен с basic auth (бери hash через `caddy hash-password`):
dev.{site}.com {
    reverse_proxy localhost:{dev-port}
    encode gzip zstd
    basicauth {
        dev <bcrypt-hash>
    }
}
```

Применить:

```bash
sudo cp /home/deploy/prod/{site}/deploy/{site}.caddy.example /etc/caddy/Caddyfile.d/{site}.caddy
sudo nano /etc/caddy/Caddyfile.d/{site}.caddy   # сверь домен / порт / dev-блок
sudo caddy validate --config /etc/caddy/Caddyfile && sudo systemctl reload caddy

# Если это первый сайт — удали placeholder, чтобы Caddy не слушал лишний :8080:
sudo rm -f /etc/caddy/Caddyfile.d/00-placeholder.caddy
sudo systemctl reload caddy
```

## 5. SSL

Ничего делать не нужно. При первом HTTPS-запросе Caddy сам пройдёт ACME-challenge (HTTP-01 по 80 порту), получит сертификат от Let's Encrypt и положит его в `/var/lib/caddy/`. Проверь:

```bash
curl -I https://{domain}                           # должен быть 200/301
sudo journalctl -u caddy --since "5 min ago" | grep -i "certificate obtained"
```

Если порт 80 закрыт ufw или DNS ещё не указывает на VPS — Caddy будет ретраиться и сыпать в лог `obtain: ...`. Проверь `dig +short {domain}` и `sudo ufw status`.

## 6. Автопродление SSL

Делает сам Caddy (за ~30 дней до истечения, в фоне). Cron / systemd-таймеры не нужны — мы их не ставили. Проверить состояние:

```bash
sudo systemctl status caddy --no-pager
sudo ls -la /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/{domain}/
```

## 7. GitHub Secrets и Variables

В репо на GitHub → Settings → Secrets and variables → Actions:

**Secrets:**
- `DEPLOY_SSH_KEY` — приватный `~/.ssh/deploy_key` с VPS целиком.
- `SERVER_IP` — IP твоего VPS.

**Variables:**
- `SITE_NAME` — имя сайта (совпадает с `{site}` выше и именем PM2-процесса).

Если заказчик — владелец репо, он делает это у себя, ты подсказываешь значения.

## 8. Первый деплой через Actions (тест)

На Mac:

```bash
cd ~/projects/{site}
# сделай любую незначительную правку в README
git add README.md && git commit -m "chore: trigger first deploy"
git push origin main
```

Зайди в GitHub → Actions → смотри лог `deploy-prod.yml`. Должен успешно завершиться за 1–3 минуты. На VPS:

```bash
pm2 logs {site}-prod --lines 20       # проверь, рестартнулся ли процесс
```

Открой `https://{domain}` — должна быть новая версия.

## 9. Записать в реестр и память проекта

- Актуализируй `~/ports.md` на VPS (добавь PM2-имена и домен рядом с портами).
- В проекте на Mac — обнови `.claude/memory/references.md`: IP сервера, SSH-путь, порты, URL, имя PM2-процесса, путь папки на VPS.

## Готово

- [ ] A-записи ведут на сервер, `dig` подтверждает.
- [ ] `~/prod/{site}/` склонирован, собран, PM2 стартанул на нужном порту.
- [ ] `~/dev/{site}/` (если нужен) — аналогично.
- [ ] `/etc/caddy/Caddyfile.d/{site}.caddy` подключён, `caddy validate` проходит, HTTPS открывается.
- [ ] SSL выписан Caddy автоматически, `https://{domain}` отдаёт 200/301.
- [ ] Если это первый сайт — `00-placeholder.caddy` удалён.
- [ ] GitHub Secrets/Variables заполнены.
- [ ] Тестовый push в `main` прогнал pipeline успешно.
- [ ] `~/ports.md` и `.claude/memory/references.md` актуальны.

## Частые проблемы

- **502 после деплоя** → `pm2 restart {site}-prod`, `pm2 logs`. Часто — забыли `pnpm install --frozen-lockfile` после изменения зависимостей.
- **`git pull` в GH Actions падает** → ключ `deploy_key` не добавлен в GitHub или папка `~/prod/{site}` не инициализирована.
- **Caddy не выпускает SSL** → `dig +short {domain}` не показывает IP сервера (DNS не пропагнулся), либо `ufw` блокирует 80/443. Лог: `journalctl -u caddy -n 50 | grep -i obtain`.
- **`caddy validate` падает после правки** → typo в Caddyfile синтаксисе. Caddy показывает строку и причину; обычно — забытая `}` или пробел перед `{`.
- **Порт занят** (`EADDRINUSE`) → не сверился с `~/ports.md`, конфликт с другим сайтом.

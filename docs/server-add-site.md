# Server: Add Site (подключение нового сайта на готовый VPS)

**Исполняет Claude по SSH** — по канону `CLAUDE.md` (ключ разработчика, предупредив, что собирается сделать); человек рядом — на шагах с чужими GUI (DNS у регистратора, secrets в репо заказчика). Проходится один раз на **каждый новый сайт**. Предполагается, что VPS уже прошёл `server-manual-setup.md`.

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

## 3. Создать папки: релизы + shared/data

Под push-based deploy VPS не клонирует репо и не билдит — только принимает tar.gz-артефакт от GitHub Actions (scp + распаковка) в `releases/<sha>/` и переключает симлинк `current/`. Подготовить корневые папки:

```bash
ssh deploy@{ip} 'mkdir -p ~/prod/{site}/releases ~/prod/{site}/shared/data'
```

Если нужен dev-preview:
```bash
ssh deploy@{ip} 'mkdir -p ~/dev/{site}/releases ~/dev/{site}/shared/data'
```

**`shared/data` — fallback-лиды (JSONL).** В `.env.production` (→ секрет `PROD_ENV_FILE`) добавь:

```
LEADS_DIR=/home/deploy/prod/{site}/shared/data
```

Для dev-поддомена — свой вариант в `DEV_ENV_FILE`: `LEADS_DIR=/home/deploy/dev/{site}/shared/data`.

Путь абсолютный, симлинк в релиз не нужен; деплой и cleanup релизов эту папку **не трогают** — лиды переживают любые релизы.

Полная структура релизов (`releases/<sha>/`, `current`, `shared/`) описана в одном месте — `docs/deploy.md` § «Структура релизов на VPS». Коротко: `current` — симлинк на активный релиз; switch версии = `ln -sfn releases/<new-sha> current` + `pm2 delete`/`start`; до первого workflow `current` не существует — его создаёт первый успешный деплой, PM2-процесс тоже стартует workflow, руками здесь не запускаем. Старые релизы чистит сам workflow (последние 5 prod / 3 dev).

### SSH-ключ Actions → VPS

GitHub-runner ходит на VPS по single-purpose ключу `~/.ssh/{site}-deploy` (генерируется на Mac в spec `01b-server-handoff`). Публичную часть нужно один раз положить в `authorized_keys` пользователя `deploy`:

```bash
ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{ip}
# или вручную:
cat ~/.ssh/{site}-deploy.pub | ssh -p {ssh-port} deploy@{ip} 'cat >> ~/.ssh/authorized_keys'
```

Приватная часть (`~/.ssh/{site}-deploy`) загружается **только** в GitHub Environment Secret `SSH_PRIVATE_KEY` (см. § 7) и удаляется с Mac после загрузки. На VPS приватного ключа быть не должно.

## 4. Положить Caddy-конфиг

Один файл на сайт в `/etc/caddy/Caddyfile.d/{site}.caddy`. Базовый шаблон:

```caddyfile
{site}.com, www.{site}.com {
    reverse_proxy localhost:{prod-port}
    encode gzip zstd

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    # CSP — опция: составляй под фактический список источников; строгая политика
    # ломает счётчики (Метрика/GA) и inline-скрипты Next — включай только после проверки.
    # header Content-Security-Policy "default-src 'self'; ..."

    @static path *.css *.js *.woff2 *.png *.jpg *.jpeg *.webp *.avif *.svg *.ico
    header @static Cache-Control "public, max-age=31536000, immutable"

    @html path / *.html
    header @html Cache-Control "public, max-age=0, must-revalidate"
}

# Опционально — dev-поддомен с basic auth (бери hash через `caddy hash-password`):
dev.{site}.com {
    reverse_proxy localhost:{dev-port}
    encode gzip zstd
    header X-Robots-Tag "noindex, nofollow"
    basicauth {
        dev <bcrypt-hash>
    }
}
```

Применить (файл `deploy/{site}.caddy.example` лежит в репо на Mac — на VPS деплой-артефакт папку `deploy/` не привозит):

```bash
# с Mac, из папки проекта:
scp -P {ssh-port} deploy/{site}.caddy.example deploy@{ip}:/tmp/
# на VPS:
sudo mv /tmp/{site}.caddy.example /etc/caddy/Caddyfile.d/{site}.caddy
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

В репо на GitHub → Settings → Environments → создать `production` (опционально + `dev`). В environment-секреты:

**Secrets (Environment `production`):**
- `SSH_PRIVATE_KEY` — содержимое `~/.ssh/{site}-deploy` с Mac (приватный, single-purpose). Загружай через `gh secret set SSH_PRIVATE_KEY --env production < ~/.ssh/{site}-deploy` — после загрузки приватный файл с Mac можно удалить.
- `SSH_HOST` — IP VPS.
- `SSH_USER` — `deploy`.
- `SSH_PORT` — `2222` (либо `22`, если оставлял дефолт в `bootstrap-vps.sh`).
- `PROD_ENV_FILE` — содержимое `.env.production` целиком (multiline). Если в `.env` есть строки, начинающиеся со слова `EOF` — переименуй или используй `gh secret set --body-file`.

Если используются `NEXT_PUBLIC_*` (Turnstile, Я.Метрика, GA) — добавить как отдельные secrets, чтобы попадали в билд на runner.

**Variables (Repository):**
- `SITE_NAME` — имя сайта (совпадает с `{site}` выше и именем PM2-процесса).
- `PROD_PORT` — prod-порт из `~/ports.md` (§ 1); без него `pm2 start` уйдёт без `PORT=` и первый деплой будет красным.
- `DEV_PORT` — dev-порт (только если настраивается dev-поддомен).

Для dev-поддомена — отдельный environment `dev` с собственным `SSH_PRIVATE_KEY` (можно тот же ключ) и `DEV_ENV_FILE`.

Если заказчик — владелец репо, он делает это у себя, ты подсказываешь значения.

## 8. Первый деплой через Actions (тест)

На Mac:

```bash
cd ~/projects/{site}
# вариант 1 (main защищён — стандартный случай): PR из dev
git checkout dev && git commit --allow-empty -m "chore: trigger first deploy" && git push origin dev
gh pr create --base main --head dev --title "First deploy" --body "Triggers initial deploy-prod"
gh pr merge --squash --auto

# вариант 2 (branch protection недоступна — private + free GitHub):
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
- [ ] `~/prod/{site}/releases/` создан под deploy.
- [ ] `~/prod/{site}/shared/data/` создана, `LEADS_DIR` прописан в `PROD_ENV_FILE`.
- [ ] `~/dev/{site}/releases/` создан (если нужен dev-preview).
- [ ] Публичная часть `~/.ssh/{site}-deploy.pub` (с Mac) добавлена в `~/.ssh/authorized_keys` пользователя `deploy` на VPS.
- [ ] `/etc/caddy/Caddyfile.d/{site}.caddy` подключён, `caddy validate` проходит, HTTPS открывается.
- [ ] SSL выписан Caddy автоматически, `https://{domain}` отдаёт 200/301.
- [ ] Если это первый сайт — `00-placeholder.caddy` удалён.
- [ ] GitHub Environment `production` создан, secrets заполнены; repository variables `SITE_NAME` и `PROD_PORT` (+ `DEV_PORT` при dev-поддомене) выставлены.
- [ ] Тестовый push в `main` прогнал pipeline успешно — на VPS появилась `releases/<sha>/` и симлинк `current → releases/<sha>`, PM2 стартанул `current/server.js` на нужном порту.
- [ ] `~/ports.md` и `.claude/memory/references.md` актуальны.

## Частые проблемы

- **502 после деплоя** → `pm2 logs {site}-prod --lines 50`. Часто — `current/server.js` указывает на пустую папку (артефакт не доехал/не распаковался) либо в `.env` нет нужной переменной.
- **`Permission denied (publickey)` в Actions** → публичная часть single-purpose ключа не добавлена в `/home/deploy/.ssh/authorized_keys`, либо в GitHub Secrets `SSH_PRIVATE_KEY` лежит другой ключ. Проверь обе стороны.
- **Шаг `Upload and unpack release` упал** → смотри сигнатуру: `scp: Permission denied` (ключ/права), `gzip: unexpected end of file` / `tar: short read` (битый архив), `server.js отсутствует в релизе` (кривая упаковка). Права на `~/prod/{site}/` — под `deploy` (см. § 3).
- **`current` не переключился** → проверь `readlink -f ~/prod/{site}/current` после workflow; если симлинк не обновился — у `deploy` нет прав на `ln -sfn` (вряд ли, обычно проблема в путях с пробелами).
- **PM2 не находит `current/server.js`** → workflow не успел положить standalone-артефакт целиком; проверь `ls ~/prod/{site}/current/` — должны быть `server.js`, `.next/`, `public/`. Если первый деплой — `pm2 start current/server.js --name {site}-prod` руками.
- **Caddy не выпускает SSL** → `dig +short {domain}` не показывает IP сервера (DNS не пропагнулся), либо `ufw` блокирует 80/443. Лог: `journalctl -u caddy -n 50 | grep -i obtain`.
- **`caddy validate` падает после правки** → typo в Caddyfile синтаксисе. Caddy показывает строку и причину; обычно — забытая `}` или пробел перед `{`.
- **Порт занят** (`EADDRINUSE`) → не сверился с `~/ports.md`, конфликт с другим сайтом.

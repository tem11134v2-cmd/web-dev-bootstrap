# Server: Add Site (подключение нового сайта на готовый VPS)

**Это инструкция для человека.** Проходится один раз на **каждый новый сайт**. Предполагается, что VPS уже прошёл `server-manual-setup.md`.

## Вход

Claude Code в репозитории уже сгенерировал (спека `01b-server-handoff`):
- `.github/workflows/deploy-prod.yml` (+ опционально `deploy-dev.yml`)
- `deploy/nginx.conf.example` — шаблон nginx-конфига с подставленным доменом и портами

Твоя задача ниже — положить это на сервер и связать всё по портам / доменам / SSL.

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
npm ci
npm run build
PORT={prod-port} pm2 start npm --name {site}-prod -- start
pm2 save
```

Если нужен dev-preview:

```bash
mkdir -p ~/dev/{site}
cd ~/dev/{site}
git clone git@github.com:{owner}/{repo}.git .
git checkout dev
npm ci
npm run build
PORT={dev-port} pm2 start npm --name {site}-dev -- start
pm2 save
```

> **Note про git clone через SSH:** у `deploy`-пользователя должен быть ключ, добавленный в GitHub под аккаунтом заказчика/разработчика. Можно переиспользовать тот же `~/.ssh/deploy_key` (добавить его публичную часть в GitHub → Settings → SSH keys или как Deploy key в конкретном репо). Проверь: `ssh -T git@github.com` должно приветствовать.

## 4. Положить nginx-конфиг

```bash
sudo cp /home/deploy/prod/{site}/deploy/nginx.conf.example /etc/nginx/sites-available/{site}
# отредактируй если нужно (пути, порт, server_name)
sudo ln -s /etc/nginx/sites-available/{site} /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Страница должна открываться по IP или домену по HTTP. Если 502 — PM2-процесс ещё не поднят: `pm2 logs {site}-prod`.

## 5. SSL

```bash
sudo certbot --nginx -d {domain}                   # только prod
sudo certbot --nginx -d {domain} -d dev.{domain}   # если есть dev-поддомен
```

Certbot сам допишет HTTPS-секцию в `/etc/nginx/sites-available/{site}` и перезагрузит nginx. Проверь открывается ли `https://{domain}`.

## 6. Автопродление SSL

Уже настроено системным таймером `certbot.timer` (ставится из `server-manual-setup.md`). Проверить:

```bash
sudo systemctl list-timers | grep certbot
sudo certbot renew --dry-run
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
- [ ] Nginx-конфиг подключён, `nginx -t` проходит, HTTP открывается.
- [ ] SSL выписан certbot, HTTPS работает.
- [ ] GitHub Secrets/Variables заполнены.
- [ ] Тестовый push в `main` прогнал pipeline успешно.
- [ ] `~/ports.md` и `.claude/memory/references.md` актуальны.

## Частые проблемы

- **502 после деплоя** → `pm2 restart {site}-prod`, `pm2 logs`. Часто — забыли `npm ci` после изменения зависимостей.
- **`git pull` в GH Actions падает** → ключ `deploy_key` не добавлен в GitHub или папка `~/prod/{site}` не инициализирована.
- **Certbot не видит server_name** → сначала подними HTTP-секцию в nginx, перезагрузи, потом запускай certbot.
- **Порт занят** (`EADDRINUSE`) → не сверился с `~/ports.md`, конфликт с другим сайтом.

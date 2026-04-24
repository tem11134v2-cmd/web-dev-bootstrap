# Spec 01b: Server handoff (Claude пишет в репо, человек применяет на VPS)

## KB files to read first

- docs/deploy.md
- docs/server-add-site.md (для справки, **не для исполнения**)
- docs/spec.md (домен)
- `.claude/memory/references.md`

## Goal

Сгенерировать в репозитории всё, что нужно, чтобы разработчик (пользователь) за 30 минут подключил сайт на уже готовый VPS:
- `.github/workflows/deploy-prod.yml` (и `deploy-dev.yml` если нужен preview);
- `deploy/nginx.conf.example` — nginx-шаблон с подставленными доменом и портами;
- `deploy/README.md` — чек-лист действий для пользователя, сшитый из `docs/server-manual-setup.md`, `docs/server-add-site.md`, `docs/domain-connect.md`.

**Claude не ходит по SSH на сервер.** Всё, что требует VPS-доступа — человек делает сам по `deploy/README.md`.

## Входные данные

Спроси у пользователя и зафиксируй в `references.md`:

- Домен prod (например, `example.com`).
- Нужен ли dev-поддомен (`dev.example.com`) — да/нет.
- IP VPS и является ли VPS свежим (нужен `server-manual-setup.md`) или на нём уже есть другие сайты (сразу `server-add-site.md`).
- Если VPS не свежий — попроси пользователя открыть `~/ports.md` на VPS и назвать свободную пару портов (prod 3000 + N*10, dev prod + 1000). Если свежий — предложи дефолт 3010/4010 (3000 оставляем как «служебный» свободный, если понадобится).
- Имя сайта `{site}` (оно же имя GitHub-репо, оно же имя PM2-процесса).

## Tasks

### 1. `.github/workflows/deploy-prod.yml`

Сгенерируй файл по шаблону из `docs/deploy.md`. Ключевые точки:
- Trigger: `push` → `branches: [main]`.
- Использует секреты `DEPLOY_SSH_KEY`, `SERVER_IP` и переменную `SITE_NAME`.
- Шаги: `webfactory/ssh-agent` → SSH в `~/prod/{site}` → `git pull` → `npm ci` → `npm run build` → `pm2 restart {site}-prod`.

### 2. `.github/workflows/deploy-dev.yml` (если нужен preview)

Аналогично, но:
- Trigger: `push` → `branches: [dev]`.
- Папка на VPS: `~/dev/{site}`.
- PM2-имя: `{site}-dev`.

### 3. `deploy/nginx.conf.example`

Шаблон nginx-секции для этого сайта с **подставленным** доменом и портом. Два блока: HTTP (80, redirect → HTTPS) и HTTPS (443, proxy_pass на порт). Если есть dev-поддомен — дополнительно два блока для `dev.{domain}`.

Базовый шаблон бери из `docs/server-add-site.md`. Не копируй HTTPS-блок с пустыми `ssl_certificate` — их допишет certbot при вызове `certbot --nginx` на VPS.

Выводи минимальный HTTP-блок, HTTPS сформирует certbot.

### 4. `deploy/README.md`

Короткий (не более 80 строк) пошаговый чек-лист **для пользователя**, который:
1. Ссылается на `docs/server-manual-setup.md` если VPS свежий.
2. Ссылается на `docs/domain-connect.md` для A-записей.
3. Ссылается на `docs/server-add-site.md` для клона + nginx + SSL.
4. Даёт блок «Секреты для GitHub» с конкретными значениями (кроме приватного ключа — это пользователь берёт с VPS сам).
5. Даёт команду теста: `git push origin main` → проверить Actions → проверить URL.

Не дублируй содержимое `docs/server-*.md` — только ссылки + данные, специфичные для ЭТОГО сайта (домен, порт, `{site}`).

### 5. `.gitignore` проверка

Убедись, что в корневом `.gitignore` есть:

```
.env*
!.env.example
data/leads.json
node_modules/
.next/
out/
dist/
*.log
```

### 6. Коммит и push

Коммит с понятным сообщением: `chore: add deploy workflows and nginx template for {site}`. Push в `dev` (не в `main` — `main` защищён), открывай PR, просишь пользователя смёрджить после проверки.

## Boundaries

- **Never:** коммитить приватные ключи, секреты, `.env`. Если пользователь случайно вставил их в чат — предупреди и **не сохраняй в файлы**.
- **Never:** пытаться подключаться к VPS по SSH, даже если пользователь дал IP. Claude работает только с локальной папкой и GitHub.
- **Ask first:** перед push в `main` (обычно pushим в `dev`, merge руками через PR).

## Done when

- `.github/workflows/deploy-prod.yml` (и `deploy-dev.yml` если нужен) созданы, валидный YAML.
- `deploy/nginx.conf.example` создан с подставленным доменом и портом.
- `deploy/README.md` создан, ссылается на все нужные `docs/server-*.md`.
- `.gitignore` проверен.
- Коммит в `dev`, PR открыт, пользователь его видит.

## Memory updates

- `references.md` — домен prod, dev-поддомен (если есть), IP VPS, пары портов, имя `{site}`.
- `decisions.md` — если были выборы (использовать Cloudflare, включить dev-preview) — с **Why:**.
- `project_state.md` — отметить `01b` done, следующая `02-project-init`. Отдельно пометить: «ждём от пользователя: настройку VPS по `deploy/README.md` и первый успешный Actions-run».

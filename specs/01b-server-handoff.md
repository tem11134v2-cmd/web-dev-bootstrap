# Spec 01b: Server handoff (Claude пишет в репо, человек применяет на VPS)

## KB files to read first

- docs/deploy.md (push-based flow, структура `releases/<sha>/`)
- docs/server-add-site.md (для справки, **не для исполнения**)
- docs/spec.md (домен)
- `.claude/memory/references.md`
- `_BUILD/v3/templates/deploy-prod.yml.example` — канонический шаблон workflow, бери оттуда
- `_BUILD/v3/templates/deploy-dev.yml.example` — то же для dev (если нужен preview)

## Goal

Сгенерировать в репозитории всё, что нужно, чтобы разработчик (пользователь) за ~30 минут подключил сайт на уже готовый VPS под **push-based deploy** (build на runner → rsync артефакта → атомарный switch симлинка):

- `.github/workflows/deploy-prod.yml` (+ опционально `deploy-dev.yml`);
- `deploy/{site}.caddy.example` — шаблон Caddy-конфига с подставленным доменом и портами;
- `deploy/README.md` — чек-лист действий для пользователя, сшитый из `docs/server-manual-setup.md`, `docs/server-add-site.md`, `docs/domain-connect.md`;
- сгенерировать на Mac разработчика single-purpose SSH-ключ для деплоя (пользователь выполняет команду из `deploy/README.md`).

**Claude не ходит по SSH на сервер.** Всё, что требует VPS-доступа — человек делает сам по `deploy/README.md`.

## Входные данные

Спроси у пользователя и зафиксируй в `references.md`:

- Домен prod (например, `example.com`).
- Нужен ли dev-поддомен (`dev.example.com`) — да/нет.
- IP VPS и является ли VPS свежим (нужен `server-manual-setup.md`) или на нём уже есть другие сайты (сразу `server-add-site.md`).
- Если VPS не свежий — попроси пользователя открыть `~/ports.md` на VPS и назвать свободную пару портов (prod 3000 + N*10, dev 4000 + N*10). Если свежий — предложи дефолт 3010/4010 (3000 оставляем как «служебный» свободный, если понадобится).
- Имя сайта `{site}` (оно же имя GitHub-репо, оно же имя PM2-процесса, оно же `vars.SITE_NAME` в Actions).
- Кастомный SSH-порт VPS (по дефолту `2222`, если в `bootstrap-vps.sh` оставлено).

## Tasks

### 1. `.github/workflows/deploy-prod.yml`

Скопируй шаблон из `_BUILD/v3/templates/deploy-prod.yml.example` в `.github/workflows/deploy-prod.yml`. Менять в нём почти ничего не нужно — все per-site значения вынесены в Variables/Secrets:

- `vars.SITE_NAME` — имя сайта.
- `secrets.SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER`, `SSH_PORT`, `PROD_ENV_FILE`.
- `secrets.NEXT_PUBLIC_TURNSTILE_SITE_KEY` / `NEXT_PUBLIC_YM_ID` / `NEXT_PUBLIC_GA_ID` — если используются на билде.

Что workflow делает (тезисно, для понимания):

1. **build job:** checkout → pnpm install → `pnpm build` (ENV-переменные из секретов попадают в standalone-сборку) → упаковывает `.next/standalone` + `.next/static` + `public/` в `deploy/` → uploads as artifact `app`.
2. **deploy job (environment: production):** скачивает artifact → ssh-keygen для приватного ключа из `SSH_PRIVATE_KEY` → `rsync -az --delete deploy/ deploy@VPS:releases/<sha>/` → пишет `.env` из `PROD_ENV_FILE` секрета → `ln -sfn releases/<sha> current` → `pm2 reload {site}-prod --update-env` (или `pm2 start current/server.js` при первом деплое) → cleanup старых релизов (last 5).

`concurrency: group: deploy-prod-${{ vars.SITE_NAME }}` + `cancel-in-progress: false` ставит параллельные деплои в очередь — два rsync-а в одну папку могут испортить артефакт.

### 2. `.github/workflows/deploy-dev.yml` (если нужен preview)

Скопируй `_BUILD/v3/templates/deploy-dev.yml.example` в `.github/workflows/deploy-dev.yml`. Отличия от prod:
- триггер на ветке `dev`,
- `environment: dev` (отдельный набор Environment Secrets, в т.ч. `DEV_ENV_FILE`),
- путь на VPS `~/dev/{site}/`,
- PM2-имя `{site}-dev`,
- cleanup last 3 релизов.

Если dev-поддомен не нужен — этот файл **не создавать** (лишний workflow будет фейлиться на пуше в `dev` без secrets).

### 3. `deploy/{site}.caddy.example`

Caddy-шаблон для этого сайта. Базовый блок (бери из `docs/server-add-site.md` § 4):

```caddyfile
{domain}, www.{domain} {
    reverse_proxy localhost:{prod-port}
    encode gzip zstd

    @static path *.css *.js *.woff2 *.png *.jpg *.jpeg *.webp *.avif *.svg *.ico
    header @static Cache-Control "public, max-age=31536000, immutable"

    @html path / *.html
    header @html Cache-Control "public, max-age=0, must-revalidate"
}
```

Если есть dev-поддомен — добавь второй блок с `dev.{domain}`, `localhost:{dev-port}` и `basicauth` (placeholder `<bcrypt-hash>` — пользователь сгенерирует через `caddy hash-password`).

SSL Caddy выпустит сам после первого HTTPS-запроса (HTTP-01 challenge через 80 порт). В шаблоне НЕ пиши блоки про сертификаты — Caddy управляет ими автоматически.

### 4. `deploy/README.md`

Короткий (~80 строк) пошаговый чек-лист **для пользователя**. Структура:

```markdown
# Deploy: {site}

## Что у тебя уже есть
- VPS {fresh|существующий} на {ip}, SSH-порт {ssh-port}.
- Домен `{domain}`{и `dev.{domain}` если есть}, A-запись на {ip} (см. § 1).

## 1. DNS
A-запись {domain} → {ip}. Если есть dev-поддомен — `dev.{domain}` → {ip}.
Подробности — `docs/domain-connect.md`. Дождись `dig +short {domain}` показывает {ip}.

## 2. VPS bootstrap (если свежий)
Один раз на VPS:
1. `ssh-copy-id root@{ip}` с Mac.
2. `ssh root@{ip} 'CADDY_ADMIN_EMAIL=<email> bash -s' < scripts/bootstrap-vps.sh`.
Подробности — `docs/server-manual-setup.md`.

## 3. Сгенерировать deploy-ключ на Mac
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy -N "" -C "{site}-deploy"
   ```
Public-часть в authorized_keys на VPS:
   ```bash
   ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{ip}
   ```
Проверь: `ssh -i ~/.ssh/{site}-deploy -p {ssh-port} deploy@{ip} 'hostname'` отвечает.

## 4. GitHub Environment + Secrets
GitHub → репо → Settings → Environments → создать `production`. В Secrets положить:
- `SSH_PRIVATE_KEY` — содержимое `~/.ssh/{site}-deploy` (приватная часть).
- `SSH_HOST` — `{ip}`.
- `SSH_USER` — `deploy`.
- `SSH_PORT` — `{ssh-port}`.
- `PROD_ENV_FILE` — содержимое локального `.env.production` целиком (multiline). Создавай через
   ```bash
   gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} \
     < ~/projects/{site}/.env.production
   ```
- (если используются на билде) `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `NEXT_PUBLIC_YM_ID`, `NEXT_PUBLIC_GA_ID`.

В Variables (repository, не environment): `SITE_NAME` = `{site}`.

После загрузки в GitHub Secrets — удали приватный `~/.ssh/{site}-deploy` с Mac (опционально, безопаснее).

Для dev-поддомена — отдельный environment `dev` с собственным `DEV_ENV_FILE`.

## 5. Папка под релизы и Caddy на VPS
По `docs/server-add-site.md` § 3 и § 4:
   ```bash
   ssh deploy@{ip} 'mkdir -p ~/prod/{site}/releases'
   ```
Скопируй `deploy/{site}.caddy.example` в `/etc/caddy/Caddyfile.d/{site}.caddy`, удали `00-placeholder.caddy` если это первый сайт, `caddy validate && systemctl reload caddy`.

## 6. Тестовый деплой
Любой коммит, попавший в `main`, триггерит `deploy-prod.yml`. Если `main` защищён — мердж PR из `dev`. Если protection недоступна (private + free GitHub) — `git push origin main` напрямую.
   ```bash
   # вариант 1 (main защищён):
   git checkout dev && git commit --allow-empty -m "chore: trigger first deploy" && git push origin dev
   gh pr create --base main --head dev --title "First deploy" --body "Triggers initial deploy-prod"
   gh pr merge --squash --auto

   # вариант 2 (нет protection):
   git push origin main
   ```
GitHub → Actions → `Deploy production` должен пройти за 2–4 мин (build на runner, rsync, симлинк). На VPS:
   ```bash
   ssh deploy@{ip} 'pm2 logs {site}-prod --lines 20'
   ```
Открой `https://{domain}` — должна быть свежая версия.

## 7. Записать в реестр
- `~/ports.md` на VPS: добавить строку с портами и PM2-именами.
- `.claude/memory/references.md` в проекте: IP, домен, путь `~/prod/{site}/`, PM2-имя.
```

Не дублируй содержимое `docs/server-*.md` — только конкретные значения для ЭТОГО сайта (домен, порт, `{site}`, IP).

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

Коммит с понятным сообщением: `chore: add deploy workflows and Caddy template for {site}`. Push в `dev` (не в `main` — `main` защищён), открывай PR, просишь пользователя смёрджить после проверки.

## Boundaries

- **Never:** коммитить приватные ключи, секреты, `.env`. Если пользователь случайно вставил их в чат — предупреди и **не сохраняй в файлы**.
- **Never:** пытаться подключаться к VPS по SSH, даже если пользователь дал IP. Claude работает только с локальной папкой и GitHub.
- **Never:** генерировать ключ `~/.ssh/{site}-deploy` сам — это шаг для пользователя в `deploy/README.md`. Claude не должен ни видеть приватные ключи, ни их создавать.
- **Ask first:** перед push в `main` (обычно pushим в `dev`, merge руками через PR).

## Done when

- `.github/workflows/deploy-prod.yml` (и `deploy-dev.yml` если нужен) созданы по шаблонам из `_BUILD/v3/templates/`, валидный YAML.
- `deploy/{site}.caddy.example` создан с подставленным доменом и портами (Caddy-шаблон, не nginx).
- `deploy/README.md` создан, ссылается на все нужные `docs/server-*.md`, содержит конкретные значения для этого сайта.
- `.gitignore` проверен.
- Коммит в `dev`, PR открыт, пользователь его видит.

## Memory updates

- `references.md` — домен prod, dev-поддомен (если есть), IP VPS, пары портов, имя `{site}`, кастомный SSH-порт.
- `decisions.md` — если были выборы (использовать Cloudflare, включить dev-preview, изменить дефолтный порт SSH) — с **Why:**.
- `project_state.md` — отметить `01b` done, следующая `02-project-init`. Отдельно пометить: «ждём от пользователя: настройку VPS по `deploy/README.md` + загрузка GitHub Environment Secrets + первый успешный Actions-run».

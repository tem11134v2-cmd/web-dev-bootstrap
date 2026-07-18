# Spec 01b: Server handoff (деплой-инфраструктура в репо + подключение VPS)

> Оркестрация: builder-sonnet (Ask first — ключи и merge остаются за человеком); параллель: с 02–06; verifier: не нужен (гейт = зелёный Actions-run)

## KB files to read first

- docs/deploy.md (push-based flow, структура `releases/<sha>/`)
- docs/server-add-site.md (исполняет Claude по SSH, человек рядом)
- docs/spec.md (домен)
- `.claude/memory/references.md`
- `_BUILD/templates/deploy-prod.yml.example` — канонический шаблон workflow, бери оттуда
- `_BUILD/templates/deploy-dev.yml.example` — то же для dev (если нужен preview)
- `_BUILD/templates/deploy-readme.md.example` — шаблон чек-листа `deploy/README.md`

## Goal

Сгенерировать в репозитории всё, что нужно, чтобы за ~30 минут подключить сайт на уже готовый VPS под **push-based deploy** (build на runner → tar.gz по scp → проверки на VPS → атомарный switch симлинка):

- `.github/workflows/deploy-prod.yml` (+ опционально `deploy-dev.yml`);
- `deploy/{site}.caddy.example` — шаблон Caddy-конфига с подставленным доменом и портами;
- `deploy/README.md` — чек-лист подключения из шаблона `_BUILD/templates/deploy-readme.md.example`;
- single-purpose SSH-ключ для деплоя генерируется на Mac разработчика (команда — в `deploy/README.md`).

**SSH — по канону CLAUDE.md (раздел Rules):** серверные шаги из `deploy/README.md` Claude может выполнить сам по SSH, предупредив пользователя, что именно собирается сделать. Человеку остаётся только то, что требует чужих GUI: DNS у регистратора, оплата VPS, выдача ключей/паролей.

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

Скопируй шаблон из `_BUILD/templates/deploy-prod.yml.example` в `.github/workflows/deploy-prod.yml`. Менять в нём почти ничего не нужно — все per-site значения вынесены в Variables/Secrets:

- `vars.SITE_NAME` — имя сайта.
- `vars.PROD_PORT` — прод-порт из `~/ports.md` (для dev-workflow — `vars.DEV_PORT`); настроить в repo → Settings → Variables вместе с секретами.
- `secrets.SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER`, `SSH_PORT`, `PROD_ENV_FILE`.
- `secrets.NEXT_PUBLIC_TURNSTILE_SITE_KEY` / `NEXT_PUBLIC_YM_ID` / `NEXT_PUBLIC_GA_ID` — если используются на билде.

Что workflow делает (тезисно, для понимания). Один job build+deploy (environment: production; без upload-artifact — экономит квоту аккаунта): checkout → pnpm install → `pnpm build` (ENV-переменные из секретов попадают в standalone-сборку) → упаковка `.next/standalone` + `.next/static` + `public/` в `release.tar.gz` + `gzip -t` на runner-е → `scp` на VPS → там снова `gzip -t`, распаковка в `releases/<sha>/` и проверка наличия `server.js` — всё ДО переключения симлинка → пишет `.env` из `PROD_ENV_FILE` → `ln -sfn releases/<sha> current` → перезапуск PM2 (после смены симлинка — `delete && start` с `PORT=... HOSTNAME=127.0.0.1`, не `restart` — PM2 кэширует resolved-путь) → healthcheck `curl`; не 200 — автооткат симлинка на предыдущий релиз и красный run → cleanup старых релизов (last 5, `shared/` не трогает).

`concurrency: group: deploy-prod-${{ vars.SITE_NAME }}` + `cancel-in-progress: false` ставит параллельные деплои в очередь — две выгрузки (scp + распаковка) в одну папку могут испортить релиз.

### 2. `.github/workflows/deploy-dev.yml` (если нужен preview)

Скопируй `_BUILD/templates/deploy-dev.yml.example` в `.github/workflows/deploy-dev.yml`. Отличия от prod:
- триггер на ветке `dev`,
- `environment: dev` (отдельный набор Environment Secrets, в т.ч. `DEV_ENV_FILE`),
- путь на VPS `~/dev/{site}/`,
- PM2-имя `{site}-dev`,
- cleanup last 3 релизов.

Если dev-поддомен не нужен — этот файл **не создавать** (лишний workflow будет фейлиться на пуше в `dev` без secrets).

### 3. `deploy/{site}.caddy.example`

Caddy-шаблон для этого сайта. Prod-блок **бери целиком из `docs/server-add-site.md` § 4** (включая security headers и кэш-директивы) — не пересобирай по памяти, подставь только `{domain}` и `{prod-port}`.

Если есть dev-поддомен — добавь второй блок `dev.{domain}`; его отличия от prod-блока: `reverse_proxy localhost:{dev-port}`, `basicauth` (placeholder `<bcrypt-hash>` — пользователь сгенерирует через `caddy hash-password`) и `header X-Robots-Tag "noindex, nofollow"`.

SSL Caddy выпустит сам после первого HTTPS-запроса (HTTP-01 challenge через 80 порт). В шаблоне НЕ пиши блоки про сертификаты — Caddy управляет ими автоматически.

### 4. `deploy/README.md`

Скопируй шаблон `_BUILD/templates/deploy-readme.md.example` в `deploy/README.md` и заполни плейсхолдеры значениями ЭТОГО сайта: `{site}`, `{domain}`, `{ip}`, `{ssh-port}`, порты, `{owner}`. Не дублируй содержимое `docs/server-*.md` — в README только конкретные значения и порядок шагов.

Шаги с SSH из README Claude может выполнить сам (канон CLAUDE.md), предупредив пользователя. Человеку остаются: DNS у регистратора, GitHub-аккаунт, выдача ключей/паролей.

Всё, что нужно от заказчика (доступ к DNS/регистратору, ключи внешних сервисов), — сразу строками в `CLIENT-TODO.md` (создан в 00 из `specs/templates/client-todo-template.md`).

### 5. `.gitignore` проверка

Убедись, что в корневом `.gitignore` есть:

```
.env*
!.env.example
data/
node_modules/
.next/
out/
dist/
*.log
```

`data/` игнорируется каталогом целиком (fallback-лиды `leads.jsonl`, заказы `orders.jsonl` — ПДн не коммитятся никогда).

### 6. Коммит и push

Коммит с понятным сообщением: `chore: add deploy workflows and Caddy template for {site}`. Push в `dev` (не в `main` — `main` защищён), открывай PR, просишь пользователя смёрджить после проверки.

## Boundaries

- **Never:** коммитить приватные ключи, секреты, `.env`. Если пользователь случайно вставил их в чат — предупреди и **не сохраняй в файлы**.
- **SSH:** по канону CLAUDE.md — предупредив пользователя; read-only проверки (`pm2 status`, `ls releases/`, `curl -I`) и батчированные идемпотентные скрипты, не интерактивные правки на сервере.
- **Never:** генерировать ключ `~/.ssh/{site}-deploy` сам — это шаг для пользователя в `deploy/README.md`. Claude не должен ни видеть приватные ключи, ни их создавать.
- **Ask first:** перед push в `main` (обычно pushим в `dev`, merge руками через PR).

## Done when

- `.github/workflows/deploy-prod.yml` (и `deploy-dev.yml` если нужен) созданы по шаблонам из `_BUILD/templates/`, валидный YAML.
- `deploy/{site}.caddy.example` создан с подставленным доменом и портами (Caddy-шаблон, не nginx).
- `deploy/README.md` создан из `_BUILD/templates/deploy-readme.md.example`, плейсхолдеры заполнены значениями этого сайта.
- `.gitignore` проверен.
- Коммит в `dev`, PR открыт, пользователь его видит.
- Нужды от заказчика (DNS, ключи) записаны в `CLIENT-TODO.md`.
- **Гейт:** первый Actions-run зелёный и `https://{domain}` отвечает 200 — иначе к 04 не переходим.

## Memory updates

- `references.md` — домен prod, dev-поддомен (если есть), IP VPS, пары портов, имя `{site}`, кастомный SSH-порт.
- `decisions.md` — если были выборы (использовать Cloudflare, включить dev-preview, изменить дефолтный порт SSH) — с **Why:**.
- `CLIENT-TODO.md` — DNS-записи, доступы, ключи: всё, что ждём от заказчика.
- `project_state.md` — отметить `01b` done, следующая `02-project-init`. Отдельно пометить блокер до гейта: «ждём: GitHub Environment Secrets + первый зелёный Actions-run + `https://{domain}` отвечает 200».

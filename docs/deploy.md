# Deploy

Push-based deploy: разработка на Mac → push в GitHub → GitHub-runner собирает standalone-артефакт → tar.gz по scp на VPS → распаковка в `releases/<sha>/` (с проверками до симлинка) → атомарный switch симлинка `current/` → `pm2 delete` + `pm2 start` → healthcheck (не 200 → автооткат симлинка). На VPS нет ни git, ни pnpm, ни build toolchain — только Node runtime + Caddy + PM2.

## Общая картина

```
┌─────────────────────┐    git push      ┌──────────────┐
│  Mac (Claude Code)  │ ────────────────▶│  GitHub repo │
│  ~/projects/{site}  │                  │  branches:   │
│  localhost:3000     │                  │  - main      │
└─────────────────────┘                  │  - dev       │
                                         └──────┬───────┘
                                                │ GitHub Actions (on push)
                                                ▼
                                  ┌──────────────────────────┐
                                  │ ubuntu-latest runner     │
                                  │ один job build+deploy    │
                                  │ pnpm install --frozen   │
                                  │ pnpm build (standalone) │
                                  │ pack: standalone+static │
                                  │   +public → tar.gz      │
                                  │   + gzip -t             │
                                  └──────┬───────────────────┘
                                         │ scp release.tar.gz (SSH)
                                         │ + gzip -t, распаковка,
                                         │   чек server.js
                                         │ + write .env from secret
                                         │ + ln -sfn current
                                         │ + pm2 delete && start
                                         │ + healthcheck (fail→откат)
                                         ▼
                                  ┌──────────────────────────┐
                                  │ VPS (Node + Caddy + PM2) │
                                  │  ~/prod/{site}/          │
                                  │    releases/<sha-1>/     │
                                  │    releases/<sha-2>/     │
                                  │    releases/<sha-3>/  ←  │
                                  │    current ───────┘      │
                                  │    shared/data (лиды)    │
                                  │       │                  │
                                  │       ▼ pm2 (PORT env)   │
                                  │   localhost:3010         │
                                  │       ▼                  │
                                  │     Caddy + ACME         │
                                  │   {domain}, www.{domain} │
                                  │   dev.{domain} (опц.)    │
                                  └──────────────────────────┘
```

## Структура релизов на VPS

Push-based deploy кладёт каждый билд в `releases/<sha>/` и переключает симлинк `current` атомарно. Это даёт мгновенный rollback (`ln -sfn` обратно) без пересборки. Это **единственное** полное описание структуры релизов в пакете — `server-add-site.md` ссылается сюда.

```
/home/deploy/prod/{site}/
├── releases/
│   ├── 7f3a9c2…/         старый релиз (sha коммита из github.sha)
│   ├── b1e8d4f…/         предыдущий
│   └── c5d2a91…/         новый, активный
│       ├── server.js     entry point standalone-сборки Next.js
│       ├── .next/
│       │   └── static/   (положен runner-ом рядом со standalone)
│       ├── public/       (положен runner-ом рядом со standalone)
│       └── .env          (записан workflow из PROD_ENV_FILE secret)
├── shared/
│   └── data/             fallback-лиды (JSONL, LEADS_DIR) — живёт МЕЖДУ релизами
└── current → releases/c5d2a91…/
```

- **Switch на новый релиз:** `ln -sfn releases/<new-sha> current`, затем `pm2 delete` + `pm2 start` (боевой урок: `pm2 restart`/`reload` кэширует resolved-путь симлинка и продолжает крутить старый релиз).
- **Rollback:** переключить симлинк на предыдущий sha и так же перезапустить процесс — см. § «Откат прода» ниже.
- **Cleanup:** workflow держит последние 5 релизов prod (3 для dev) — `ls -1tr releases | head -n -5 | xargs rm -rf`. **`shared/` деплой и cleanup не трогают** — лиды переживают любые релизы; в `.env` прописан абсолютный путь `LEADS_DIR=/home/deploy/prod/{site}/shared/data`, симлинк в релиз не нужен.
- **Первый деплой:** до первого workflow в `~/prod/{site}/` есть только пустые `releases/` и `shared/data/`; `current` создаётся первым же успешным запуском, дальше PM2 живёт на `current/server.js`.

## Собственность

- **Mac и локальная папка** — у разработчика. **GitHub-репо** — владелец обычно заказчик, разработчик — collaborator (для собственных проектов разработчик = владелец). **VPS, домен, SSL** — заказчик (или разработчик для собственных).
- При уходе разработчика: удалить его из GitHub collaborators + снять его SSH-ключ с VPS — всё продолжает работать. См. `specs/12-handoff.md`.

## Ветки

- `main` — прод. Пушим сюда **только через Pull Request** (protected branch); перед merge — проверь preview на `dev.domain.com` (если настроен).
- `dev` — интеграционная ветка для preview. Разработчик пушит сюда напрямую.
- Feature-ветки (`feat/*`, `fix/*`) — по желанию для крупных задач с PR в `dev`.

## Preview для заказчика

По желанию проекта. Варианта два:

1. **Поддомен `dev.domain.com` на том же VPS.** GitHub Actions деплоит ветку `dev` в папку `~/dev/{site}/` с отдельным портом (4xxx) и отдельным блоком в Caddyfile. Плюс: всегда свежая копия, та же среда что и прод. Минус: ещё один PM2-процесс + ещё один блок в `Caddyfile.d/{site}.caddy` (SSL Caddy выпустит сам).
2. **Cloudflare Tunnel / ngrok с Mac.** Быстрый временный публичный URL к `localhost:3000`. Плюс: никакой инфры. Минус: работает только пока Mac запущен и тоннель открыт — на продакшн-preview не годится.

Для клиентских проектов по умолчанию — вариант 1. Для MVP/демок — 2.

## Как выглядит GitHub Actions

Канонический шаблон workflow — `_BUILD/templates/deploy-prod.yml.example`. Спека `01b-server-handoff` копирует его в `.github/workflows/deploy-prod.yml` без изменений (все per-site значения вынесены в Variables/Secrets).

**Один job `build-and-deploy`** (runs-on: ubuntu-latest, environment: production). Разделение на два job-а через `upload-artifact`/`download-artifact` не используем — боевой урок: квота артефактов аккаунта забивается за несколько недель деплоев и роняет пайплайн.

Шаги:

1. Checkout, `pnpm install --frozen-lockfile`.
2. `pnpm build` — переменные `NEXT_PUBLIC_*` приходят из secrets GitHub Environment (`production`/`dev`) и запекаются в standalone-сборку.
3. Pack: `cp -r .next/standalone/. deploy/`, `cp -r .next/static deploy/.next/static`, `cp -r public deploy/public`, затем `tar -czf release.tar.gz -C deploy .` + `gzip -t` — битый архив ловим ещё на runner-е.
4. Setup SSH из `secrets.SSH_PRIVATE_KEY` (`ed25519`) + `ssh-keyscan` в `known_hosts`.
5. Upload and unpack release: `scp release.tar.gz` на VPS во `/tmp/`, там `gzip -t` (архив мог побиться при передаче), распаковка в `releases/<github.sha>/` и проверка наличия `server.js` — всё **до** переключения симлинка; нет `server.js` → exit 1.
6. Write `.env` из `secrets.PROD_ENV_FILE` heredoc-ом в `releases/<sha>/.env`, `chmod 600`.
7. Активация: `ln -sfn releases/<sha> current`, затем `pm2 delete {site}-prod || true` и `PORT={port} HOSTNAME=127.0.0.1 pm2 start current/server.js --name {site}-prod`, `pm2 save`. `PORT`/`HOSTNAME=127.0.0.1` — env ОС при каждом старте (standalone `server.js` читает их из окружения процесса, не из `.env`); после смены симлинка — только `delete` + `start` (почему не `restart`/`reload` — § «Структура релизов» выше).
8. Healthcheck: `curl -sI http://127.0.0.1:{port}` → не 200 → **автооткат**: симлинк возвращается на предыдущий релиз, процесс перезапускается (`delete` + `start`), workflow падает красным.
9. Cleanup: `ls -1tr releases | head -n -5 | xargs rm -rf` (last 5 для prod, last 3 для dev). `shared/` не трогается.

**Аналогичный `deploy-dev.yml`** (`_BUILD/templates/deploy-dev.yml.example`) — для ветки `dev`, environment `dev`, путь `~/dev/{site}/`.

**`concurrency`** на per-site группе с `cancel-in-progress: false`: параллельные деплои встают в очередь, чтобы две выгрузки (scp + распаковка) в одну `releases/<sha>/` не порвали релиз.

**Секреты и переменные GitHub:**

| Где | Имя | Что |
|---|---|---|
| Environment `production` (secret) | `SSH_PRIVATE_KEY` | Приватная часть `~/.ssh/{site}-deploy` (single-purpose). На VPS лежит только публичная часть в `authorized_keys`. |
| Environment `production` (secret) | `SSH_HOST` | IP VPS. |
| Environment `production` (secret) | `SSH_USER` | `deploy`. |
| Environment `production` (secret) | `SSH_PORT` | Кастомный SSH-порт (по дефолту `2222`). |
| Environment `production` (secret) | `PROD_ENV_FILE` | Содержимое `.env.production` целиком (multiline). |
| Environment `production` / `dev` (secret) | `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `NEXT_PUBLIC_YM_ID`, `NEXT_PUBLIC_GA_ID` | Используются на билде в standalone-сборке (если применимо). |
| Repository (variable) | `SITE_NAME` | Имя сайта = имя PM2-процесса = `{site}` в путях VPS. |
| Repository (variable) | `PROD_PORT` (и `DEV_PORT` для dev-workflow) | Порт из реестра `~/ports.md` на VPS; шаблоны yml подставляют `vars.PROD_PORT`/`vars.DEV_PORT` в `PORT=` на `pm2 start`. |

Менять `PROD_ENV_FILE` после правки локального `.env.production`:
```bash
gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} \
  < ~/projects/{site}/.env.production
git commit --allow-empty -m "chore: bump env" && git push origin main
```

## Ежедневный цикл

На Mac:
```bash
cd ~/projects/{site}
pnpm dev                    # localhost:3000
# правим код через Claude Desktop
git add -A && git commit -m "feat: ..."
git push origin dev          # deploy-dev.yml → dev.domain.com
# проверили, всё ок → PR dev → main → merge → deploy-prod.yml → domain.com
```

Claude Desktop в это время работает с файлами в `~/projects/{site}` и пушит через `git` / `gh`. На VPS он ходит по SSH по канону `CLAUDE.md`: read-only проверки деплоя (`pm2 status`, `ls releases/`, `curl -I`), предупредив пользователя, что именно собирается сделать.

## Откат прода

Это основное описание отката (реализация скрипта — `docs/automation.md` § rollback). С Mac разработчика:

```bash
cd ~/projects/{site}
PROD_PORT={port} scripts/rollback.sh   # порт — repo variable PROD_PORT / ~/ports.md на VPS / references.md
```

Скрипт переключает симлинк `~/prod/{site}/current` на предыдущий релиз (последний по mtime в `releases/`, исключая текущий) и перезапускает процесс: `pm2 delete {site}-prod` + `PORT={port} HOSTNAME=127.0.0.1 pm2 start current/server.js --name {site}-prod` (`reload` после смены симлинка не годится — кэширует resolved-путь). Секунды, без пересборки.

После — на Mac разработчик:
```bash
git revert <bad-commit> && git push origin main   # для merge-коммита: git revert -m 1 <hash>
```
Actions соберёт чистый релиз поверх. Откатанный релиз остаётся в `releases/<sha>/` пока его не подчистит cleanup-step (last-5/last-3).

После успешного релиза полезно ставить тег `git tag stable-YYYY-MM-DD && git push --tags` — чтобы было видно проверенные точки в `git log`.

## Git-дисциплина

- **Не коммитим:** `.env*`, `data/`, `node_modules/`, сборки, логи. См. `.gitignore`.
- Остальное (сообщения коммитов, ребейз после `gh pr merge`) — `docs/workflow.md` § Git-дисциплина; ветки — § «Ветки» выше.

## Связанные файлы

- **Ручной сетап VPS** (делаешь ты, один раз на VPS): `docs/server-manual-setup.md`
- **Добавить сайт на готовый VPS** (делаешь ты, один раз на сайт): `docs/server-add-site.md`
- **Как уживаются несколько сайтов:** `docs/server-multisite.md`
- **Подключение домена:** `docs/domain-connect.md`
- **Передача проекта заказчику:** `specs/12-handoff.md`.

## Cloudflare (опционально, поверх схемы)

**Когда подключать:** трафик > 1k/день, нужны DDoS-защита / WAF / global CDN, или просто бесплатный edge-кэш.

**Базовая настройка:**
1. Делегируй NS домена на Cloudflare (через регистратора).
2. SSL/TLS mode: **Full (strict)** — чтобы CF проверял Let's Encrypt-сертификат, выписанный Caddy.
3. Always Use HTTPS: ON.
4. Brotli: ON.
5. Caching → Browser Cache TTL: Respect Existing Headers.
6. Cache Rules для статики `*/_next/static/*` — Cache Everything, Edge TTL = 1 month. (Page Rules и Auto Minify Cloudflare удалил в 2024 — если встречаешь их в чужих гайдах, это устаревшее.)

**Подводные камни:**
- **HTTP-01 challenge через Cloudflare proxy не работает** — CF перехватывает `/.well-known/acme-challenge/`. Чтобы Caddy мог выписать первый сертификат: временно выключи proxy (серое облачко = DNS only), дождись выпуска (`journalctl -u caddy | grep "certificate obtained"`), включи proxy обратно. Альтернатива — DNS-01 challenge через Caddy plugin для Cloudflare (`xcaddy build` с `caddy-dns/cloudflare`), но это отдельная сборка Caddy.
- Cloudflare кеширует HTML — после релиза контент может не обновиться. Решение: не кэшировать `.html`, либо purge по API в GitHub Actions после деплоя.
- IP клиента в логах Caddy = IP Cloudflare. Чтобы видеть реальный — добавь в site-блок `Caddyfile.d/{site}.caddy` директиву `trusted_proxies cloudflare` + Caddy-плагин `caddy-trusted-proxy-cloudflare` (или вручную перечисли CF-диапазоны).

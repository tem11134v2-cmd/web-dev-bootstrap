# Deploy

Push-based deploy: разработка на Mac → push в GitHub → GitHub-runner собирает standalone-артефакт → rsync на VPS в `releases/<sha>/` → атомарный switch симлинка `current/` → `pm2 reload`. На VPS нет ни git, ни pnpm, ни build toolchain — только Node runtime + Caddy + PM2.

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
                                  │ pnpm install --frozen   │
                                  │ pnpm build (standalone) │
                                  │ pack: .next/standalone  │
                                  │     + .next/static       │
                                  │     + public/            │
                                  └──────┬───────────────────┘
                                         │ rsync -az --delete (SSH)
                                         │ + write .env from secret
                                         │ + ln -sfn current
                                         │ + pm2 reload
                                         ▼
                                  ┌──────────────────────────┐
                                  │ VPS (Node + Caddy + PM2) │
                                  │  ~/prod/{site}/          │
                                  │    releases/<sha-1>/     │
                                  │    releases/<sha-2>/     │
                                  │    releases/<sha-3>/  ←  │
                                  │    current ───────┘      │
                                  │       │                  │
                                  │       ▼ pm2 reload       │
                                  │   localhost:3010         │
                                  │       ▼                  │
                                  │     Caddy + ACME         │
                                  │   {domain}, www.{domain} │
                                  │   dev.{domain} (опц.)    │
                                  └──────────────────────────┘
```

## Структура релизов на VPS

Push-based deploy кладёт каждый билд в `releases/<sha>/` и переключает симлинк `current` атомарно. Это даёт мгновенный rollback (`ln -sfn` обратно) и нулевой даунтайм при `pm2 reload`.

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
└── current → releases/c5d2a91…/
```

- **Switch на новый релиз:** `ln -sfn releases/<new-sha> current && pm2 reload {site}-prod`. Атомарно, без перезапуска процесса с холодного старта.
- **Rollback:** `scripts/rollback.sh` находит предыдущий sha, переключает симлинк обратно, делает `pm2 reload`. Без пересборки — миллисекунды.
- **Cleanup:** workflow держит последние 5 релизов prod (3 для dev) — `ls -1tr releases | head -n -5 | xargs rm -rf`.
- **Первый деплой:** до первого workflow в `~/prod/{site}/` есть только пустая папка `releases/`; `current` создаётся первым же успешным запуском, дальше PM2 живёт на `current/server.js`.

Подробности по созданию папки и доступам — `docs/server-add-site.md`.

## Собственность

- **Mac и локальная папка** — у разработчика.
- **GitHub-репо** — владелец обычно заказчик; разработчик — collaborator. Для собственных проектов разработчик = владелец.
- **VPS, домен, SSL** — заказчик (или разработчик для собственных).
- При уходе разработчика: удалить его из GitHub collaborators + снять его SSH-ключ с VPS (если был) — всё продолжает работать. См. `specs/12-handoff.md`.

## Ветки

- `main` — прод. Пушим сюда **только через Pull Request** (protected branch).
- `dev` — интеграционная ветка для preview. Разработчик пушит сюда напрямую.
- Feature-ветки (`feat/*`, `fix/*`) — по желанию для крупных задач с PR в `dev`.

Коммиты — на английском, по подзадачам (см. `docs/workflow.md`).

## Preview для заказчика

По желанию проекта. Варианта два:

1. **Поддомен `dev.domain.com` на том же VPS.** GitHub Actions деплоит ветку `dev` в папку `~/dev/{site}/` с отдельным портом (4xxx) и отдельным блоком в Caddyfile. Плюс: всегда свежая копия, та же среда что и прод. Минус: ещё один PM2-процесс + ещё один блок в `Caddyfile.d/{site}.caddy` (SSL Caddy выпустит сам).
2. **Cloudflare Tunnel / ngrok с Mac.** Быстрый временный публичный URL к `localhost:3000`. Плюс: никакой инфры. Минус: работает только пока Mac запущен и тоннель открыт — на продакшн-preview не годится.

Для клиентских проектов по умолчанию — вариант 1. Для MVP/демок — 2.

## Как выглядит GitHub Actions

Канонический шаблон workflow — `_BUILD/v3/templates/deploy-prod.yml.example`. Спека `01b-server-handoff` копирует его в `.github/workflows/deploy-prod.yml` без изменений (все per-site значения вынесены в Variables/Secrets).

Структура двух job-ов:

1. **`build`** (runs-on: ubuntu-latest):
   - `pnpm install --frozen-lockfile`
   - `pnpm build` — переменные `NEXT_PUBLIC_*` приходят из Repository/Environment secrets и попадают в standalone-сборку.
   - Pack: `cp -r .next/standalone/. deploy/`, `cp -r .next/static deploy/.next/static`, `cp -r public deploy/public`.
   - `actions/upload-artifact` под именем `app`.

2. **`deploy`** (needs: build, environment: production):
   - `actions/download-artifact` `app` → `deploy/`.
   - Setup SSH из `secrets.SSH_PRIVATE_KEY` (`ed25519`) + `ssh-keyscan` в `known_hosts`.
   - `rsync -az --delete -e "ssh -i …" deploy/ deploy@VPS:releases/<github.sha>/`
   - Write `.env` из `secrets.PROD_ENV_FILE` heredoc-ом в `releases/<sha>/.env`, `chmod 600`.
   - `ln -sfn releases/<sha> current && pm2 reload {site}-prod --update-env` (при первом деплое — `pm2 start current/server.js`).
   - Cleanup: `ls -1tr releases | head -n -5 | xargs rm -rf` (last 5 для prod, last 3 для dev).

**Аналогичный `deploy-dev.yml`** — для ветки `dev`, environment `dev`, путь `~/dev/{site}/`.

**`concurrency`** на per-site группе с `cancel-in-progress: false`: параллельные деплои встают в очередь, чтобы два rsync-а в одну `releases/<sha>/` не порвали артефакт.

**Секреты и переменные GitHub:**

| Где | Имя | Что |
|---|---|---|
| Environment `production` (secret) | `SSH_PRIVATE_KEY` | Приватная часть `~/.ssh/{site}-deploy` (single-purpose). На VPS лежит только публичная часть в `authorized_keys`. |
| Environment `production` (secret) | `SSH_HOST` | IP VPS. |
| Environment `production` (secret) | `SSH_USER` | `deploy`. |
| Environment `production` (secret) | `SSH_PORT` | Кастомный SSH-порт (по дефолту `2222`). |
| Environment `production` (secret) | `PROD_ENV_FILE` | Содержимое `.env.production` целиком (multiline). |
| Repository (secret) | `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `NEXT_PUBLIC_YM_ID`, `NEXT_PUBLIC_GA_ID` | Используются на билде в standalone-сборке (если применимо). |
| Repository (variable) | `SITE_NAME` | Имя сайта = имя PM2-процесса = `{site}` в путях VPS. |

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

Claude Desktop в это время:
- работает с файлами в `~/projects/{site}`;
- пушит через `git` / `gh` (не через SSH на сервер — туда он не ходит).

## Откат прода

С Mac разработчика (НЕ заходя на VPS):

```bash
cd ~/projects/{site}
scripts/rollback.sh
```

Скрипт переключает симлинк `~/prod/{site}/current` на предыдущий релиз (последний по mtime в `releases/`, исключая текущий) и делает `pm2 reload {site}-prod --update-env`. Атомарно, миллисекунды, без пересборки. См. `docs/automation.md` § rollback.

После — на Mac разработчик:
```bash
git revert <bad-commit>
# для merge-коммита — git revert -m 1 <hash>
git push origin main
```
Actions соберёт чистый релиз поверх. Откатанный релиз остаётся в `releases/<sha>/` пока его не подчистит cleanup-step (last-5/last-3).

После успешного релиза полезно ставить тег `git tag stable-YYYY-MM-DD && git push --tags` — чтобы было видно проверенные точки в `git log`.

## Git-дисциплина

- **Никогда не пушим напрямую в `main`** — только через PR из `dev` (protected branch защищает).
- **Не коммитим:** `.env*`, `data/leads.json`, `node_modules/`, сборки, логи. См. `.gitignore`.
- Перед merge `dev → main` — проверь preview на `dev.domain.com` (если настроен).
- Коммит-сообщения на английском, краткие, в настоящем времени (`fix: handle empty form`, не `fixed`).

## Связанные файлы

- **Ручной сетап VPS** (делаешь ты, один раз на VPS): `docs/server-manual-setup.md`
- **Добавить сайт на готовый VPS** (делаешь ты, один раз на сайт): `docs/server-add-site.md`
- **Как уживаются несколько сайтов:** `docs/server-multisite.md`
- **Подключение домена:** `docs/domain-connect.md`
- **Cloudflare** (опционально): секция ниже.
- **Передача проекта заказчику:** `specs/12-handoff.md`.

## Cloudflare (опционально, поверх схемы)

**Когда подключать:** трафик > 1k/день, нужны DDoS-защита / WAF / global CDN, или просто бесплатный edge-кэш.

**Базовая настройка:**
1. Делегируй NS домена на Cloudflare (через регистратора).
2. SSL/TLS mode: **Full (strict)** — чтобы CF проверял Let's Encrypt-сертификат, выписанный Caddy.
3. Always Use HTTPS: ON.
4. Auto Minify (CSS/JS/HTML): OFF — Next уже делает.
5. Brotli: ON.
6. Caching → Browser Cache TTL: Respect Existing Headers.
7. Page Rules для статики `*/_next/static/*` — Cache Everything, Edge TTL = 1 month.

**Подводные камни:**
- **HTTP-01 challenge через Cloudflare proxy не работает** — CF перехватывает `/.well-known/acme-challenge/`. Чтобы Caddy мог выписать первый сертификат: временно выключи proxy (серое облачко = DNS only), дождись выпуска (`journalctl -u caddy | grep "certificate obtained"`), включи proxy обратно. Альтернатива — DNS-01 challenge через Caddy plugin для Cloudflare (`xcaddy build` с `caddy-dns/cloudflare`), но это отдельная сборка Caddy.
- Cloudflare кеширует HTML — после релиза контент может не обновиться. Решение: не кэшировать `.html`, либо purge по API в GitHub Actions после деплоя.
- IP клиента в логах Caddy = IP Cloudflare. Чтобы видеть реальный — добавь в site-блок `Caddyfile.d/{site}.caddy` директиву `trusted_proxies cloudflare` + Caddy-плагин `caddy-trusted-proxy-cloudflare` (или вручную перечисли CF-диапазоны).

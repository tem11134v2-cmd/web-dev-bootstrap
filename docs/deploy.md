# Deploy

Одна схема на всё: разработка на Mac → push в GitHub → GitHub Actions разворачивает на VPS.

## Общая картина

```
┌─────────────────────┐     git push      ┌──────────────┐
│  Mac (Claude Code)  │ ─────────────────▶│  GitHub repo │
│  ~/projects/{site}  │                   │  branches:   │
│  localhost:3000     │                   │  - main      │
└─────────────────────┘                   │  - dev       │
                                          └──────┬───────┘
                                                 │ GitHub Actions
                                                 │ (on push)
                                                 ▼
                                   ┌─────────────────────────┐
                                   │   VPS (ты настроил      │
                                   │   руками, см.           │
                                   │   server-manual-setup)  │
                                   │                         │
                                   │  ~/prod/{site}/  :3010  │ ← main
                                   │  ~/dev/{site}/   :4010  │ ← dev (опц.)
                                   │         ▼               │
                                   │      Caddy + ACME       │
                                   │    domain.com           │
                                   │    dev.domain.com (опц.)│
                                   └─────────────────────────┘
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

Файл `.github/workflows/deploy-prod.yml` (создаётся в спеке `01b-server-handoff`):

```yaml
name: Deploy prod
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.DEPLOY_SSH_KEY }}
      - run: |
          ssh -o StrictHostKeyChecking=no deploy@${{ secrets.SERVER_IP }} "
            cd ~/prod/${{ vars.SITE_NAME }} && \
            git pull origin main && \
            pnpm install --frozen-lockfile && \
            pnpm build && \
            pm2 restart ${{ vars.SITE_NAME }}-prod
          "
```

Аналогичный `deploy-dev.yml` для ветки `dev` — если заказчику нужен preview.

**Секреты и переменные GitHub:**
- `DEPLOY_SSH_KEY` (secret) — приватный ключ, публичную часть ты положил в `~/.ssh/authorized_keys` на VPS руками.
- `SERVER_IP` (secret) — IP сервера.
- `SITE_NAME` (variable) — имя проекта, оно же имя папки на VPS и имя PM2-процесса.

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

Если релиз сломал прод — зайти на VPS руками:

```bash
ssh deploy@{server-ip}
cd ~/prod/{site}
git log --oneline -5
git reset --hard {commit-hash}
pnpm install --frozen-lockfile && pnpm build && pm2 restart {site}-prod
```

После успешного релиза полезно ставить тег `git tag stable-YYYY-MM-DD && git push --tags` — чтобы было откуда откатываться.

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

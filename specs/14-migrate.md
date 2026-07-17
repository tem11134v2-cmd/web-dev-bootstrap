# Spec 14: Migrate site (между серверами или в рамках handoff)

> Оркестрация: интерактив (SSH-ops, ведёт оркестратор с подтверждениями человека), субагенту не отдаётся; SSH — по канону CLAUDE.md (предупреждать пользователя, изменения только батчированными идемпотентными скриптами); параллель: нет; verifier: не нужен (гейт = curl/dig-проверки + soak 7 дней)

## KB files to read first

- docs/deploy.md (push-based flow, структура `releases/<sha>/`)
- docs/server-manual-setup.md (если целевой VPS свежий)
- docs/server-add-site.md (подключение сайта на готовый VPS)
- `.claude/memory/references.md` (IP текущего VPS, порты, пути)

## Goal

Перенести сайт с одного VPS на другой **без потери данных**, с контролируемым переключением DNS и предсказуемым decommission старого VPS.

## Входные данные (Claude спрашивает)

- **Сценарий.** M1 (на более мощный VPS у того же владельца) / M2 (на VPS заказчика при handoff) / M3 (экстренный) / M4 (клон на новый домен).
- **Старый VPS.** IP, SSH-алиас, пути `~/prod/{site}/releases/`, `~/prod/{site}/current` (симлинк), PM2-имена, порт из `~/ports.md`.
- **Новый VPS.** Свежий или уже bootstrap'нут? Если свежий — запусти сначала `bootstrap-vps.sh`.
- **Domain.** Тот же или новый? (для M4 — новый).
- **Downtime toleration.** Для M1/M2 — ноль (через CF proxy / dual-write). Для M3 — 5–15 мин.

## Tasks

### 1. Подготовить новый VPS

1. Если свежий — `bootstrap-vps.sh` (см. `docs/server-manual-setup.md`). На VPS будут только Node runtime + Caddy + PM2; ни git, ни pnpm там нет (push-based deploy). Получить IP, кастомный SSH-порт.
2. Проверить `~/ports.md` нового — зарезервировать пару портов для переезжающего сайта (можно те же, что и на старом, если свободно).

### 2. Подключить сайт на новом VPS

3. На новом VPS под `deploy`:
   ```bash
   ssh deploy@new-vps 'mkdir -p ~/prod/{site}/releases'
   ```
4. Положить публичную часть deploy-ключа разработчика в `~/.ssh/authorized_keys` пользователя `deploy` на новом VPS:
   ```bash
   ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@new-vps
   ```
5. Положить Caddy-конфиг с подменённым upstream-портом (если порт меняется) — батчированно, без интерактивных правок. Файл `deploy/{site}.caddy.example` лежит в репо на Mac (деплой-артефакт папку `deploy/` на VPS не привозит):
   ```bash
   # с Mac, из папки проекта:
   scp -P {ssh-port} deploy/{site}.caddy.example deploy@new-vps:/tmp/
   # на новом VPS:
   sudo mv /tmp/{site}.caddy.example /etc/caddy/Caddyfile.d/{site}.caddy
   # если порт на новом VPS другой — подменить неинтерактивно:
   sudo sed -i 's/127.0.0.1:{old-port}/127.0.0.1:{new-port}/' /etc/caddy/Caddyfile.d/{site}.caddy
   grep reverse_proxy /etc/caddy/Caddyfile.d/{site}.caddy   # сверить порт глазами
   sudo caddy validate --config /etc/caddy/Caddyfile && sudo systemctl reload caddy
   ```
   Caddy ничего не выпустит, пока DNS не указывает на новый IP — это нормально, обработка ACME отложится до § 5.

### 3. Перенести runtime-данные

6. Перенести то, что **не в git и не в standalone-сборке**. Главное — `~/prod/{site}/shared/data` (fallback-лиды `leads.jsonl`, `LEADS_DIR`): она живёт вне `releases/`, деплой её не трогает, переносится один-в-один:
   ```bash
   # с Mac:
   ssh deploy@new-vps 'mkdir -p ~/prod/{site}/shared/data'
   # rsync два remote в одной команде не умеет («The source and destination cannot
   # both be remote») — гоняем со старого VPS, зайдя с agent forwarding (ssh -A):
   ssh -A deploy@old-vps \
     'rsync -az ~/prod/{site}/shared/data/ deploy@new-vps:~/prod/{site}/shared/data/'
   # если есть uploads (вне git, внутри релиза):
   ssh -A deploy@old-vps \
     'rsync -az ~/prod/{site}/current/public/uploads/ deploy@new-vps:~/prod/{site}/releases/_seed-uploads/'
   ```
   Если agent forwarding недоступен (ключ не в агенте / провайдер режет) — два прыжка через Mac: `rsync -az old-vps:...` во временную папку на Mac, затем `rsync -az` из неё на new-vps.
   `_seed-uploads/` — временная: после первого деплоя перенеси её содержимое в активный релиз (`cp -r ... current/public/uploads/`). На старых проектах (до v4) fallback-лиды могли лежать в `current/data/leads.json` — проверь и захвати их тоже. Источник истины для лидов — подключённые каналы (почта/CRM), `leads.jsonl` это fallback.

### 4. Обновить GitHub Environment Secrets

7. В репо → Settings → Environments → `production` (и `dev` если есть):
   - `SSH_HOST` → новый IP.
   - `SSH_PORT` → кастомный порт нового VPS (если отличается).
   - `SSH_PRIVATE_KEY` — содержимое того же `~/.ssh/{site}-deploy` приватного ключа разработчика (он же был в старом environment'е). Если делаешь ротацию ключа в рамках миграции — сгенерируй новый, положи публичную часть в `authorized_keys` нового VPS (§ 2.4), приватную загрузи через `gh secret set --env production SSH_PRIVATE_KEY`.
   - `PROD_ENV_FILE` — без изменений, **если только** провайдер не блокирует исходящий трафик к каким-то IP / API-ключи не надо ротировать.
8. Триггернуть workflow пушем пустого коммита (`git commit --allow-empty -m "chore: redeploy to new VPS"`) или `Actions → Re-run`. Должен собраться билд на runner-е, артефакт уехать tar.gz-ом (scp) на новый VPS, симлинк переключиться, PM2 стартануть.

### 5. DNS switchover

9. Обновить A-запись `{domain}` → новый IP у регистратора (или в Cloudflare, если используется). GUI регистратора — **делает человек** (канон CLAUDE.md); Claude даёт точное значение записи.
10. Подождать распространения: `dig +short {domain}` — проверяет Claude; новый IP должен возвращаться стабильно. Обычно 5–30 минут.
11. SSL Caddy на новом VPS выпустит автоматически при первом HTTPS-запросе (HTTP-01 challenge). Никаких `certbot` вызовов делать не нужно. Проверь:
    ```bash
    curl -I https://{domain}
    ssh deploy@new-vps 'sudo journalctl -u caddy --since "5 min ago" | grep -i "certificate obtained"'
    ```
12. Открой `https://{domain}` — должна быть новая версия со стандартным баннером Caddy в заголовках (Server: Caddy).

### 6. Soak и decommission

13. **7 дней** держать старый VPS включённым, Caddy + PM2 работают. На случай, если надо откатить DNS обратно.
14. После 7 дней (или раньше, если уверен). Перед `rm` — убедиться, что `~/prod/{site}/shared/data` (fallback-лиды) перенесена в § 3 или выгружена:
    ```bash
    ssh deploy@old-vps
    pm2 delete {site}-prod {site}-dev 2>/dev/null
    pm2 save
    sudo rm /etc/caddy/Caddyfile.d/{site}.caddy
    sudo caddy validate --config /etc/caddy/Caddyfile && sudo systemctl reload caddy
    rm -rf ~/prod/{site} ~/dev/{site}
    # Удалить строку в ~/ports.md (порты возвращаются в пул)
    ```
15. Если сайт был единственным на старом VPS — выключить VPS у провайдера. Не удалять первые 7 дней даже после decom (вдруг пропустили что-то).

### 7. Обновить память

16. `.claude/memory/references.md` — новый IP, SSH-путь, порты.
17. `.claude/memory/decisions.md` — дата миграции, причина, результат.
18. `.claude/memory/project_state.md` — отметить событие «migrated to {new-ip} on {date}».

## Boundaries

- **Always:** перед DNS switch — убедиться, что новый VPS отвечает на `curl -H 'Host: {domain}' http://new-vps-ip` правильным контентом.
- **Always:** перед `rm` папок старого VPS — убедиться, что сайт работает на новом (`curl -I https://{domain}` показывает свежий артефакт; в логе Caddy на новом — реальные запросы).
- **Ask first:** перед выключением старого VPS у провайдера (необратимо в зависимости от тарифа).
- **Never:** `scp` `.env` в git. Перенос секретов — через GitHub Secrets, не через диск.
- **Never:** снимать DNS со старого IP до того, как новый принимает трафик.

## Для M3 (экстренная миграция)

Сокращённая версия:
- Bootstrap нового VPS + add-site (`mkdir releases/`, ssh-copy-id, Caddyfile.d/) — за 15 мин.
- Обновить `SSH_HOST` в Environment секрете → запустить workflow пустым коммитом → ждать прохождения билда (~3 мин на runner).
- DNS переключить — Caddy выпишет SSL автоматически после propagate.
- `shared/data/leads.jsonl` — `rsync` со старого VPS, если он ещё в сети; иначе восстановить лиды из подключённых каналов (почта/CRM).
- Клиенту сразу сообщить: «Сайт переезжает, возможен downtime до 15 минут».
- Soak и decommission по обычному плану.

## Для M4 (клон на другой домен)

- `gh repo create --template <source-repo> tem11134v2-cmd/{new-site} --private --clone`.
- Пройти как новый сайт: `_BUILD/HOW-TO-START.md` §0-§3 → `specs/00 → 14`.
- `docs/spec.md`, `content.md`, `pages.md`, `integrations.md` — переписать под новый продукт.
- Новая пара портов, новая строка в `ports.md`, новый Caddy-конфиг в `Caddyfile.d/{new-site}.caddy`.
- Отдельный GitHub Environment + Secrets под новый сайт (даже если он на том же VPS — `vars.SITE_NAME` другое, разделение чистое).

## Done when

- Новый VPS принимает трафик, HTTPS работает, лиды доходят в CRM.
- На новом VPS `~/prod/{site}/current` указывает на свежий релиз, `pm2 list` показывает `{site}-prod` online.
- Старый VPS deactivated (Caddyfile.d-конфиг убран, pm2 удалён, папки чисты).
- Старый VPS в течение 7 дней остаётся «тёплым» на случай отката, потом выключается.
- `references.md` актуален.

## Memory updates

- `references.md` — IP, пути, порты.
- `decisions.md` — миграция: что, когда, почему, как прошла.
- `lessons.md` — если вылезли новые грабли — туда.

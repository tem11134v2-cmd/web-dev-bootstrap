# Spec 14: Migrate site (между серверами или в рамках handoff)

## KB files to read first

- docs/deploy.md (текущий flow)
- docs/server-manual-setup.md (если целевой VPS свежий)
- docs/server-add-site.md (подключение сайта на готовый VPS)
- `.claude/memory/references.md` (IP текущего VPS, порты, пути)

## Goal

Перенести сайт с одного VPS на другой **без потери данных**, с контролируемым переключением DNS и предсказуемым decommission старого VPS.

## Входные данные (Claude спрашивает)

- **Сценарий.** M1 (на более мощный VPS у того же владельца) / M2 (на VPS заказчика при handoff) / M3 (экстренный) / M4 (клон на новый домен).
- **Старый VPS.** IP, SSH-алиас, пути `~/prod/{site}` и опц. `~/dev/{site}`, PM2-имена, порт из `~/ports.md`.
- **Новый VPS.** Свежий или уже bootstrap'нут? Если свежий — запусти сначала `bootstrap-vps.sh`.
- **Domain.** Тот же или новый? (для M4 — новый).
- **Downtime toleration.** Для M1/M2 — ноль (через CF proxy / dual-write). Для M3 — 5–15 мин.

## Tasks

### 1. Подготовить новый VPS

1. Если свежий — `bootstrap-vps.sh` (см. `docs/server-manual-setup.md`). Получить IP, публичный `~/.ssh/deploy_key.pub`.
2. Проверить `~/ports.md` нового — зарезервировать пару портов для переезжающего сайта (можно те же, что и на старом, если свободно).

### 2. Подключить сайт на новом VPS

3. Пройти `docs/server-add-site.md` на новом сервере: папки, клон `main`, `pnpm install --frozen-lockfile && pnpm build`, `PORT=... pm2 start`, Caddy-конфиг (SSL Caddy выпустит автоматически после переключения DNS).
4. Не запускать `certbot` пока — валидация упадёт, домен ещё не смотрит сюда.

### 3. Перенести runtime-данные

5. `scp` того, что **не в git**:
   ```bash
   # на Mac или с нового VPS:
   rsync -avz old-vps:/home/deploy/prod/{site}/data/ new-vps:/home/deploy/prod/{site}/data/
   # если есть uploads:
   rsync -avz old-vps:/home/deploy/prod/{site}/public/uploads/ new-vps:/home/deploy/prod/{site}/public/uploads/
   ```
6. Источник истины для лидов — CRM, `data/leads.json` это fallback. Если файла нет или устарел — не критично.
7. `.env` на новом VPS скопировать/создать руками. **Никогда не через git.**

### 4. Обновить GitHub Secrets

8. В репо → Settings → Secrets and variables → Actions:
   - `SERVER_IP` → новый IP.
   - `DEPLOY_SSH_KEY` → приватный `~/.ssh/deploy_key` с **нового** VPS (или сохрани старый ключ, и публичную часть положи в `authorized_keys` нового — быстрее, но плодит ключи).
9. Триггернуть workflow вручную (`Actions` → `Re-run jobs`) или пушем пустого коммита. Билд должен пройти на новом сервере.

### 5. DNS switchover

10. Обновить A-запись `{domain}` → новый IP у регистратора (или в Cloudflare, если используется).
11. Подождать распространения: `dig +short {domain}` с разных машин должен возвращать новый IP. Обычно 5–30 минут.
12. **Теперь** на новом VPS: `sudo certbot --nginx -d {domain}` — выпишет SSL.
13. Проверить `https://{domain}` — открывается новая версия.

### 6. Soak и decommission

14. **7 дней** держать старый VPS включённым, nginx + PM2 работают. На случай, если надо откатить DNS обратно.
15. После 7 дней (или раньше, если уверен):
    ```bash
    ssh old-vps
    pm2 delete {site}-prod {site}-dev 2>/dev/null
    pm2 save
    sudo rm /etc/nginx/sites-enabled/{site} /etc/nginx/sites-available/{site}
    sudo nginx -t && sudo systemctl reload nginx
    rm -rf ~/prod/{site} ~/dev/{site}
    # Удалить строку в ~/ports.md (порты возвращаются в пул)
    ```
16. Если сайт был единственным на старом VPS — выключить VPS у провайдера. Не удалять первые 7 дней даже после decom (вдруг пропустили что-то).

### 7. Обновить память

17. `.claude/memory/references.md` — новый IP, SSH-путь, порты.
18. `.claude/memory/decisions.md` — дата миграции, причина, результат.
19. `.claude/memory/project_state.md` — отметить событие «migrated to {new-ip} on {date}».

## Boundaries

- **Always:** перед `certbot` — проверить `dig` что домен смотрит на новый IP. Иначе валидация упадёт и выжжет лимит Let's Encrypt.
- **Always:** перед `rm` папок старого VPS — убедиться, что сайт работает на новом (`curl -I https://{domain}` отдаёт 200 с нового сервера — проверить через `tail -f /var/log/nginx/access.log` на новом).
- **Ask first:** перед выключением старого VPS у провайдера (необратимо в зависимости от тарифа).
- **Never:** `scp` `.env` в git. `scp` напрямую между серверами.
- **Never:** снимать DNS со старого IP до того, как новый принимает трафик.

## Для M3 (экстренная миграция)

Сокращённая версия:
- Bootstrap нового VPS + add-site за 20 мин.
- `scp` `data/leads.json` из последнего бэкапа или из CRM-экспорта.
- DNS переключить **до** выпуска SSL на новом (certbot подождёт).
- Клиенту сразу сообщить: «Сайт переезжает, возможен downtime до 15 минут».
- Soak и decommission по обычному плану.

## Для M4 (клон на другой домен)

- `gh repo create --template <source-repo> tem11134v2-cmd/{new-site} --private --clone`.
- Пройти как новый сайт по `specs/00.5 → 13`.
- `docs/spec.md`, `content.md`, `pages.md`, `integrations.md` — переписать под новый продукт.
- Новая пара портов, новая строка в `ports.md`, новый nginx-конфиг.

## Done when

- Новый VPS принимает трафик, HTTPS работает, лиды доходят в CRM.
- Старый VPS deactivated (nginx выключен, pm2 удалён, папки чисты).
- Старый VPS в течение 7 дней остаётся «тёплым» на случай отката, потом выключается.
- `references.md` актуален.

## Memory updates

- `references.md` — IP, пути, порты.
- `decisions.md` — миграция: что, когда, почему, как прошла.
- `lessons.md` — если вылезли новые грабли — туда.

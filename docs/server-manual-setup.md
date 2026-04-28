# Server: Initial bootstrap

Разовая настройка свежего Ubuntu-VPS. Источник истины — `scripts/bootstrap-vps.sh` (идемпотентный, протестированный на Ubuntu 24.04 Timeweb в апреле 2026). Этот документ — описание **как** этот скрипт использовать и **почему** он делает именно это.

**Формат работы:** Claude запускает скрипт по SSH сам, наблюдает результат. Разработчик подтверждает доступ к серверу и IP.

## Что нужно от разработчика

1. IP VPS, уже прогретого у провайдера (Timeweb, Hetzner, Reg.ru, любой Ubuntu 22.04/24.04).
2. Один раз выполнить с Mac:
   ```bash
   ssh-copy-id root@{ip}
   ```
   Это кладёт публичный SSH-ключ разработчика в `/root/.ssh/authorized_keys`. Разово требует root-пароль (вводится в его терминале, не в чат).
3. Сказать Claude: «сервер {ip}, запускай bootstrap».

Больше от разработчика ничего не нужно — дальше Claude.

## Что делает скрипт

| Шаг | Что |
|-----|-----|
| 1 | Создаёт пользователя `deploy` без пароля (`adduser --gecos "" --disabled-password`), добавляет в `sudo` group, копирует SSH-ключ из `/root/.ssh/authorized_keys`, прописывает `NOPASSWD:ALL` в `/etc/sudoers.d/deploy`. |
| 2 | SSH hardening через drop-in `/etc/ssh/sshd_config.d/99-hardening.conf`: `Port 2222` (nonstandard — режет фоновый брутфорс), `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`. Нейтрализует конфликтующий `50-cloud-init.conf` (на Timeweb/Hetzner там `PasswordAuthentication yes`), комментирует `PermitRootLogin yes` в основном конфиге, переключает с `ssh.socket` на `ssh.service` (иначе Port из конфига игнорируется). `sshd -t` + `systemctl restart ssh.service`. |
| 3 | UFW: deny incoming / allow outgoing / allow `SSH_PORT`, 80, 443. `ufw --force enable`. Устанавливает fail2ban (строгий jail.local: 3 попытки / 10 мин / 24 ч бан, `backend=systemd` для Ubuntu 24.04) и `unattended-upgrades` (security-only patches, без авто-reboot). |
| 4 | Swap 2GB через `fallocate`, записывает в `/etc/fstab`. Критично на VPS с ≤4 GB RAM — билд Next.js иначе падает в OOM. |
| 5 | Node.js 22 из NodeSource, Caddy (из официального apt-репо cloudsmith), git, PM2 глобально. |
| 6 | Папки `~/prod`, `~/dev` под deploy. Создаёт `~/ports.md` с шаблоном реестра (правило `prod = 3000 + N*10`, `dev = prod + 1000`). |
| 7 | Генерит deploy-ключ `~/.ssh/deploy_key` (ed25519) для GitHub Actions, публичную половину дописывает в `~/.ssh/authorized_keys` самого же deploy (чтобы Actions мог ходить на себя), дедуп через `sort -u`. |
| 8 | Кладёт базовый `/etc/caddy/Caddyfile` (глобальный `email` + `import /etc/caddy/Caddyfile.d/*.caddy`), создаёт пустую папку `/etc/caddy/Caddyfile.d/` с placeholder-блоком на `:8080`, проверяет `caddy validate`, `systemctl enable --now caddy`. |

**Чего скрипт НЕ делает:**
- **Не включает `pm2-deploy` systemd-сервис.** Сервис `pm2 startup` требует непустого dump; если вызвать `systemctl enable --now pm2-deploy` без запущенных приложений — systemd видит, что pm2 сразу вышел, и помечает unit как `failed (Result: protocol)`. Включаем сервис в `server-add-site.md` после первого `pm2 save` с реальным процессом.
- **Не выпускает SSL.** SSL выпускает Caddy автоматически при первом запросе на домен — но это происходит только когда в `Caddyfile.d/` появляется per-site конфиг (`server-add-site.md`). До первого сайта SSL негде выписывать.
- **Не ставит пароль для `deploy`.** Пароль не нужен: sudo через NOPASSWD, логин по SSH-ключу. Если когда-нибудь понадобится консольный вход через панель провайдера — задать руками: `sudo passwd deploy`.

## Как запустить

`CADDY_ADMIN_EMAIL` обязателен — Caddy использует его для регистрации в ACME (Let's Encrypt). Без email сертификаты не выпишутся.

```bash
# На Mac, откуда Claude подключается:
scp /path/to/web-dev-bootstrap/scripts/bootstrap-vps.sh root@{ip}:/tmp/
ssh root@{ip} 'CADDY_ADMIN_EMAIL=admin@example.com bash /tmp/bootstrap-vps.sh'
```

Или одной командой без scp:
```bash
ssh root@{ip} 'CADDY_ADMIN_EMAIL=admin@example.com bash -s' < /path/to/scripts/bootstrap-vps.sh
```

Или через raw URL после merge ветки в `main`:
```bash
ssh root@{ip} 'CADDY_ADMIN_EMAIL=admin@example.com bash -c "curl -fsSL https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/main/scripts/bootstrap-vps.sh | bash"'
```

Если нужно задать нестандартные значения:
```bash
ssh root@{ip} 'CADDY_ADMIN_EMAIL=admin@example.com DEPLOY_USER=dev SWAP_SIZE=4G NODE_MAJOR=22 bash -s' < scripts/bootstrap-vps.sh
```

## Параметры скрипта

| Variable | Default | Description |
|----------|---------|-------------|
| `DEPLOY_USER` | `deploy` | Имя служебного пользователя. |
| `DEPLOY_PUBKEY` | (пусто) | Публичный ключ для `authorized_keys` этого пользователя. Если не задан — берётся `/root/.ssh/authorized_keys`. Задавай, если хочешь явно зафиксировать ключ (например, запуская через cloud-init). |
| `NODE_MAJOR` | `22` | Мажорная версия Node.js. |
| `SWAP_SIZE` | `2G` | Размер swap-файла. |
| `SSH_PORT` | `2222` | На какой порт перевести SSH. Если не хочешь менять — `SSH_PORT=22`. |
| `CADDY_ADMIN_EMAIL` | — (обязателен) | Email для ACME (Let's Encrypt). На него Caddy получает уведомления об истечении сертификатов. |

### Mac-сторона: `~/.ssh/config`

После смены порта добавь в `~/.ssh/config` на Mac алиас, чтобы не писать `-p` каждый раз:

```
Host vps1 <IP>
    HostName <IP>
    User deploy
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Дальше `ssh vps1` или `ssh deploy@<IP>` работают одинаково без флагов.

## Верификация после запуска

Claude выполняет этот блок для проверки:

```bash
ssh deploy@{ip} 'bash -s' <<'EOF'
echo "== OS =="; lsb_release -d
echo "== User =="; id; sudo -n true && echo "sudo NOPASSWD: OK"
echo "== SSH hardening =="; sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication)'
echo "== Firewall =="; sudo ufw status verbose | head -10
echo "== fail2ban =="; sudo systemctl is-active fail2ban
echo "== Swap =="; swapon --show
echo "== Stack =="; node -v; caddy version; pm2 --version
echo "== Caddy =="; systemctl is-active caddy; sudo caddy validate --config /etc/caddy/Caddyfile && echo "Caddyfile valid"
echo "== Caddyfile.d =="; ls /etc/caddy/Caddyfile.d/
echo "== Folders =="; ls -ld ~/prod ~/dev; [ -f ~/ports.md ] && echo "ports.md OK"
echo "== Deploy key (public, уже в authorized_keys) =="; cat ~/.ssh/deploy_key.pub
EOF
```

Ожидаемое:
- `permitrootlogin no`, `passwordauthentication no`, `pubkeyauthentication yes`.
- `ufw` active, 22/80/443 allowed.
- `fail2ban` active.
- Swap `2G`.
- Node `v22.x`, Caddy `2.x`, pm2 `6.x`.
- Caddy active, `Caddyfile valid`, в `Caddyfile.d/` лежит `00-placeholder.caddy` (заменится на per-site конфиг при первом сайте).
- `~/prod`, `~/dev`, `~/ports.md` на месте.
- `~/.ssh/deploy_key.pub` выводится (эту строку положим в GitHub Secrets при первом сайте).

## Частые проблемы (для Claude при запуске)

| Симптом | Причина | Фикс |
|---------|---------|------|
| `ssh root@{ip}` отказывает после запуска скрипта | Скрипт отключил root-логин — это норма | Дальше работаем только `ssh deploy@{ip}` |
| `sshd -T` после хардинга показывает `passwordauthentication yes` | Провайдер положил `/etc/ssh/sshd_config.d/50-cloud-init.conf` с `PasswordAuthentication yes` | Скрипт это обрабатывает (затирает файл). Если запустили вручную без скрипта — затереть самим и `systemctl reload ssh` |
| SSH `Port 2222` задан в конфиге, но sshd слушает только 22 | Ubuntu 22.04+ использует socket activation (`ssh.socket`), который игнорирует `Port` в `sshd_config` и берёт порты из сгенерированного `ssh.socket.d/addresses.conf` | Скрипт делает `systemctl disable --now ssh.socket && systemctl enable --now ssh.service`. Дальше Port из конфига авторитативен |
| `systemctl status pm2-deploy` — failed (protocol) | Известная проблема: pm2 startup + пустой dump | Это ожидаемо **до первого сайта**. Сервис включится после `pm2 save` в `server-add-site.md` |
| `apt install` висит | Интерактивный prompt (debconf) | Все наши запуски уже под `DEBIAN_FRONTEND=noninteractive`. Если что-то проскочило — добавь `-o Dpkg::Options::="--force-confnew"` |
| Caddy слушает `:8080` после bootstrap | Это placeholder-блок до первого сайта | Удалится при добавлении первого сайта в `server-add-site.md` |
| ACME-сертификат не выпускается | Домен не указывает на VPS, либо порт 80/443 закрыт ufw | `dig +short {domain}` должен вернуть IP сервера; `sudo ufw status` — 80/443 allow |

## Обслуживание (раз в месяц)

```bash
ssh deploy@{ip} '
  sudo apt update && sudo apt upgrade -y
  pm2 logs --nostream --lines 50
  df -h
  sudo systemctl status caddy --no-pager
  sudo journalctl -u caddy --since "1 month ago" | grep -iE "error|certificate" | tail -20
'
```

Caddy сам обновляет сертификаты за ~30 дней до истечения. Ручной `certbot renew` не нужен и не существует — мы его не ставили.

## Далее

- `docs/domain-connect.md` — A-записи, `dig`, проверка перед SSL.
- `docs/server-add-site.md` — подключить первый сайт на готовый VPS.
- `docs/server-multisite.md` — когда и как уживаются несколько сайтов.

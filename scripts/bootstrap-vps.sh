#!/usr/bin/env bash
# VPS bootstrap — разовая настройка свежего Ubuntu 22.04 / 24.04.
#
# Выполняется под root (через `ssh root@IP bash -s < bootstrap-vps.sh`)
# ИЛИ уже существующим sudo-пользователем (`curl ... | sudo bash`).
#
# Idempotent: можно перезапускать, если что-то пошло не так.
# Протестирован на Ubuntu 24.04.4 (Timeweb), апрель 2026.

set -euo pipefail

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

# ─────────────────────────────────────────────
# Параметры (можно переопределить переменными окружения перед запуском)
# ─────────────────────────────────────────────
DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_PUBKEY="${DEPLOY_PUBKEY:-}"   # публичный ключ разработчика (Mac). Обязателен, иначе deploy не сможет залогиниться.
NODE_MAJOR="${NODE_MAJOR:-22}"
SWAP_SIZE="${SWAP_SIZE:-2G}"
SSH_PORT="${SSH_PORT:-2222}"         # нестандартный SSH порт — режет фоновый брутфорс-шум. Не «безопасность», а noise reduction.
CADDY_ADMIN_EMAIL="${CADDY_ADMIN_EMAIL:-}"   # email для ACME (Let's Encrypt). Обязателен — без него Caddy не выпишет SSL.

if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт должен запускаться под root." >&2
  exit 1
fi

if [ -z "$DEPLOY_PUBKEY" ]; then
  # Fallback: если запустили через `ssh root@host bash -s`, и у root уже есть
  # authorized_keys (положенные ssh-copy-id'ом), используем их для deploy.
  if [ -s /root/.ssh/authorized_keys ]; then
    log "DEPLOY_PUBKEY не задан — возьму ключи из /root/.ssh/authorized_keys"
  else
    echo "DEPLOY_PUBKEY пуст и /root/.ssh/authorized_keys отсутствует. Нечего класть в ~/${DEPLOY_USER}/.ssh/authorized_keys." >&2
    exit 1
  fi
fi

if [ -z "$CADDY_ADMIN_EMAIL" ]; then
  echo "CADDY_ADMIN_EMAIL пуст. Caddy использует его для регистрации в ACME (Let's Encrypt) — без email сертификаты не выпишутся." >&2
  echo "Запускай так: CADDY_ADMIN_EMAIL=admin@example.com bash bootstrap-vps.sh" >&2
  exit 1
fi

# ─────────────────────────────────────────────
# 1. Пользователь deploy + sudo NOPASSWD + SSH key
# ─────────────────────────────────────────────
log "[1/8] Deploy user + sudo"
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --gecos "" --disabled-password "$DEPLOY_USER"
fi
usermod -aG sudo "$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
if [ -n "$DEPLOY_PUBKEY" ]; then
  echo "$DEPLOY_PUBKEY" > "/home/$DEPLOY_USER/.ssh/authorized_keys"
else
  cp /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"
fi
chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"

echo "$DEPLOY_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$DEPLOY_USER"
chmod 440 "/etc/sudoers.d/$DEPLOY_USER"
visudo -c -f "/etc/sudoers.d/$DEPLOY_USER" >/dev/null

# ─────────────────────────────────────────────
# 2. SSH hardening (drop-in + нейтрализация cloud-init)
# ─────────────────────────────────────────────
log "[2/8] SSH hardening (port $SSH_PORT)"
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<CFG
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
CFG

# Ubuntu (Timeweb и другие cloud-образы) кладут /etc/ssh/sshd_config.d/50-cloud-init.conf
# с `PasswordAuthentication yes`. sshd читает drop-in'ы first-match-wins — `50-*` грузится
# раньше `99-*`, так что перекрывает. Нейтрализуем (оставляем пустым).
if [ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]; then
  : > /etc/ssh/sshd_config.d/50-cloud-init.conf
fi
# В основном конфиге тоже может быть `PermitRootLogin yes` — комментируем.
sed -i 's/^PermitRootLogin yes/#PermitRootLogin yes  # overridden by 99-hardening.conf/' /etc/ssh/sshd_config || true

# Ubuntu 22.04+ использует socket activation через ssh.socket. Пока он активен,
# Port из sshd_config игнорируется (порт берётся из ssh.socket.d/addresses.conf).
# Переключаем на прямой ssh.service, чтобы Port заработал.
sshd -t
if systemctl is-active --quiet ssh.socket; then
  systemctl disable --now ssh.socket
fi
systemctl enable --now ssh.service
systemctl restart ssh.service

# ─────────────────────────────────────────────
# 3. Firewall + fail2ban
# ─────────────────────────────────────────────
log "[3/8] ufw + fail2ban + unattended-upgrades"
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow "$SSH_PORT"/tcp comment 'SSH' >/dev/null
ufw allow 80/tcp comment 'HTTP' >/dev/null
ufw allow 443/tcp comment 'HTTPS' >/dev/null
ufw --force enable >/dev/null

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq fail2ban unattended-upgrades apt-listchanges

# fail2ban: строже дефолта (3 попытки, бан 24 часа), следит за актуальным ssh портом.
# sshd log на Ubuntu 24.04 — journald, не /var/log/auth.log; backend=systemd критичен.
cat > /etc/fail2ban/jail.local <<CFG
[DEFAULT]
bantime  = 24h
findtime = 10m
maxretry = 3
backend  = systemd

[sshd]
enabled = true
port    = $SSH_PORT
CFG
systemctl enable --now fail2ban
systemctl restart fail2ban

# unattended-upgrades: ставит только security patches, без авто-reboot.
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'CFG'
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
CFG
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CFG'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CFG
systemctl enable --now unattended-upgrades

# ─────────────────────────────────────────────
# 4. Swap
# ─────────────────────────────────────────────
log "[4/8] Swap ($SWAP_SIZE)"
# Pre-clean: если /swapfile уже есть, но не нужного размера — пересоздать.
# Иначе ранее присутствующий 512M-файл (Timeweb default) останется как есть.
if [ -f /swapfile ]; then
  current_bytes=$(stat -c %s /swapfile 2>/dev/null || echo 0)
  want_bytes=$(numfmt --from=iec "$SWAP_SIZE" 2>/dev/null || echo 0)
  if [ "$current_bytes" -ne "$want_bytes" ] && [ "$want_bytes" -gt 0 ]; then
    swapon --show | grep -q '^/swapfile' && swapoff /swapfile
    rm -f /swapfile
  fi
fi
if ! swapon --show | grep -q swapfile; then
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ─────────────────────────────────────────────
# 5. Стек: Node, pnpm, Caddy, git, PM2
# ─────────────────────────────────────────────
log "[5/8] Stack (Node $NODE_MAJOR, pnpm via corepack, Caddy, git, PM2)"
if ! command -v node >/dev/null || [ "$(node -v | cut -c2- | cut -d. -f1)" != "$NODE_MAJOR" ]; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - >/dev/null
fi

# Caddy apt-репо (официальный, см. https://caddyserver.com/docs/install#debian-ubuntu-raspbian).
# Caddy сам делает ACME (Let's Encrypt / ZeroSSL), автообновление SSL, HTTP/2, HTTP/3.
# Заменяет связку nginx + certbot + cron renewal.
if [ ! -f /etc/apt/sources.list.d/caddy-stable.list ]; then
  apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl
  curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  apt-get update -qq
fi
apt-get install -y -qq nodejs caddy git

# pnpm через corepack (он идёт в комплекте с Node 16.13+). Активируем системно,
# чтобы и root, и deploy получили рабочий бинарник /usr/local/bin/pnpm.
corepack enable >/dev/null
corepack prepare pnpm@latest --activate >/dev/null

# PM2 ставим через pnpm — для консистентности с остальной инфрой (npm на VPS не нужен).
pnpm add -g pm2 >/dev/null 2>&1 || pnpm add -g pm2

# ─────────────────────────────────────────────
# 6. Папки и реестр портов (под deploy)
# ─────────────────────────────────────────────
log "[6/8] Folders + ports registry"
sudo -u "$DEPLOY_USER" mkdir -p "/home/$DEPLOY_USER/prod" "/home/$DEPLOY_USER/dev"
if [ ! -f "/home/$DEPLOY_USER/ports.md" ]; then
  sudo -u "$DEPLOY_USER" tee "/home/$DEPLOY_USER/ports.md" >/dev/null <<'MD'
# Ports registry on this VPS

Правило: prod = 3000 + N*10, dev = prod + 1000.

| Site | prod port | dev port | PM2 names | Domain | Added |
|------|-----------|----------|-----------|--------|-------|
MD
fi

# ─────────────────────────────────────────────
# 7. Deploy key для GitHub Actions
# ─────────────────────────────────────────────
log "[7/8] GitHub Actions deploy key"
if [ ! -f "/home/$DEPLOY_USER/.ssh/deploy_key" ]; then
  sudo -u "$DEPLOY_USER" ssh-keygen -t ed25519 \
    -f "/home/$DEPLOY_USER/.ssh/deploy_key" -N '' \
    -C "github-actions@$(hostname)" >/dev/null
  cat "/home/$DEPLOY_USER/.ssh/deploy_key.pub" >> "/home/$DEPLOY_USER/.ssh/authorized_keys"
  sudo -u "$DEPLOY_USER" sort -u "/home/$DEPLOY_USER/.ssh/authorized_keys" \
    -o "/home/$DEPLOY_USER/.ssh/authorized_keys"
  chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
fi

# ─────────────────────────────────────────────
# 8. Caddy: базовый Caddyfile + папка для per-site конфигов
# ─────────────────────────────────────────────
log "[8/8] Caddy config"
install -d -m 755 /etc/caddy/Caddyfile.d

cat > /etc/caddy/Caddyfile <<CFG
{
    email $CADDY_ADMIN_EMAIL
}

import /etc/caddy/Caddyfile.d/*.caddy
CFG

# Если /etc/caddy/Caddyfile.d/ пуст — `caddy validate` падает на glob-импорте.
# Кладём заглушку: пустой блок, который валиден и не отвечает ни на какой домен.
if [ -z "$(ls -A /etc/caddy/Caddyfile.d/ 2>/dev/null)" ]; then
  cat > /etc/caddy/Caddyfile.d/00-placeholder.caddy <<'CFG'
# Placeholder. Per-site конфиги добавляются в server-add-site.md
# и удаляют этот файл при первом сайте.
:8080 {
    respond "caddy is up; no sites configured yet" 200
}
CFG
fi

caddy validate --config /etc/caddy/Caddyfile
systemctl enable --now caddy
systemctl reload caddy

# ─────────────────────────────────────────────
# Done. Note: pm2-deploy systemd service НЕ включаем сейчас — пустой dump
# у pm2 приводит к `failed (Result: protocol)` в systemd. Включим в
# server-add-site.md после первого `pm2 save` с реальным процессом.
# ─────────────────────────────────────────────
log "Bootstrap complete."
printf '\n\033[1;32m✓ Server ready.\033[0m\n'
printf 'SSH:        ssh -p %s %s@<IP>\n' "$SSH_PORT" "$DEPLOY_USER"
printf 'Deploy user: %s (sudo NOPASSWD, SSH key-only)\n' "$DEPLOY_USER"
printf 'Stack:       Node %s, Caddy %s, PM2 %s\n' \
  "$(node -v)" "$(caddy version | awk '{print $1}')" "$(pm2 --version)"
printf 'Caddy ACME:  email=%s (Let'\''s Encrypt автообновление, cron не нужен)\n' "$CADDY_ADMIN_EMAIL"
printf 'Security:    ufw (%s/80/443), fail2ban (3 fails → 24h), unattended-upgrades (security only)\n' "$SSH_PORT"
printf '\nGitHub Actions deploy key (public):\n'
cat "/home/$DEPLOY_USER/.ssh/deploy_key.pub"
printf '\nДальше: docs/server-add-site.md для подключения первого сайта.\n'

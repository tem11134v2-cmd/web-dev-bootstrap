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
log "[2/8] SSH hardening"
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'CFG'
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

sshd -t
systemctl reload ssh

# ─────────────────────────────────────────────
# 3. Firewall + fail2ban
# ─────────────────────────────────────────────
log "[3/8] ufw + fail2ban"
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp comment 'SSH' >/dev/null
ufw allow 80/tcp comment 'HTTP' >/dev/null
ufw allow 443/tcp comment 'HTTPS' >/dev/null
ufw --force enable >/dev/null

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq fail2ban
systemctl enable --now fail2ban

# ─────────────────────────────────────────────
# 4. Swap
# ─────────────────────────────────────────────
log "[4/8] Swap ($SWAP_SIZE)"
if ! swapon --show | grep -q swapfile; then
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ─────────────────────────────────────────────
# 5. Стек: Node, nginx, git, certbot, PM2
# ─────────────────────────────────────────────
log "[5/8] Stack (Node $NODE_MAJOR, nginx, git, certbot, PM2)"
if ! command -v node >/dev/null || [ "$(node -v | cut -c2- | cut -d. -f1)" != "$NODE_MAJOR" ]; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - >/dev/null
fi
apt-get install -y -qq nodejs nginx git certbot python3-certbot-nginx
npm install -g pm2 >/dev/null 2>&1 || npm install -g pm2

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
# 8. Nginx: убрать дефолтный сайт
# ─────────────────────────────────────────────
log "[8/8] Nginx cleanup"
[ -L /etc/nginx/sites-enabled/default ] && rm /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx

# ─────────────────────────────────────────────
# Done. Note: pm2-deploy systemd service НЕ включаем сейчас — пустой dump
# у pm2 приводит к `failed (Result: protocol)` в systemd. Включим в
# server-add-site.md после первого `pm2 save` с реальным процессом.
# ─────────────────────────────────────────────
log "Bootstrap complete."
printf '\n\033[1;32m✓ Server ready.\033[0m\n'
printf 'Deploy user: %s (sudo NOPASSWD, SSH key-only)\n' "$DEPLOY_USER"
printf 'Stack: Node %s, nginx %s, PM2 %s, certbot %s\n' \
  "$(node -v)" "$(nginx -v 2>&1 | awk -F/ '{print $2}')" \
  "$(pm2 --version)" "$(certbot --version 2>&1 | awk '{print $2}')"
printf '\nGitHub Actions deploy key (public):\n'
cat "/home/$DEPLOY_USER/.ssh/deploy_key.pub"
printf '\nТеперь переходи к docs/server-add-site.md для подключения первого сайта.\n'

# Deploy: Server Setup

Справочник по первичной настройке VPS, nginx, SSL, Cloudflare. Подробный пошаговый runbook — в `specs/01-infrastructure.md`. Концептуальный обзор схем A/B — в `docs/deploy.md`.

## Первичная настройка VPS (общее для A и B)

**1. Заказ VPS:** Ubuntu 22.04 LTS. Минимум 2 CPU / 4 GB RAM / 40 GB SSD. Тяжёлый билд → 4/8/40. Статический IP, root SSH.

**2. Безопасность:**
```bash
adduser deploy && usermod -aG sudo deploy
# /etc/ssh/sshd_config: PermitRootLogin no → systemctl restart sshd
ufw allow 22 && ufw allow 80 && ufw allow 443 && ufw enable
apt install fail2ban -y && systemctl enable fail2ban
```

**3. Установка стека:**
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs nginx git certbot python3-certbot-nginx
npm install -g pm2 && pm2 startup
```

**4. Swap (если 4 GB RAM или меньше — иначе билд OOM):**
```bash
fallocate -l 2G /swapfile && chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

## Настройка схемы B (дополнительно)

**5. GitHub-репо:** owner = заказчик, приватный, разработчик — collaborator с push. **Protected branch `main`:** только через merge PR.

**6. SSH-ключ для автодеплоя:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""
# Public → ~/.ssh/authorized_keys на VPS
# Private → GitHub Secrets как DEPLOY_SSH_KEY
```

**7. `.github/workflows/deploy.yml`:**
```yaml
name: Deploy to prod
on: { push: { branches: [main] } }
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: webfactory/ssh-agent@v0.9.0
        with: { ssh-private-key: "${{ secrets.DEPLOY_SSH_KEY }}" }
      - run: |
          ssh -o StrictHostKeyChecking=no deploy@SERVER_IP "
            cd ~/prod/PROJECT && git pull origin main && \
            npm ci && npm run build && pm2 restart PROJECT-prod
          "
```

**8. Первый деплой prod:**
```bash
cd ~/prod/{project}
git clone git@github.com:{owner}/{repo}.git . && git checkout main
npm ci && npm run build
PORT=3000 pm2 start npm --name {project}-prod -- start
pm2 save
```

**9. Первый клон dev:**
```bash
cd ~/dev/{project}
git clone git@github.com:{owner}/{repo}.git . && git checkout dev
npm install && npm run build
PORT=4000 pm2 start npm --name {project}-dev -- start
pm2 save
```

**10. Распределение портов:** prod 3000/3005/3010, dev = prod + 1000. Реестр портов веди в README VPS.

## Nginx (общий шаблон, prod + опционально dev)

```nginx
# /etc/nginx/sites-available/{project}

server { listen 80; server_name domain.com; return 301 https://$host$request_uri; }

server {
    listen 443 ssl http2;
    server_name domain.com;

    ssl_certificate /etc/letsencrypt/live/domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    gzip on; gzip_static on; gzip_comp_level 5;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml font/woff2;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location /_next/static/ { proxy_pass http://127.0.0.1:3000; expires 365d; add_header Cache-Control "public, immutable"; }
    location /_next/image { proxy_pass http://127.0.0.1:3000; expires 30d; }
    location ~* \.(jpg|jpeg|png|webp|avif|gif|svg|ico|woff2|woff|ttf)$ { proxy_pass http://127.0.0.1:3000; expires 30d; }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# --- DEV (только схема B) ---
# server { listen 80; server_name dev.domain.com; return 301 https://$host$request_uri; }
# server {
#     listen 443 ssl http2; server_name dev.domain.com;
#     ssl_certificate ... dev.domain.com/fullchain.pem;
#     ssl_certificate_key ... dev.domain.com/privkey.pem;
#     # auth_basic "Dev"; auth_basic_user_file /etc/nginx/.htpasswd;  # не индексировать
#     location / { proxy_pass http://127.0.0.1:4000; ... }
# }
```

```bash
ln -s /etc/nginx/sites-available/{project} /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
certbot --nginx -d domain.com [-d dev.domain.com]
```

## Cloudflare (опционально, поверх любой схемы)

**Когда подключать:** трафик > 1k/день, нужны DDoS-защита / WAF / global CDN, или просто бесплатный edge-кэш.

**Базовая настройка:**
1. Делегируй NS домена на Cloudflare (через регистратора).
2. SSL/TLS mode: **Full (strict)** — чтобы CF проверял твой Let's Encrypt.
3. Always Use HTTPS: ON.
4. Auto Minify (CSS/JS/HTML): OFF — Next уже делает.
5. Brotli: ON — даёт +10–15% к gzip без головняка с компиляцией nginx.
6. Caching → Browser Cache TTL: Respect Existing Headers.
7. Page Rules для статики `*/_next/static/*` — Cache Everything, Edge TTL = 1 month.

**Подводные камни:**
- Cloudflare кеширует HTML — после релиза `pm2 restart` контент может не обновиться. Решение: не кэшировать `.html`, либо purge по API в GitHub Actions после деплоя.
- IP клиента в nginx-логах = IP Cloudflare. Чтобы видеть реальный — `set_real_ip_from` + `real_ip_header CF-Connecting-IP` в nginx.

## Типовые проблемы

- **Билд OOM** → swap (см. § 4) или билд в GitHub Actions с заливкой готового `.next/`.
- **PM2 не стартанул после ребута** → `pm2 startup` (даст команду с sudo) → `pm2 save`.
- **Nginx 502 после деплоя** → `pm2 logs {project}-prod --lines 100`, `pm2 restart {project}-prod`.
- **Конфликт push** → `git pull --rebase origin dev`.
- **`conflicting server_name`** в nginx → бэкап-конфиг лежит **внутри** `sites-enabled/` и парсится. Перенеси бэкап в `~/nginx-backups/`.

## Регулярное обслуживание (раз в месяц)

`apt update && apt upgrade`, `npm outdated` в проекте, `pm2 logs`, `df -h`, `certbot certificates`.

## Чек-лист старта клиентского проекта (схема B)

- [ ] VPS заказан, root SSH получен
- [ ] `deploy` пользователь, root SSH отключён, ufw + fail2ban
- [ ] Node.js, nginx, PM2, certbot установлены
- [ ] Папки `~/dev/{project}` и `~/prod/{project}` созданы
- [ ] GitHub-репо (owner = заказчик), разработчик — collaborator
- [ ] Protected branch `main` настроен
- [ ] Deploy SSH-ключ создан и в GitHub Secrets
- [ ] `.github/workflows/deploy.yml` настроен и проверен
- [ ] Домены: A-запись, SSL для prod и dev
- [ ] Nginx-конфиг с prod + dev поддоменами
- [ ] PM2-процессы запущены и в автозагрузке
- [ ] Cloudflare (опционально) подключён
- [ ] Первый push проверен — автодеплой работает
- [ ] Заказчику передана краткая инструкция

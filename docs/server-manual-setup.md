# Server: Manual Setup (разовый, на свежий VPS)

**Это инструкция для человека, не для Claude.** Claude Code в эту папку не ходит — он только пушит в GitHub. Ты выполняешь этот чек-лист руками по SSH.

Проходится один раз на каждый **новый VPS**. Если VPS уже настроен — открывай `docs/server-add-site.md` для подключения ещё одного сайта.

## 0. Требования к VPS

- **ОС:** Ubuntu 22.04 LTS или 24.04 LTS.
- **Ресурсы:** минимум 2 CPU / 4 GB RAM / 40 GB SSD. Для 3+ сайтов на одном VPS — 4 CPU / 8 GB / 80 GB.
- **Доступ:** root SSH по паролю от провайдера (переделаем на ключ ниже).
- **IP:** статический, публичный.

## 1. Первый вход и создание пользователя `deploy`

```bash
ssh root@{server-ip}
adduser deploy                 # задай пароль
usermod -aG sudo deploy
```

Прокинь свой ключ с Mac:

```bash
# На Mac (если ключа ещё нет):
ssh-keygen -t ed25519 -C "{твой-email}"
ssh-copy-id deploy@{server-ip}
```

Проверь вход: `ssh deploy@{server-ip}` — должно пустить без пароля.

## 2. Безопасность SSH

На сервере под `deploy`:

```bash
sudo nano /etc/ssh/sshd_config
# PermitRootLogin no
# PasswordAuthentication no
sudo systemctl restart sshd
```

Проверь, что `ssh root@{server-ip}` теперь отказывает. **Не закрывай первый SSH-сеанс, пока не убедился, что второй работает.**

## 3. Firewall и fail2ban

```bash
sudo ufw allow 22 && sudo ufw allow 80 && sudo ufw allow 443 && sudo ufw enable
sudo apt update && sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
```

## 4. Swap (если RAM ≤ 4 GB — иначе билд Next.js упадёт с OOM)

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 5. Стек

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs nginx git certbot python3-certbot-nginx
sudo npm install -g pm2
pm2 startup                    # выполни выданную команду через sudo
```

Проверь: `node -v` (должно быть 22.x), `nginx -v`, `pm2 --version`.

## 6. Папки

```bash
mkdir -p ~/prod ~/dev
# Внутрь папок сайты будут укладываться при подключении — см. server-add-site.md.
```

## 7. Реестр портов

```bash
nano ~/ports.md
```

Вставь шаблон:

```markdown
# Ports registry on this VPS

| Site       | prod port | dev port | PM2 names                   | Domain               |
|------------|-----------|----------|-----------------------------|----------------------|
| (пример)   | 3010      | 4010     | example-prod / example-dev  | example.com          |
```

Актуализируй этот файл каждый раз при добавлении сайта — чтобы не словить конфликт портов. Подробнее — `docs/server-multisite.md`.

## 8. Deploy-ключ для GitHub Actions

GitHub Actions будет ходить на VPS по SSH. Генерим отдельный ключ только под деплой:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""
cat ~/.ssh/deploy_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/deploy_key            # ⬅️ приватный ключ — скопируй целиком
```

Приватный ключ положишь в GitHub Secrets (`DEPLOY_SSH_KEY`) при подключении первого сайта (см. `server-add-site.md`). Публичный уже лежит в `authorized_keys`.

## 9. Базовый nginx

Проверь, что nginx запущен и отдаёт дефолтную страницу: `http://{server-ip}` в браузере → «Welcome to nginx».

```bash
sudo systemctl enable --now nginx
sudo nginx -t                  # проверка конфига
```

Конфиги конкретных сайтов пойдут в `/etc/nginx/sites-available/`, подключаются симлинком в `sites-enabled/`. Удали дефолтный сайт после первой настройки, если мешает:

```bash
sudo rm /etc/nginx/sites-enabled/default
```

## 10. Проверка

- [ ] `ssh deploy@{ip}` пускает без пароля, `ssh root@{ip}` — нет.
- [ ] `ufw status` — active, открыты 22/80/443.
- [ ] `sudo systemctl status fail2ban` — active.
- [ ] `node -v` ≥ 22, `pm2 ls` — пусто, но команда работает.
- [ ] `nginx -t` — syntax is ok.
- [ ] `~/prod/` и `~/dev/` созданы, `~/ports.md` заведён.
- [ ] Deploy-ключ создан, публичный добавлен в `authorized_keys`, приватный сохранён (положишь в GitHub Secrets при первом сайте).

Готово. Теперь на этот VPS можно подключать любое количество сайтов через `docs/server-add-site.md`.

## Обслуживание (раз в месяц)

```bash
sudo apt update && sudo apt upgrade
pm2 logs --nostream --lines 50         # полистай на ошибки
df -h                                  # место на диске
sudo certbot certificates              # сроки SSL
```

## Типовые проблемы

- **Nginx 502 на любом сайте** → PM2-процесс не стартанул: `pm2 logs {site}-prod --lines 100`.
- **`pm2 ls` пусто после ребута** → забыл `pm2 startup` + `pm2 save`.
- **Билд уронил сервер по OOM** → включи swap (п. 4).
- **`conflicting server_name` при reload nginx** → бэкап-конфиг лежит внутри `sites-enabled/`. Перенеси в `~/nginx-backups/`.

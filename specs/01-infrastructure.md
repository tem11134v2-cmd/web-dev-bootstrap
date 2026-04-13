# Spec 01: Инфраструктура (VPS, домен, репозиторий)

## KB files to read first

- docs/deploy.md (две схемы A/B, ежедневная работа)
- docs/deploy-server-setup.md (VPS bootstrap, nginx, SSL, Cloudflare, шаблоны)
- docs/spec.md (домен, контакты)
- `.claude/memory/references.md`

## Goal

Поднять VPS, настроить SSH/безопасность, установить стек сервера (Node.js, Nginx, PM2, certbot), выбрать схему деплоя (A или B), настроить DNS и SSL. На выходе — сервер, готовый принять первый билд проекта.

## Решение: схема деплоя

В начале спеки явно спросить пользователя:

- **Схема A** (dev=prod на одном VPS, без GitHub remote): подходит для одиночных проектов, твоих собственных сайтов. Деплой = `npm run build && pm2 restart`. Просто, быстро, минимум движущихся частей.
- **Схема B** (dev+prod в двух папках, GitHub Actions автодеплой при merge dev→main): подходит для клиентских проектов, где заказчик — owner репозитория, разработчик — collaborator.

Зафиксировать выбор в `.claude/memory/decisions.md` с **Why:**.

## Tasks

### 1. Заказ и базовая настройка VPS

1. Пользователь заказывает VPS (Ubuntu 22.04 LTS, минимум 2 CPU / 4 GB RAM / 40 GB SSD), даёт root SSH-доступ
2. Создать non-root пользователя `deploy`, добавить в sudo
3. Запретить root SSH (`/etc/ssh/sshd_config: PermitRootLogin no`), перезапустить sshd
4. Включить ufw (порты 22/80/443) и fail2ban
5. Установить swap-файл 2 GB (для безопасной сборки Next.js на 4GB RAM)

### 2. Установка стека

6. Установить Node.js 22.x, Nginx, git, certbot:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
   apt install -y nodejs nginx git certbot python3-certbot-nginx
   npm install -g pm2
   pm2 startup  # выполнить выданную команду
   ```

### 3. DNS и Cloudflare (опционально)

7. Спросить пользователя: использовать Cloudflare или прямые A-записи?
   - **Cloudflare:** добавить домен в CF, настроить DNS (proxied для основного домена, DNS only для dev-поддомена), SSL mode = Full (strict), кэш-правила см. docs/deploy-server-setup.md
   - **Прямые A-записи:** просто A-запись на IP сервера у регистратора
8. Дождаться распространения DNS (`dig +short [domain]`)

### 4. Папки и репозиторий — по выбранной схеме

**Если схема A:**
- Создать `/var/www/[project]/` или `~/[project]/`
- `git init` локально, без remote (опционально — приватный remote для бэкапа)

**Если схема B:**
- Создать `~/dev/[project]/` и `~/prod/[project]/`
- Заказчик создаёт приватный GitHub-репо (owner — заказчик), добавляет разработчика как collaborator
- Настроить protected branch `main` (push только через PR)
- Сгенерировать deploy SSH-ключ: `ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""`, public — в `~/.ssh/authorized_keys` на VPS, private — в GitHub Secrets как `DEPLOY_SSH_KEY`
- Создать `.github/workflows/deploy.yml` (шаблон в docs/deploy-server-setup.md)
- Распределить порты: prod 3000, dev 4000 (или следующая свободная пара по реестру)

### 5. Базовая Claude Code инфраструктура

9. Создать `.claude/hooks.json` — защита от `rm -rf` и `git push origin main`, автоформат через prettier (шаблон в docs/workflow.md)
10. Создать `.claude/commands/catchup.md` — восстановление контекста после `/clear` (шаблон в docs/workflow.md)

### 6. Документация и память

11. Заполнить `.claude/memory/references.md`: VPS IP, SSH, пути prod/dev, порты, GitHub URL (если B), DNS-провайдер
12. Зафиксировать выбор схемы в `.claude/memory/decisions.md` с **Why:**

## Boundaries

- **Always:** проверять `nginx -t` перед reload, бэкапить sshd_config до правок
- **Ask first:** перед заказом платных услуг (VPS, домен, Cloudflare Pro), перед настройкой Cloudflare proxied (может ломать WebSocket — обсудить)
- **Never:** хранить root-пароль в репо/памяти, использовать пароль вместо SSH-ключа, push в main напрямую (схема B)

## Done when

- VPS доступен по `ssh deploy@[ip]`, root SSH отключён, ufw + fail2ban активны
- Node 22, Nginx, PM2, certbot установлены
- DNS резолвит домен на IP сервера
- Папки проекта созданы по выбранной схеме
- (Схема B) GitHub репо создан, deploy-ключ настроен, workflow готов
- `.claude/hooks.json` и `.claude/commands/catchup.md` созданы
- `references.md` и `decisions.md` обновлены

## Memory updates

- `references.md` — IP, SSH, пути, порты, домены, GitHub URL
- `decisions.md` — выбор схемы A/B + Why, выбор Cloudflare/прямой DNS + Why
- `project_state.md` — отметить done, следующая `02-project-init`

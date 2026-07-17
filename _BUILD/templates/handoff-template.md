# Handoff: {site-name}

<!--
Шаблон HANDOFF.md. Спека 12 копирует его в корень проекта репо как HANDOFF.md
и заполняет все {плейсхолдеры}. Язык — русский, простыми словами, для заказчика.
Секции под выбранную модель (H1/H2/H3) урезаются по спеке 12.
-->

## Что у тебя есть

- **Сайт:** https://{domain}
- **Код:** https://github.com/{client-owner}/{repo}
- **VPS:** {provider}, IP {x.x.x.x}, SSH `ssh deploy@{ip}` (порт {ssh-port}, ключ нужен)
- **Домен:** зарегистрирован у {registrar}
- **CRM:** {crm-url}
- **Аналитика:** Я.Метрика {counter-id}, GA {ga-id}

## Как править сайт

1. На своём компьютере установить Claude Desktop.
2. `git clone git@github.com:{client-owner}/{repo}.git`.
3. Открыть папку в Claude Desktop, сказать «Read CLAUDE.md and specs/INDEX.md, затем следуй specs/13-extend-site.md для правок».

## Runbook — что делать если сломалось

### Сайт не открывается (502 Bad Gateway)

```
ssh deploy@{ip}
pm2 logs {site}-prod --lines 50   # посмотреть ошибки
pm2 restart {site}-prod
```

### SSL-сертификат истёк

Caddy выписывает и обновляет SSL сам (за ~30 дней до истечения). Если всё же истёк — обычно проблема в том, что Caddy не работал:

```
ssh deploy@{ip}
sudo systemctl status caddy --no-pager
sudo journalctl -u caddy --since "1 day ago" | grep -iE "error|certificate"
sudo systemctl restart caddy   # только если status показывает failed
```

### Обновления из GitHub не приехали

1. GitHub → репо → Actions → последний запуск `deploy-prod.yml`.
2. Если упал — посмотреть лог упавшего шага (Build / Upload and unpack release / Activate release). Чаще всего: SSH-ключ устарел, `PROD_ENV_FILE` секрет потёрся, на VPS закончилось место (`df -h`).
3. Если не запустился — убедиться, что merge в `main` прошёл, ветка `main` не заморожена.
4. После исправления — «Re-run failed jobs» или пустой коммит:
   ```bash
   git commit --allow-empty -m "chore: trigger deploy" && git push origin main
   ```

Под push-based deploy на VPS **нет git и нет pnpm** — ручной `git pull && pnpm build` не сработает. Если совсем плохо и Actions недоступны: попроси разработчика собрать standalone-сборку локально, упаковать в tar.gz (`gzip -t` для проверки) и передать по scp, распаковав в `~/prod/{site}/releases/<sha>/`, затем `ln -sfn` + `pm2 delete {site}-prod` + `PORT={port} HOSTNAME=127.0.0.1 pm2 start current/server.js --name {site}-prod` (после смены симлинка `restart`/`reload` не годятся — кэшируют старый путь).

### Билд падает с OOM (out of memory)

Билд идёт на GitHub-runner-е (стандартные 7 ГБ RAM) — на VPS OOM произойти не может. Если в логе runner-а видно OOM — обычно это слишком тяжёлый бандл; спрашивай разработчика, не VPS-проблема.

### Откат на последнюю рабочую версию

С машины разработчика:

```bash
cd ~/projects/{site}
PROD_PORT={port} scripts/rollback.sh    # порт — из ~/ports.md на VPS / repo variable PROD_PORT
```

Скрипт переключит симлинк `~/prod/{site}/current` на предыдущий релиз и перезапустит процесс: `pm2 delete` + `PORT={port} HOSTNAME=127.0.0.1 pm2 start`. Атомарно, секунды, без пересборки.

После — разработчик делает `git revert <bad-commit> && git push origin main` (для merge-коммита: `git revert -m 1 <hash>`), и Actions соберёт чистый релиз поверх.

### Лиды не доходят (почта / Telegram / CRM)

1. На VPS: `tail ~/prod/{site}/shared/data/leads.jsonl` — есть ли свежие записи? Файл — страховка: туда пишется только то, что НЕ ушло ни в один канал.
2. Если записи появляются — токен/пароль/webhook канала сломались. Обновить `PROD_ENV_FILE` через `gh secret set` и пушнуть пустой коммит, либо fallback — `scripts/sync-env.sh`.
3. Если файла нет и каналы молчат — Server Action не отрабатывает. Проверить `pm2 logs {site}-prod` на ошибки.

### Сайт работает медленно

1. PSI: pagespeed.web.dev → ввести URL → Mobile + Desktop.
2. Если упало после релиза — `scripts/rollback.sh` (см. выше).
3. Если без изменений — VPS перегружен: `htop`, `df -h`, возможно пора на более мощный VPS (см. `specs/14-migrate.md`, сценарий M1).

### Переезд / отключение сервера

Перед декомиссией (выключением) старого VPS — **проверь и выгрузи `~/prod/{site}/shared/data`** (fallback-лиды `leads.jsonl` и другие runtime-данные): скопируй папку себе или на новый сервер. После удаления VPS эти данные не восстановить.

## Ежемесячное обслуживание

```bash
ssh deploy@{ip}
sudo apt update && sudo apt upgrade -y          # ОС патчи (auto-updates security-only, остальное вручную)
pm2 logs --nostream --lines 100                 # быстрый просмотр ошибок
df -h                                           # свободное место
sudo systemctl status caddy --no-pager          # Caddy жив? (он сам обновляет SSL за 30 дней до)
```

Раз в квартал: Я.Вебмастер — ошибки индексации; PSI — деградация скорости.

## Когда закончу платить разработчику

1. GitHub → репо → Settings → Collaborators → убрать `{dev-github}`.
2. На VPS:
   ```
   ssh deploy@{ip}
   # отредактировать ~/.ssh/authorized_keys — убрать строку с ключом разработчика
   nano ~/.ssh/authorized_keys
   ```
3. Если меняли email учёток сервисов на разработчиковые — вернуть на свои.

## Контакты для вопросов

- Разработчик: {имя, e-mail/telegram}
- Сроки реакции: {SLA}

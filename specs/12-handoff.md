# Spec 12: Передача проекта заказчику + runbook

## KB files to read first

- docs/deploy.md (push-based flow, структура `releases/<sha>/`)
- docs/server-manual-setup.md (что на сервере, роль `deploy`)
- docs/server-add-site.md (раздел «Частые проблемы»)
- docs/automation.md (rollback.sh, sync-env.sh fallback)
- `.claude/memory/references.md` (всё что заказчик должен получить)
- `.claude/memory/decisions.md` (что заказчик должен знать о решениях)
- Если handoff совмещён с переездом на инфру заказчика — `specs/14-migrate.md` (сценарий M2).

## Goal

Передать заказчику все доступы и инструкции для самостоятельной эксплуатации сайта. Выбрать модель handoff'а (H1/H2/H3), привести проект к этой модели, оставить заказчику `HANDOFF.md` с runbook'ом типичных аварий.

## Модели handoff

Спроси заказчика (или перечитай договор), какая модель:

- **H1 — Full transfer** (дефолт для клиентских проектов). Заказчик становится владельцем всего: GitHub-репо, VPS, домен, аккаунты. Разработчик остаётся `collaborator` на время оплаченной поддержки, потом удаляется. Самая чистая модель юридически.
- **H2 — Client-owned, dev operates.** Собственность передана заказчику, разработчик продолжает вести проект (обновления, мониторинг, правки) как operator. SSH + GitHub collaborator остаются.
- **H3 — Read-only для заказчика.** Заказчик получает только доступ к статистике/CRM. Редкий случай.

Зафиксировать выбор в `.claude/memory/decisions.md`.

## Tasks (для H1, дефолт)

### 1. Transfer GitHub ownership

1. Разработчик → Settings репо → Transfer ownership → указать аккаунт заказчика (или его GitHub-организацию).
2. Заказчик подтверждает приём.
3. После передачи разработчик автоматически становится collaborator с push-правами (настроить срок через invite re-issue, если нужно).

### 2. Transfer VPS

4. Если VPS на аккаунте разработчика:
   - Заказчик заводит свой аккаунт у провайдера.
   - По тарифу провайдера — либо перенос VPS между аккаунтами (Timeweb/Hetzner поддерживают), либо переезд на новый VPS на его аккаунте (= сценарий M2, см. `specs/14-migrate.md`).
5. На целевом VPS: новый публичный SSH-ключ заказчика → в `~/.ssh/authorized_keys` пользователя `deploy`. Оставить ключ разработчика до окончания поддержки.

### 3. Transfer domain

6. Разработчик у регистратора → Transfer out → код авторизации → передать заказчику.
7. Заказчик у своего регистратора → Transfer in + код. Распространение 5–7 дней (лочится на время трансфера).

### 4. Transfer third-party accounts

8. Все сервисы на аккаунт заказчика (если ещё не там): CRM, Метрика, GA, GSC, Я.Вебмастер, Cloudflare (если используется).
9. Если сервисы создавали под учёткой разработчика — сменить email владельца на почту заказчика, добавить его, удалить себя.

### 5. Создать HANDOFF.md в репо

10. Файл в корне проекта (русский, простыми словами). Структура:

```markdown
# Handoff: {site name}

## Что у тебя есть
- **Сайт:** https://{domain}
- **Код:** https://github.com/{client-owner}/{repo}
- **VPS:** {provider}, IP {x.x.x.x}, SSH `ssh deploy@{ip}` (порт 2222, ключ нужен)
- **Домен:** зарегистрирован у {registrar}
- **CRM:** {crm-url}
- **Аналитика:** Я.Метрика {counter-id}, GA {ga-id}

## Как править сайт
1. На своём компьютере установить Claude Desktop.
2. `git clone git@github.com:{client-owner}/{repo}.git`.
3. Открыть папку в Claude Desktop, сказать «Read CLAUDE.md and specs/INDEX.md, затем следуй specs/13-extend-site.md для правок».

## Runbook — что делать если сломалось
... (см. раздел ниже)

## Ежемесячное обслуживание
... (см. раздел ниже)

## Контакты для вопросов
... (разработчик, сроки реакции, e-mail)
```

### 6. Runbook — типовые аварии

Положи в `HANDOFF.md` как секцию:

```markdown
## Runbook

### Сайт не открывается (502 Bad Gateway)

ssh deploy@{ip}
pm2 logs {site}-prod --lines 50   # посмотреть ошибки
pm2 restart {site}-prod

### SSL-сертификат истёк

Caddy выписывает и обновляет SSL сам (за ~30 дней до истечения). Если всё же истёк — обычно проблема в том, что Caddy не работал. Лечится так:

ssh deploy@{ip}
sudo systemctl status caddy --no-pager
sudo journalctl -u caddy --since "1 day ago" | grep -iE "error|certificate"
sudo systemctl restart caddy   # только если status показывает failed

### Обновления из GitHub не приехали

1. GitHub → репо → Actions → последний запуск `deploy-prod.yml`.
2. Если упал — посмотреть лог job-а (build / deploy / activate). Чаще всего: SSH-ключ устарел, `PROD_ENV_FILE` секрет потёрся, на VPS закончилось место (`df -h`).
3. Если не запустился — убедиться, что merge в `main` прошёл, ветка `main` не заморожена.
4. После исправления — «Re-run failed jobs» или пустой коммит:
   ```bash
   git commit --allow-empty -m "chore: trigger deploy" && git push origin main
   ```

Под push-based deploy на VPS **нет git и нет pnpm** — ручной `git pull && pnpm build` не сработает. Если совсем плохо и Actions недоступны: попроси разработчика собрать standalone-сборку локально и `rsync` руками в `~/prod/{site}/releases/<sha>/`, затем `ln -sfn` + `pm2 reload`.

### Билд падает с OOM (out of memory)

Билд идёт на GitHub-runner-е (стандартные 7 ГБ RAM) — на VPS OOM произойти не может. Если в логе runner-а видно OOM — обычно это слишком тяжёлый бандл; cпрашивай разработчика, не VPS-проблема.

### Откат на последнюю рабочую версию

С Mac разработчика:
   ```bash
   cd ~/projects/{site}
   scripts/rollback.sh
   ```
Скрипт переключит симлинк `~/prod/{site}/current` на предыдущий релиз и сделает `pm2 reload`. Атомарно, миллисекунды, без пересборки.

После — в Mac разработчик делает `git revert <bad-commit> && git push origin main` (для merge-коммита: `git revert -m 1 <hash>`), и Actions соберёт чистый релиз поверх.

### Лиды не доходят в CRM

1. На VPS: `tail ~/prod/{site}/current/data/leads.json` — есть ли свежие записи? (путь идёт через симлинк в активный релиз)
2. Если есть в файле, но нет в CRM — токен/webhook сломались. Обновить `PROD_ENV_FILE` через `gh secret set` и пушнуть пустой коммит, либо как fallback — `scripts/sync-env.sh`.
3. Если в файле пусто — Server Action `submitLead` сам не отрабатывает. Проверить `pm2 logs {site}-prod` на ошибки.

### Сайт работает медленно

1. PSI: pagespeed.web.dev → ввести URL → Mobile + Desktop.
2. Если упало после релиза — `scripts/rollback.sh` (см. выше).
3. Если без изменений — VPS перегружен: `htop`, `df -h`, возможно пора на более мощный VPS (см. `specs/14-migrate.md`, сценарий M1).
```

### 7. Ежемесячное обслуживание

11. В `HANDOFF.md` — секция «Раз в месяц»:
    ```bash
    ssh deploy@{ip}
    sudo apt update && sudo apt upgrade -y          # ОС патчи (auto-updates security-only, остальное вручную)
    pm2 logs --nostream --lines 100                 # быстрый просмотр ошибок
    df -h                                           # свободное место
    sudo systemctl status caddy --no-pager          # Caddy жив? (он сам обновляет SSL за 30 дней до)
    ```
12. Напомнить заказчику раз в квартал смотреть Я.Вебмастер на ошибки индексации и PSI на деградацию.

### 8. Отзыв прав разработчика (когда поддержка кончилась)

13. Инструкция **внутри HANDOFF.md** (чтобы заказчик сделал сам по истечении договора):
    ```markdown
    ### Когда закончу платить разработчику

    1. GitHub → репо → Settings → Collaborators → убрать `{dev-github}`.
    2. На VPS:
       ssh deploy@{ip}
       # отредактировать ~/.ssh/authorized_keys — убрать строку с ключом разработчика
       nano ~/.ssh/authorized_keys
    3. Если меняли email учёток сервисов на разработчиковые — вернуть на свои.
    ```
14. **Держи** этот раздел в HANDOFF.md, даже если сейчас handoff только начинается — заказчик захочет увидеть, что у него есть «выход».

### 9. Финальные коммиты и теги

15. Коммит `chore: add HANDOFF.md for client {name}`.
16. Тег `v1.0` — релизная версия.
17. Push `v1.0` в origin (`git push origin v1.0`).

### 10. Передача + Loom

18. Заказчику:
    - Ссылка на `HANDOFF.md` в репо (после transfer ownership).
    - `references.md` содержимое (можно в .md-файле или PDF).
    - Контакты разработчика, SLA (сроки реакции, часы работы).
19. Короткое видео 10–15 мин (Loom, любая запись экрана):
    - Где что (репо, VPS, CRM, метрики).
    - Как открыть Claude Desktop и попросить правку.
    - Что делать если упало (пройтись по runbook'у быстро).
20. Созвон по желанию заказчика.

## Tasks (для H2 — Client-owned, dev operates)

- Шаги 1–4 (transfer of ownership) делаются полностью.
- Шаги 5–10 (HANDOFF + runbook) тоже делаются, но с упором: «вот как заказчик мониторит сам, вот как разработчик всё ещё работает».
- Шаг 8 (отзыв прав) не актуален сейчас, но в HANDOFF.md оставить на будущее.

## Tasks (для H3 — Read-only)

- Вместо transfer ownership — добавить заказчика как `read-only` collaborator (или просто `viewer`).
- HANDOFF.md в урезанном виде: только «куда смотреть статистику», «с кем связаться».

## Boundaries

- **Always:** убедиться, что заказчик владеет ВСЕМ (или понимает, кто чем владеет, если H2); задокументировать каждый credential в `references.md` (без секретов).
- **Ask first:** перед удалением своих SSH-ключей / collaborator-прав — обсудить с заказчиком timing, чтобы не потерять ему доступ к чему-то важному.
- **Never:** оставлять секреты (токены, пароли, `.env`) на своей машине после передачи; передавать `.env` через Telegram/почту (используй 1Password shared vault или аналог).

## Done when

- Выбрана модель H1/H2/H3 и зафиксирована в `decisions.md`.
- Для H1: заказчик владеет репо, VPS, доменом, третьими сервисами. Разработчик остаётся collaborator на срок поддержки.
- `HANDOFF.md` создан, содержит runbook + обслуживание + инструкцию по отзыву прав.
- Проведён созвон или записан Loom.
- Тег `v1.0` создан и запушен.
- `project_state.md` зафиксировал дату и модель передачи.

## Memory updates

- `project_state.md` — «handed off [YYYY-MM-DD], model: H1/H2/H3».
- `decisions.md` — выбор модели handoff'а + Why.
- `references.md` — финальная сверка, всё актуально, владелец каждого ресурса отмечен.
- `lessons.md` — что вынесли из проекта в целом.

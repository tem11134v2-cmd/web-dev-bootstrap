# Deploy

Две схемы деплоя на VPS. Выбери одну до старта проекта — переход потом возможен, но болезненный. Серверная инфраструктура и nginx — в `docs/deploy-server-setup.md`.

## Какую схему выбрать

| Признак | A: Solo (dev=prod) | B: Client + CI/CD |
|---|---|---|
| Кто работает с кодом | Только разработчик | Разработчик + потенциально команда |
| Кто владелец инфры | Разработчик | Заказчик |
| Передача проекта в будущем | Маловероятна | Обязательна |
| GitHub remote | Опционально (или вообще нет) | Обязательно (owner = заказчик) |
| Preview-окружение | Нет (или ручной port) | Есть (`dev.domain.com`) |
| Деплой | `pm2 restart` локально | `git push` → GitHub Actions |
| Когда выбирать | Свой проект, MVP, ранний этап | Клиентский проект сразу |

**По умолчанию для клиентских проектов — B.** A — только когда уверен, что проект твой и долго.

---

## Схема A: Solo (dev = prod на одном VPS)

**Архитектура:**
```
VPS
└── ~/projects/{project}/   ← одна папка, одна ветка main
    ├── npm run dev   → port 4000   (когда нужен hot-reload)
    └── npm run start → port 3000   (production, под PM2)
       PM2 → nginx → SSL → Internet
```

**Деплой (после правок):**
```bash
npm run build     # включает sharp-сжатие public/
pm2 restart {project}
```

Без `git push`, без CI, без второй папки. Если правишь на VPS через `claude` — `git commit` опционален (для истории), не обязателен для деплоя.

**Преимущества:** простота, мгновенный деплой, минимум движущихся частей.
**Минусы:** нет preview-окружения, нет защиты от поломки prod, передача заказчику требует миграции.

**Когда A → когда переходить на B:**
- Появилась команда (≥2 разработчика).
- Заказчик попросил доступы к коду / инфре.
- Нужны preview-ссылки для согласования макетов.
- Релизы стали рискованными (большие фичи, регрессии).

---

## Схема B: Client + GitHub Actions

**Архитектура:**
```
VPS заказчика
├── ~/dev/{project}/    ← ветка dev, port 4000, dev.domain.com
│                          (preview для заказчика)
│      git push origin dev
│             │
│        GitHub repo (owner = заказчик)
│             │
│   PR dev → main → review → merge
│             │
│        GitHub Actions
│             │
└── ~/prod/{project}/   ← ветка main, port 3000, domain.com
                          (git pull + build + pm2 restart автоматом)
```

**Почему две папки:**
- Изоляция dev от prod — сломать dev не ломает prod.
- Заказчик видит preview на `dev.domain.com` до релиза.
- Два PM2-процесса, два nginx-поддомена.
- Для крупных проектов prod выносится на отдельный VPS.

**Собственность:**
- VPS, домен, GitHub-репо — на аккаунте **заказчика**.
- Разработчик — collaborator в GitHub + SSH-юзер на VPS.
- При уходе разработчика: удалить SSH-ключ + collaborator — всё работает.

**Настройка инфры (VPS, GitHub Actions, nginx, SSL, Cloudflare):** см. `docs/deploy-server-setup.md` и `specs/01-infrastructure.md`.

---

## Ежедневная работа

**Схема A:**
```bash
# Локально на VPS или удалённо
npm run build && pm2 restart {project}
# Опционально git commit для истории
```

**Схема B:**
```bash
ssh deploy@server && cd ~/dev/{project} && claude
# Правки → git add/commit/push origin dev
# Preview на dev.domain.com (нужен pm2 restart {project}-dev — отдельный workflow или вручную)
# Релиз: PR dev → main → merge → GitHub Actions автоматом
```

## Откат при поломке prod

```bash
ssh deploy@server && cd ~/prod/{project}
git log --oneline -5
git reset --hard {commit-hash}
npm run build && pm2 restart {project}-prod
```

В схеме A — то же, без второй папки. Полезно держать `git tag stable-YYYY-MM-DD` после успешных релизов.

## Масштабирование: когда выносить prod на отдельный VPS

Сигналы:
- CPU постоянно > 70% или RAM > 80%.
- Билд тормозит сайт > 10 секунд.
- Трафик > 10K уникальных в сутки.
- Появилась БД с большим объёмом.

Как вынести (схема B):
1. Заказать второй VPS (мощнее), пройти первичную настройку.
2. Перенести prod на новый VPS, dev остаётся на старом.
3. В GitHub Actions workflow поменять IP в SSH-команде.
4. Домены: `domain.com` → новый IP, `dev.domain.com` → старый.

## Передача проекта заказчику (если стартовал по схеме A)

1. Перенеси код в GitHub-репо с owner = заказчик.
2. Заведи на VPS второй пользователь / новый VPS под prod.
3. Настрой `.github/workflows/deploy.yml` и две папки `dev`/`prod` (см. `deploy-server-setup.md`).
4. Сними свои SSH-ключи с VPS, выйди из collaborators.
5. Передай: SSH-доступ, домен, GitHub owner-права, инструкцию.

Подробный runbook — `specs/12-handoff.md`.

## Git-дисциплина при деплое

- **Схема A:** работа на `main`, commit-by-task для истории.
- **Схема B:** работа на `dev`, никогда напрямую в `main` — только PR.
- Сообщения на английском, краткие.
- Не коммить: `.env`, `data/leads.json`, `node_modules/`, лог-файлы.
- Перед merge в `main` — проверить на `dev.domain.com`.

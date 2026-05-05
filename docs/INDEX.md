# docs/ — Knowledge Base

Универсальные модули KB. Читаются по требованию: открывай только то, что относится к текущей задаче (см. «KB files to read first» в каждой спеке). Никогда не загружай всё подряд — это съест контекст.

> **Серверные операции выполняет Claude** через SSH на VPS. Разовая подготовка: разработчик один раз делает `ssh-copy-id root@{ip}`, дальше Claude подключается ключом. Источник истины для bootstrap — `scripts/bootstrap-vps.sh`, протестирован на Ubuntu 24.04 Timeweb.

## Карта файлов

| Файл | Что внутри | Когда читать |
|---|---|---|
| `workflow.md` | Цикл Explore→Plan→Implement→Commit, управление контекстом, doom loop, антипаттерны | В начале любой сессии (можно один раз и помнить) |
| `stack.md` | Версии всех зависимостей, init-команды, scripts | На init проекта; при добавлении/обновлении пакета |
| `architecture.md` | Структура папок, App Router, Server/Client разделение, naming, max-150-строк | На init; при создании нового компонента; при рефакторинге |
| `design-system.md` | Философия, цветовые токены, типографика, layout, header/footer, анимации | На дизайн-системе; при добавлении новых секций; при правках цветов |
| `content-layout.md` | 44 типа секций конверсионного сайта + applicability + shadcn-маппинг | При сборке любой страницы; когда заказчик прислал текст и нужно понять тип секции |
| `forms-and-crm.md` | Архитектура форм, RHF+Zod, Server Action `submitLead`, multi-sink доставка лидов (Sheets / Telegram / CRM через `Promise.allSettled`), AmoCRM/Bitrix24 шаблоны, JSON-fallback, ConsultationDialog, useOptimistic | При создании любой формы; при подключении любого канала лидов |
| `legal-templates.md` | 152-ФЗ: cookie-баннер, согласие на ПДн, политика, оферта, чек-лист РКН | При создании форм на RU-сайте; перед публикацией; при подаче в РКН |
| `seo.md` | robots/sitemap, мета, Schema.org, ЧПУ, перелинковка, коммерческие факторы, Яндекс-специфика, Турбо/ИКС | На каждой новой странице; при подключении Яндекс/Google |
| `performance.md` | Core Web Vitals, изображения, шрифты, CSS, JS, кэш, серверная часть (Caddy `encode gzip zstd` + Cache-Control в шаблоне `server-add-site.md`), **Methodology § 13** (lessons), бюджет, чек-лист | На performance-аудите; при подозрении на регрессию; при выборе либ |
| `conversion-patterns.md` | 10 принципов конверсии: CTA, social proof, lead magnet, quiz, exit-intent, sticky, формы | На главной/посадочных; при доработке воронки |
| `deploy.md` | Единая схема (Mac → GitHub → VPS), ветки, GitHub Actions, ежедневный цикл, откат, Cloudflare | При init проекта; при ежедневном деплое; при правках CI/CD |
| `server-manual-setup.md` | Разовая настройка свежего VPS через `scripts/bootstrap-vps.sh`: пользователь, SSH, ufw, swap, Node runtime + Caddy + PM2 (build на runner, pnpm/git на VPS не ставятся) | Один раз на каждый новый VPS |
| `server-add-site.md` | Подключение нового сайта на готовый VPS: порты, клон, Caddy-конфиг, SSL (автоматический), GitHub Secrets, первый деплой | Один раз на каждый новый сайт |
| `server-multisite.md` | Как уживаются несколько сайтов на одном VPS (реестр портов, PM2, Caddyfile.d, когда выносить на отдельный VPS) | При подключении 2-го и далее сайта; при масштабировании |
| `domain-connect.md` | A-записи у регистратора или Cloudflare, проверка `dig`, подготовка к SSL | Один раз на каждый домен |
| `automation.md` | Хуки `.claude/hooks/*` (session-start, before-push, guard-rm, format, stop-reminder) + slash-команды `.claude/commands/*` (handoff, resume, catchup) + скрипты `scripts/sync-env.sh`, `rollback.sh`. Что делают, как отключить, как добавить новый | Когда непонятно что хук пишет в чате; когда нужно sync/rollback; при добавлении нового хука; при настройке multi-Claude flow |
| `troubleshooting.md` | Частые косяки: gh auth mismatch, DDoS-Guard 301, SSH permission denied в deploy job, симлинк `current` не переключился, rsync ошибки, PM2 не находит `server.js`, Caddy не стартует, SSL не выписывается, branch protection 403, swap не пересоздаётся, prod 404 | Когда что-то сломалось — сначала сюда, потом `lessons.md` |

## Проектные файлы (не KB)

Пишутся под конкретный проект, не входят в bootstrap:

| Файл | Что внутри | Кто заполняет |
|---|---|---|
| `docs/spec.md` | Бизнес, ЦА, услуги, бренд (цвета, шрифт), контакты, домен, основные SEO-запросы | Создаётся в `00-brief` из материалов заказчика |
| `docs/content.md` | Тексты по страницам в едином формате | Заказчик / копирайтер; разработчик только раскладывает |
| `docs/pages.md` | Карта страниц + статус + редиректы (старые URL → новые) | На init + поддерживается до релиза |
| `docs/integrations.md` | CRM, аналитика, домен, внешние сервисы (без секретов) | Постепенно по ходу проекта |

## Правила работы с docs/

- **Не загружай весь docs/ в контекст.** Каждая спека явно перечисляет нужные файлы.
- **Если правишь docs/ по ходу проекта** — это сигнал что bootstrap устарел. Рассмотри: правка специфична для проекта (тогда в `docs/spec.md`/`pointers.md`) или универсальна (тогда — в bootstrap).
- **Дедупликация:** если факт повторяется в двух файлах — это бага. Источник истины указан в miграционной карте; на остальных страницах — ссылка на источник.
- **Каждый файл ≤ 200 строк.** Если разрастается — разбивай (пример: серверная часть раскатана на `server-manual-setup.md` / `server-add-site.md` / `server-multisite.md` / `domain-connect.md`).

## Источник истины (где именно искать)

| Тема | Файл |
|---|---|
| `console.log` удалить | `performance.md` § 4 |
| WCAG AA контрастность | `performance.md` § 11 |
| Lighthouse 90+ / PSI методика | `performance.md` § 13 |
| «Вирусный client» антипаттерн | `architecture.md` (короткий) + `performance.md` § 13.4 (развёрнуто) |
| `META_DESCRIPTION` константа | `architecture.md` (паттерн) + `seo.md` (применение в Schema) |
| Caddy-шаблон | `server-add-site.md` |
| GitHub Actions deploy.yml | `deploy.md` + `specs/01b-server-handoff.md` |
| Cookie-баннер + согласие на ПДн | `legal-templates.md` |
| 44 типа секций | `content-layout.md` |
| Шаблон спеки | `specs/templates/spec-template.md` |

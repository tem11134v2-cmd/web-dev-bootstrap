# docs/ — Knowledge Base

Универсальные модули KB. Читаются по требованию: открывай только то, что относится к текущей задаче (см. «KB files to read first» в каждой спеке). Никогда не загружай всё подряд — это съест контекст.

> Серверные операции и SSH — по канону «SSH-политика» в корневом `CLAUDE.md`.

## Карта файлов

| Файл | Что внутри | Когда читать |
|---|---|---|
| `workflow.md` | Цикл Explore→Plan→Implement→Commit, управление контекстом, doom loop, встроенный браузер, антипаттерны | В начале любой сессии (можно один раз и помнить) |
| `stack.md` | Версии всех зависимостей, канонический `next.config.ts`, init-команды, scripts | На init проекта; при добавлении/обновлении пакета |
| `architecture.md` | Структура папок, App Router, Server/Client разделение, naming, max-150-строк | На init; при создании нового компонента; при рефакторинге |
| `design-system.md` | Философия, цветовые токены (OKLCH), типографика, layout, header/footer, боевые CSS-правила | На дизайн-системе; при добавлении новых секций; при правках цветов |
| `design-motion.md` | Каталог паттернов подачи (табы, слайдеры, bento, sticky, reveal…), анти-монотонность, бюджет движения, `prefers-reduced-motion` | Спеки 03/04 и любые правки дизайна |
| `content-layout.md` | 44 типа секций + applicability + shadcn-маппинг + «Placeholder + show-флаги» | При сборке любой страницы; когда заказчик прислал текст и нужно понять тип секции |
| `conversion-patterns.md` | 10 принципов конверсии: CTA, social proof, lead magnet, quiz, exit-intent, sticky, формы | На главной/посадочных; при доработке воронки |
| `ai-assets.md` | Конвейер AI-изображений с заказчиком: фото-промты (Блок СТИЛЯ + сюжеты), правила, раскладка в `public/images/`, image-MCP | Когда заказчику нужны фото/иллюстрации |
| `forms-and-crm.md` | Ядро форм: архитектура multi-sink, Server Action `submitLead`, классификация результатов, fallback, Turnstile-принцип, Zod-схема | При создании любой формы |
| `forms-sink-recipes.md` | Полные листинги sinks (email / Sheets / Telegram / AmoCRM / B24), чек-листы «подготовка канала», тест-ключи Turnstile | Точечно при подключении конкретного канала в спеке 09 |
| `legal-templates.md` | 152-ФЗ: cookie-баннер, согласие на ПДн, политика, оферта, чек-лист РКН | При создании форм на RU-сайте; перед публикацией; при подаче в РКН |
| `seo.md` | robots/sitemap, мета, hreflang, Schema.org, ЧПУ, перелинковка, коммерческие факторы, Яндекс-специфика, Турбо/ИКС | На каждой новой странице; при подключении Яндекс/Google |
| `performance.md` | Core Web Vitals, изображения, шрифты, CSS, JS, кэш, серверная часть (Caddy `encode gzip zstd` + Cache-Control в шаблоне `server-add-site.md`), **Methodology § 13** (lessons), бюджет, чек-лист | На performance-аудите; при подозрении на регрессию; при выборе либ |
| `deploy.md` | Единая схема (Mac → GitHub → VPS), ветки, GitHub Actions, ежедневный цикл, откат, Cloudflare | При init проекта; при ежедневном деплое; при правках CI/CD |
| `server-manual-setup.md` | Разовая настройка свежего VPS через `scripts/bootstrap-vps.sh`: пользователь, SSH, ufw, swap, Node runtime + Caddy + PM2 (build на runner, pnpm/git на VPS не ставятся) | Один раз на каждый новый VPS |
| `server-add-site.md` | Подключение нового сайта на готовый VPS: порты, клон, Caddy-конфиг, SSL (автоматический), GitHub Secrets, первый деплой | Один раз на каждый новый сайт |
| `server-multisite.md` | Как уживаются несколько сайтов на одном VPS (реестр портов, PM2, Caddyfile.d, когда выносить на отдельный VPS) | При подключении 2-го и далее сайта; при масштабировании |
| `domain-connect.md` | A-записи у регистратора или Cloudflare, проверка `dig`, подготовка к SSL | Один раз на каждый домен |
| `automation.md` | Хуки `.claude/hooks/*` (session-start, before-push, guard-rm, format, subagent-stop, stop-reminder) + slash-команды `.claude/commands/*` (handoff, resume, catchup, orchestrate) + скрипты `scripts/sync-env.sh`, `rollback.sh`. Что делают, как отключить, как добавить новый | Когда непонятно что хук пишет в чате; когда нужно sync/rollback; при добавлении нового хука; при настройке multi-Claude flow |
| `orchestration.md` | Оркестраторный режим: что читает оркестратор, роли (builder-sonnet / builder-opus / verifier / integrator), брифы, гейты, что нельзя параллелить | Оркестраторные волны (полный сайт, rollout, recreate); мелкие задачи — интерактивно, без него |
| `troubleshooting.md` | Частые косяки: gh auth mismatch, DDoS-Guard 301, SSH permission denied в deploy job, симлинк `current` не переключился, ошибки передачи артефакта (scp/tar), PM2 не находит `server.js`, Caddy не стартует, SSL не выписывается, branch protection 403, swap не пересоздаётся, prod 404 | Когда что-то сломалось — сначала сюда, потом `lessons.md` |

## Проектные файлы (не KB)

Пишутся под конкретный проект, не входят в bootstrap:

| Файл | Что внутри | Кто заполняет |
|---|---|---|
| `docs/spec.md` | Бизнес, ЦА, услуги, бренд (цвета, шрифт), контакты, домен, основные SEO-запросы | Создаётся в `00-brief` из материалов заказчика |
| `docs/content.md` | Тексты по страницам в едином формате | Заказчик / копирайтер; разработчик только раскладывает |
| `docs/pages.md` | Карта страниц + статус + редиректы (старые URL → новые) | На init + поддерживается до релиза |
| `docs/integrations.md` | CRM, аналитика, домен, внешние сервисы (без секретов) | Постепенно по ходу проекта |
| `docs/photo-prompts.md` | Фото-промты для AI-изображений: Блок СТИЛЯ + сюжеты по кадрам | Claude по `docs/ai-assets.md`, когда нужны изображения |
| `CLIENT-TODO.md` (корень) | Что нужно от заказчика: доступы, материалы, подтверждения, верификации | Создаётся в `00-brief`, пополняется по триггерам (правило в `CLAUDE.md`) |

## Правила работы с docs/

- **Не загружай весь docs/ в контекст.** Каждая спека явно перечисляет нужные файлы.
- **Если правишь docs/ по ходу проекта** — это сигнал что bootstrap устарел. Рассмотри: правка специфична для проекта (тогда в `docs/spec.md`/`pointers.md`) или универсальна (тогда — в bootstrap).
- **Дедупликация:** если факт повторяется в двух файлах — это бага. Источник истины — таблица ниже; на остальных страницах — ссылка на источник, не копия.
- **Каждый файл ≤ 200 строк** (цель). Если разрастается — разбивай (примеры: серверная часть → `server-manual-setup.md` / `server-add-site.md` / `server-multisite.md` / `domain-connect.md`; формы → ядро `forms-and-crm.md` + `forms-sink-recipes.md`).

## Источник истины (где именно искать)

| Тема | Файл |
|---|---|
| Канонический `next.config.ts` | `stack.md` |
| `console.log` удалить | `performance.md` § 4 |
| WCAG AA контрастность | `performance.md` § 11 |
| Lighthouse 90+ / PSI методика | `performance.md` § 13 |
| «Вирусный client» антипаттерн | `architecture.md` (короткий) + `performance.md` § 13.4 (развёрнуто) |
| `META_DESCRIPTION` константа | `architecture.md` (паттерн) + `seo.md` (применение в Schema) |
| Паттерны подачи, анти-монотонность, бюджет движения | `design-motion.md` |
| Листинги sinks и подготовка каналов | `forms-sink-recipes.md` |
| Caddy-шаблон | `server-add-site.md` |
| GitHub Actions deploy.yml | `deploy.md` + `_BUILD/templates/deploy-prod.yml.example` |
| Cookie-баннер + согласие на ПДн | `legal-templates.md` |
| 44 типа секций | `content-layout.md` |
| Шаблон спеки | `specs/templates/spec-template.md` |
| Шаблон CLIENT-TODO | `specs/templates/client-todo-template.md` |

# Handoff S4 → S5

## Что сделано в S4

Создано 12 файлов в `docs/` (все ≤ 200 строк, все на русском):

| Файл | Строк | Источник | Заметки |
|---|---|---|---|
| `workflow.md` | 117 | M1 | Hooks-примеры выкинуты в `specs/01-infrastructure.md` (TODO в S5) |
| `stack.md` | 73 | M2 | + `package.json` scripts, note про Zod tree-shake (ссылка на performance) |
| `architecture.md` | 108 | M3 | «Вирусный client» — короткий блок + ссылка на performance |
| `design-system.md` | 91 | M4 | Цвета — не плейсхолдер, а ссылка на `00-brief.md` |
| `content-layout.md` | 164 | M5 | 44 секции в плотном формате (исходные 347 строк → 164) |
| `forms-and-crm.md` | 200 | M6 | + AmoCRM/Bitrix24 шаблоны, чекбокс согласия, fallback в JSON |
| `deploy.md` | 143 | M7 | Концепции + схемы A/B + ежедневная работа + откат + handoff |
| `deploy-server-setup.md` | 178 | M7 (split) | VPS, nginx, SSL, Cloudflare, troubleshooting |
| `seo.md` | 191 | M8 | + Турбо/ИКС/региональность/Вебмастер, дедуп Lighthouse/WCAG → performance |
| `performance.md` | 199 | M9 + lessons | § 13 «Methodology» — интегрированные lessons. «Вирусный client» поглощён |
| `conversion-patterns.md` | 85 | M10 | + ссылка на legal-templates для согласий |
| `legal-templates.md` | 133 | NEW | 152-ФЗ: cookie-баннер, согласие на ПДн, политика, оферта, чек-лист РКН |

`docs/INDEX.md` ещё не создан — это задача S5 (вместе с `specs/INDEX.md`).

## Дедупликация (как и обещали в migration-map)

- **`console.log` удалить** — оставлено только в `performance.md` § 4.
- **WCAG контрастность** — только в `performance.md` § 11; в `seo.md`/`design-system.md` — короткие ссылки.
- **Lighthouse 90+ / PSI** — только в `performance.md`; в `seo.md` чек-лист — «производительность зелёная (см. performance)».
- **Hooks .json пример** — выкинут из `workflow.md`, ссылка на `specs/01-infrastructure.md`.
- **`/catchup` команда-пример** — выкинут из `workflow.md`, ссылка туда же.

## Решения, отклонения от плана

1. **deploy.md разбит на два файла** (`deploy.md` + `deploy-server-setup.md`) — иначе не влезал в 200 строк. Concept/daily/handoff в основном; VPS/nginx/Cloudflare/troubleshooting в server-setup. В `CLAUDE.md` обновить ссылки в S5.
2. **`docs/INDEX.md`** — не создан в S4. План: S5, после того как все docs оформлены.
3. **`scheduling/Brotli`** в `performance.md` — упомянут как опция, но рекомендация = gzip + `gzip_static` (по lessons из user-memory).
4. **«Вирусный client»** реально присутствует в трёх местах: короткое упоминание в `architecture.md`, развёрнуто в `performance.md` § 4 + § 13.4. Дублирование намеренное — это критичный паттерн, а файлы читаются по отдельности.
5. **CLAUDE.md** в `/root/web-dev-bootstrap-v2/CLAUDE.md` уже ссылается на `docs/deploy.md` (схемы A/B) — соответствует. Но не упоминает `deploy-server-setup.md` — добавить в S5.

## Что осталось для S5 (specs/)

По migration-map.md:

- `specs/INDEX.md` — последовательность 13 этапов + 4 опциональных + extend
- `specs/00-brief.md` — приём готовых файлов от пользователя
- `specs/01-infrastructure.md` — VPS-bootstrap (пошагово), хуки `.claude/hooks.json`, команда `/catchup`
- `specs/02-project-init.md` — init-команды + структура папок
- `specs/03-design-system.md` — `tailwind.config` setup + цвета из брифа
- `specs/04-homepage-and-approval.md` — главная + промежуточный деплой + правки заказчика
- `specs/05-subpages-template.md` — шаблонизация `ServicePageTemplate`
- `specs/06-subpages-rollout.md` — массовая раскатка по `pages.md`
- `specs/07-blog-optional.md` — MDX-блог
- `specs/08-seo-schema.md` — Schema.org, sitemap, robots
- `specs/09-forms-crm.md` — формы по `docs/forms-and-crm.md`
- `specs/10-analytics.md` — Метрика, GSC, Вебмастер
- `specs/11-performance.md` — performance-аудит по `docs/performance.md` § 13
- `specs/12-handoff.md` — передача проекта + runbook аварий
- `specs/13-extend-site.md` — цикл расширения после релиза
- `specs/optional/opt-quiz.md`, `opt-ecommerce.md`, `opt-i18n.md`, `opt-migrate-from-existing.md`
- `specs/templates/spec-template.md`, `page-spec-template.md`
- `specs/examples/` — 1–2 примера (взять из migrator/specs/20 и 25, обезличить)

Уже существуют файлы-«заглушки» в `specs/` (00–13 + optional/templates/examples) — проверить содержимое, перезаписать или дописать. Список `ls specs/` из стартового сообщения совпадает с планом.

## Файлы, не тронутые в S4

- `_BUILD/migration-map.md` — служебный, удалится после релиза v2.0.
- `CLAUDE.md` (live) — обновить в S5: добавить ссылку на `deploy-server-setup.md` и на `INDEX.md` файлы.
- `_BUILD/changelog.md` — не создан (не требовался в S4, см. план).
- `_BUILD/unpack-instructions.md` — не создан (план: финал внутрь bootstrap-v2.md).

## Сигналы для следующей сессии

- Если specs уже частично заполнены — **прочитать каждый перед перезаписью**, не дублировать работу.
- Шаблон спеки в `specs/templates/spec-template.md` — структура из `docs/workflow.md` § «Спецификации».
- Examples — `migrator/specs/20-server-components-refactor.md` и `25-performance-audit.md` (обезличить).

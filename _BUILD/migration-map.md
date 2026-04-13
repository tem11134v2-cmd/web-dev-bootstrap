# Карта переезда: web-dev-bootstrap.md v1.7 → v2.0

Служебный файл для отслеживания, что куда переезжает. После релиза v2.0 — удалить.

## Старый bootstrap → новые файлы

| Старое (v1.7) | Строки | Новое (v2.0) | Действие |
|---|---|---|---|
| Инструкция по развёртыванию | 6-25 | `_BUILD/unpack-instructions.md` (черновик) → финал внутрь bootstrap-v2.md | Переписать: 8 шагов под новую структуру |
| МОДУЛЬ 1: WORKFLOW | 28-217 | `docs/workflow.md` | Сократить дубли с performance/seo, оставить дисциплину + контекст |
| МОДУЛЬ 2: STACK | 219-265 | `docs/stack.md` | Минимум правок |
| МОДУЛЬ 3: ARCHITECTURE | 267-349 | `docs/architecture.md` | Убрать «вирусный client» (уйдёт в performance) — оставить ссылку |
| МОДУЛЬ 4: DESIGN-SYSTEM | 351-422 | `docs/design-system.md` | Минимум правок |
| МОДУЛЬ 5: CONTENT-LAYOUT | 424-771 | `docs/content-layout.md` | Минимум правок (44 секции — ценно) |
| МОДУЛЬ 6: FORMS-AND-CRM | 773-856 | `docs/forms-and-crm.md` | Дополнить шаблонами интеграций (AMO, Bitrix24 — опционально) |
| МОДУЛЬ 7: DEPLOY | 858-1226 | `docs/deploy.md` | **Переписать**: две схемы (A: solo dev=prod, B: client с GitHub Actions) + Cloudflare-секция |
| МОДУЛЬ 8: SEO | 1228-1557 | `docs/seo.md` | Дополнить: Турбо/ИКС/региональность, ссылки на legal-templates |
| МОДУЛЬ 9: PERFORMANCE | 1559-1870 | `docs/performance.md` | Интегрировать lessons из user-memory как «Methodology» секцию, абсорбировать «вирусный client» |
| МОДУЛЬ 10: CONVERSION-PATTERNS | 1873-1928 | `docs/conversion-patterns.md` | Минимум правок |
| ШАБЛОНЫ ПРОЕКТНЫХ ФАЙЛОВ | 1931-2044 | Уходят в `00-brief.md` как «что приносит пользователь» | Переформатировать под входной формат (готовые .md от пользователя или tilda-export) |
| ШАБЛОН CLAUDE.md | 2046-2110 | `CLAUDE.md` (live, не template) + `_BUILD/claude-md-template.md` (для bootstrap) | Дополнить секцией «Memory triggers» |
| CHANGELOG | 2114-2127 | `_BUILD/changelog.md` → финал в bootstrap-v2.md | Сохранить + добавить v2.0 entry |

## Новые файлы (не было в v1.7)

| Файл | Источник содержимого |
|---|---|
| `docs/INDEX.md` | Новый: таблица «файл → что внутри → когда читать» |
| `docs/legal-templates.md` | Новый: 152-ФЗ cookie-баннер, согласие на ПДн, плейсхолдер политики/оферты |
| `specs/INDEX.md` | Новый: последовательность 13 этапов + 4 опциональных + extend |
| `specs/00-brief.md` | Новый: приём готовых файлов от пользователя (.md или tilda-export) |
| `specs/01-infrastructure.md` | Из старого DEPLOY (первичная настройка VPS) |
| `specs/02-project-init.md` | Из старого STACK (init-команды) + ARCHITECTURE (структура папок) |
| `specs/03-design-system.md` | Из старого DESIGN-SYSTEM + tailwind.config setup |
| `specs/04-homepage-and-approval.md` | Новый: главная + промежуточный деплой + правки заказчика |
| `specs/05-subpages-template.md` | Новый: шаблонизация (паттерн ServicePageTemplate из migrator) |
| `specs/06-subpages-rollout.md` | Новый: массовая раскатка по pages.md |
| `specs/07-blog-optional.md` | Новый: MDX-блог |
| `specs/08-seo-schema.md` | Из старого SEO (Schema.org, sitemap, robots) |
| `specs/09-forms-crm.md` | Из старого FORMS-AND-CRM |
| `specs/10-analytics.md` | Из старого SEO раздел 10 (Метрика, GSC, Вебмастер) |
| `specs/11-performance.md` | Из старого PERFORMANCE + lessons методология |
| `specs/12-handoff.md` | Из старого DEPLOY раздел «Передача проекта» + runbook аварий |
| `specs/13-extend-site.md` | Новый: цикл расширения после релиза (новые страницы, блоки, статьи) |
| `specs/optional/opt-quiz.md` | Из migrator (специфика квиза-калькулятора) |
| `specs/optional/opt-ecommerce.md` | Новый, из CONTENT-LAYOUT раздел «Товарные блоки» |
| `specs/optional/opt-i18n.md` | Новый: next-intl |
| `specs/optional/opt-migrate-from-existing.md` | Новый: экстракция со старого сайта (Tilda и др.) — шрифты, лого, фото, тексты, редиректы |
| `specs/templates/spec-template.md` | Новый: пустой шаблон (см. файл) |
| `specs/templates/page-spec-template.md` | Новый: шаблон спеки страницы (см. файл) |
| `specs/examples/` | 1-2 живых примера из migrator (specs/20, specs/25 — обезличенные) |
| `.claude/memory/` (6 файлов + INDEX) | Новый: проектная память с триггерами обновления |

## Что выкидываем

| Что | Откуда | Почему |
|---|---|---|
| Дубли «console.log удалить» | performance, seo, deploy | Оставить только в performance |
| Дубли «WCAG контраст» | architecture, performance, seo | Оставить в performance (a11y), в seo — ссылка |
| Дубли «Lighthouse 90+» | architecture, deploy, seo | Оставить в performance, в остальных — упоминание |
| `.claude/hooks.json` пример в workflow.md | workflow.md | Перенести в `01-infrastructure.md` (это шаг настройки, а не правило) |
| `.claude/commands/catchup.md` пример | workflow.md | Перенести в `01-infrastructure.md` |
| Placeholder «Заполни под проект» цвета | design-system | Заменить на реальный поток: цвета приходят в `00-brief.md` |
| Англо-русский switching внутри одного модуля | везде | Унифицировать: docs/specs — RU, code/CLAUDE.md — EN |

## Заметки на полях

- В старом bootstrap деплой описан только по схеме B (две папки + GitHub Actions). У пользователя реальный migrator работает по схеме A (dev=prod на одном VPS, без remote). Обе нужны.
- Старый bootstrap молчит про cookie-banner / 152-ФЗ. Это критично для всех RU-сайтов с формами. Добавляем в `09-forms-crm.md` (обязательная задача) + `docs/legal-templates.md` (готовые тексты).
- Спеки migrator/specs/01-12 — про конкретный сайт, не подходят для examples/. Подходят `20-server-components-refactor.md` и `25-performance-audit.md` — они показывают формат «зрелой» спеки. Скопируем как есть с пометкой «образец, не выполнять».

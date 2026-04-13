# Handoff S5 → S6 (release)

## Что сделано в S5

Спек-структура была частично создана раньше (13 апреля до S4). В S5 — верификация, синхронизация со свежими `docs/` и создание двух INDEX-файлов.

### Создано в S5

| Файл | Назначение |
|---|---|
| `docs/INDEX.md` | Карта KB-файлов: что внутри + когда читать + источник истины |
| `specs/INDEX.md` | Последовательность 13 спек, граф зависимостей, optional/templates/examples |
| `_BUILD/handoff-s5.md` | Этот файл |

### Обновлено в S5

| Файл | Что поменяно |
|---|---|
| `CLAUDE.md` | KB pointers — добавлен `deploy-server-setup.md`, переформулирована Specs-секция |
| `specs/01-infrastructure.md` | Ссылки `docs/deploy.md` → `deploy.md` + `deploy-server-setup.md` (для шаблонов nginx/Cloudflare/deploy.yml) |
| `specs/11-performance.md` | Ссылка на nginx-раздел переехала в `deploy-server-setup.md` |
| `specs/12-handoff.md` | Раздел «Передача проекта» — в `deploy.md`, «Регулярное обслуживание» / «Типовые проблемы» — в `deploy-server-setup.md` |
| `specs/examples/example-20-server-components-refactor.md` | `docs/patterns.md` (не существовал) → `docs/architecture.md` + `docs/performance.md` § 13.4 |
| `specs/examples/example-25-performance-audit.md` | Добавлена ссылка на `docs/performance.md` и `docs/deploy-server-setup.md` |

### Не тронуто (всё в порядке после проверки)

Все остальные 12 спек (00, 02–10, 13) и 4 опциональные (`opt-quiz`, `opt-ecommerce`, `opt-i18n`, `opt-migrate-from-existing`) ссылаются на актуальные `docs/`-файлы, согласуются по контенту, не имеют битых ссылок. Шаблоны (`spec-template.md`, `page-spec-template.md`) актуальны.

## Полная текущая структура проекта

```
web-dev-bootstrap-v2/
├── CLAUDE.md                           ← live, для проекта-наследника
├── _BUILD/                             ← служебное, удалить перед v2.0 релизом
│   ├── migration-map.md
│   ├── handoff-s4.md
│   └── handoff-s5.md
├── docs/                               ← KB, 13 файлов, все ≤ 200 строк
│   ├── INDEX.md
│   ├── workflow.md / stack.md / architecture.md / design-system.md
│   ├── content-layout.md / forms-and-crm.md / conversion-patterns.md
│   ├── seo.md / performance.md / legal-templates.md
│   └── deploy.md + deploy-server-setup.md
└── specs/
    ├── INDEX.md
    ├── 00-brief.md … 13-extend-site.md  (14 спек)
    ├── optional/  (4 опциональные спеки)
    ├── templates/ (spec-template + page-spec-template)
    └── examples/  (README + 2 примера)
```

## Что осталось до релиза v2.0 (S6)

1. **`_BUILD/changelog.md`** — собрать changelog v1.7 → v2.0 (новые файлы, что вынесено, что добавлено, breaking changes для тех, кто работал по v1.7).
2. **`_BUILD/unpack-instructions.md`** или финальный единый файл `web-dev-bootstrap-v2.md` — формат «приходит одним .md, разворачивается в структуру». Решение нужно: оставлять как папку или склеивать в один файл (как v1.7)?
3. **Проверка `.claude/memory/` шаблонов** — есть ли в файлах реальные данные migrator или это уже обезличенные шаблоны? Если есть — обезличить.
4. **Quick smoke test:** «новый проект на bootstrap-v2» — пройти 00 → 02 → 03 на новом VPS/локально, убедиться что спеки выполнимы как написаны.
5. **Удалить `_BUILD/`** перед публикацией.

## Решения, открытые для S6

- **Формат поставки.** v1.7 был одним файлом 2128 строк. v2.0 сейчас — 30+ файлов в папках. Что лучше для нового пользователя? Варианты:
  - (a) папка как есть + README с инструкцией «склонируй и работай»
  - (b) один большой `.md` как раньше, но с явными разделителями `--- FILE: docs/workflow.md ---` и автоскриптом распаковки
  - (c) git-репо-template на GitHub (`Use this template`)
- **CLAUDE.md template vs live.** Сейчас `CLAUDE.md` уже заполнен под некий проект. Для bootstrap правильно либо плейсхолдер `[Name]`, либо отдельный `_BUILD/claude-md-template.md`. Решено в migration-map: «CLAUDE.md (live) + `_BUILD/claude-md-template.md`». Второго пока нет — задача S6.

## Сигналы для следующей сессии

- Все спеки уже проверены и согласованы — **не переписывать**, только добавлять (changelog, unpack-instructions, claude-md-template, README).
- Если пользователь хочет smoke test — нужен либо отдельный VPS, либо локалхост; на migrator.me-сервере НЕ запускать (там продакшен).
- При финализации формата поставки помнить: **простота > гибкость**. Один `.md` файл в 2128 строк было удобно (одна команда копи-паста), но сложно поддерживать. Repo-template — самый удобный для пользователя, но требует GitHub.

## Метрики

- Файлов в `docs/`: 13
- Файлов в `specs/`: 14 основных + 4 optional + 2 templates + 3 examples (README + 2) = **23**
- Все `docs/*.md` ≤ 200 строк ✅
- Все `specs/*.md` ≤ 160 строк ✅
- Битых ссылок на несуществующие файлы: **0** (после правок)
- Дублирующих секций: **0** (источники истины зафиксированы в `docs/INDEX.md`)

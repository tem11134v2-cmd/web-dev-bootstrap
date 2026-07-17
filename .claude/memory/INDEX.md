# Project Memory Index

Лёгкие записи, которые переживают `/clear` и помогают новой сессии Claude'а
быстро войти в контекст проекта. Не дублирует docs/ — только то, что НЕ
выводимо из кода и докуменации.

## Когда читать

- В начале каждой новой сессии (после `/clear` или `claude` cold start)
- Перед стартом любой спеки
- Когда CLAUDE.md ссылается на «проектные решения»

## Файлы

- [project_state.md](project_state.md) — активная фаза, текущая спека, блокеры, Task ledger (оркестраторные волны), Session log
- [decisions.md](decisions.md) — принятые решения с обоснованием **Why:**
- [feedback.md](feedback.md) — правила и табу заказчика с **Why:**
- [references.md](references.md) — реестр ID/URL внешних сервисов (никогда секреты), пути
- [lessons.md](lessons.md) — кейсы аварий и фиксов («это сломалось — починили так»)
- [pointers.md](pointers.md) — где в коде какой переиспользуемый паттерн/компонент
- `archive/` — старые записи Session log: ротация из `project_state.md` (≤15 записей в логе, старше — сюда)

## Когда обновлять (триггеры)

См. секцию `Memory triggers (when to update .claude/memory/)` в `CLAUDE.md` корня проекта.

## Что НЕ класть сюда

- Цвета, типографика, секции — это в `docs/design-system.md` и `docs/content-layout.md`
- Список страниц — в `docs/pages.md`
- Готовые тексты — в `docs/content.md`
- Стек технологий — в `CLAUDE.md`
- Подробные инструкции по деплою — в `docs/deploy.md`

Принцип: **memory = индекс и неочевидное, docs = справочник.**

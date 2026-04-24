# Spec 04: Главная страница + промежуточный деплой + одобрение заказчика

## KB files to read first

- docs/content-layout.md (полностью — нужно выбрать секции)
- docs/design-system.md
- docs/conversion-patterns.md
- docs/seo.md (раздел «Мета-теги»)
- docs/content.md (готовые тексты главной)
- docs/spec.md
- `.claude/memory/feedback.md`

## Goal

Собрать главную страницу из секций под бизнес-задачу заказчика, выкатить на dev-окружение (или прямо на prod, если dev-поддомен не настроен), показать заказчику, собрать правки, итерировать до одобрения. Без одобрения главной — НЕ переходить к подстраницам.

## Background

Главная — лицо проекта и точка демо. Одобрение главной = одобрение дизайн-системы, тона, структуры. После него подстраницы делаются по тем же лекалам — заказчик не должен возвращать «не тот стиль» на 12-й странице.

Формы здесь работают «фейково» (CTA открывает заглушку или модалку без отправки) — реальная интеграция в спеке 09.

## Tasks

### 1. Сборка секций

1. Из `docs/content.md` определить какие секции нужны (типичный набор: Hero, Stats, Services/Sub-services, Steps, Benefits, Reviews, FAQ, CTA Final)
2. Для каждой секции:
   - Создать `components/sections/[Name].tsx` (server component если нет state)
   - Использовать тип секции из `docs/content-layout.md` (структура, layout, компоненты)
   - Заполнить готовым текстом из `docs/content.md`
   - Соблюсти правила H2 (выгода, не «наши преимущества») из docs/content-layout.md
3. Собрать секции в `app/page.tsx`:
   ```tsx
   export const metadata: Metadata = { /* из docs/seo.md */ }
   export default function Home() {
     return (
       <>
         <HomeHero />
         <Stats />
         <Services />
         {/* ... */}
       </>
     )
   }
   ```

### 2. Заглушка форм консультации

4. Создать `components/forms/ConsultationDialog.tsx` (client) — модалка с полями имя/телефон, кнопка submit показывает `toast.success('Заявка принята (заглушка)')` через Sonner. Реальная отправка в спеке 09.
5. Создать `lib/consultation-context.tsx` — глобальный контекст модалки (open/setOpen)
6. Обернуть `<ConsultationDialogProvider>` вокруг `{children}` в `app/layout.tsx`
7. Все CTA-кнопки на главной → `useConsultationDialog().setOpen(true)`

### 3. Адаптив и проверка

8. Проверить mobile (375px), tablet (768px), desktop (1280px, 1920px)
9. Проверить контраст текста (WCAG AA ≥ 4.5:1)
10. Проверить отсутствие console errors
11. `npm run build` — должен пройти без ошибок

### 4. Промежуточный деплой

12. `git add . && git commit -m 'feat: homepage v1' && git push origin dev`. GitHub Actions (если dev-preview настроен в `01b`) задеплоит на `dev.[domain]`. Если preview не настраивали — мёрджим `dev → main` через PR и смотрим на prod-домене.

### 5. Демо заказчику и сбор правок

14. Отправить заказчику URL + краткий чек-лист, что посмотреть:
    - Бренд (цвета, шрифт)
    - Тон и формулировки
    - Структура (порядок секций, что добавить/убрать)
    - Адаптив (мобилка)
    - Любые правки по контенту
15. Получить правки от заказчика — записать в `.claude/memory/feedback.md` (с **Why:** где известно)
16. Итерация: внести правки → коммит → деплой → новый раунд. Повторять до явного «одобрено»

### 6. Зафиксировать одобрение

17. После одобрения создать тег `git tag homepage-approved` (или коммит `feat: homepage approved by client`)
18. Записать в `.claude/memory/decisions.md`: «Главная одобрена [дата], дизайн-язык зафиксирован. Все подстраницы — в этой же стилистике».

## Boundaries

- **Always:** коммитить после каждой завершённой секции (save points), показывать заказчику build+deploy, не «локалхост»
- **Ask first:** перед добавлением секций, не указанных в `docs/content.md` (предложить, но не реализовывать без подтверждения)
- **Never:** переходить к 05-subpages-template до явного одобрения заказчика, добавлять реальную CRM-интеграцию (это 09)

## Done when

- Главная собрана из секций, тексты из docs/content.md
- Mobile/tablet/desktop корректны
- `npm run build` проходит
- Деплой на dev/prod выполнен
- Заказчик дал явное «одобрено»
- Тег `homepage-approved` создан
- Правки заказчика записаны в `feedback.md`

## Memory updates

- `feedback.md` — все правки заказчика с **Why:** + **How to apply:**
- `decisions.md` — фиксация одобрения главной + дизайн-язык зафиксирован
- `pointers.md` — пути к секциям главной (HomeHero, Stats, Services и т.д.) — будут переиспользованы
- `project_state.md` — done, следующая `05-subpages-template`

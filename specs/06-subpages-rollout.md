# Spec 06: Раскатка подстраниц по карте

## KB files to read first

- docs/pages.md (полный список страниц)
- docs/content.md (тексты по страницам)
- docs/seo.md (метаданные, canonical, alt-теги)
- `components/service-page/ServicePageTemplate.tsx` (шаблон из 05)
- `components/service-page/types.ts`
- specs/templates/page-spec-template.md
- `.claude/memory/pointers.md`

## Goal

Создать все оставшиеся подстраницы из `docs/pages.md` с приоритетом HIGH (и MEDIUM, если хватит сессий). Каждая страница — через шаблон, с уникальным контентом, мета-тегами, JSON-LD, в sitemap.

## Background

Это самая объёмная и рутинная фаза. Цель — максимальная автоматизация: одна страница ≈ 5-10 минут (создать data-файл + page.tsx + добавить в sitemap). При большом объёме (>10 страниц) — разбить на сессии, не пытаться сделать всё за раз.

## Tasks

### 1. Подготовка списка

1. Из `docs/pages.md` извлечь все страницы со статусом `todo` и приоритетом HIGH
2. Сгруппировать по типу (страница услуги через шаблон / уникальная страница / страница-каталог)
3. Если страниц > 10 — выбрать первые 5-7 для этой сессии, остальные — следующая сессия

### 2. Раскатка по шаблону

Для каждой страницы:

4. Создать `app/[slug]/page-data.ts` с объектом типа `ServicePageData`, заполнить:
   - `slug` (URL без слешей)
   - `metaTitle` (60-70 символов, ключ + бренд)
   - `metaDescription` (150-160 символов)
   - Контент секций — из `docs/content.md`
5. Создать `app/[slug]/page.tsx`:
   ```tsx
   import { ServicePageTemplate } from '@/components/service-page/ServicePageTemplate'
   import { data } from './page-data'
   import type { Metadata } from 'next'

   export const metadata: Metadata = {
     title: data.metaTitle,
     description: data.metaDescription,
     alternates: { canonical: `https://[domain]/${data.slug}/` },
     openGraph: { title: data.metaTitle, description: data.metaDescription, url: `https://[domain]/${data.slug}/` },
   }

   export default function Page() {
     return <ServicePageTemplate data={data} />
   }
   ```
6. Добавить страницу в `app/sitemap.ts`
7. Если в `docs/pages.md` есть редирект для этой страницы — добавить в `next.config.ts → redirects()`
8. Коммит `feat: add /[slug]/ page`

### 3. Кастомные страницы

9. Страницы, которые не подходят под `ServicePageTemplate` (например, /about/, /contacts/, /reviews/) — собирать вручную из секций `components/sections/*` по тому же принципу что главная
10. Каждая — отдельный коммит

### 4. Перелинковка

11. Пройтись по всем созданным страницам, добавить:
    - Хлебные крошки (компонент `components/layout/Breadcrumbs.tsx` — создать если нет, server component)
    - Блок Related в конце страницы (3-6 связанных услуг)
    - Внутренние ссылки в основном контенте на смежные услуги (не «подробнее», а «оформление визы O-1»)
12. Обновить навигацию Header/Footer ссылками на новые страницы

### 5. Обновить статус в pages.md

13. Поменять статус страниц на `done` в `docs/pages.md`

### 6. Проверка

14. `npm run build` — должен пройти, все ссылки валидны
15. Прогнать по чек-листу docs/seo.md → «Чек-лист SEO для разработчика» для 2-3 рандомных страниц
16. Проверить sitemap.xml на localhost — все страницы есть
17. Деплой: `git push origin dev` → PR в `main`

## Boundaries

- **Always:** уникальные title/description/H1 для каждой страницы (нет дублей), коммит после каждой страницы
- **Ask first:** если страница требует структуры не из docs/content-layout.md (новый тип секции), если нет текста для страницы в docs/content.md
- **Never:** копировать title/description между страницами, оставлять страницу без canonical, забывать sitemap

## Done when

- Все запланированные страницы созданы и доступны на localhost
- Каждая в `sitemap.ts`, имеет уникальные мета-теги, canonical, OG
- Перелинковка работает (breadcrumbs, related, внутренние ссылки)
- Header/Footer навигация обновлена
- `pages.md` обновлён (статусы)
- `npm run build` проходит, нет 404 в RSC-prefetch (см. console)
- Деплой выполнен

## Memory updates

- `project_state.md` — список созданных страниц, оставшиеся (если разбивали на сессии)
- `pointers.md` — путь к Breadcrumbs, любым новым переиспользуемым секциям
- `decisions.md` — если были нестандартные структуры страниц

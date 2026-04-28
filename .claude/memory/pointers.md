---
name: pointers
description: Где в коде какой переиспользуемый компонент или паттерн. Карта «если хочешь сделать X — смотри Y»
type: reference
---

# Указатели в код

Помогает новой сессии Claude'а не искать заново «где у нас шаблон страницы услуги»
или «где генерируется JSON-LD».

## Шаблоны страниц

- **Шаблон страницы услуги:** `components/service-page/ServicePageTemplate.tsx` —
  принимает `ServicePageData`, рендерит все секции (hero, who, steps, faq, cta).
- **Кастомные страницы:** `app/[slug]/page.tsx` — собираются из секций вручную.
- **Шаблон страницы блога:** `components/blog/PostTemplate.tsx` (если есть блог).

## Контент (MDX через Content Collections)

- **Конфиг коллекций:** `content-collections.ts` в корне — Zod-схема для frontmatter,
  единая точка истины для типов всех `.mdx` в `content/`.
- **Импорт постов:** `import { allPosts } from 'content-collections'` —
  типизированный массив, генерируется на билде в `.content-collections/generated`.
- **Рендер MDX:** `<MDXContent code={post.mdx} components={{ Callout, ... }} />`
  из `@content-collections/mdx/react`.
- **Папка контента:** `content/blog/*.mdx` (статьи), `content/services/*.mdx` (услуги).

## Секции (переиспользуемые блоки)

- **Hero (главная):** `components/sections/HomeHero.tsx` — со stats и анимированными счётчиками
- **Hero (внутренняя):** `components/sections/PageHero.tsx` — упрощённый
- **FAQ:** `components/sections/Faq.tsx` — Accordion + JSON-LD автогенерация
- **CTA Final:** `components/sections/CtaFinal.tsx` — форма лида
- **Steps:** `components/sections/Steps.tsx` — таймлайн с табами
- **Comparison:** `components/sections/Comparison.tsx` — таблица «мы vs other»

## Формы

- **Глобальный диалог консультации:** `components/forms/ConsultationDialog.tsx` +
  контекст `lib/consultation-context.tsx`. Открыть из любого места:
  `useConsultationDialog().setOpen(true)`.
- **Inline-форма лида:** `components/forms/LeadForm.tsx` — для CTA Final.
- **Server Action:** `app/actions/submit-lead.ts` — единая точка приёма всех форм
  (формы вызывают через `useActionState` + `<form action={formAction}>`).
  Endpoint `/api/lead` **не существует** (мигрировали в Фазе 4 v3.0-next16).

## SEO

- **Генератор Schema.org:** `lib/schema.ts` — функции `generateOrganizationSchema()`,
  `generateFAQSchema()`, `generateBreadcrumbSchema()`, `generateServiceSchema()`.
- **Sitemap:** `app/sitemap.ts` — добавлять каждую новую публичную страницу.
- **Robots:** `app/robots.ts`.
- **Meta defaults:** `app/layout.tsx` — корневые `metadata` с openGraph, twitter.

## UI-примитивы

- Все shadcn/ui компоненты в `components/ui/`.
- Утилита `cn()` для className: `lib/utils.ts`.

## Аналитика

- **Метрика + GA:** подключены в `app/layout.tsx` через `<Script strategy="lazyOnload">`.
- **Отправка событий целей:** `lib/analytics.ts` — функция `trackGoal(name)`.

## Юридические компоненты

- **Cookie-баннер:** `components/legal/CookieBanner.tsx`
- **Согласие на ПДн (чекбокс в формах):** `components/legal/PdnConsent.tsx`
- **Тексты политики/оферты:** `app/privacy/page.tsx`, `app/terms/page.tsx`

## Стилизация

- **Цвета и типографика:** `app/globals.css` (CSS-переменные) + `tailwind.config.ts`.
- **Глобальные стили (минимум):** `app/globals.css` — только `@import "tailwindcss"`,
  CSS-переменные и утилита `.cv-auto` для content-visibility.

## Деплой и скрипты

- **package.json scripts:** `dev` (порт 3000, локально на Mac), `build`,
  `start` (порт через PORT=... при `pm2 start`), `lint`, `compress`
  (sharp оптимизация изображений).
- **Деплой:** `git push origin dev` → preview на `dev.[domain]` → PR →
  merge в `main` → GitHub Actions катит prod.

## Что добавлять сюда

После каждой завершённой спеки — указатели на новые переиспользуемые компоненты.
Если компонент использован 1 раз и не планируется переиспользовать — не добавлять.

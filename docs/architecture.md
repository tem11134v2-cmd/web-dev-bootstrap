# Architecture

Структура папок, App Router-паттерны, правила кода.

## Структура проекта

```
project/
├── app/                        # Next.js App Router pages
│   ├── layout.tsx              # Root layout (header + footer + providers)
│   ├── page.tsx                # Главная
│   ├── globals.css             # Tailwind imports + CSS variables
│   ├── robots.ts               # SEO: robots.txt
│   ├── sitemap.ts              # SEO: sitemap.xml
│   ├── not-found.tsx           # Кастомный 404
│   ├── favicon.ico, icon.svg
│   ├── (services)/             # Группа страниц услуг (route group)
│   ├── blog/                   # Блог (опционально)
│   ├── api/
│   │   └── lead/route.ts       # Единый endpoint форм
│   └── [other-pages]/
├── components/
│   ├── ui/                     # shadcn/ui примитивы
│   ├── layout/                 # Header, Footer, MobileMenu, Navigation
│   ├── sections/               # Секции страниц (Hero, FAQ, Steps, ...)
│   └── forms/                  # ContactForm, QuizForm, ConsultationDialog
├── content/
│   ├── blog/                   # Статьи (.mdx)
│   └── services/               # Контент страниц услуг (.mdx)
├── lib/
│   ├── utils.ts                # cn() и общие хелперы
│   ├── consultation-context.tsx # Глобальный контекст модалки
│   └── crm.ts                  # Клиент CRM (см. forms-and-crm.md)
├── public/                     # Статика
├── data/                       # Fallback (leads.json)
├── docs/                       # KB (эти файлы)
├── specs/                      # Спецификации задач
├── scripts/                    # Build-time скрипты (compress-images.mjs)
└── CLAUDE.md
```

## Ключевые архитектурные решения

**App Router (не Pages Router).**
- Server Components по умолчанию — меньше JS на клиенте.
- Вложенные layouts — header/footer один раз.
- Route groups `(services)` — логическая группировка без влияния на URL.

**SSG (Static Site Generation).**
- Все публичные страницы — пререндер при сборке.
- ISR для контента с обновлениями (блог).
- API routes для динамики (формы).

**MDX для контента.**
- Файлы в git, нет БД, нет CMS.
- Frontmatter для метаданных (`title`, `description`, `date`).
- React-компоненты прямо в контенте.

**Глобальные модалки через React Context.**
- `ConsultationDialogProvider` в `app/layout.tsx`.
- Любой CTA вызывает `useConsultationDialog().setOpen(true)` — без проброса props.

## Правила кода

- **TypeScript** — строгий режим, никаких `any`.
- **Functional components** — никаких классов.
- **Named exports** для компонентов, **default export** только для `page.tsx` / `layout.tsx`.
- **Max 150 строк на компонент** — больше → разбивай.
- **Tailwind only** — без custom CSS, без styled-components, без CSS modules.
- **Английские комментарии в коде**, документация (`docs/`) — на русском.
- **Naming:** `PascalCase` для компонентов, `kebab-case` для файлов утилит, `camelCase` для переменных и функций.
- Переиспользуй shadcn/ui — не изобретай свои кнопки/диалоги.
- **Дедупликация:** общие утилиты (форматирование, RichText, иконки) — в `lib/` или `components/ui/`. Не копировать между страницами.
- **Шаблонизация:** если 5+ страниц одинаковой структуры — выноси в `ServicePageTemplate` (data-объект + рендерер). Один компонент для дизайна, данные отдельно в каждом `page.tsx`.

## Server / Client разделение

По умолчанию всё **серверное**. `"use client"` нужен только для:
- `useState`, `useEffect`, `useRef` и других хуков.
- Обработчиков событий (`onClick`, `onChange`).
- Форм, диалогов, табов с состоянием.

**Не передавай иконки props-ом из server в client** — рендери на сервере, прокидывай как `children` или `ReactNode`.

> **Anti-pattern: «вирусный client».** Один `useContext` в листе превращает весь родительский tree в client-компонент. Симптом: 9 секций оказываются client из-за одного хука диалога. Фикс: извлеки хук-узел в маленький client-компонент (`ConsultationButton`), контейнер оставь server. Подробный разбор и методика измерения — в `docs/performance.md` § «Methodology».

## Metadata в `page.tsx`

Экспортируй `metadata` напрямую из серверного `page.tsx` (не через костыли в `layout.tsx`). `metadata` — статический export, недоступен как runtime-значение.

Если `description` нужен и в meta, и в компоненте (Schema.org Service, OG, hero-абзац) — выноси в константу:

```typescript
const META_DESCRIPTION = "Услуга X для аудитории Y. Конкретика, призыв.";

export const metadata: Metadata = { description: META_DESCRIPTION };

const pageData = { metaDescription: META_DESCRIPTION }; // одно место правки
```

При шаблонизации (`ServicePageTemplate`) — генерируй JSON-LD автоматически из `pageData`, не хардкодь JSON в каждом `page.tsx`.

## Ссылки на смежные документы

- Производительность, Core Web Vitals, методология аудита — `docs/performance.md`.
- SEO-разметка, Schema.org, sitemap — `docs/seo.md`.
- Деплой, схемы A/B, nginx, PM2 — `docs/deploy.md`.
- Дизайн-токены, типографика — `docs/design-system.md`.

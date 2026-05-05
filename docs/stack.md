# Stack

Технологический стек, версии, init-команды.

## Основной стек

| Технология | Версия | Назначение |
|---|---|---|
| Next.js | 16+ | Фреймворк (App Router, Turbopack) |
| React | 19+ | UI библиотека |
| TypeScript | 5+ | Типизация |
| Tailwind CSS | v4 | Стилизация (utility-first, CSS-first config) |
| shadcn/ui | latest | UI компоненты (base-ui примитивы, **не** Radix) |
| React Hook Form | 7+ | Управление формами |
| Zod | 4+ | Валидация схем (см. note ниже) |
| MDX | via Content Collections | Контент (блог, страницы услуг) — типобезопасный frontmatter через Zod-схему, build-time компиляция (см. https://www.content-collections.dev/) |
| Sonner | 2+ | Toast-уведомления |
| Lucide React | latest | Иконки |
| Sharp | latest | Оптимизация изображений (build-time) |
| Biome | 2+ | Линтер + форматтер в одном бинарнике (заменяет ESLint+Prettier, ~10× быстрее, см. https://biomejs.dev) |

## Вспомогательные пакеты

- `clsx` — условные className
- `tailwind-merge` — мерж Tailwind-классов без конфликтов
- `class-variance-authority` (CVA) — варианты компонентов
- `tw-animate-css` — CSS-анимации для Tailwind v4
- `content-collections` + `@content-collections/core` + `@content-collections/mdx` + `@content-collections/next` — типобезопасный MDX-стек для блога и контентных страниц. Заменяет связку `next-mdx-remote` + `gray-matter`. Frontmatter валидируется Zod-схемой в `content-collections.ts`, MDX компилируется на билде в `.content-collections/generated`. См. `specs/07-blog-optional.md`.
- `@marsidev/react-turnstile` — клиент Cloudflare Turnstile (антиспам форм). Серверная часть — fetch на `challenges.cloudflare.com/turnstile/v0/siteverify` без сторонних либ. Подробности — `docs/forms-and-crm.md` § «Антиспам — Cloudflare Turnstile».
- `googleapis` — official Google API client для серверного sink'а Google Sheets (`lib/sinks/sheets.ts`). JWT auth через service account credentials. Ставится в spec 09 при подключении канала Sheets. Не клиентский (server-only через `'use server'`).
- `node-telegram-bot-api` (+ `@types/node-telegram-bot-api` devDep) — Telegram Bot API клиент для серверного sink'а Telegram (`lib/sinks/telegram.ts`). Используется с `polling: false` (нам нужен только sendMessage, polling не нужен). Ставится в spec 09 при подключении канала Telegram.
- `schema-dts` (devDep) — типы Schema.org от Google. Используется в `lib/schema.ts` для типобезопасных JSON-LD генераторов: `WithContext<Service>`, `WithContext<Article>`, `WithContext<BreadcrumbList>`. Опечатка в `@type` или поле — TypeScript-ошибка на билде, а не «странный warning в Yandex Validator уже на проде».

## Почему этот стек

**Next.js 16 App Router.** Server Components по умолчанию (меньше клиентского JS), вложенные layouts, встроенная оптимизация (images, fonts, scripts), ISR/SSG из коробки, Server Actions для форм. Turbopack для быстрой dev-сборки.

> **`output: 'standalone'`.** Билд собирается на GitHub-runner и доставляется на VPS через `rsync` (push-based deploy, см. `docs/deploy.md`). Standalone-режим выкладывает минимально-достаточный сервер в `.next/standalone/server.js` со встроенными зависимостями — артефакт компактный (~30 MB вместо `node_modules` целиком), VPS-у не нужен Node toolchain (только runtime + `pm2`). PM2 на проде запускает `node current/server.js`, а не `next start`.

**Tailwind v4.** Zero-config, быстрее v3, конфиг в CSS (`@theme`). Никакого custom CSS — только утилиты.

**shadcn/ui (base-ui).** Не библиотека, а копируемые компоненты. Полный контроль над кодом, accessible из коробки. С v4 base-ui примитивы вместо Radix.

**React Hook Form + Zod.** Минимальные ре-рендеры, нативная валидация, типобезопасность. Zod-схема = source of truth для клиента и сервера. На лендинге ~100 KB Zod в бандле незаметны, в обмен — единая экосистема и зрелая интеграция с RHF.

**MDX через Content Collections.** Контент в git, нет БД, нет CMS. Frontmatter валидируется Zod-схемой в `content-collections.ts` — опечатка в дате или нехватка поля ловится на билде, а не runtime-500. Скомпилированный MDX импортируется как типизированный массив (`allPosts`, `allServices`) — IDE-автокомплит, никакого `data: any` из gray-matter. Деплоится вместе с кодом.

## Инициализация проекта

```bash
npx create-next-app@latest project-name --typescript --tailwind --app --turbopack --no-eslint
cd project-name
npx shadcn@latest init
pnpm add \
  react-hook-form @hookform/resolvers zod @marsidev/react-turnstile \
  sonner lucide-react \
  sharp clsx tailwind-merge class-variance-authority tw-animate-css
pnpm add -D --save-exact @biomejs/biome
pnpm add -D schema-dts
pnpm exec biome init
```

Флаг `--no-eslint` нужен потому что мы заменили ESLint+Prettier на Biome (один бинарник, один конфиг, проще CI). Готовый шаблон `biome.json` лежит в корне bootstrap'а как `biome.json.example` — копируй и дорабатывай при необходимости. Дальнейшие шаги настройки (структура папок, tailwind.config, scripts) — см. `specs/02-project-init.md` и `specs/03-design-system.md`.

MDX-стек (`content-collections` + `@content-collections/core` + `@content-collections/mdx` + `@content-collections/next`) ставится опционально в `specs/07-blog-optional.md` — только если в `docs/pages.md` запланирован блог или MDX-страницы. Без блога эти пакеты в проекте не нужны.

## Скрипты `package.json`

```json
{
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000",
    "lint": "biome check",
    "format": "biome check --write",
    "typecheck": "tsc --noEmit"
  }
}
```

- `dev` на Mac по умолчанию на `localhost:3000` (совпадает с портом прода на VPS — так меньше путаницы при проверке URL-ов).
- На VPS порт prod-процесса выбирается из реестра (`docs/server-multisite.md`) — обычно 3000/3010/3020 — и прописывается в PM2-команде `PORT=3010 pm2 start /home/deploy/prod/{site}/current/server.js --name {site}-prod`, а не в `package.json`. Под push-based deploy PM2 запускает не `next start`, а напрямую `server.js` из standalone-сборки. Скрипт `start` в `package.json` остаётся как локальный fallback.
- Растровые картинки в `public/` оптимизирует `next/image` на лету (sharp идёт как `optionalDependency` Next.js 15+ и подключается автоматически). Постбилд-шага сжатия нет.
- `lint` и `format` идут через Biome — он же делает сортировку Tailwind-классов (правило `useSortedClasses`), поэтому `prettier-plugin-tailwindcss` не нужен. `typecheck` отделён от `lint`, потому что Biome не делает type-checking — это всегда `tsc`.

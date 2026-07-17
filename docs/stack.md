# Stack

Технологический стек, версии, init-команды.

## Основной стек

| Технология | Версия | Назначение |
|---|---|---|
| Next.js | 16+ | Фреймворк (App Router, Turbopack — дефолт) |
| React | 19+ | UI библиотека |
| TypeScript | 5+ | Типизация |
| Tailwind CSS | v4 | Стилизация (utility-first, CSS-first config) |
| shadcn/ui | latest | UI компоненты (base-ui примитивы, **не** Radix) |
| React Hook Form | 7+ | Управление формами |
| Zod | 4+ | Валидация схем (см. note ниже) |
| MDX | via Content Collections | Контент (блог, страницы услуг) — типобезопасный frontmatter через Zod-схему, build-time компиляция (см. https://www.content-collections.dev/) |
| Sonner | 2+ | Toast-уведомления |
| Lucide React | latest | Иконки |
| Biome | 2+ | Линтер + форматтер в одном бинарнике (заменяет ESLint+Prettier, ~10× быстрее, см. https://biomejs.dev) |

> **Zod 4 API.** Во всех примерах пакета — API четвёртой версии: `z.email()` вместо `z.string().email()`, кастомные сообщения через `{ error: '...' }` вместо `errorMap`. Полям форм всегда `.max()` (name ≤200, phone ≤30, message ≤3000).

`sharp` отдельно не ставим — он идёт `optionalDependency` Next.js и подключается к `next/image` автоматически.

## Вспомогательные пакеты

- `clsx` — условные className
- `tailwind-merge` — мерж Tailwind-классов без конфликтов
- `class-variance-authority` (CVA) — варианты компонентов
- `tw-animate-css` — CSS-анимации для Tailwind v4
- `@content-collections/core` + `@content-collections/next` + `@content-collections/mdx` (devDeps) — типобезопасный MDX-стек для блога и контентных страниц, заменяет `next-mdx-remote` + `gray-matter`. **Пакета `content-collections` в npm не существует** — `import { allPosts } from 'content-collections'` работает через tsconfig-алиас на `.content-collections/generated`. Install: `pnpm add -D @content-collections/core @content-collections/next @content-collections/mdx` — в `specs/07-blog-optional.md`, только если запланирован блог/MDX-страницы.
- `@marsidev/react-turnstile` — клиент Cloudflare Turnstile (антиспам форм). Серверная часть — fetch на `challenges.cloudflare.com/turnstile/v0/siteverify` без сторонних либ. Ставится один раз в spec 09. Подробности — `docs/forms-and-crm.md`.
- `googleapis` — official Google API client для серверного sink'а Google Sheets (`lib/sinks/sheets.ts`). JWT auth через service account. Ставится в spec 09 при подключении канала Sheets. Server-only.
- Telegram-sink (`lib/sinks/telegram.ts`) — голый `fetch` на Bot API (`https://api.telegram.org/bot{token}/sendMessage`). Пакет `node-telegram-bot-api` не нужен.
- `motion` (бывш. framer-motion) — опционально, только для reveal/scroll-эффектов в клиентских островах; всё, что можно, — CSS. См. `docs/design-motion.md`.
- `schema-dts` (devDep) — типы Schema.org от Google. Используется в `lib/schema.ts` для типобезопасных JSON-LD генераторов: `WithContext<Service>`, `WithContext<Article>`, `WithContext<BreadcrumbList>`. Опечатка в `@type` или поле — TypeScript-ошибка на билде, а не «странный warning в Yandex Validator уже на проде».

## Почему этот стек

**Next.js 16 App Router.** Server Components по умолчанию (меньше клиентского JS), вложенные layouts, встроенная оптимизация (images, fonts, scripts), ISR/SSG из коробки, Server Actions для форм. Turbopack — дефолтный бандлер, флаги не нужны.

**Tailwind v4.** Zero-config, быстрее v3, конфиг в CSS (`@theme`). Никакого custom CSS — только утилиты.

**shadcn/ui (base-ui).** Не библиотека, а копируемые компоненты. Полный контроль над кодом, accessible из коробки. Init — с явным `-b base` (base-ui примитивы — дефолт shadcn с июля 2026, но фиксируем флагом). Правило: **примитивы** (кнопки, инпуты, диалоги, табы, аккордеоны, карусель) — только shadcn/ui; **секции** — собственные композиции из этих примитивов.

**React Hook Form + Zod.** Минимальные ре-рендеры, нативная валидация, типобезопасность. Zod-схема = source of truth для клиента и сервера. На лендинге ~100 KB Zod в бандле незаметны, в обмен — единая экосистема и зрелая интеграция с RHF.

**MDX через Content Collections.** Контент в git, нет БД, нет CMS. Frontmatter валидируется Zod-схемой в `content-collections.ts` — опечатка в дате или нехватка поля ловится на билде, а не runtime-500. Скомпилированный MDX импортируется как типизированный массив (`allPosts`, `allServices`) — IDE-автокомплит, никакого `data: any` из gray-matter. Деплоится вместе с кодом. Таблица сравнения с `next-mdx-remote` — `docs/architecture.md`.

## `next.config.ts` — канонический эталон

Это **единственный эталон `next.config.ts` в пакете** — остальные документы ссылаются сюда, а не копируют конфиг.

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
  compress: false, // gzip/brotli отдаёт Caddy
}

export default nextConfig
```

- `output: 'standalone'` — билд собирается на GitHub-runner и доставляется на VPS tar.gz-ом по scp (push-based deploy, см. `docs/deploy.md`). Standalone выкладывает минимально-достаточный сервер в `.next/standalone/server.js` со встроенными зависимостями (~30 MB вместо `node_modules` целиком); VPS-у не нужен Node toolchain — только runtime + PM2, который запускает `node current/server.js`, а не `next start`.
- `experimental.ppr`, `experimental_ppr`, `experimental.useCache`, `experimental.optimizeCss` — **удалены из Next 16**, не добавлять. Опциональный кэш-режим — top-level `cacheComponents: true`, по умолчанию выключен: `docs/architecture.md` § «Cache Components».
- Опции `images.*` для перформанса — `docs/performance.md` § next.config.

## Инициализация проекта

Блок справочный — точный пошаговый рецепт со всеми проверками: `specs/02-project-init.md`.

```bash
npx create-next-app@latest project-name --typescript --tailwind --app --use-pnpm
# в визарде: линтер — Biome (create-next-app сам предлагает), Turbopack — дефолт
cd project-name
echo "node-linker=hoisted" > .npmrc    # обязательный шаг, см. ниже
npx shadcn@latest init -b base
npx shadcn@latest add sonner           # sonner — через shadcn add, не отдельным pnpm add
pnpm add react-hook-form @hookform/resolvers zod lucide-react \
  clsx tailwind-merge class-variance-authority tw-animate-css
pnpm add -D schema-dts
```

- **Biome выбирается в визарде `create-next-app`** — флаг `--no-eslint` и ручной `biome init` не нужны. `next lint` удалён в Next 16, линт — только Biome. Готовый шаблон `biome.json` — в корне bootstrap'а (`biome.json.example`), копируй и дорабатывай.
- **`.npmrc` с `node-linker=hoisted` обязателен**: без него standalone-сборка на pnpm падает в рантайме с крашем `@swc/helpers` (поймано дважды — см. `docs/troubleshooting.md`).
- `@marsidev/react-turnstile` ставится в spec 09 (формы), MDX-стек — в spec 07 (блог). На старте они не нужны.
- Дальнейшие шаги (структура папок, дизайн-токены, scripts) — `specs/02-project-init.md` и `specs/03-design-system.md`.

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

- `dev` — без флага `--turbopack`: в Next 16 Turbopack и так дефолт. Порт 3000 совпадает с прод-портом на VPS — меньше путаницы при проверке URL-ов.
- На VPS порт prod-процесса выбирается из реестра (`docs/server-multisite.md`) — обычно 3000/3010/3020 — и передаётся PM2 через env ОС: `PORT={port} HOSTNAME=127.0.0.1 pm2 start .../current/server.js --name {site}-prod` (см. `docs/deploy.md`). PM2 запускает `server.js` из standalone-сборки, не `next start`; скрипт `start` остаётся локальным fallback-ом.
- `lint` и `format` — Biome; он же сортирует Tailwind-классы (правило `useSortedClasses`), поэтому `prettier-plugin-tailwindcss` не нужен. `typecheck` отделён от `lint` — Biome не делает type-checking, это всегда `tsc`.

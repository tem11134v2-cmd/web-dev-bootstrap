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
| MDX | via next-mdx-remote | Контент (блог, страницы услуг) |
| Sonner | 2+ | Toast-уведомления |
| Lucide React | latest | Иконки |
| Sharp | latest | Оптимизация изображений (build-time) |

## Вспомогательные пакеты

- `clsx` — условные className
- `tailwind-merge` — мерж Tailwind-классов без конфликтов
- `class-variance-authority` (CVA) — варианты компонентов
- `tw-animate-css` — CSS-анимации для Tailwind v4
- `gray-matter` — парсинг frontmatter в MDX

## Почему этот стек

**Next.js 16 App Router.** Server Components по умолчанию (меньше клиентского JS), вложенные layouts, встроенная оптимизация (images, fonts, scripts), ISR/SSG из коробки, API routes для форм. Turbopack для быстрой dev-сборки.

> **Почему без `output: "standalone"`.** Standalone собирает минимальный сервер в `.next/standalone/` для случаев, когда билд едет в Docker-образ или CI доставляет артефакт. У нас билд собирается прямо на VPS после `git pull`, PM2 запускает `next start` — standalone в этой схеме просто лишний артефакт. Если проект вырастет до Docker/отдельной build-ноды — включим тогда.

**Tailwind v4.** Zero-config, быстрее v3, конфиг в CSS (`@theme`). Никакого custom CSS — только утилиты.

**shadcn/ui (base-ui).** Не библиотека, а копируемые компоненты. Полный контроль над кодом, accessible из коробки. С v4 base-ui примитивы вместо Radix.

**React Hook Form + Zod.** Минимальные ре-рендеры, нативная валидация, типобезопасность. Zod-схема = source of truth для клиента и сервера.

**MDX.** Контент в git, нет БД, нет CMS. Frontmatter для метаданных. Деплоится вместе с кодом.

> **Note про Zod v4.** Tree-shaking не работает для методов на объектах (`z.string().email()`) — вся либа тянется в бандл (~100 KB gzip). Для крупных проектов с большими бандлами рассмотри Valibot (1–3 KB, функциональный API). Для типичного лендинга Zod достаточно. Подробнее см. `docs/performance.md` § «Красные флаги зависимостей».

## Инициализация проекта

```bash
npx create-next-app@latest project-name --typescript --tailwind --app --turbopack
cd project-name
npx shadcn@latest init
npm install \
  react-hook-form @hookform/resolvers zod \
  sonner lucide-react \
  next-mdx-remote gray-matter \
  sharp clsx tailwind-merge class-variance-authority tw-animate-css
```

Дальнейшие шаги настройки (структура папок, tailwind.config, scripts) — см. `specs/02-project-init.md` и `specs/03-design-system.md`.

## Скрипты `package.json`

```json
{
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000",
    "lint": "next lint"
  }
}
```

- `dev` на Mac по умолчанию на `localhost:3000` (совпадает с портом прода на VPS — так меньше путаницы при проверке URL-ов).
- На VPS порт prod-процесса выбирается из реестра (`docs/server-multisite.md`) — обычно 3000/3010/3020 — и прописывается в PM2-команде `PORT=3010 pm2 start npm --name {site}-prod -- start`, а не в `package.json`. Скрипт `start` остаётся как fallback.
- Растровые картинки в `public/` оптимизирует `next/image` на лету (sharp идёт как `optionalDependency` Next.js 15+ и подключается автоматически). Постбилд-шага сжатия нет.

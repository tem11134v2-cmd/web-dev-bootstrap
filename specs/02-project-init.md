# Spec 02: Инициализация проекта Next.js

> Оркестрация: builder-sonnet; параллель: с 01b; verifier: pnpm build в той же сессии

## KB files to read first

- docs/stack.md
- docs/architecture.md
- docs/spec.md (название проекта, домен)
- `.claude/memory/references.md`, `.claude/memory/decisions.md`

## Goal

Создать Next.js-проект со всей структурой папок, установленными зависимостями и базовой конфигурацией. На выходе — `pnpm dev` показывает пустую страницу без ошибок, `pnpm build` проходит, встроенный браузер видит dev-сервер. Готовая база для дизайн-системы.

## Background: template-флоу

Репо уже создано из bootstrap-шаблона (`gh repo create --template`) — в корне лежат `CLAUDE.md`, `docs/`, `specs/`, `.claude/`, `biome.json.example`. Поэтому scaffold **нельзя** делать как `npx create-next-app [name]` — он создаст вложенную папку `[name]/` внутри клона, и деплой/скрипты сломаются. Правильный рецепт: scaffold во временную папку → перенос содержимого в корень репо → удаление временной.

## Tasks

1. Scaffold во временную папку (из корня репо):
   ```bash
   npx create-next-app@latest tmp-scaffold --typescript --tailwind --app --use-pnpm
   ```
   В визарде: линтер — **Biome** (create-next-app сам предлагает), import alias — дефолтный `@/*`. Флаг `--turbopack` не нужен — в Next 16 Turbopack дефолт.
2. Перенести содержимое `tmp-scaffold/` в корень репо с разрешением конфликтов:
   ```bash
   # .gitignore: слить — строки из tmp-scaffold/.gitignore добавить в корневой (без дублей)
   # README.md: НЕ перетирать — остаётся из шаблона
   rm -f tmp-scaffold/.gitignore tmp-scaffold/README.md
   rm -rf tmp-scaffold/.git   # если create-next-app успел сделать git init
   cp -a tmp-scaffold/. ./
   rm -rf tmp-scaffold
   ```
   Остальные файлы scaffold (package.json, tsconfig.json, next.config.ts, app/) конфликтов с шаблоном не имеют — переносятся как есть.
3. Создать `.npmrc` в корне проекта:
   ```
   node-linker=hoisted
   ```
   Без него standalone-сборка на pnpm падает крашем `@swc/helpers`. После создания — `pnpm install` (перелинковка node_modules).
4. Инициализировать shadcn/ui с явным base-ui:
   ```bash
   npx shadcn@latest init -b base
   ```
5. Установить базовые shadcn/ui компоненты:
   ```bash
   npx shadcn@latest add button card accordion dialog input select tabs badge separator sheet form label textarea radio-group sonner
   ```
6. Установить дополнительные пакеты:
   ```bash
   pnpm add react-hook-form @hookform/resolvers zod lucide-react clsx tailwind-merge class-variance-authority tw-animate-css
   pnpm add -D schema-dts
   ```
   Turnstile (`@marsidev/react-turnstile`) ставится в спеке 09 вместе с формами. `sharp` отдельно не ставить — optionalDependency Next. MDX-стек (`@content-collections/*`) — в `specs/07-blog-optional.md`, только если в `docs/pages.md` запланирован блог.

   `schema-dts` даёт типы для JSON-LD (`WithContext<Service>` и т.д.) — используются в `lib/schema.ts` начиная со спеки 05.
7. Настроить Biome: create-next-app уже поставил `@biomejs/biome` через визард. Скопировать корневой `biome.json.example` (из шаблона) поверх сгенерированного `biome.json` — это Biome 2: `files.includes` с `!`-негациями, `useSortedClasses` для Tailwind. Прогнать `pnpm exec biome check --write` один раз, чтобы привести scaffold-файлы к формату.
8. Настроить `next.config.ts` — строго канон из `docs/stack.md` (`output: 'standalone'`, `compress: false`). Больше ничего не добавлять: без `experimental.*`, без images-настроек. Зачем так — объяснено в `docs/stack.md` и `docs/deploy.md`.
9. Настроить `package.json` scripts (dev и prod используют порт 3000; на VPS фактический порт передаётся через `PORT=...` при `pm2 start`):
   ```json
   "scripts": {
     "dev": "next dev -p 3000",
     "build": "next build",
     "start": "next start -p 3000",
     "lint": "biome check",
     "format": "biome check --write",
     "typecheck": "tsc --noEmit"
   }
   ```
   `lint`/`format` — через Biome (он же сортирует Tailwind-классы). `typecheck` отделён — Biome не проверяет типы, это делает `tsc`.
10. Создать структуру папок (если каких-то нет):
    ```
    app/                  # уже создано create-next-app
    components/ui/        # уже создано shadcn/ui init
    components/layout/    # создать
    components/sections/  # создать
    components/forms/     # создать
    content/services/     # создать (для MDX)
    content/blog/         # создать (если планируется блог)
    lib/                  # уже создано (utils.ts), добавить consultation-context.tsx
    public/images/        # создать
    public/fonts/         # создать (если шрифты локально)
    public/og/            # создать (для OG-картинок)
    data/                 # создать (для fallback-лидов локально)
    ```
11. Проверить `.gitignore` после слияния (шаг 2): обязательны `.env*` (кроме `!.env.example`), `data/` (каталог целиком — fallback-лиды `leads.jsonl` и прочие ПДн), `node_modules`, `.next`, `*.log`
12. Создать пустой `app/layout.tsx` с базовым HTML-каркасом (lang="ru", placeholder Header/Footer, ConsultationDialogProvider — будет добавлен в спеке 04) и пустую `app/page.tsx` (просто `<main>Hello</main>` — наполнение в спеке 04)
13. `CLAUDE.md`: заполнить `# Project:` реальным именем сайта и удалить BOOTSTRAP META-комментарий из шапки. Файл уже в корне из шаблона — копировать ничего не нужно
14. Создать `.claude/launch.json` — префлайт встроенного браузера:
    ```json
    {"version":"0.0.1","configurations":[{"name":"dev","runtimeExecutable":"pnpm","runtimeArgs":["dev"],"port":3000}]}
    ```
    Проверить: `preview_start` с `name=dev` поднимает dev-сервер, `preview_logs` без ошибок.
15. Первый коммит: `chore: initial Next.js setup`
16. Верификация в этой же сессии: `pnpm build` проходит; localhost:3000 — пустая страница без ошибок в консоли

## Boundaries

- **Always:** использовать точные версии из docs/stack.md, не «latest» наугад
- **Ask first:** перед добавлением любой зависимости, не указанной в docs/stack.md
- **Never:** удалять `pnpm-lock.yaml`, добавлять Radix напрямую (только через shadcn base-ui), править файлы внутри `.next/`, оставлять вложенную папку со scaffold в репо

## Done when

- В корне репо НЕТ вложенной папки с проектом — scaffold перенесён, `tmp-scaffold/` удалена
- `pnpm dev` запускает сервер на порту 3000 без ошибок; `pnpm build` проходит (verifier этой спеки)
- Все папки структуры созданы
- shadcn/ui компоненты установлены, Tailwind работает (проверка: `<Button>` рендерится со стилями)
- `next.config.ts` — ровно канон из `docs/stack.md`: `output: 'standalone'`, `compress: false`, без `experimental.*`
- `.npmrc` с `node-linker=hoisted` в корне
- `biome.json` — Biome 2 (`files.includes`); `pnpm lint` и `pnpm format` отрабатывают без падений; в `package.json` нет ESLint/Prettier-зависимостей
- `CLAUDE.md`: `# Project:` заполнен реальным именем, BOOTSTRAP META-комментарий удалён
- `.claude/launch.json` создан; `preview_start name=dev` поднимает сервер, `preview_logs` чистые
- Первый коммит создан

## Memory updates

- `project_state.md` — done, следующая спека по развилке из 00 (обычно `03-design-system`; либо opt-design-to-site / opt-design-from-references / opt-visual-recreate)
- `pointers.md` — пока пуст: переиспользуемые компоненты появятся с 03+

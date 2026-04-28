# Spec 07: Блог на MDX через Content Collections (опционально)

## KB files to read first

- docs/architecture.md (раздел «MDX через Content Collections»)
- docs/content-layout.md (секции для информационных страниц)
- docs/seo.md (Article schema, метаданные)
- docs/pages.md (есть ли блог в плане?)
- docs/stack.md (актуальные версии Content Collections + MDX-плагины)
- (внешние) https://www.content-collections.dev/docs

## Goal

Создать блог на MDX через **Content Collections** (без БД, статьи = файлы в git, типобезопасные через Zod-схему). На выходе — список статей по `/blog/`, страница статьи `/blog/[slug]/`, RSS-фид (опционально), статьи в sitemap.

## Когда делать эту спеку

- В `docs/pages.md` запланирован блог — делать
- Не запланирован — пропустить целиком

## Почему Content Collections, а не next-mdx-remote

| | next-mdx-remote | Content Collections |
|---|---|---|
| Парсинг frontmatter | вручную через `gray-matter` | через Zod-схему в config |
| Типобезопасность | нет (data: any из gray-matter) | да (типы автогенерируются) |
| Когда парсится MDX | на каждом запросе/билде в runtime | один раз на билде, кэшируется |
| Опечатка в frontmatter | падает 500 на проде | TypeScript-ошибка на билде |
| Сборка bundle | один из MDX-кусков попадает в JS-бандл | компилируется в `.content-collections/` рядом с `.next/` |

Вторичные плюсы: автогенерация TypeScript-типов из схемы, дев-вотчер на `content/blog/*.mdx` (изменения подхватываются без рестарта), общая утилита `allPosts` вместо ручного `lib/blog.ts`.

## Tasks

### 1. Установка

1. Поставить пакеты:
   ```bash
   pnpm add content-collections @content-collections/core @content-collections/mdx @content-collections/next
   pnpm add -D @tailwindcss/typography
   ```
   `@tailwindcss/typography` нужен для `prose`-классов в теле статьи (см. шаг 9).

2. Обернуть `next.config.ts`:
   ```typescript
   import { withContentCollections } from '@content-collections/next'

   const nextConfig = {
     // существующие настройки
   }

   export default withContentCollections(nextConfig)
   ```

3. Добавить в `tsconfig.json` алиас (Content Collections генерит модуль `content-collections` в `.content-collections/`):
   ```json
   {
     "compilerOptions": {
       "paths": {
         "@/*": ["./*"],
         "content-collections": ["./.content-collections/generated"]
       }
     }
   }
   ```

4. Добавить в `.gitignore`: `.content-collections/`.

### 2. Конфигурация коллекции

5. Создать `content-collections.ts` в корне проекта:
   ```typescript
   import { defineCollection, defineConfig } from '@content-collections/core'
   import { compileMDX } from '@content-collections/mdx'
   import { z } from 'zod'

   const posts = defineCollection({
     name: 'posts',
     directory: 'content/blog',
     include: '**/*.mdx',
     schema: z.object({
       title: z.string(),
       description: z.string().min(50).max(160),
       date: z.string(),
       author: z.string().optional(),
       cover: z.string().optional(),
       tags: z.array(z.string()).optional(),
       draft: z.boolean().optional(),
     }),
     transform: async (doc, ctx) => {
       const mdx = await compileMDX(ctx, doc)
       return {
         ...doc,
         mdx,
         slug: doc._meta.path,
         readingTime: Math.ceil(doc.content.split(/\s+/).length / 200), // грубая оценка
       }
     },
   })

   export default defineConfig({ collections: [posts] })
   ```
   Опечатка в имени поля frontmatter → TypeScript-ошибка на билде. Невалидный `date` или `description` короче 50 символов → понятный лог в `content-collections build` с указанием файла.

### 3. Структура контента

6. Каждая статья — `content/blog/[slug].mdx` с frontmatter, который соответствует Zod-схеме:
   ```mdx
   ---
   title: "Заголовок статьи"
   description: "150-160 символов"
   date: "2026-04-13"
   author: "Имя"
   cover: "/blog/[slug]-cover.jpg"
   tags: ["виза", "США"]
   ---

   # Заголовок (или используется title из frontmatter)

   Текст статьи с **markdown** и React-компонентами:

   <Callout type="info">Можно вставлять компоненты прямо в MDX</Callout>
   ```

### 4. Список статей

7. Создать `app/blog/page.tsx` (server component):
   ```typescript
   import { allPosts } from 'content-collections'

   export const metadata = { title: 'Блог', description: '...' }

   export default function BlogIndex() {
     const posts = allPosts
       .filter(p => !p.draft)
       .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
     return <PostsGrid posts={posts} />
   }
   ```
   - Сетка карточек (cover + title + date + excerpt)
   - Пагинация если статей > 12 (опционально)
   - `allPosts` — типизированный массив, IDE покажет автокомплит на `post.title`, `post.tags` и т.д.

### 5. Страница статьи

8. Создать `app/blog/[slug]/page.tsx`:
   ```typescript
   import { allPosts } from 'content-collections'
   import { MDXContent } from '@content-collections/mdx/react'
   import { notFound } from 'next/navigation'

   export function generateStaticParams() {
     return allPosts.filter(p => !p.draft).map(p => ({ slug: p.slug }))
   }

   export function generateMetadata({ params }: { params: { slug: string } }) {
     const post = allPosts.find(p => p.slug === params.slug)
     if (!post) return {}
     return {
       title: post.title,
       description: post.description,
       openGraph: { images: post.cover ? [post.cover] : [] },
     }
   }

   export default function PostPage({ params }: { params: { slug: string } }) {
     const post = allPosts.find(p => p.slug === params.slug)
     if (!post || post.draft) notFound()
     return (
       <article className="prose prose-lg mx-auto max-w-3xl">
         <MDXContent code={post.mdx} components={{ Callout }} />
       </article>
     )
   }
   ```
   - Hero с обложкой, заголовком, датой, автором (вне `<MDXContent />`, до него)
   - Контент статьи (типографика prose-стилей)
   - Блок Related (3 свежие статьи по пересечению `tags`)
   - CTA в конце (форма или ссылка на услугу)
   - JSON-LD `Article` schema (см. `docs/seo.md`, `lib/schema.ts`)

### 6. SEO

9. Добавить статьи в `app/sitemap.ts`:
   ```typescript
   import { allPosts } from 'content-collections'
   // ...
   ...allPosts.filter(p => !p.draft).map(post => ({
     url: `${baseUrl}/blog/${post.slug}`,
     lastModified: new Date(post.date),
   }))
   ```
10. RSS-фид (опционально): `app/rss.xml/route.ts` — итерация по `allPosts`.
11. Уникальные OG-картинки: либо `cover` из frontmatter, либо генерация через `app/blog/[slug]/opengraph-image.tsx`.

### 7. Стилизация контента

12. Подключить typography-плагин в `app/globals.css` (Tailwind v4 — через `@plugin`):
    ```css
    @plugin "@tailwindcss/typography";
    ```
13. Применить `prose` классы к контенту статьи: `<article className="prose prose-lg max-w-3xl mx-auto">`.
14. Настроить prose-цвета под бренд проекта через CSS-переменные в `globals.css`.

### 8. Тестирование

15. Создать 2-3 тестовых статьи (или взять реальные из брифа).
16. `pnpm dev` — проверить:
    - `content-collections build` отработал (видно в лог-выводе при старте)
    - `/blog/` показывает список
    - `/blog/[slug]/` рендерит MDX, метаданные верные
    - Изменение frontmatter в `.mdx` — Zod-валидация ловит ошибки до рендера
    - Изменение тела статьи — hot-reload работает
17. JSON-LD `Article` валиден в schema.org validator.
18. `pnpm build` проходит, нет рантайм-парсинга MDX (всё в `.content-collections/`).

## Boundaries

- **Always:** SSG (никакого SSR/CSR для статей — это статичный контент), Zod-схема — единственная точка истины для frontmatter, draft-посты исключены через `.filter(p => !p.draft)` И в листинге, И в `generateStaticParams`, И в sitemap
- **Ask first:** перед добавлением комментариев / поиска / тегов-фильтров (это +сложность, обычно не нужно), перед миграцией существующего контента из Tilda/WP (если статьи есть — отдельный раунд spec 13 / `optional/opt-migrate-from-existing.md`)
- **Never:** хранить статьи в БД (теряем простоту git-flow), использовать клиентский MDX (тяжёлый бандл), читать `.mdx` вручную через `fs.readFileSync` (этим занимается Content Collections), оставлять `gray-matter` в зависимостях (Content Collections заменил его)

## Done when

- `content-collections.ts` создан, Zod-схема покрывает все используемые поля frontmatter
- Папка `content/blog/` существует, есть тестовые статьи, frontmatter проходит валидацию
- `/blog/` показывает список из типизированного `allPosts`
- `/blog/[slug]/` рендерит MDX через `<MDXContent />`
- Метаданные, JSON-LD Article, sitemap включают статьи
- prose-стили применены, читается комфортно
- `pnpm build` проходит, `.content-collections/` собирается, опечатка в frontmatter ловится на билде

## Memory updates

- `pointers.md` — путь к `content-collections.ts` (config) и автогенерированному `allPosts`, шаблону статьи, prose-настройкам
- `references.md` — папка `content/blog/` для добавления новых статей
- `decisions.md` — почему Content Collections, а не next-mdx-remote / Contentlayer (последний deprecated)
- `project_state.md` — done (или skipped), следующая `08-seo-schema`

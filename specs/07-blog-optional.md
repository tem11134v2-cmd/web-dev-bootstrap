# Spec 07: Блог на MDX (опционально)

## KB files to read first

- docs/architecture.md (раздел «MDX для контента»)
- docs/content-layout.md (секции для информационных страниц)
- docs/seo.md (Article schema, метаданные)
- docs/pages.md (есть ли блог в плане?)

## Goal

Создать блог на MDX (без БД, статьи = файлы в git). На выходе — список статей по `/blog/`, страница статьи `/blog/[slug]/`, RSS-фид (опционально), статьи в sitemap.

## Когда делать эту спеку

- В `docs/pages.md` запланирован блог — делать
- Не запланирован — пропустить целиком

## Tasks

### 1. Структура контента

1. Каждая статья — `content/blog/[slug].mdx` с frontmatter:
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

### 2. Утилиты чтения MDX

2. Создать `lib/blog.ts`:
   ```typescript
   import fs from 'fs'
   import path from 'path'
   import matter from 'gray-matter'

   const BLOG_DIR = path.join(process.cwd(), 'content/blog')

   export function getAllPosts() {
     const files = fs.readdirSync(BLOG_DIR).filter(f => f.endsWith('.mdx'))
     return files.map(file => {
       const source = fs.readFileSync(path.join(BLOG_DIR, file), 'utf8')
       const { data } = matter(source)
       return { slug: file.replace('.mdx', ''), ...data }
     }).sort((a, b) => new Date(b.date) - new Date(a.date))
   }

   export function getPostBySlug(slug: string) {
     const source = fs.readFileSync(path.join(BLOG_DIR, `${slug}.mdx`), 'utf8')
     return matter(source)
   }
   ```

### 3. Список статей

3. Создать `app/blog/page.tsx` (server component):
   - `metadata` с title/description
   - Сетка карточек (cover + title + date + excerpt)
   - Пагинация если статей > 12 (опционально)

### 4. Страница статьи

4. Создать `app/blog/[slug]/page.tsx`:
   - `generateStaticParams()` — для SSG всех статей
   - `generateMetadata()` — из frontmatter статьи
   - Рендер MDX через `next-mdx-remote/rsc`
   - Hero с обложкой, заголовком, датой, автором
   - Контент статьи (типографика prose-стилей)
   - Блок Related (3 свежие статьи)
   - CTA в конце (форма или ссылка на услугу)
   - JSON-LD `Article` schema

### 5. SEO

5. Добавить статьи в `app/sitemap.ts` (динамически из `getAllPosts()`)
6. RSS-фид (опционально): `app/rss.xml/route.ts`
7. Уникальные OG-картинки: либо `cover` из frontmatter, либо генерация через `app/blog/[slug]/opengraph-image.tsx`

### 6. Стилизация контента

8. Установить `@tailwindcss/typography` (если ещё не):
   ```bash
   pnpm add -D @tailwindcss/typography
   ```
9. Применить `prose` классы к контенту статьи: `<article className="prose prose-lg max-w-3xl mx-auto">`
10. Настроить prose-цвета под бренд проекта

### 7. Тестирование

11. Создать 2-3 тестовых статьи (или взять реальные из брифа)
12. Проверить: список открывается, статья открывается, MDX рендерится, метаданные верные, JSON-LD валиден
13. `pnpm build` проходит

## Boundaries

- **Always:** SSG (никакого SSR/CSR для статей — это статичный контент)
- **Ask first:** перед добавлением комментариев / поиска / тегов-фильтров (это +сложность, обычно не нужно)
- **Never:** хранить статьи в БД (теряем простоту git-flow), использовать клиентский MDX (тяжёлый бандл)

## Done when

- Папка `content/blog/` существует, есть тестовые статьи
- `/blog/` показывает список
- `/blog/[slug]/` показывает статью с правильным MDX-рендером
- Метаданные, JSON-LD Article, sitemap включают статьи
- prose-стили применены, читается комфортно
- `pnpm build` проходит

## Memory updates

- `pointers.md` — путь к `lib/blog.ts`, шаблону статьи, prose-настройкам
- `references.md` — папка `content/blog/` для добавления новых статей
- `project_state.md` — done (или skipped), следующая `08-seo-schema`

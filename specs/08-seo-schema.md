# Spec 08: SEO техничка и Schema.org

## KB files to read first

- docs/seo.md (полностью)
- docs/pages.md (все страницы для sitemap)
- `lib/schema.ts` (генераторы из спеки 05)
- `app/sitemap.ts`, `app/robots.ts`, `app/layout.tsx`

## Goal

Доделать всю SEO-техничку: sitemap покрывает все страницы, robots.txt корректен, Schema.org валидируется, canonical/OG/twitter теги на каждой странице, редиректы 301 настроены. На выходе — сайт готов к индексации, нет ошибок в Google Rich Results и Yandex Validator.

## Tasks

### 1. robots.ts и sitemap.ts

1. `app/robots.ts`:
   ```typescript
   export default function robots(): MetadataRoute.Robots {
     return {
       rules: [{ userAgent: '*', allow: '/', disallow: ['/api/', '/admin/', '/*?*'] }],
       sitemap: 'https://[domain]/sitemap.xml',
       host: 'https://[domain]',
     }
   }
   ```
2. `app/sitemap.ts` — собрать все публичные страницы (статичные из docs/pages.md + динамические из getAllPosts() если есть блог)

### 2. Schema.org разметка — расширение

3. Дополнить `lib/schema.ts` функциями:
   - `generateOrganizationSchema()` — для footer/layout
   - `generateLocalBusinessSchema()` (если у заказчика физический офис)
   - `generateBreadcrumbSchema(slug)` — уже есть, проверить
   - `generateArticleSchema(post)` — для блога
4. Внедрить `Organization` schema в `app/layout.tsx`:
   ```tsx
   <script type="application/ld+json"
     dangerouslySetInnerHTML={{ __html: JSON.stringify(generateOrganizationSchema()) }} />
   ```

### 3. Редиректы 301

5. Из `docs/pages.md` собрать список редиректов
6. Добавить в `next.config.ts`:
   ```typescript
   async redirects() {
     return [
       { source: '/old-url', destination: '/new-url', permanent: true },
     ]
   }
   ```
7. Nginx-уровень редиректов (если применимо):
   - `www → без www` (или наоборот)
   - Trailing slash единый формат
   - `/index.html`, `/index.php` → 301 на `/`

### 4. Чистка дублей и canonical

8. Каждая страница имеет уникальный canonical (см. metadata.alternates.canonical)
9. Проверить нет ли страниц с одинаковыми title/description (через `npm run build` + ручной обход)
10. Закрыть от индексации страницы с GET-параметрами (уже в robots.ts через `/*?*`)

### 5. Yandex-специфика

11. Создать (или обновить) `app/yandex_[verification-code].html` для подтверждения Яндекс Вебмастера (когда настроим в спеке 10)
12. Региональность: указать регион в Яндекс Бизнес (вне кода, в спеке 10)
13. **Турбо-страницы Яндекса** — обычно НЕ нужны для коммерческих сайтов на Next.js (SSG быстрее Турбо). Пропускаем по умолчанию.

### 6. Чек-листом по seo.md → «Чек-лист SEO для разработчика»

14. Пройтись по 15 пунктам чек-листа для 3-5 рандомных страниц:
    - Title, Description, H1, Canonical, OG, Breadcrumbs, Alt-теги, ЧПУ, Schema, Sitemap, перелинковка, server render, 404, mobile, tel: links

### 7. Валидация

15. **Google Rich Results Test** — проверить главную и одну страницу услуги, одну статью блога
16. **Yandex Validator разметки** — то же самое
17. Build + деплой

## Boundaries

- **Always:** canonical на каждой странице, alt на каждой картинке, schema.description == metadata.description (одна константа, не дублировать текст)
- **Ask first:** перед массовыми редиректами (если их > 50), перед добавлением hreflang (это i18n, отдельная спека)
- **Never:** оставлять дубли title/description, ставить noindex на коммерческие страницы, использовать `<h1>` несколько раз на странице

## Done when

- robots.ts и sitemap.ts покрывают всё
- Organization JSON-LD в layout, Service/FAQ/Breadcrumb на страницах услуг, Article на статьях
- Редиректы 301 настроены (next.config + nginx)
- Нет дублей title/description (проверено)
- Google Rich Results + Yandex Validator проходят без ошибок
- Чек-лист SEO пройден для 3-5 страниц

## Memory updates

- `pointers.md` — расширенный `lib/schema.ts`, sitemap.ts
- `decisions.md` — выбор trailing slash, www/без www, любые нестандартные SEO-решения
- `references.md` — путь к Yandex Webmaster verification (когда получим в 10)
- `project_state.md` — done, следующая `09-forms-crm`

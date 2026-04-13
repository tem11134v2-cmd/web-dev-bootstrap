# SEO

Технический SEO для Next.js. Повторяющиеся темы (Lighthouse, контрастность, console.log) — в `docs/performance.md`. Юридические страницы — в `docs/legal-templates.md`.

## 1. Индексация и доступность

**`app/robots.ts`:**
```typescript
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: "/", disallow: ["/api/", "/admin/", "/*?*"] }],
    sitemap: "https://domain.com/sitemap.xml",
  };
}
```

**`app/sitemap.ts`:**
```typescript
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: "https://domain.com", lastModified: new Date(), priority: 1, changeFrequency: "weekly" },
    { url: "https://domain.com/services/visa-o1", lastModified: new Date(), priority: 0.8, changeFrequency: "monthly" },
    // Все публичные страницы. Без noindex-страниц. При шаблонизации — генерировать программно из pages-data.
  ];
}
```

**Правила:**
- Нет `<meta name="robots" content="noindex">` на нужных страницах.
- Нет `X-Robots-Tag` блокировок (проверь nginx).
- Страницы с GET-параметрами закрыты от индекса.
- Контент рендерится на сервере (SSG/SSR), **не** через client-side JS.

## 2. Дубли и редиректы

**`next.config.ts` — редиректы:**
```typescript
async redirects() {
  return [
    { source: "/old-url", destination: "/new-url", permanent: true },
  ];
}
```

**Обязательные склейки (nginx):**
- `www → без www` (или наоборот) — выбрать главное зеркало, 301.
- `http → https` — 301.
- Trailing slash — единый формат, 301 на каноничный.
- `/index.html`, `/index.php` → 301 на `/`.
- Множественные слеши `////` → 301 на нормальный URL.

**Trailing slash в Next.js:**
```typescript
const nextConfig = { trailingSlash: false }; // выбрать один формат и не менять
```

**Правила:**
- Нет дублей контента между страницами.
- Внутренние ссылки — на конечные URL (без цепочек редиректов).
- Один кластер запросов = одна страница (без каннибализации).

## 3. Мета-теги

```typescript
export const metadata: Metadata = {
  title: "Ключ + коммерческая добавка | Бренд",  // 60–70 символов
  description: "150–160 символов: ключ, ценность, призыв к действию.",
  openGraph: {
    title: "...", description: "...",
    images: [{ url: "/og-image.jpg", width: 1200, height: 630 }],
    type: "website", locale: "ru_RU", siteName: "Brand",
  },
  twitter: { card: "summary_large_image", title: "...", description: "...", images: ["/og-image.jpg"] },
  alternates: { canonical: "https://domain.com/page" },
};
```

**Правила:**
- **Title:** уникальный, основной ключ + коммерческая добавка (Купить/Заказать/в [город]), 60–70 символов.
- **Description:** уникальный, ключ + ценность + CTA, 150–160 символов.
- **H1:** один на странице, основной ключ, тег `<h1>` (не стиль).
- **Canonical:** на каждой странице, указывает на себя.
- **OG:** для шеринга в соцсетях, картинка 1200×630.
- Нет дублей `title`/`description` между страницами.

При шаблонизации `META_DESCRIPTION` выноси в константу — паттерн в `docs/architecture.md`.

## 4. Заголовки и URL

**Иерархия заголовков:** `h1 → h2 → h3` без пропусков. Декоративные подзаголовки в карточках — `<p className="font-semibold">`, не `<h3>`.

**URL (ЧПУ):**
- Транслит, без спецсимволов.
- Глубина ≤ 3 (`/category/subcategory/page/`).
- Длина ≤ 90–115 символов.
- Только строчные, дефис-разделитель.
- Пример: `/viza-talantov/` — не `/visa_talantov/`, не `/VisaTalantov/`, не `/page?id=123`.

## 5. Schema.org JSON-LD

**Organization** (в `app/layout.tsx`):
```typescript
<script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({
  "@context": "https://schema.org",
  "@type": "Organization",
  name: "Brand", url: "https://domain.com", logo: "https://domain.com/logo.svg",
  contactPoint: { "@type": "ContactPoint", telephone: "+7-XXX-XXX-XXXX", contactType: "customer service", availableLanguage: ["Russian"] },
  address: { "@type": "PostalAddress", streetAddress: "...", addressLocality: "...", postalCode: "...", addressCountry: "RU" },
  sameAs: ["https://t.me/...", "https://wa.me/..."],
}) }} />
```

**FAQ Schema** (на страницах с FAQ):
```typescript
{ "@context": "https://schema.org", "@type": "FAQPage",
  mainEntity: items.map(i => ({ "@type": "Question", name: i.q, acceptedAnswer: { "@type": "Answer", text: i.a } })) }
```

**BreadcrumbList:**
```typescript
{ "@context": "https://schema.org", "@type": "BreadcrumbList",
  itemListElement: [
    { "@type": "ListItem", position: 1, name: "Главная", item: "https://domain.com" },
    { "@type": "ListItem", position: 2, name: "Услуги", item: "https://domain.com/services" },
    { "@type": "ListItem", position: 3, name: "Виза O-1" },
  ] }
```

**Service / Product:** `description` в Schema **должен совпадать** с `<meta description>` — используй константу `META_DESCRIPTION` (см. `architecture.md`). При шаблонизации генерируй JSON-LD автоматически из `pageData`.

**Проверка:** [Яндекс Валидатор разметки](https://webmaster.yandex.ru/tools/microtest/), [Google Rich Results](https://search.google.com/test/rich-results).

## 6. Внутренняя перелинковка

- Хлебные крошки на всех страницах кроме главной (UI + Schema BreadcrumbList).
- Header/footer — ссылки на основные разделы.
- Связанные страницы ссылаются друг на друга (блок «Похожие услуги»).
- Якорные тексты с ключами: «оформление визы O-1», не «подробнее».
- Глубина от главной до любой страницы ≤ 3 клика.

## 7. Коммерческие факторы (для сайтов услуг)

**Обязательно:** цены с валютой, контакты с любой страницы, страница «Контакты» с адресом/картой/часами/формой, форма обратного звонка, детальное описание услуг.

**Желательно:** реквизиты, фото офиса/команды, сертификаты, страница «О компании», портфолио с деталями, отзывы, способы оплаты с логотипами, гарантии, калькуляторы/квизы, все способы связи (Telegram, WhatsApp, email, телефон), email на своём домене (не gmail).

## 8. Яндекс-специфика (для RU-проектов)

**Яндекс.Вебмастер:**
- Подтвердить владение (HTML-файл или `<meta name="yandex-verification">`).
- Загрузить sitemap.
- Указать главное зеркало.
- Регион сайта (Москва/Россия/без региона) — влияет на гео-выдачу.
- Мониторить «Возможные проблемы» и «Безопасность».

**Яндекс.Бизнес:** организация зарегистрирована, регион присвоен, NAP consistency (Name/Address/Phone совпадают с сайтом).

**ИКС (Индекс качества сайта):** не управляется напрямую, растёт от: цитируемости (ссылки), пользовательских факторов (Метрика), коммерческих факторов, наличия в Яндекс.Бизнесе. Резкое падение ИКС = сигнал санкций.

**Турбо-страницы:** для RU-сайтов **не подключаем** — проигрывают по конверсии современным SSG-сайтам с правильным CWV. Если сайт уже соответствует бюджету в `docs/performance.md`, Турбо избыточен и ломает аналитику.

**Региональность:** для географических лендингов (`/moskva/`, `/spb/`) — отдельные страницы с уникальным контентом + указание региона в Вебмастере для каждого поддомена/раздела (если поддомены).

## 9. Контент для ранжирования

- Каждая страница имеет уникальное облако релевантности (нет дублей контента).
- Структура соответствует ТОПу (смотри типы страниц у конкурентов).
- Тип страницы соответствует интенту: листинг / карточка / лендинг / статья.
- Для блога: притягательный H1, сильный первый абзац, оглавление с якорными ссылками (`id` на `<h2>`), ссылки на связанные статьи и коммерческие разделы.

## 10. Юридические страницы для индексации

Для RU-сайтов в индексе **должны быть**: `/privacy`, `/consent`, при оплате — `/offer`. Тексты — `docs/legal-templates.md`. Эти страницы — `noindex` не надо, наоборот: их наличие = коммерческий фактор.

## Чек-лист SEO для разработчика (на каждую новую страницу)

- [ ] Уникальные `title` и `description` с ключом
- [ ] Один `<h1>` с основным ключом
- [ ] `canonical` URL
- [ ] OG-теги (title, description, image 1200×630)
- [ ] Хлебные крошки (UI + Schema BreadcrumbList)
- [ ] Alt-теги на всех изображениях
- [ ] ЧПУ URL с ключом на транслите
- [ ] Schema.org разметка (Organization, FAQ, Service где применимо)
- [ ] Страница в `sitemap.ts`
- [ ] Внутренние ссылки на/с связанных страниц
- [ ] Контент рендерится на сервере (не client-only)
- [ ] 404 — корректный код ответа
- [ ] Телефоны кликабельны (`tel:`)
- [ ] Нет mixed content (всё HTTPS)
- [ ] Производительность зелёная (см. `docs/performance.md`)

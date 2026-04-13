# Page Spec: [Название страницы]

<!--
Шаблон спеки для добавления новой страницы. Используется в спеках
05-subpages-template, 06-subpages-rollout, 13-extend-site.

Скопируй файл, заполни, удали комментарии.
-->

## KB files to read first

- docs/architecture.md
- docs/content-layout.md
- docs/seo.md
- components/[существующий-шаблон-страницы].tsx — если есть
- docs/pages.md — проверить что страница есть в карте

## Goal

<!--
1 предложение: какая страница, какой её SEO-запрос, какая роль в воронке.
Пример: «Посадочная для запроса «виза O-1 США», коммерческий интент, ведёт
на форму консультации».
-->

## Page metadata

<!--
Всё что попадает в <head>. Должно быть уникальным относительно других страниц.
-->

- **URL:** `/[путь]/`
- **H1:** [заголовок страницы, видимый в hero]
- **Title:** [60-70 символов, ключ + коммерческая добавка + бренд]
- **Description:** [150-160 символов, ключ + ценность + CTA]
- **Canonical:** `https://[domain]/[путь]/`
- **OG image:** `/og/[slug].jpg` (1200×630) — создать если нет

## Sections

<!--
Список секций сверху вниз. Используй типы из docs/content-layout.md
(Hero, Stats, Benefits, Steps, FAQ, CTA Final и т.д.).
Под каждой — кратко: контент, особенности.
-->

1. **Hero** — H1 + подзаголовок + 2 CTA + 3 stat-карточки (цифры компании)
2. **Client Segments** (Для кого) — 4 типа клиентов
3. **Steps** (Этапы) — 5 шагов
4. **Benefits** — 6 карточек преимуществ
5. **Comparison** — таблица «мы vs самостоятельно»
6. **FAQ** — 6 вопросов (Schema.org FAQPage)
7. **CTA Final** — форма консультации

## Content

<!--
Готовые тексты по секциям. Если приходят отдельным файлом — указать путь.
-->

См. `docs/content.md → раздел [название страницы]`
ИЛИ вставить тексты ниже.

## Schema.org

<!--
Какие JSON-LD блоки нужны на этой странице.
-->

- `BreadcrumbList` — авто из шаблона
- `FAQPage` — из секции FAQ
- `Service` — название, описание, provider, areaServed, offers (если есть цена)
- [другое — Article, Product, LocalBusiness и т.д.]

## Internal links

<!--
Перелинковка: какие страницы ссылаются СЮДА и куда ссылается ЭТА.
Помогает SEO и навигации.
-->

- **Входящие:** главная (карточка в Services), `/visa-talantov/` (блок Related)
- **Исходящие:** `/grin-karta/` (Related), `/blog/o1-vs-eb1/` (контекстная ссылка в тексте), форма консультации (CTA)

## Media

<!--
Какие изображения/иконки нужны и где их брать.
-->

- Hero image: `/images/[slug]-hero.jpg` (1920×1080, WebP, < 200 KB) — из брифа / стоков
- Иконки секций: lucide-react (Shield, Award, Users, ...)
- OG image: `/og/[slug].jpg` (1200×630)

## CTA target

<!--
Куда ведут все CTA на странице.
-->

- Hero CTA primary → открывает ConsultationDialog (модалка)
- Hero CTA secondary → скролл к секции Steps (`#steps`)
- Mid CTA → форма консультации (inline)
- Final CTA → форма консультации (полноширинная)

## Tasks

1. Создать `app/[путь]/page.tsx` (server component) с metadata
2. Создать `app/[путь]/page-data.ts` (если шаблонизация) с данными секций
3. Подключить шаблон `ServicePageTemplate` или собрать секции вручную
4. Добавить страницу в `app/sitemap.ts`
5. Добавить редиректы в `next.config.ts` (если есть старый URL)
6. Проверить локально: SEO теги, Schema.org валидатор, мобилка, формы
7. Деплой по схеме (см. docs/deploy.md)

## Done when

- Страница открывается, контент рендерится на сервере (view-source виден)
- Title/Description/H1/Canonical корректны и уникальны
- Schema.org валидируется (Yandex Validator + Google Rich Results)
- Все CTA работают (модалка, форма)
- В `sitemap.xml` страница есть
- Lighthouse mobile + desktop ≥ 90 (после деплоя)

## Memory updates

- `project_state.md` — добавить страницу в список done
- `pointers.md` — если создан новый паттерн (например, новая секция)

# Performance

Core Web Vitals в зелёной зоне: **LCP < 2.5s, CLS < 0.1, INP < 200ms**. Это хаб для перформанса, accessibility и методологии аудита.

## 1. Изображения

- Все растровые → WebP / AVIF. `next/image` вместо `<img>` везде (автоматически отдаёт современные форматы).
- SVG для иконок, логотипов, графики.
- Каждое изображение — явные `width` и `height` (или `aspect-ratio`), иначе CLS.
- `sizes` prop для адаптивных изображений — мобилка получает маленькую картинку.
- **Бюджет:** Hero 200–300 KB, обычные 100–150 KB, иконки до 50 KB.
- Ниже fold → `loading="lazy"`. На первом экране → `priority` + **явно** `fetchpriority="high"`.
- iframe (видео, карты) → `loading="lazy"`.
- SVG прогнать через SVGO (–50–80%). Часто используемые иконки — инлайн.
- EXIF удалить из всех JPEG/PNG.

> **Next 16+ нюанс:** `priority` на `<Image>` **не гарантирует** `fetchpriority="high"` в preload-теге. Ставить явно через проп.

## 2. Шрифты

- Хостить локально (`/public/fonts/` или `next/font`) — убирает DNS-lookup к Google Fonts.
- `font-display: swap` — текст виден сразу.
- Только нужные начертания (max 2–3) и нужные символы (subsetting). Cyrillic-сабсет обязателен — шрифт без него валит билд/типографику (см. spec 03).
- Preload критичного: `<link rel="preload" href="/fonts/main.woff2" as="font" type="font/woff2" crossorigin>`.
- Только `woff2` — поддержка 97%+, лучшее сжатие.

## 3. CSS

- Tailwind purge — убирает мёртвые стили (срезает 80–90%). Проверить через DevTools → Coverage.
- CLS-защита: `aspect-ratio` или `min-height` на баннерах, embed, изображениях. `size-adjust` в `@font-face`.
- Не использовать `@import` в CSS (цепочка блокирующих запросов).
- `contain: layout style paint` на изолированных блоках — освобождает рендер.
- **`scroll-behavior: smooth` НЕ ставить на `html`/`body`** — ломает page transitions. Точечное правило: `html:has(:target) { scroll-behavior: smooth; }`.

## 4. JavaScript

**Минификация и tree-shaking.** Проверять размеры через `@next/bundle-analyzer` (`pnpm add -D @next/bundle-analyzer`, обернуть `next.config.ts` в `withBundleAnalyzer`, запустить `ANALYZE=true pnpm build`).

**Красные флаги зависимостей:**

| Вместо | Используй | Причина |
|---|---|---|
| `moment` (~300 KB) | `date-fns`, `dayjs` | Модульный |
| `import _ from "lodash"` | `lodash-es` именованные импорты | Tree-shake |
| Полный `@mui/material` | Отдельные компоненты | По одному, не всё |
| `react-icons` целиком | `react-icons/lu` (Lucide) или нужный сабсет | Tree-shake срабатывает только на сабсетах |

> Tree-shaking **не работает** для fluent-методов на объекте схемы (цепочки вида `schema.method().method()`) — библиотека тянется целиком. Симптом: после удаления одного импорта Zod бандл не уменьшился.

**Code splitting.** `next/dynamic` для модальных окон, табов, галерей, карт, графиков. Для тяжёлых либ — dynamic import.

**Сторонние скрипты.** Аналитика → `<Script strategy="lazyOnload">`. Виджеты (чат, callback) → грузить по событию (scroll/click). Каждый скрипт = DNS-lookup + загрузка + парсинг.

**INP оптимизация.** Long tasks разбивать на < 50ms (`requestIdleCallback`, `setTimeout(0)`, `scheduler.yield()`). Тяжёлые вычисления → Web Worker. `debounce`/`throttle` на scroll, resize, input. `React.memo`/`useMemo`/`useCallback` против лишних ре-рендеров.

**Анимации** — только `transform`/`opacity`; **LCP-блок не анимируется на загрузке**; `prefers-reduced-motion` обязателен. Каталог паттернов и бюджет движения — `docs/design-motion.md`.

**`console.log` — удалить в production** (одно место правки на весь проект).

## 5. HTML и рендеринг

- Статика → SSG (`generateStaticParams`).
- Динамика → SSR + ISR.
- Не использовать CSR для контента первого экрана.
- `<link rel="preload">` на критичные ресурсы первого экрана (hero-картинка, шрифт).
- `<link rel="preconnect">` / `dns-prefetch` для доменов сторонних ресурсов.
- Next.js `<Link>` делает prefetch автоматически.

> **`loading.tsx` может быть вреден.** Если все секции страницы — Server Components без async-данных, Next оборачивает страницу в Suspense, скелетон блокирует LCP, PSI видит скелетон как LCP-элемент. В этом случае **удалить** `loading.tsx`.

## 6. Сервер (Caddy)

Сжатие и кэш-заголовки живут в Caddy, не в Next: в `next.config.ts` стоит `compress: false` (канон — `docs/stack.md`), Caddy отдаёт `encode gzip zstd`, immutable-кэш на статику `/_next/static/` и `must-revalidate` на HTML. Полный шаблон site-блока (вместе с security-заголовками) — `docs/server-add-site.md` § 4; добавлять поверх ничего не нужно.

HTTP/2, HTTP/3 (QUIC), TLS 1.3, OCSP stapling, автопродление SSL — в Caddy включены по умолчанию.

Проверка на проде:

```bash
curl -I https://{domain}/_next/static/...  # Cache-Control: public, max-age=31536000, immutable
curl -I --http3 https://{domain}           # открывается по HTTP/3
```

Если включён Cloudflare proxy — `trusted_proxies cloudflare` в site-блок (см. `docs/deploy.md` § Cloudflare).

## 7. Кэширование в Next: `use cache`

Директива `'use cache'` работает только при включённом top-level `cacheComponents: true` в `next.config.ts` — **в шаблоне по умолчанию выключено**, включается осознанно (см. `docs/architecture.md` § «Cache Components»). Прежние `experimental.useCache` / `unstable_cache` — история.

Если включили, помечай `'use cache'`:
- тяжёлые server-компоненты с дорогим парсингом/расчётом (Content Collections и так build-time — поверх `allPosts` обычно избыточно);
- серверные fetch к редко-меняющимся API (курсы, статусы, контент CMS);
- детерминированные расчёты (таблица цен по `region`/`tier`) — одна отработка на набор аргументов.

Не помечай: всё, что зависит от пользователя — `cookies()` / `headers()` / `searchParams`. Кэш зашарит ответ между пользователями — security-баг; Next ругнётся на билде. `cacheTag()` / `cacheLife()` — точечная инвалидация и TTL; `revalidatePath`/`revalidateTag` — для «перепосчитать после мутации».

ISR = серверный кэш с автоматической ревалидацией; нашим статичным сайтам обычно достаточно SSG + ISR без кэш-режима.

## 8. `next.config.ts`

Канонический конфиг — `docs/stack.md` (единственный эталон в пакете). Для перформанса опционально добавь блок `images`:

```ts
images: {
  formats: ['image/avif', 'image/webp'],
  deviceSizes: [640, 750, 828, 1080, 1200, 1920],
  minimumCacheTTL: 60 * 60 * 24 * 365,
},
```

- `experimental.optimizeCss` **не добавлять** — пакет critters заархивирован и не ставится.
- `optimizePackageImports` — webpack-only, Turbopack игнорирует.

## 9. Оптимизация изображений

`next/image` сам ресайзит и переводит в WebP/AVIF на лету — sharp подключается как `optionalDependency` Next.js автоматически. Постбилд-шага сжатия в шаблоне нет.

> **Урок с 1 vCPU VPS:** оптимизация «на лету» на слабом сервере дорогая — первые запросы к тяжёлым картинкам съедают CPU. Фикс: **ужимай исходники** в `public/` одноразовым скриптом (sharp), но **не выключай оптимизатор** — `unoptimized` навсегда теряет AVIF/ресайзы, а ужатые исходники решают проблему один раз.

```bash
npx sharp-cli --input "public/**/*.{jpg,jpeg,png}" --output public/ --mozjpeg --quality 75
```

К `pnpm build` это не подключаем — одноразовая операция после переноса тяжёлой статики.

## 10. Accessibility (a11y)

- **Контрастность текста** — ≥ 4.5:1 (обычный) или ≥ 3:1 (≥ 24px). Типичная ошибка: `text-gray-500` (`#6b7280`) на белом = 3.8:1, не проходит. Решение: `text-gray-600` (`#4b5563`) = 5.9:1.
- **На тёмном фоне** — `text-white/40` не проходит. Минимум `text-white/60`.
- **Иерархия заголовков** — `h1 → h2 → h3` без пропусков.
- **Alt-теги** на всех `<Image>`, описательные.
- **Touch-target** ≥ 48×48px.

## 11. Прочее

- **ScrollToTop** — клиентский компонент с `usePathname()` + `window.scrollTo({ top: 0, behavior: "auto" })`. **`auto`, не `smooth`** — иначе страница «плавно ползёт» вверх перед сменой контента.
- **Top loader** (опционально) — `nextjs-toploader` в `app/layout.tsx`, 3px, accent color, без спиннера.
- **Карты/видео** — lazy load по клику. YouTube → `lite-youtube-embed` (~–500 KB).
- **`content-visibility: auto`** на секциях ниже fold — CSS-only, бесплатный win.
- `passive: true` на scroll/touch listeners. `Promise.all()` для параллельных запросов.
- Favicon: SVG с PNG fallback.
- **404 в RSC-prefetch** — если в навигации есть ссылки на несуществующие страницы, Next генерирует 404. Убрать ссылки или создать страницы-заглушки.

## 12. Methodology — порядок аудита производительности

Дистиллят из реальных аудитов. Универсально для любого Next.js / React сайта.

**1. Сначала измерь.** Bundle analyzer + Lighthouse/PSI ДО правок — baseline. Без этого оптимизируешь не то, что болит.

**2. Смотри на HTML, не только на метрики.** В `view-source:` ищи: `<!--$?-->` (Suspense pending → блокирует LCP), `<link rel="stylesheet">` без preload (рендер-блокер), отсутствие `fetchpriority="high"` на preload LCP, раздутые inline `<style>`.

**3. Server > Dynamic > Lazy.** Если компонент не требует state/effects/handlers — сделай его server. Server Component = 0 KB клиентского JS. Это строго лучше `next/dynamic`.

**4. «Вирусный client» антипаттерн.** Один `useContext` в листе превращает родительский tree в client. Симптом: 9 секций — client из-за одного хука диалога. Фикс: извлеки хук-узел в маленький client (`ConsultationButton`), контейнер оставь server.

**5. Монолитные библиотеки.** Tree-shake не работает для методов на объектах, классов с многими методами, либ с re-export всего. См. таблицу § 4.

**6. `loading.tsx` гейтит LCP.** На pure-Server-Component страницах — чистый overhead. Удали, если рендер синхронный.

**7. Explicit beats implicit.** `priority` ≠ `fetchpriority="high"` (ставь явно). `browserslist` в `package.json` Turbopack игнорит. `optimizePackageImports` — webpack-only. `inlineCss: true` помогает на быстрой сети, вредит на 4G.

**8. PSI mobile шумит ±5–10 баллов.** Один замер обманчив. Медиана из 3–5. Desktop стабильнее (±1–2). Истина — в CrUX field data через 1–2 недели.

**9. LCP breakdown.** Лайтхаус даёт: TTFB / load delay / load duration / element render delay. Если render delay > 50% — проблема **не** в картинке/сервере, а в блокере (Suspense, CSS, гидратация). Не сжимай картинку — убирай блокер.

**10. Дубли-компоненты.** При рефакторинге проверяй, нет ли уже такого. Пример: `components/service-page/ConsultationButton.tsx` существует, а создаёшь `components/ConsultationButton.tsx`. Консолидируй.

**11. Измеряй в активной вкладке.** Фоновая вкладка браузера морозит CSS-transitions — computed styles мерить с `transition: none` или в активной вкладке.

**Safety net для рискованных аудитов:**
- `git tag pre-spec-N` перед правками.
- Backup Caddy-конфига **вне** `/etc/caddy/Caddyfile.d/` (`Caddyfile` парсит весь glob; бэкап `*.caddy.bak` рядом — словит `caddy validate` ошибку). Кладите бэкапы в `/home/deploy/caddy-backups/`.
- Тестовый Next prod на свободном порту перед редеплоем основного.

## 13. Бюджет производительности

| Ресурс | Лимит (gzip) |
|---|---|
| HTML | до 50 KB |
| CSS | до 70 KB общий, до 15 KB critical |
| JS (первая загрузка) | до 200 KB |
| Шрифты | до 100 KB (woff2) суммарно |
| Изображения первого экрана | до 300 KB суммарно |
| TTFB | до 200ms (хорошо), до 600ms (допустимо) |
| HTTP-запросов | до 30 |

## 14. Чек-лист быстрой проверки

**Изображения/шрифты:** sharp-сжатие исходников, WebP/AVIF, `next/image` везде, lazy ниже fold, `priority`+`fetchpriority="high"` на LCP, woff2 локально (cyrillic-сабсет), `font-display: swap`, preload критичных, явные размеры/aspect-ratio.
**JS/CSS:** purged Tailwind, code splitting, dynamic для тяжёлого, third-party скрипты `lazyOnload`/по событию, long tasks < 50ms, bundle analyzer проверен, `console.log` удалены, анимации только `transform`/`opacity`, LCP-блок не анимируется, `content-visibility: auto` ниже fold.
**Сервер:** Caddy `encode gzip zstd`, immutable на статику, revalidate на HTML, HTTP/2 + HTTP/3, TLS 1.3 — всё включено через шаблон `docs/server-add-site.md` § 4. Preconnect для внешних доменов в `<head>`.
**A11y/UX:** WCAG AA контрастность (4.5:1 / 3:1), `h1→h2→h3` без пропусков, ScrollToTop, нет 404 в RSC-prefetch, `loading.tsx` удалён если не нужен.
**Финальная проверка:** LCP breakdown изучен, PageSpeed Insights — зелёная зона (медиана из 3–5 замеров).

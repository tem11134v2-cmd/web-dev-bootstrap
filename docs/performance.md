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
- Только нужные начертания (max 2–3) и нужные символы (subsetting).
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

> Tree-shaking **не работает** для методов на объектах (`z.string().email()`) — вся либа тянется целиком. Симптом: после удаления одного импорта Zod бандл не уменьшился.

**Code splitting.** `next/dynamic` для модальных окон, табов, галерей, карт, графиков. Для тяжёлых либ — dynamic import.

**Сторонние скрипты.** Аналитика → `<Script strategy="lazyOnload">`. Виджеты (чат, callback) → грузить по событию (scroll/click). Каждый скрипт = DNS-lookup + загрузка + парсинг.

**INP оптимизация.** Long tasks разбивать на < 50ms (`requestIdleCallback`, `setTimeout(0)`, `scheduler.yield()`). Тяжёлые вычисления → Web Worker. `debounce`/`throttle` на scroll, resize, input. `React.memo`/`useMemo`/`useCallback` против лишних ре-рендеров.

**`console.log` — удалить в production** (одно место правки на весь проект).

## 5. HTML и рендеринг

- Статика → SSG (`generateStaticParams`).
- Динамика → SSR + ISR.
- Не использовать CSR для контента первого экрана.
- `<link rel="preload">` на критичные ресурсы первого экрана (hero-картинка, шрифт).
- `<link rel="preconnect">` / `dns-prefetch` для доменов сторонних ресурсов.
- Next.js `<Link>` делает prefetch автоматически.

> **`loading.tsx` может быть вреден.** Если все секции страницы — Server Components без async-данных, Next оборачивает страницу в Suspense, скелетон блокирует LCP, PSI видит скелетон как LCP-элемент. В этом случае **удалить** `loading.tsx`.

## 6. Сжатие на сервере

**В `next.config.ts`:** `compress: false` — отдай сжатие Caddy (C быстрее, поддерживает zstd, кэширует результат).

**Caddy — `encode` директива в site-блоке:**
```caddyfile
{domain}, www.{domain} {
    reverse_proxy localhost:{prod-port}
    encode gzip zstd     # zstd для современных браузеров (Chrome 123+, Firefox 126+), gzip как fallback
}
```

Это уже включено в шаблоне `docs/server-add-site.md` § 4. Caddy сам выбирает формат по `Accept-Encoding` клиента и кэширует сжатые ответы в памяти. **brotli** в Caddy с коробки нет (нужен `xcaddy build` с плагином `caddy-encode-brotli`), но zstd обычно даёт сопоставимый или лучший результат и поддерживается шире, поэтому brotli обычно не нужен.

Не сжимать: WebP, AVIF, JPEG, PNG, woff2 (уже сжаты). Caddy `encode` сам пропускает их по типу контента.

## 7. Кэширование

```caddyfile
{domain}, www.{domain} {
    reverse_proxy localhost:{prod-port}
    encode gzip zstd

    # Статика — immutable (Next.js добавляет хэши в имена)
    @static path *.css *.js *.woff2 *.png *.jpg *.jpeg *.webp *.avif *.svg *.ico
    header @static Cache-Control "public, max-age=31536000, immutable"

    # HTML — revalidate
    @html path / *.html
    header @html Cache-Control "public, max-age=0, must-revalidate"
}
```

Этот блок уже в шаблоне `docs/server-add-site.md` § 4 — добавлять не надо, проверить можно через `curl -I https://{domain}/_next/static/...` (должен быть `Cache-Control: public, max-age=31536000, immutable`).

ISR в Next.js = серверный кэш с автоматической ревалидацией. Redis для тяжёлых API/БД.

### Next.js: директива `use cache`

В Next.js 16 серверные функции и компоненты можно отметить `'use cache'` — Next автоматически кэширует результат на основании входных параметров. Это **штатная замена** прежним `unstable_cache` / `fetch.cache: 'force-cache'` / `cache()` — синтаксически проще, видно из IDE, работает и для React Server Components, и для обычных server-функций.

```typescript
// Тяжёлый расчёт, который можно посчитать один раз и держать в кэше
async function getServicesPricing(region: string) {
  'use cache'
  const all = await db.pricing.findMany({ where: { region } })
  return all.map(transformForUI)
}

// Серверный компонент целиком
export async function HeavyServerSection({ slug }: { slug: string }) {
  'use cache'
  const data = await loadFromMDX(slug)
  return <Section data={data} />
}
```

Когда применять:
- **Тяжёлые server-компоненты** с дорогим парсингом контента (MDX без Content Collections, расчёты на основе константных данных). Content Collections и так build-time, поэтому `use cache` поверх `allPosts` обычно избыточен — но если у блога есть filter-by-tag с тяжёлым transform, имеет смысл обернуть.
- **Серверные fetch-вызовы к редко-меняющимся API** (курсы валют, статус праздничных дней, контент CMS). Дешевле, чем guard `Promise.all` + ручной `unstable_cache`.
- **Расчёты с детерминированным выходом** — рендер большой таблицы цен на основании `region`, `currency`, `tier`. На каждый уникальный набор аргументов — одна отработка, дальше из кэша.

Когда **не** применять:
- Динамика, привязанная к запросу пользователя (личный кабинет, корзина, авторизация). Кэш будет шарить ответ между пользователями — security-баг.
- Компоненты, которые читают `cookies()` / `headers()` / `searchParams`. Next ругнётся на билде, потому что кэшируемая функция не должна зависеть от per-request state.
- Когда `revalidatePath` / `revalidateTag` дешевле и точнее. `use cache` лучше для «посчитать один раз», `revalidate*` — для «перепосчитать после мутации».

`cacheTag()` и `cacheLife()` дают точечный контроль (TTL, инвалидация по тегу). По умолчанию TTL — 15 минут, можно поднять до часа/дня для редко-меняющегося контента.

> **Важно про конфиг.** В Next.js 16 директива `use cache` требует включения через `experimental.useCache: true` в `next.config.ts` (на момент 16.0). Уточняй актуальный статус в [docs](https://nextjs.org/docs/app/api-reference/directives/use-cache) — фича выходит из experimental постепенно.

## 8. Серверная оптимизация (Caddy)

Caddy с коробки делает большую часть того, что в nginx нужно прописывать вручную:

| Что | Как в Caddy |
|---|---|
| HTTP/2 | Включён по умолчанию для HTTPS-сайтов |
| HTTP/3 (QUIC) | Включён по умолчанию начиная с Caddy 2.6 |
| TLS 1.3 | Дефолт; TLS 1.0/1.1 отключены |
| OCSP stapling | Включён автоматически для всех Caddy-выписанных сертификатов |
| SSL session resumption | Включено |
| Auto-renewal SSL | За 30 дней до истечения, без cron |

Проверить активные параметры на проде:
```bash
ssh deploy@{ip} 'sudo journalctl -u caddy --since "1 day ago" | grep -iE "tls handshake|http3" | head -5'
curl -I --http3 https://{domain}                      # должен открыться по HTTP/3
nmap --script ssl-enum-ciphers -p 443 {domain} | head # cipher suites
```

Кастомизировать почти ничего не нужно. Если включаешь Cloudflare proxy — добавь `trusted_proxies cloudflare` в site-блок (см. `docs/deploy.md` § Cloudflare), чтобы реальный IP клиента попадал в логи.

## 9. `next.config.ts`

```typescript
const nextConfig = {
  output: 'standalone',           // компактный артефакт для push-based deploy (см. docs/deploy.md)
  compress: false,                // сжатие — на Caddy (encode gzip zstd)
  reactStrictMode: true,
  images: {
    formats: ["image/avif", "image/webp"],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
    minimumCacheTTL: 60 * 60 * 24 * 365,
  },
  experimental: {
    optimizeCss: true,             // требует пакет critters
    // optimizePackageImports: ["lucide-react"] — webpack-only, Turbopack игнорирует
  },
};
```

## 10. Оптимизация изображений

`next/image` сам ресайзит и переводит в WebP/AVIF на лету — sharp подключается как `optionalDependency` Next.js 15+ и активируется автоматически. Постбилд-шага сжатия в шаблоне нет.

Если нужно один раз пройтись по тяжёлой статике в `public/` (например, после переноса со старого сайта) — вручную:

```bash
npx sharp-cli --input "public/**/*.{jpg,jpeg,png}" --output public/ --mozjpeg --quality 75
```

К `pnpm build` это не подключаем — пусть остаётся одноразовой операцией.

## 11. Accessibility (a11y)

- **Контрастность текста** — ≥ 4.5:1 (обычный) или ≥ 3:1 (≥ 24px). Типичная ошибка: `text-gray-500` (`#6b7280`) на белом = 3.8:1, не проходит. Решение: `text-gray-600` (`#4b5563`) = 5.9:1.
- **На тёмном фоне** — `text-white/40` не проходит. Минимум `text-white/60`.
- **Иерархия заголовков** — `h1 → h2 → h3` без пропусков.
- **Alt-теги** на всех `<Image>`, описательные.
- **Touch-target** ≥ 48×48px.

## 12. Прочее

- **ScrollToTop** — клиентский компонент с `usePathname()` + `window.scrollTo({ top: 0, behavior: "auto" })`. **`auto`, не `smooth`** — иначе страница «плавно ползёт» вверх перед сменой контента.
- **Top loader** (опционально) — `nextjs-toploader` в `app/layout.tsx`, 3px, accent color, без спиннера.
- **Карты/видео** — lazy load по клику. YouTube → `lite-youtube-embed` (~–500 KB).
- **`content-visibility: auto`** на секциях ниже fold — CSS-only, бесплатный win.
- `passive: true` на scroll/touch listeners.
- `Promise.all()` для параллельных запросов.
- Favicon: SVG с PNG fallback.
- **404 в RSC-prefetch** — если в навигации есть ссылки на несуществующие страницы, Next генерирует 404. Убрать ссылки или создать страницы-заглушки.

## 13. Methodology — порядок аудита производительности

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

**Safety net для рискованных аудитов:**
- `git tag pre-spec-N` перед правками.
- Backup Caddy-конфига **вне** `/etc/caddy/Caddyfile.d/` (`Caddyfile` парсит весь glob; бэкап `*.caddy.bak` или `*.caddy.old` рядом — словит `caddy validate` ошибку). Кладите бэкапы в `/home/deploy/caddy-backups/` или другую папку, не входящую в импорт.
- Тестовый Next prod на свободном порту перед редеплоем основного.

## 14. Бюджет производительности

| Ресурс | Лимит (gzip) |
|---|---|
| HTML | до 50 KB |
| CSS | до 70 KB общий, до 15 KB critical |
| JS (первая загрузка) | до 200 KB |
| Шрифты | до 100 KB (woff2) суммарно |
| Изображения первого экрана | до 300 KB суммарно |
| TTFB | до 200ms (хорошо), до 600ms (допустимо) |
| HTTP-запросов | до 30 |

## 15. Чек-лист быстрой проверки

**Изображения/шрифты:** sharp-сжатие, WebP/AVIF, `next/image` везде, lazy ниже fold, `priority`+`fetchpriority="high"` на LCP, woff2 локально, `font-display: swap`, preload критичных, явные размеры/aspect-ratio.
**JS/CSS:** purged Tailwind, code splitting, dynamic для тяжёлого, third-party скрипты `lazyOnload`/по событию, long tasks < 50ms, bundle analyzer проверен, `console.log` удалены, анимации только `transform`/`opacity`, `content-visibility: auto` ниже fold.
**Сервер:** Caddy `encode gzip zstd`, immutable на статику, revalidate на HTML, HTTP/2 + HTTP/3, TLS 1.3, OCSP stapling — всё включено по умолчанию через шаблон `docs/server-add-site.md` § 4. Preconnect для внешних доменов в `<head>`.
**A11y/UX:** WCAG AA контрастность (4.5:1 / 3:1), `h1→h2→h3` без пропусков, ScrollToTop, нет 404 в RSC-prefetch, `loading.tsx` удалён если не нужен.
**Финальная проверка:** LCP breakdown изучен, PageSpeed Insights — зелёная зона (медиана из 3–5 замеров).

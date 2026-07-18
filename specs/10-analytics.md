# Spec 10: Аналитика и вебмастера

> Оркестрация: builder-sonnet (код) | создание счётчиков/верификации — human-gated; параллель: нет (правит layout.tsx); verifier: не нужен (проверка = Realtime/Вебвизор)

## KB files to read first

- docs/integrations.md (какие счётчики, какие цели)
- `app/layout.tsx`
- `app/sitemap.ts`
- `components/legal/CookieBanner.tsx` (событие `cookie-consent` из спеки 09)

## Goal

Подключить Яндекс Метрику + Google Analytics (загрузка только после согласия в cookie-баннере), настроить цели на формы, верифицировать сайт в Я.Вебмастере и GSC, отправить sitemap. На выходе — заказчик видит трафик и конверсии, поисковики начали индексацию.

## Tasks

### 1. Получить идентификаторы — **делает человек** (чужие GUI)

1. Спросить пользователя, что уже есть. Чего нет — мини-чек-листы кликов:
   - **Я.Метрика:** metrika.yandex.ru → «Добавить счётчик» → имя + домен + часовой пояс → принять условия → включить Вебвизор → «Создать» → скопировать ID (число).
   - **GA4:** analytics.google.com → Admin → Create Property → имя + часовой пояс + валюта → Data Stream «Web» → URL сайта → скопировать **Measurement ID** (`G-XXXXXXX`).
   - **Я.Вебмастер:** webmaster.yandex.ru → «+» → домен → выбрать способ верификации (мета-тег или HTML-файл) → передать Claude код.
   - **GSC:** search.google.com/search-console → Add property (URL prefix) → способ верификации → передать код.
   Недоступное сейчас (нет аккаунта, доступ у заказчика) — строками в `CLIENT-TODO.md` («Доступы»: счётчики; «Верификации»: Вебмастер, GSC).
2. Записать ID в `.claude/memory/references.md`.
3. ID — в `.env` (они публичные):
   ```
   NEXT_PUBLIC_YM_ID=XXXXXXXX
   NEXT_PUBLIC_GA_ID=G-XXXXXXX
   ```

### 2. Подключение в код (Claude)

4. Создать `components/analytics/Metrika.tsx` (client component):
   ```tsx
   'use client'
   import Script from 'next/script'
   const YM_ID = process.env.NEXT_PUBLIC_YM_ID
   export function Metrika() {
     if (!YM_ID) return null
     return (
       <Script id="ym" strategy="lazyOnload">{`
         (function(m,e,t,r,i,k,a){m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};
         m[i].l=1*new Date();k=e.createElement(t),a=e.getElementsByTagName(t)[0],
         k.async=1,k.src=r,a.parentNode.insertBefore(k,a)})
         (window,document,"script","https://mc.yandex.ru/metrika/tag.js","ym");
         ym(${YM_ID}, "init", { clickmap:true, trackLinks:true, accurateTrackBounce:true, webvisor:true });
       `}</Script>
     )
   }
   ```
5. Аналогично `components/analytics/GA.tsx` для Google Analytics.
6. **Счётчики грузятся только после согласия в cookie-баннере.** Обёртка `components/analytics/Analytics.tsx` (client) — состояние согласия из localStorage → условный рендер:
   ```tsx
   'use client'
   export function Analytics() {
     const [consented, setConsented] = useState(false)
     useEffect(() => {
       setConsented(localStorage.getItem('cookie-consent') === 'accepted')
       const on = () => setConsented(true)
       window.addEventListener('cookie-consent', on)   // диспатчит CookieBanner (спека 09)
       return () => window.removeEventListener('cookie-consent', on)
     }, [])
     if (!consented) return null
     return (<><Metrika /><GA /></>)
   }
   ```
   Подключить `<Analytics />` в `app/layout.tsx` перед `</body>` (не Metrika/GA напрямую). Ключ localStorage сверить с реализацией CookieBanner.

### 3. Цели и события

7. Создать `lib/analytics.ts`:
   ```typescript
   export function trackGoal(name: string, params?: Record<string, any>) {
     if (typeof window === 'undefined') return
     // @ts-ignore
     window.ym?.(YM_ID, 'reachGoal', name, params)
     // @ts-ignore
     window.gtag?.('event', name, params)
   }
   ```
8. Вставить вызовы `trackGoal` на ключевые события:
   - `lead_submitted` — после успешного submit формы
   - `consultation_opened` — при открытии модалки консультации
   - `phone_clicked` — клик по `tel:` ссылке (если есть)
   - `messenger_clicked` — клик по telegram/whatsapp кнопке
   - `form_validation_error` — опционально, где люди застревают
9. **Человек:** в интерфейсе Я.Метрики (Цели → «Добавить цель» → тип «JavaScript-событие») создать цели с теми же именами. Claude даёт список имён списком в чат.

### 4. Верификация и sitemap — **делает человек**, Claude готовит код

10. **Яндекс Вебмастер:**
    - Claude кладёт верификацию: HTML-файл в `public/` или мета-тег (по способу из шага 1).
    - Человек: Вебмастер → «Проверить» → после подтверждения: Индексирование → Файлы Sitemap → добавить `https://{domain}/sitemap.xml`.
    - Регион: Вебмастер → Региональность (+ Яндекс Бизнес — привязать карточку организации).
11. **Google Search Console:**
    - Claude: мета-тег в `app/layout.tsx → metadata.verification.google` (или HTML-файл).
    - Человек: GSC → Verify → Sitemaps → отправить sitemap.

### 5. UTM-метки и фильтры

12. Если планируется реклама — обсудить с заказчиком UTM-структуру.
13. **Человек:** в Я.Метрике создать фильтр «не учитывать» IP заказчика и разработчика (Настройки → Фильтры).

### 6. Тестирование

14. После деплоя:
    - Открыть сайт в инкогнито, **принять cookie-баннер** → счётчики загрузились (Network: `mc.yandex.ru`, `googletagmanager.com`). До принятия — запросов счётчиков НЕТ.
    - Я.Метрика → Вебвизор: сессия через 5-10 минут. GA Realtime: посетитель сразу.
    - Тестовая заявка → цель `lead_submitted` сработала.

## Boundaries

- **Always:** скрипты через `<Script strategy="lazyOnload">`; загрузка счётчиков только после согласия (152-ФЗ); цели англ. snake_case; всё, что требует чужих GUI, — человек (Claude даёт чек-лист кликов и ждёт ID/коды).
- **Ask first:** перед добавлением Tag Manager (вес; прямой вызов обычно проще), перед интеграцией с рекламными кабинетами.
- **Never:** ставить Метрику/GA в `<head>` напрямую; грузить счётчики до согласия; отслеживать персональные данные (имя/телефон в event params — нарушает 152-ФЗ).

## Done when

- Метрика и GA подключены через consent-гейт: до «Принять» — не грузятся, после — видны посетители в обоих.
- Цели созданы и срабатывают (проверено тестовой заявкой).
- Я.Вебмастер и GSC подтверждены, sitemap отправлен.
- Регион в Я.Бизнес указан (для локального бизнеса).
- IP заказчика/разработчика исключены из статистики.
- Незакрытые пункты (доступы, верификации на стороне заказчика) — в `CLIENT-TODO.md`.

## Memory updates

- `references.md` — ID счётчиков, ссылки на Метрику/GA/Вебмастер/GSC, контакт ответственного у заказчика
- `pointers.md` — `lib/analytics.ts → trackGoal()`, `components/analytics/*` (включая consent-обёртку `Analytics.tsx`)
- `decisions.md` — какие именно цели созданы и зачем
- `project_state.md` — done, следующая `11-performance`

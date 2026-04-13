# Spec 10: Аналитика и вебмастера

## KB files to read first

- docs/seo.md (раздел «Аналитика и вебмастера»)
- docs/integrations.md (какие счётчики, какие цели)
- `app/layout.tsx`
- `app/sitemap.ts`

## Goal

Подключить Яндекс Метрику + Google Analytics, настроить цели на формы, верифицировать сайт в Яндекс Вебмастере и Google Search Console, отправить sitemap. На выходе — заказчик видит трафик и конверсии в обоих счётчиках, поисковики начали индексацию.

## Tasks

### 1. Получить идентификаторы

1. Спросить пользователя:
   - Я. Метрика: создан счётчик? Если нет — создать на yandex.ru/metrika (получить ID)
   - Google Analytics: создан GA4? Если нет — создать на analytics.google.com (получить Measurement ID)
   - Я. Вебмастер: домен добавлен? (webmaster.yandex.ru)
   - GSC: ресурс добавлен? (search.google.com/search-console)
2. Записать ID в `.claude/memory/references.md`
3. ID Метрики и GA — в `.env` (или прямо в коде, они публичные):
   ```
   NEXT_PUBLIC_YM_ID=XXXXXXXX
   NEXT_PUBLIC_GA_ID=G-XXXXXXX
   ```

### 2. Подключение в код

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
5. Аналогично `components/analytics/GA.tsx` для Google Analytics
6. Подключить оба в `app/layout.tsx` перед `</body>`

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
   - `form_validation_error` — опционально, для отслеживания где люди застревают
9. В Я.Метрика интерфейсе создать соответствующие цели типа «JavaScript-событие» с такими же именами

### 4. Верификация и sitemap

10. **Яндекс Вебмастер:**
    - Способ верификации: HTML-файл (положить в `app/yandex_[code].txt/route.ts` или просто в `public/`)
    - После подтверждения: загрузить sitemap (`https://[domain]/sitemap.xml`)
    - Указать регион (Яндекс Бизнес → привязать карточку организации)
11. **Google Search Console:**
    - Способ верификации: HTML-файл или мета-тег в `app/layout.tsx → metadata.verification.google`
    - После подтверждения: отправить sitemap

### 5. UTM-метки и фильтры

12. Если планируется реклама — обсудить с заказчиком UTM-структуру
13. В Я.Метрике создать сегмент «без сотрудников» (исключить IP заказчика и разработчика)

### 6. Тестирование

14. После деплоя:
    - Открыть сайт в инкогнито
    - В Я.Метрика → Вебвизор увидеть сессию через 5-10 минут
    - В GA Realtime увидеть посетителя сразу
    - Отправить тестовую заявку → проверить что цель `lead_submitted` сработала

## Boundaries

- **Always:** скрипты через `<Script strategy="lazyOnload">` (не блокировать рендер), цели именованные англ. snake_case
- **Ask first:** перед добавлением Tag Manager (он добавляет вес — обычно прямой вызов проще), перед интеграцией с рекламными кабинетами
- **Never:** ставить Метрику/GA через `<head>` напрямую (используем next/script), отслеживать персональные данные (имя/телефон в event params — нарушает 152-ФЗ)

## Done when

- Метрика и GA подключены, видны посетители в обоих счётчиках
- Цели созданы и срабатывают (проверено тестовой заявкой)
- Я. Вебмастер и GSC подтверждены, sitemap отправлен
- Регион в Я. Бизнес указан (для локального бизнеса)
- IP заказчика/разработчика исключены из статистики

## Memory updates

- `references.md` — ID счётчиков, ссылки на Метрику/GA/Вебмастер/GSC, контакт ответственного у заказчика
- `pointers.md` — `lib/analytics.ts → trackGoal()`, `components/analytics/*`
- `decisions.md` — какие именно цели созданы и зачем
- `project_state.md` — done, следующая `11-performance`

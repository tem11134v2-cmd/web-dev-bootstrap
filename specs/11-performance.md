# Spec 11: Performance audit + оптимизация (Lighthouse 90+)

## KB files to read first

- docs/performance.md (полностью — все разделы и Methodology § 13)
- docs/server-add-site.md (nginx + Cache-Control, для справки — применяет на сервере человек)
- `next.config.ts`
- `app/page.tsx` + типовая страница услуги

## Goal

Lighthouse Performance, Accessibility, Best Practices, SEO ≥ 90 на mobile и desktop. Финальный pass перед передачей заказчику. Применить методологию из docs/performance.md последовательно.

## Background

Это критическая спека, нельзя пропустить. Делается ПОСЛЕ всех остальных, когда сайт функционально готов. На любую зелёную метрику можно сэкономить день, но на красную — потерять заказы и позиции.

**Принципы методологии (из docs/performance.md):**
1. Измеряй ДО, не после
2. Смотри HTML, не только метрики
3. Server Components > Dynamic imports > Lazy loading
4. LCP breakdown показывает где искать (если render delay > 50% — не картинка/сервер виноваты)
5. PSI mobile шумит ±10 — медиана из 3-5 замеров

## Tasks

### 1. Baseline (зафиксировать стартовую точку)

1. `git tag pre-spec-11` — точка отката
2. Запустить bundle analyzer:
   ```bash
   npm install -D @next/bundle-analyzer
   ANALYZE=true npx next build
   ```
3. PSI замер главной + одной страницы услуги (mobile + desktop) — записать стартовые цифры в `.claude/memory/lessons.md` (не для урока, а как baseline)

### 2. Bundle: убрать раздутые зависимости

4. По красным флагам из docs/performance.md:
   - Если есть `zod` v4 — заменить на `valibot` (1-3 KB вместо ~100 KB)
   - Если есть `moment` — заменить на `date-fns` или `dayjs`
   - Если есть полный `lodash` — `lodash-es` с именованными импортами
5. Проверить bundle ещё раз — что снизилось

### 3. Server Components (если ещё не везде)

6. Аудит каждой страницы: где `"use client"` и почему?
7. Применить «viral client» паттерн: вынести хук-узлы (например, `useConsultationDialog()`) в отдельные client-компоненты, контейнер оставить server
8. Цель: страницы услуг — server, формы и кнопки с диалогом — отдельные client-компоненты

### 4. Dynamic imports для тяжёлого client-кода

9. Найти крупные client-компоненты ниже фолда:
   - QuizWidget (если есть)
   - ReviewsBlock (если много карточек)
   - ComparisonTable (если большая таблица)
10. Обернуть в `next/dynamic` с loading skeleton:
    ```typescript
    const QuizWidget = dynamic(() => import('@/components/sections/QuizWidget'), {
      loading: () => <div className="h-96 animate-pulse bg-muted rounded-xl" />,
    })
    ```

### 5. Изображения

11. Все растровые изображения в `public/` прогнать через sharp (JPEG quality 75, PNG level 9, удалить EXIF):
    ```bash
    npx sharp-cli --input "public/**/*.{jpg,jpeg,png}" --output public/ --mozjpeg --quality 75
    ```
12. Все `<img>` заменить на `next/image` (если где-то остались)
13. На LCP-элементе (hero image): `priority` + `fetchPriority="high"` (явно — `priority` не гарантирует preload-приоритет в Next 16)
14. Все картинки — явные `width`/`height` или `aspect-ratio`

### 6. Шрифты

15. Шрифты только woff2, локально (через `next/font`)
16. `display: 'swap'`
17. Только нужные начертания и subset (latin + cyrillic)

### 7. CSS

18. content-visibility utility в `globals.css`:
    ```css
    .cv-auto { content-visibility: auto; contain-intrinsic-size: auto 500px; }
    ```
19. Применить `.cv-auto` к секциям ниже фолда на главной (FAQ, Reviews, Contact)
20. НЕ ставить `scroll-behavior: smooth` глобально (см. lessons performance), только условно через `html:has(:target)`

### 8. loading.tsx — проверить не вредит ли

21. Если вся страница — server components без async — `loading.tsx` создаст пустой Suspense skeleton, который PSI воспримет как LCP. Удалить такие `loading.tsx`
22. Оставить только там где есть реально async-данные

### 9. Nginx-уровень

23. Включить gzip_static (уже включён в стандартной конфигурации):
    ```nginx
    gzip_static on;
    ```
24. Brotli — если `nginx -V 2>&1 | grep brotli` показывает поддержку, включить. Если нет — пропустить (gzip_static достаточно)
25. Cache-Control: immutable на статику, revalidate на HTML — проверить (шаблон nginx в docs/server-add-site.md)

### 10. next.config — финальная проверка

26. `compress: false` (сжатие на nginx)
27. `images.formats: ['image/avif', 'image/webp']`
28. `images.minimumCacheTTL: 60 * 60 * 24 * 365`

### 11. Console и dev-артефакты

29. Удалить все `console.log` из кода (grep + удалить)
30. Удалить `loading.tsx` если применимо (см. шаг 21)
31. Проверить: нет 404 в RSC-prefetch (открыть Network в DevTools)

### 12. Финальный замер

32. Build + deploy
33. PSI mobile + desktop для главной + 1-2 страниц услуг
34. Цель: все 4 метрики ≥ 90 (Performance, Accessibility, Best Practices, SEO)
35. Если что-то < 90 — открыть Lighthouse-репорт, починить конкретные находки
36. Записать финальные цифры в `.claude/memory/lessons.md` для истории

### 13. Accessibility (WCAG AA)

37. Проверить контрастность через DevTools или WCAG-калькулятор:
    - `text-gray-500` (#6b7280) на белом = 3.8:1 — НЕ проходит, заменить на `text-gray-600` (#4b5563) = 5.9:1
    - На тёмном фоне `text-white/40` НЕ проходит, минимум `text-white/60`
38. Иерархия заголовков: h1 → h2 → h3 без пропусков
39. Все `<Image>` имеют осмысленный alt
40. Все интерактивные элементы доступны с клавиатуры (Tab по форме работает)

## Boundaries

- **Always:** замер ДО и ПОСЛЕ (медиана из 3 замеров mobile, 1 desktop), коммит после каждой группы оптимизаций
- **Ask first:** перед изменением nginx-конфига (бэкап обязателен), перед удалением функционала ради метрики
- **Never:** жертвовать функциональностью ради цифр, оптимизировать без bundle analyzer (легко пилить не то), удалять console.log массово через find/replace без проверки

## Done when

- Lighthouse mobile + desktop: Performance ≥ 90, Accessibility ≥ 90, Best Practices ≥ 90, SEO ≥ 90 на 3-5 страницах
- Bundle analyzer чист (нет красных флагов)
- Server Components везде где можно, dynamic imports для тяжёлого client
- Изображения оптимизированы, шрифты локальны
- nginx: gzip_static on, immutable cache
- Нет console.log, нет лишних loading.tsx
- WCAG AA контраст и иерархия заголовков

## Memory updates

- `lessons.md` — замеры до/после, что больше всего помогло, что не сработало
- `pointers.md` — путь к bundle analyzer конфигу, dynamic-обёрткам
- `decisions.md` — все нестандартные оптимизации с обоснованием
- `project_state.md` — done, следующая `12-handoff`

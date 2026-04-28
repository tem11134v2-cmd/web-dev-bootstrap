# Spec 03: Дизайн-система

## KB files to read first

- docs/design-system.md (полностью)
- docs/spec.md (бренд: цвета, шрифт, тон)
- `.claude/memory/feedback.md` (табу по дизайну от заказчика)

## Goal

Зашить в проект бренд: цвета, типографику, отступы, базовые компоненты Header/Footer. На выходе — `app/page.tsx` использует фирменные цвета, открывается с правильным шрифтом, есть видимые header и footer (пусть пустые).

## Tasks

### 1. Цвета и переменные

1. Конвертировать HEX из `docs/spec.md` в **OKLCH** (через oklch.com или аналог) — Tailwind v4 нативно работает в OKLCH, перцептивно ровные осветления/градиенты, поддержка P3-гамм. Подробнее почему OKLCH — `docs/design-system.md` § «OKLCH вместо HEX/HSL/RGB».
2. В `app/globals.css` определить токены палитры через Tailwind v4 `@theme` (CSS-переменные внутри блока `@theme` автоматически становятся Tailwind utility-классами `bg-primary`, `text-accent` и т.д.):
   ```css
   @import "tailwindcss";

   @theme {
     /* HEX из брифа → OKLCH (см. комментарии для сверки с оригиналом) */
     --color-primary: oklch(0.45 0.15 250);   /* #2D4A8A — фирменный синий */
     --color-accent: oklch(0.65 0.20 30);     /* #E07A3F — оранжевый CTA */
     --color-section-bg: oklch(0.97 0.005 250); /* #F4F6FA — светлый фон секции */
     --color-text: oklch(0.30 0 0);           /* #424242 — основной текст */
     --color-background: oklch(1 0 0);        /* #FFFFFF */
     --color-border: oklch(0.85 0 0);         /* #D6D6D6 */
   }
   ```
   HEX в комментариях — это «source of truth от заказчика». При пересмотре палитры можно сверить.
3. Проверить: класс `bg-primary` рендерится с правильным цветом, `bg-primary/90` (через `color-mix in oklch`) даёт видимо «тот же цвет чуть светлее», без сдвига оттенка

### 2. Типографика

4. Подключить шрифт через `next/font` (предпочтительно Inter, Geist или из брифа):
   ```typescript
   // app/layout.tsx
   import { Inter } from 'next/font/google'
   const inter = Inter({ subsets: ['latin', 'cyrillic'], display: 'swap' })
   ```
5. Если шрифт не из Google — положить woff2 в `public/fonts/`, использовать `next/font/local`
6. Применить шрифт к `<html className={inter.className}>`
7. Настроить размеры заголовков в Tailwind (через `@theme` или классы): H1 48-56px, H2 36-40px, H3 24-28px

### 3. Header

8. Создать `components/layout/Header.tsx` (server component, если не нужны hooks):
   - Sticky top, белый фон, тонкая тень при скролле (через CSS sticky + shadow на scroll, без JS если возможно)
   - Логотип слева (использовать `<Image>` из `next/image`, путь `/logo.svg`)
   - Навигация по центру (заглушка из 3-4 пунктов из `docs/pages.md`, реальная — в спеке 04)
   - CTA-кнопка справа (текст из брифа, открытие модалки — заглушка `onClick={() => alert('TODO')}`, реальный обработчик в спеке 09)
   - Mobile: бургер-меню через shadcn `<Sheet>`, slide-in
   - **Без телефона в хедере** (см. feedback.md если правило применимо)

### 4. Footer

9. Создать `components/layout/Footer.tsx` (server component):
   - Тёмный фон (primary или dark gradient)
   - 3-4 колонки: навигация / услуги / контакты / соцсети (данные из docs/spec.md и docs/pages.md)
   - Юридический disclaimer внизу (если требуется по брифу)
   - Копирайт `© {new Date().getFullYear()} {Company}`
   - Юр-ссылки `/privacy/` и `/terms/` НЕ добавляем сейчас — самих страниц ещё нет, ссылки появятся в спеке 09 одновременно с созданием страниц

### 5. Layout

10. Подключить Header и Footer в `app/layout.tsx`:
    ```tsx
    <body>
      <Header />
      <main>{children}</main>
      <Footer />
    </body>
    ```
11. В `app/page.tsx` — вставить демо-блок с цветами/типографикой для визуальной проверки палитры (потом удалится в спеке 04)

### 6. Базовые мета-теги

12. В `app/layout.tsx` — корневой `metadata` с дефолтами:
    ```typescript
    export const metadata: Metadata = {
      metadataBase: new URL('https://[domain]'),
      title: { default: '[Brand]', template: '%s | [Brand]' },
      description: '[из брифа]',
      openGraph: { type: 'website', locale: 'ru_RU', siteName: '[Brand]' },
    }
    ```

## Boundaries

- **Always:** использовать только Tailwind-классы, никаких inline styles, никакого custom CSS кроме CSS-переменных в globals.css
- **Ask first:** если бренд требует кастомного шрифта (не из Google Fonts) — уточнить лицензию
- **Never:** добавлять анимации parallax/particles, переопределять цвета в отдельных компонентах (только через переменные), верстать через CSS-модули или styled-components

## Testing

1. Открыть localhost:3000 — header виден, footer виден, цвета фирменные, шрифт правильный
2. Проверить адаптив: 375px (mobile burger), 768px, 1280px — header не ломается
3. Проверить контрастность: текст на цветных фонах ≥ 4.5:1 (WCAG AA)

## Done when

- CSS-переменные с фирменными цветами в `globals.css`
- Шрифт подключён через `next/font`, виден на странице
- Header sticky с лого, навигацией, CTA, mobile-меню
- Footer с колонками и копирайтом
- Layout содержит Header + main + Footer + дефолтный metadata
- Демо-страница на localhost рендерится с правильным брендом

## Memory updates

- `pointers.md` — Header/Footer пути, тип шрифта
- `decisions.md` — выбор шрифта (если не дефолтный), любые отклонения от docs/design-system.md
- `project_state.md` — done, следующая `04-homepage-and-approval`

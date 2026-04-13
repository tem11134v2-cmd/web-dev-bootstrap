# Design System

Философия дизайна, токены, layout, header/footer.

## Философия

**Premium minimalism.** Ориентир — Apple, Stripe, Linear. Щедрые отступы, чистая типографика, тонкие анимации. **Не** пёстро, **не** игриво, **не** перегружено.

## Цветовая палитра

Цвета приходят из брифа клиента (`docs/spec.md` после `00-brief.md`). Структура палитры:

| Токен | Назначение |
|---|---|
| `--color-primary` | Основной цвет (хедер, фоны, акценты) |
| `--color-accent` | CTA-кнопки, яркие элементы |
| `--color-text` | Основной текст (тёмно-серый, не чёрный — `#424242` ориентир) |
| `--color-bg` | Основной фон (`#FFFFFF`) |
| `--color-section-bg` | Чередование секций (светлый оттенок primary) |
| `--color-border` | Разделители, границы карточек (`#D6D6D6` ориентир) |

Объявляются в `app/globals.css` через Tailwind v4 `@theme`. Шаблон — в `specs/03-design-system.md`.

> **Контрастность — критично.** Любая пара `text/background` должна давать ≥ 4.5:1 (обычный текст) или ≥ 3:1 (крупный, ≥ 24px). Проверять до утверждения палитры. Подробнее — `docs/performance.md` § «Accessibility».

## Типографика

- Чистый sans-serif (Inter, Geist, system-ui).
- **H1:** 48–56px (bold). На мобильном: 32–36px.
- **H2:** 36–40px (semibold). Мобильный: 28–32px.
- **H3:** 24–28px (medium).
- **Body:** 16–18px, `line-height: 1.5–1.6`. Мобильный: 16px.
- Один шрифт-семейство, максимум 2–3 начертания (см. `docs/performance.md` § «Шрифты»).

## Компоненты — общие правила

- **Только shadcn/ui** — никаких самописных UI-примитивов.
- **CTA-кнопки:** `accent` color, `rounded-lg`, `py-3 px-8`, `font-semibold`, hover: `opacity-90` или `darken`.
- **Карточки:** `bg-white`, `rounded-xl`, `shadow-sm`, hover: `translateY(-4px) + shadow-lg` (hover-lift).
- **Иконки:** Lucide React, `24px` в карточках, `20px` в тексте. Рендерить на сервере, не пробрасывать props-ами в client (см. `docs/architecture.md`).
- **Gradient accents:** `border-top` 3–4px с градиентом `primary → accent` на ключевых карточках.

## Layout

- **Max width контейнера:** `1200px`, `mx-auto`.
- **Section padding:** `py-20 lg:py-28` (80–112px), `px-4 lg:px-0`.
- **Чередование секций:** белый ↔ `--color-section-bg`.
- **Mobile-first:** всегда начинай с мобильного, потом `md:`, потом `lg:`.

## Анимации

**Используй:**
- Fade-in on scroll (Intersection Observer, `opacity 0→1`, `translateY 20→0`).
- Animated counters в Hero (`easeOutExpo`, ~2 секунды).
- Hover-lift на карточках (`transform + shadow`, 300ms).
- Плавные `transition` на hover для кнопок и ссылок.

**Не используй:**
- Parallax.
- Particle-эффекты.
- Тяжёлые CSS/JS-анимации.
- Auto-playing video backgrounds.
- Marquee / бегущие строки.

> **Производительность анимаций.** Только `transform` и `opacity` (GPU). Не анимировать `width`, `height`, `top`, `left`, `margin`. Для глобального плавного скролла к якорям — `html:has(:target) { scroll-behavior: smooth; }`, не `html { scroll-behavior: smooth }` (ломает page transitions). Подробнее — `docs/performance.md`.

## Header

- Sticky (`fixed top`), белый фон, `shadow` при скролле.
- Логотип слева, навигация по центру, CTA-кнопка справа.
- Mobile: бургер-меню, slide-in панель.
- Dropdown для вложенных пунктов (виды услуг и т. п.).
- **Никакого телефона в хедере** — ломает layout на мобильном. Телефон — в footer и на странице «Контакты».

## Footer

- Тёмный фон (`primary` или `dark gradient`).
- 3–4 колонки: навигация, услуги, контакты, соцсети.
- Юридический disclaimer внизу (если требуется — см. `docs/legal-templates.md`).
- Копирайт: `© {year} {Company}`.
- Ссылки на «Политику конфиденциальности» и «Согласие на обработку ПДн» — обязательно для RU-сайтов с формами.

## Что задаётся в брифе vs зашито в систему

| Из брифа клиента | Зашито в систему |
|---|---|
| Цвета (primary, accent, section-bg) | Структура палитры (6 токенов) |
| Шрифт (если клиентский бренд требует) | Sans-serif, woff2, font-display: swap |
| Логотип, фавикон | Размеры, форматы, оптимизация |
| Tone of voice заголовков | H1/H2/H3 размеры и иерархия |
| Контент секций | 44 типа секций (`docs/content-layout.md`) |

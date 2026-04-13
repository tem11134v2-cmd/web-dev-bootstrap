# Spec [opt]: Интернет-магазин (товарные карточки + корзина)

## Когда применять

Сайт продаёт физические товары (не услуги). На странице — каталог, у каждого товара цена/характеристики, нужна корзина и оформление заказа.

**Не применять** если: услуги (используй обычные посадочные), 1-3 товара (хватит обычных страниц с формами), маркетплейс/multi-vendor (нужна полноценная платформа, не Next.js + MDX).

## KB files to read first

- docs/content-layout.md (раздел «Товарные блоки»)
- docs/forms-and-crm.md
- `lib/consultation-context.tsx`

## Goal

Создать каталог товаров, страницы товаров, корзину, оформление заказа. Заказы уходят в CRM как лид с составом корзины. На выходе — небольшой магазин (до 100-200 SKU) на статической архитектуре, без полноценного бэкенда.

## Background

**Архитектура без БД:** товары — MDX-файлы или JSON в `content/products/`. SSG генерирует страницы при сборке. Корзина — `localStorage`. Оплата — внешняя (ЮKassa, Tinkoff) или «оплата при получении» (заказ в CRM).

**Если нужны:** склад, остатки в реальном времени, личный кабинет, история заказов, акции с правилами — **это не наш кейс, нужна e-commerce платформа** (Shopify, BigCommerce, или полноценный Next + БД + Stripe).

## Tasks

### 1. Структура товара

1. Создать формат товара (JSON или MDX в `content/products/`):
   ```typescript
   {
     slug: string
     name: string
     category: string
     price: number
     priceOld?: number
     currency: 'RUB' | 'USD'
     image: string
     gallery?: string[]
     description: string  // MDX
     specs: Record<string, string>
     inStock: boolean
   }
   ```
2. Создать `lib/products.ts` — `getAllProducts()`, `getProductBySlug()`, `getCategoriesTree()`

### 2. Каталог и страница товара

3. `app/catalog/page.tsx` — список товаров с фильтрами (категория, цена, наличие)
4. `app/catalog/[category]/page.tsx` — каталог категории
5. `app/product/[slug]/page.tsx` — карточка товара:
   - Hero: галерея + name + price + CTA «В корзину»
   - Specs (таблица характеристик)
   - Description (MDX)
   - Related (3-6 похожих)
   - JSON-LD `Product` schema (price, availability, image, brand)

### 3. Корзина

6. `lib/cart-context.tsx` — React Context с состоянием корзины + методы add/remove/update/clear
7. Хранение в `localStorage` (`useEffect` для синхронизации)
8. `components/cart/CartButton.tsx` — иконка в Header с бейджем-счётчиком (client)
9. `components/cart/CartDrawer.tsx` — slide-in панель (shadcn `<Sheet>`) со списком товаров и кнопкой «Оформить»

### 4. Оформление заказа (checkout)

10. `app/checkout/page.tsx`:
    - Список товаров из корзины (resumable)
    - Форма данных получателя (имя, телефон, email, адрес, способ доставки, способ оплаты)
    - Валидация Zod
    - Submit → POST на `/api/order/route.ts`
11. `app/api/order/route.ts`:
    - Валидация
    - Отправка в CRM как сделка/лид с составом корзины (массив товаров с ценой)
    - Опционально: создание счёта в ЮKassa/Tinkoff и редирект на оплату
    - Fallback: запись в `data/orders.json`
12. После успеха — очистка корзины + страница `/checkout/success/`

### 5. Платёжная интеграция (опционально)

13. Если оплата онлайн нужна:
    - **ЮKassa** (бывший Яндекс.Касса): `lib/yookassa.ts`, redirect-flow
    - **Tinkoff**: `lib/tinkoff.ts`, аналогично
    - Webhook на `/api/payment-callback/` для подтверждения оплаты
14. Если оплата при получении/счёт в банке — пропустить

### 6. SEO для магазина

15. Каждая страница товара — уникальные мета (на основе name + price + brand)
16. Категории каталога в sitemap
17. JSON-LD `Product` обязательно (для Google Shopping и Я.Маркет)
18. `Offer` schema с актуальной ценой и `availability`

## Boundaries

- **Always:** товары — статика в git (max 200 SKU), всё остальное — внешние сервисы
- **Ask first:** перед интеграцией платёжки (нужны данные ИП/ООО заказчика, KYC), перед добавлением личного кабинета (это уже не «лёгкий магазин»)
- **Never:** хранить данные карт, делать корзину серверной (без необходимости — `localStorage` достаточно), писать собственный платёжный шлюз

## Done when

- Каталог открывается, фильтры работают
- Страница товара полная (галерея, specs, description, related, JSON-LD)
- Корзина: добавить/убрать/изменить количество, сохраняется между сессиями
- Checkout: форма + валидация + отправка в CRM с составом
- (Опц.) Платёжная интеграция: тестовый платёж проходит в sandbox-режиме
- Mobile UX корректен (особенно корзина и checkout)

## Memory updates

- `pointers.md` — пути к каталогу, продукту, корзине, чекауту, продуктовым утилитам
- `references.md` — платёжный провайдер (если есть), API-ключи (без значений)
- `decisions.md` — где хранятся товары (MDX/JSON), почему такая архитектура (статика vs БД)

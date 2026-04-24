# Spec 09: Формы, CRM, юридическое (152-ФЗ)

## KB files to read first

- docs/forms-and-crm.md (полностью)
- docs/legal-templates.md (152-ФЗ: cookie-баннер, согласие на ПДн)
- docs/integrations.md (какая CRM, какие поля)
- docs/spec.md (контакты заказчика)
- `components/forms/ConsultationDialog.tsx` (заглушка из спеки 04)
- `components/service-page/ServicePageForms.tsx` (заглушки из спеки 05)

## Goal

Заменить заглушки форм реальной интеграцией: валидация → API route → CRM → fallback. Добавить юридическое: cookie-баннер по 152-ФЗ, согласие на обработку ПДн в формах, страницы политики/оферты с готовыми текстами от пользователя.

## Tasks

### 1. API endpoint

1. Создать `app/api/lead/route.ts`:
   - POST с JSON body
   - Zod-валидация (схема)
   - Rate limiting: 1 запрос / 10 секунд / IP (через `Map<ip, timestamp>` в памяти, или `next-rate-limit`)
   - Отправка в CRM (через `lib/crm.ts`)
   - Fallback: если CRM недоступна → запись в `data/leads.json`
   - Возврат `{ success: true }` или `{ error: '...' }`
2. Создать `lib/crm.ts` под выбранную CRM:
   - **AMO CRM:** POST на `/api/v4/leads/complex` с Bearer токеном
   - **Bitrix24:** POST на webhook URL
   - **Другая:** уточнить у пользователя API
3. Все секреты — в `.env`:
   ```
   AMO_CRM_URL=...
   AMO_CRM_TOKEN=...
   ```

### 2. Подключение к формам

4. В `components/forms/ConsultationDialog.tsx`:
   - Реальная валидация (Zod-схема: name min 2, phone min 10, опционально email/message)
   - `handleSubmit` → `fetch('/api/lead', { method: 'POST', body: JSON.stringify(data) })`
   - Loading state на кнопке (disabled + spinner)
   - Sonner toast: успех зелёный, ошибка красный
5. В `components/service-page/ServicePageForms.tsx` — то же для inline mid/final CTA
6. Добавить в каждую форму **чекбокс согласия на обработку ПДн** (компонент `components/legal/PdnConsent.tsx`):
   ```tsx
   <Checkbox required />
   <span className="text-xs">Согласен с <a href="/privacy/">политикой конфиденциальности</a></span>
   ```

### 3. Cookie-баннер (152-ФЗ)

7. Создать `components/legal/CookieBanner.tsx` (client) — текст из `docs/legal-templates.md`:
   - Появляется снизу при первом визите
   - Кнопки «Принять» / «Подробнее» (ссылка на /privacy/)
   - localStorage-флаг чтобы не показывать повторно
   - Не блокирует контент (баннер, не модалка)
8. Подключить в `app/layout.tsx`

### 4. Юридические страницы

9. Создать `app/privacy/page.tsx` — текст политики конфиденциальности (пользователь приносит готовый из генератора, вставляем как есть, оборачиваем в `prose`)
10. Создать `app/terms/page.tsx` — оферта/условия (если применимо, иначе пропустить)
11. Обе страницы:
    - `metadata: { robots: { index: false, follow: true } }` — обычно не индексируются
    - В footer есть ссылки (это уже в спеке 03)
    - Простой server component с prose-стилями

### 5. Тестирование

12. Локально — заполнить форму, отправить, проверить:
    - Лид появился в CRM (если есть тестовый аккаунт)
    - При ошибке CRM — лид появился в `data/leads.json`
    - Toast показал результат
    - Чекбокс ПДн обязателен (без него submit blocked)
13. Cookie-баннер появляется на чистом браузере, исчезает после «Принять», не возвращается
14. Rate limiting — два быстрых submit с одного IP → второй вернёт ошибку
15. `npm run build` проходит, .env переменные не попали в клиентский бандл (не использовать `NEXT_PUBLIC_` для секретов!)

### 6. Деплой

16. На сервере — добавить `.env` с реальными секретами (если нет — создать)
17. `chmod 600 .env`, владелец `deploy`
18. Push в `dev` → проверка на preview → PR в `main` → автодеплой через GitHub Actions
19. На проде — отправить тестовую заявку, убедиться что доходит в CRM

## Boundaries

- **Always:** валидация И на клиенте И на сервере (Zod в обоих местах), секреты в .env, согласие на ПДн обязательно
- **Ask first:** если CRM требует нестандартного маппинга полей, если у заказчика нет готовой политики/оферты (предложить шаблонные генераторы)
- **Never:** коммитить .env, использовать `NEXT_PUBLIC_` для секретов, отправлять данные без согласия на ПДн, делать exit-intent попап на мобильном

## Done when

- `/api/lead` принимает, валидирует, шлёт в CRM, имеет fallback
- Все формы (consultation dialog, mid/final CTA на странице услуги) работают на проде
- Cookie-баннер показывается, юридические страницы доступны
- Согласие на ПДн обязательно во всех формах
- Тестовая заявка доехала до CRM на проде

## Memory updates

- `references.md` — название CRM, URL, контакт ответственного, путь к .env (без значений)
- `pointers.md` — `app/api/lead/route.ts`, `lib/crm.ts`, `components/legal/*`
- `decisions.md` — выбор CRM, нюансы маппинга, источник политики (генератор / юрист заказчика)
- `lessons.md` — если что-то сломалось при интеграции (CRS, токены, и т.д.)
- `project_state.md` — done, следующая `10-analytics`

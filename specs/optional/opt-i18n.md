# Spec [opt]: Многоязычность (next-intl)

## Когда применять

Сайт должен быть на 2+ языках. Типичный случай: русский (основной) + английский для иностранной аудитории.

**Не применять** если: один язык, перевод нужен «когда-нибудь потом» (добавишь когда возникнет реальная задача — лучше чем тащить груз).

## KB files to read first

- docs/architecture.md
- docs/seo.md (раздел про hreflang)
- docs/pages.md (на каких страницах нужна локализация)
- `app/layout.tsx`, `app/page.tsx`

## Goal

Подключить next-intl, перевести весь UI и контент сайта на 2+ языка с поддержкой language switcher, корректным hreflang и SEO. На выходе — `/ru/...` (или дефолт без префикса) и `/en/...` структура с раздельной индексацией.

## Tasks

### 1. Архитектурное решение: префикс или поддомен

1. Спросить пользователя:
   - **Префикс в пути** (`domain.com/en/page`) — проще, один сертификат, лучше для SEO внутри одного домена
   - **Поддомен** (`en.domain.com`) — больше SEO-разделение, но требует второго блока в `Caddyfile.d/{site}.caddy` (SSL Caddy выпустит автоматически)
2. Префикс — рекомендация по умолчанию
3. Зафиксировать в `decisions.md`

### 2. Подключение next-intl

4. Установить:
   ```bash
   npm install next-intl
   ```
5. Создать `i18n/request.ts` (конфигурация next-intl)
6. Создать `messages/ru.json` и `messages/en.json` — словари для UI:
   ```json
   {
     "header.menu.services": "Услуги",
     "cta.consultation": "Бесплатная консультация",
     ...
   }
   ```
7. Обернуть `app/[locale]/layout.tsx` в `<NextIntlClientProvider>`
8. Реструктурировать app/ в `app/[locale]/...` (или оставить дефолтный язык без префикса — продвинутая конфигурация)

### 3. Перевод UI

9. Заменить хардкод-тексты в Header/Footer/общих компонентах на `useTranslations()`
10. Кнопки CTA, плейсхолдеры форм, ошибки валидации — через словари
11. Даты, числа — через `useFormatter()` (учитывает локаль)

### 4. Перевод контента (страниц услуг, блога)

12. Контент — отдельно для каждого языка:
    - Если шаблон страниц (`ServicePageData`) — продублировать `app/[locale]/[slug]/page-data.{ru,en}.ts` или хранить data в `content/services/[slug].{ru,en}.json`
    - Если MDX блог — `content/blog/[slug].{ru,en}.mdx`
13. Тексты переводит заказчик (или копирайтер), не Claude

### 5. Language Switcher

14. Создать `components/layout/LangSwitcher.tsx` (client):
    - Выпадающий список языков
    - При выборе — `router.replace(pathname, { locale: 'en' })` через next-intl
    - Сохранить выбор в cookie (next-intl делает автоматом)
15. Поместить в Header (рядом с CTA или в углу)

### 6. SEO: hreflang и canonical

16. В каждой странице metadata:
    ```typescript
    alternates: {
      canonical: `https://[domain]/${locale}${pathname}`,
      languages: {
        ru: `https://[domain]/ru${pathname}`,
        en: `https://[domain]/en${pathname}`,
        'x-default': `https://[domain]/ru${pathname}`,
      }
    }
    ```
17. Sitemap должен включать все языковые версии всех страниц
18. Robots.txt без изменений (всё индексируем)

### 7. Я. Вебмастер и GSC

19. В Я. Вебмастере добавить второй язык как зеркало или отдельный регион (по обстановке)
20. В GSC добавить таргетинг по странам, если рынок ограничен (US-only английский)

## Boundaries

- **Always:** все UI-тексты через словари, hreflang на каждой странице, тексты переводит пользователь (не Claude)
- **Ask first:** перед добавлением 3-го языка (растёт сложность поддержки), перед machine-переводом контента (вредит SEO и доверию)
- **Never:** держать одинаковый контент на двух языках (дубли), переводить только часть страниц (либо всё, либо ничего)

## Done when

- next-intl настроен, структура `app/[locale]/...` работает
- Все UI-тексты в словарях, переключение языка работает
- Каждая страница есть на каждом языке
- hreflang корректен (проверить через Google Rich Results / Ahrefs Site Audit)
- Sitemap включает все локализации
- Lighthouse не упал

## Memory updates

- `decisions.md` — выбор префикса/поддомена, список локалей
- `pointers.md` — пути к словарям, LangSwitcher, конфигу next-intl
- `references.md` — кто переводит контент (заказчик / копирайтер / агентство)

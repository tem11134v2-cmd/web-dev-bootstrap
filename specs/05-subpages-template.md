# Spec 05: Шаблон подстраницы услуги

## KB files to read first

- docs/architecture.md (раздел «Шаблонизация» и «Server/Client разделение»)
- docs/content-layout.md (секции для страниц услуг)
- docs/seo.md (Schema.org Service, метаданные)
- docs/pages.md (список подстраниц, чтобы понять разнообразие)
- specs/templates/page-spec-template.md
- `components/sections/*` (созданные в спеке 04 — переиспользуем)

## Goal

Создать единый шаблон страницы услуги (`ServicePageTemplate`), который принимает данные и рендерит все секции. Одна реальная страница услуги собрана как proof of concept. На выходе — добавление новой страницы услуги = создание data-объекта + одна строка `<ServicePageTemplate data={data} />`.

## Background

В типовом проекте 5-30 страниц услуг с одинаковой структурой (hero → who → steps → benefits → comparison → faq → cta). Без шаблона = копирование 30 раз = ад правок. С шаблоном = правка в одном месте применяется ко всем.

Server Component по умолчанию (нулевой клиентский JS для статичных секций). Интерактивные части (формы, диалог консультации) — отдельно.

## Tasks

### 1. Тип данных страницы

1. Создать `components/service-page/types.ts`:
   ```typescript
   export type ServicePageData = {
     slug: string
     metaTitle: string
     metaDescription: string
     hero: { h1: string, subhead: string, badges?: string[], ctaText: string }
     who?: { title: string, items: { icon: string, title: string, desc: string }[] }
     steps?: { title: string, items: { title: string, desc: string, duration?: string }[] }
     benefits?: { title: string, items: { icon: string, title: string, desc: string }[] }
     comparison?: { title: string, rows: { feature: string, us: string, them: string }[] }
     faq?: { title: string, items: { q: string, a: string }[] }
     // ...прочие секции по необходимости
   }
   ```

### 2. Шаблон (server component)

2. Создать `components/service-page/ServicePageTemplate.tsx` — server component:
   ```tsx
   export function ServicePageTemplate({ data }: { data: ServicePageData }) {
     return (
       <>
         <PageHero data={data.hero} />
         {data.who && <Who data={data.who} />}
         {data.steps && <Steps data={data.steps} />}
         {/* ... */}
         <ServicePageForms slug={data.slug} />
       </>
     )
   }
   ```
3. Все секции — server components, кроме форм

### 3. Клиентская часть (формы)

4. Создать `components/service-page/ServicePageForms.tsx` — client component:
   - Mid-CTA форма (inline)
   - Final CTA форма (inline)
   - Кнопки «Бесплатная консультация» — open consultation dialog
   - Заглушки отправки (реальная CRM в спеке 09)

### 4. JSON-LD генерация

5. Создать `lib/schema.ts` с типизированными генераторами через `schema-dts` (установлен в спеке 02):
   ```typescript
   import type { WithContext, Service, BreadcrumbList, FAQPage } from 'schema-dts'

   export function generateServiceSchema(data: ServicePageData): WithContext<Service> {
     return {
       '@context': 'https://schema.org',
       '@type': 'Service',
       name: data.metaTitle,
       description: data.metaDescription,
       // ...
     }
   }

   export function generateBreadcrumbSchema(slug: string): WithContext<BreadcrumbList> { /* ... */ }
   export function generateFAQSchema(items: { q: string; a: string }[]): WithContext<FAQPage> { /* ... */ }
   ```
   Типизация ловит опечатки в `@type`/полях на билде (`tsc --noEmit`), а не на Yandex Validator-е уже после деплоя.
6. В шаблоне внедрить JSON-LD автоматически из `data` (не хардкод в каждом page.tsx)

### 5. Proof of concept

7. Выбрать одну услугу из `docs/pages.md` (любую, лучше типовую)
8. Создать `app/[slug]/page.tsx`:
   ```tsx
   import { ServicePageTemplate } from '@/components/service-page/ServicePageTemplate'
   import { data } from './page-data'

   export const metadata = { title: data.metaTitle, description: data.metaDescription }
   export default function Page() {
     return <ServicePageTemplate data={data} />
   }
   ```
9. Создать `app/[slug]/page-data.ts` — заполнить из `docs/content.md`
10. Открыть на localhost — проверить что страница рендерится, контент верный, формы кликабельны

### 6. Проверка качества

11. `view-source` — убедиться что весь контент в HTML (не подгружается JS)
12. Schema.org валидатор — Yandex Validator + Google Rich Results
13. Адаптив, контраст, console errors
14. `pnpm build` проходит

## Boundaries

- **Always:** все статичные секции — server components, выносить «вирусные» хуки в отдельные client-компоненты (см. lessons «viral client» в performance.md)
- **Ask first:** если страница требует уникальных секций, не подходящих под шаблон — обсудить, делаем как кастомную или расширяем шаблон
- **Never:** добавлять `"use client"` в page.tsx (только если страница реально интерактивная), хардкодить JSON-LD в page.tsx (только через генератор)

## Done when

- `ServicePageTemplate` (server) и `ServicePageForms` (client) созданы
- Тип `ServicePageData` экспортируется
- `lib/schema.ts` с генераторами JSON-LD
- Одна страница услуги собрана и работает
- view-source показывает весь контент в HTML
- Schema.org валидируется
- `pnpm build` проходит

## Memory updates

- `pointers.md` — обязательно: путь к шаблону, типу данных, генераторам JSON-LD, ServicePageForms
- `decisions.md` — структура data-объекта, что вошло в шаблон, что осталось кастомным
- `project_state.md` — done, следующая `06-subpages-rollout`

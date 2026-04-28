---
name: references
description: Внешние ID, URL, пути к ресурсам проекта. БЕЗ секретов (токены/пароли — в .env)
type: reference
---

# Внешние ресурсы и ID проекта

Указатели на внешние системы. Что есть, где лежит, как идентифицировать.
**ВАЖНО:** секреты (токены, пароли, ключи) — только в `.env`, никогда здесь.

## Инфраструктура

- **Локальная папка (Mac):** `~/projects/[project]/`
- **VPS IP:** [xxx.xxx.xxx.xxx]
- **SSH:** `ssh deploy@[ip]`
- **Папка prod на VPS:** `~/prod/[project]/`
- **Папка dev на VPS:** `~/dev/[project]/` (если настроен dev-preview)
- **PM2 процесс prod:** `[project]-prod` (порт из `~/ports.md` — обычно 30X0)
- **PM2 процесс dev:** `[project]-dev` (порт prod + 1000) — если есть preview
- **Caddy config:** `/etc/caddy/Caddyfile.d/[project].caddy`

## Домены

- **Production:** `https://[domain]`
- **Dev preview:** `https://dev.[domain]` (если настроен)
- **DNS:** [Cloudflare / прямые A-записи / регистратор]
- **SSL:** Let's Encrypt, выписан и автообновляется Caddy (за ~30 дней до истечения)

## Репозиторий

- **GitHub:** `[owner]/[repo]` (приватный)
- **Owner:** заказчик / разработчик
- **Default branch:** `main` (protected)
- **Working branch:** `dev`

## CRM

- **Система:** [AMO / Bitrix24 / HubSpot / собственная]
- **URL:** `https://[subdomain].amocrm.ru` (или вебхук-URL)
- **Контакт ответственного:** [имя, telegram]
- **Маппинг полей:** см. `docs/forms-and-crm.md` или `lib/crm.ts`

## Аналитика

- **Яндекс Метрика:** счётчик `XXXXXXXX`, цели: [список]
- **Яндекс Вебмастер:** подтверждён, sitemap отправлен
- **Google Analytics:** `GA-XXXXXXX`
- **Google Search Console:** подтверждён, sitemap отправлен

## Контент и медиа

- **Бриф:** `docs/spec.md` (заполнен на этапе 00-brief)
- **Тексты:** `docs/content.md` или `content/services/*.mdx`
- **Карта страниц:** `docs/pages.md`
- **Изображения:** `public/images/`
- **Шрифты:** `public/fonts/` или `next/font` (см. `app/layout.tsx`)
- **Логотип:** `public/logo.svg`
- **OG-картинки:** `public/og/`

## Юридические тексты

- **Политика конфиденциальности:** `app/privacy/page.tsx` (текст вставлен из генератора)
- **Согласие на ПДн:** компонент `components/legal/PdnConsent.tsx`
- **Cookie-баннер:** компонент `components/legal/CookieBanner.tsx`

## Прочее

- **Telegram чат с заказчиком:** [@username или ссылка]
- **Google Диск с медиа:** [URL папки]
- **Figma макет** (если есть): [URL]

---
name: references
description: Внешние ID, URL, пути к ресурсам проекта. БЕЗ секретов (токены/пароли — в .env)
type: reference
---

# Внешние ресурсы и ID проекта

Указатели на внешние системы. Что есть, где лежит, как идентифицировать.
**ВАЖНО:** секреты (токены, пароли, ключи) — только в `.env`, никогда здесь.

## Инфраструктура

- **VPS IP:** [xxx.xxx.xxx.xxx]
- **SSH:** `ssh deploy@[ip]`
- **Папка prod:** `~/prod/[project]/` (или `/var/www/[project]/` для схемы A)
- **Папка dev:** `~/dev/[project]/` (только для схемы B)
- **PM2 процесс prod:** `[project]-prod` (порт 3000)
- **PM2 процесс dev:** `[project]-dev` (порт 4000) — только B
- **Nginx config:** `/etc/nginx/sites-available/[project]`

## Домены

- **Production:** `https://[domain]`
- **Dev preview:** `https://dev.[domain]` (только B)
- **DNS:** [Cloudflare / прямые A-записи / регистратор]
- **SSL:** Let's Encrypt, auto-renew через certbot

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

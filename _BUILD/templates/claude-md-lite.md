<!--
Лайт-профиль: когда полный bootstrap избыточен (лендинг 1-3 страницы).
Полный профиль — _BUILD/claude-md-template.md.
Скопируй как CLAUDE.md в корень проекта, заполни [плейсхолдеры], удали этот комментарий.
-->

# Project: [Name]

[Одна строка: что за сайт, для кого, главная цель. Пример: «aksioma.pro — лендинг бухгалтерской фирмы, цель — заявки на консультацию».]

## Stack

Next.js 16 (App Router) + Tailwind v4 + shadcn/ui + TypeScript. Biome, pnpm.
`output: 'standalone'`, `compress: false` (gzip отдаёт Caddy). Форма → Server Action `submitLead` → email-sink (SMTP), fallback-лиды в `LEADS_DIR`.
Deploy: push в `main` → GitHub Actions → tar.gz → VPS (PM2 + Caddy).

## Истина дизайна

- Токены — только в `@theme` в `app/globals.css` (цвета OKLCH, шрифты, радиусы). Не хардкодить значения в компонентах.
- **Тексты в `lib/content.ts` согласованы с заказчиком — НЕ переписывать.** Правки текста — только по явной просьбе, точечно.
- Примитивы — shadcn/ui; секции — свои композиции. Данных от клиента нет → блок скрыт show-флагом, данные не выдумываются.

## Rules

- Plan mode перед кодом; коммит после каждой завершённой подзадачи (английские сообщения).
- После каждой правки — проверка встроенным браузером: 375 / 768 / 1280 + `read_console_messages {onlyErrors: true}` (ноль ошибок).
- Server Components по умолчанию; `"use client"` только для state/effects.
- `.env*` не коммитить. Секреты прода — GitHub Environment `production`, секрет `PROD_ENV_FILE`.

## Deploy runbook (5 шагов)

1. `pnpm typecheck && pnpm lint && pnpm build` локально — зелёные.
2. Push в `main` → Actions собирает standalone, кладёт в `releases/<sha>/` на VPS.
3. Workflow сам: проверит архив (`gzip -t`) и `server.js`, переключит симлинк `current/`.
4. PM2: **`pm2 delete` затем `start`** (не restart — кэширует resolved-путь симлинка); `PORT=... HOSTNAME=127.0.0.1` в env команды.
5. Проверка: `curl -I https://{domain}/` → 200. Не 200 — workflow уже откатил симлинк; смотри `gh run view --log-failed`.

Откат руками: `scripts/rollback.sh` (симлинк на предыдущий релиз + pm2 delete/start).

## TODO / Blockers (мини CLIENT-TODO)

<!-- Формат строки: - [ ] что нужно — зачем — блокирует что — статус/дата -->

- [ ] [Доступ/материал от заказчика] — [зачем] — [что блокирует] — [статус]

## Память

Журнал сессий — прямо здесь или в `.claude/memory/project_state.md` (если завёл). Понял, что нужно что-то от заказчика → сразу строка в TODO выше.

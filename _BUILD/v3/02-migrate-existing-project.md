# ТЗ-2: Миграция существующего проекта v2.x → v3.0

**Это промт-инструкция для одной Claude-сессии в папке КЛИЕНТСКОГО проекта** (не в bootstrap-репо). Запускается отдельно на каждый старый проект, который надо обновить под стандарты v3.0.

---

## Кому, где, как

- **Где запускать:** в папке живого проекта (например, `~/projects/migrator`, `~/projects/clinic-landing`)
- **Кто запускает:** разработчик через Claude Code Desktop, **в новой сессии** на конкретный проект
- **Сколько раз:** один раз на каждый старый проект (повторяется столько раз, сколько у тебя проектов на v2.x)
- **Сколько времени:** 30–90 минут на проект, зависит от размера и того, насколько проект отклонился от bootstrap

## Стартовый промт сессии

В папке живого проекта в Claude-чате:

```
Прочитай файл `~/ClaudeCode/web-dev-bootstrap/_BUILD/v3/02-migrate-existing-project.md`
и выполни его на этом проекте. Сначала покажи план миграции с учётом текущей версии,
жди подтверждения перед любыми правками.
```

---

## Что делает эта миграция

Приводит существующий проект под стандарты bootstrap v3.0:
- npm → pnpm
- nvm → mise (если используется)
- ESLint+Prettier → Biome
- `next-mdx-remote` → Content Collections (только если был блог)
- `/api/lead` Route Handler → Server Action
- Добавляет Cloudflare Turnstile в формы (если ещё нет)
- Переписывает GitHub Actions workflow на push-based (build на runner + rsync + симлинки)
- Обновляет `.claude/hooks/`, `.claude/memory/INDEX.md`, `CLAUDE.md`, `.gitignore`
- Включает `output: 'standalone'` в `next.config.ts`
- Добавляет slash-команды `/handoff`, `/resume`, `/catchup`
- (Опционально) Caddy на VPS — это **отдельная** работа, см. раздел в конце

## Что миграция НЕ делает

- ❌ Не трогает контент сайта (тексты, страницы, изображения)
- ❌ Не меняет дизайн-систему (цвета, шрифты, секции)
- ❌ Не переписывает бизнес-логику (CRM-интеграции, формы, специфика)
- ❌ Не заменяет Zod (остаётся)
- ❌ Не заменяет shadcn/ui компоненты
- ❌ Не трогает данные `data/leads.json` или `public/uploads/`

---

## Этап 1: Pre-flight проверки

Прежде чем что-то менять — собери информацию.

### 1.1. Определить текущую версию проекта

```bash
# Если есть _BUILD/changelog.md — посмотреть последний тег:
grep -m1 -E "^## v[0-9]" _BUILD/changelog.md 2>/dev/null

# Если нет — определить по косвенным признакам:
# - есть ли .claude/hooks/ (с какого момента ввели хуки)
# - есть ли _BUILD/ (с v2.0)
# - есть ли scripts/bootstrap-vps.sh (с v2.1.1)
# - какая версия в README.md (если указана)
```

Возможные исходные точки:
- **v2.0.x** — есть `_BUILD/`, нет `.claude/hooks/`, нет SSH-разрешения для Claude
- **v2.1.x** — есть `.claude/hooks/`, SSH разрешён, single deploy scheme
- **v2.2.x** — есть `.claude/settings.json` (а не hooks.json), Automation rules в CLAUDE.md
- **v2.2.2** — после ТЗ-1 Phase 0 hotfixes (если был применён)

Зафиксируй текущую версию в начале session log. От неё зависит объём миграции.

### 1.2. Проверить состояние проекта

```bash
git status                  # должно быть clean (если есть uncommitted — спросить пользователя)
git log --oneline -5        # последние коммиты
git remote -v               # проверить origin
gh auth status              # gh-аккаунт совпадает с owner репо?
```

Если что-то не так (например, есть несохранённые изменения, или gh mismatch) — **остановись и спроси пользователя**, не продолжай миграцию вслепую.

### 1.3. Backup tag

**Обязательный шаг** перед любыми правками:

```bash
git tag pre-v3-migration-$(date +%Y%m%d)
git push origin pre-v3-migration-$(date +%Y%m%d)
```

Это позволит вернуться к до-миграционному состоянию одной командой `git reset --hard pre-v3-migration-YYYYMMDD`.

### 1.4. Проверить размер миграции

Грепом понять, что в проекте есть:

```bash
# Есть ли блог (нужна Content Collections миграция)?
test -d content/blog && echo "BLOG: yes" || echo "BLOG: no"

# Есть ли формы с Turnstile уже?
grep -l "turnstile" --include="*.tsx" --include="*.ts" -r . 2>/dev/null

# Есть ли deploy_key упоминания (значит pull-based)?
grep -l "deploy_key" --include="*.yml" --include="*.md" -r .github/ scripts/ 2>/dev/null

# Какой package manager сейчас?
test -f pnpm-lock.yaml && echo "pnpm" || (test -f package-lock.json && echo "npm" || echo "?")

# Есть ли уже Biome?
test -f biome.json && echo "Biome: yes" || echo "Biome: no"
```

По результатам определи персональный план миграции для этого проекта (какие шаги пропустить, какие сделать). **Покажи план пользователю**, жди подтверждения.

---

## Этап 2: Tooling-миграция (низкий риск)

### 2.1. mise + .tool-versions

Если у пользователя ещё не стоит mise — рекомендуй установить (`brew install mise`), но не блокируй миграцию из-за этого. Если стоит:

- Удалить `.nvmrc` если есть
- Создать `.tool-versions`:
  ```
  node 22
  pnpm latest
  ```
- Запустить `mise install` (если запросит — подтвердить установку версий)

### 2.2. Перейти с npm на pnpm

```bash
# 1. Удалить старый lockfile и node_modules
rm -rf node_modules package-lock.json

# 2. Поставить pnpm если ещё нет
which pnpm || npm install -g pnpm

# 3. Установить зависимости через pnpm (создаст pnpm-lock.yaml)
pnpm install

# 4. Проверить что dev запускается
pnpm dev
# открыть localhost:3000 — рендерится? консоль чиста?
# Ctrl+C
```

В `package.json` обновить scripts:
```json
{
  "scripts": {
    "dev": "next dev -p 3000 --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "biome check",
    "format": "biome check --write",
    "typecheck": "tsc --noEmit"
  }
}
```
(уберёшь `npm run compress` если был — Next 16 сам оптимизирует через `next/image`)

В `.gitignore` убедиться что есть:
```
node_modules/
.next/
out/
.env*
!.env.example
data/leads.json
*.log
```

Закоммитить отдельно: `chore: migrate to pnpm + mise`.

### 2.3. Biome вместо ESLint + Prettier

```bash
# 1. Удалить eslint и prettier пакеты
pnpm remove eslint eslint-config-next prettier prettier-plugin-tailwindcss \
  @typescript-eslint/parser @typescript-eslint/eslint-plugin 2>/dev/null

# 2. Установить Biome
pnpm add -D --save-exact @biomejs/biome

# 3. Инициализировать
pnpm exec biome init
```

Создать/перезаписать `biome.json`:
```json
{
  "$schema": "https://biomejs.dev/schemas/2.x.x/schema.json",
  "files": {
    "ignore": ["node_modules", ".next", "out", "dist", "public/**/*.js", "content-collections/**"]
  },
  "linter": {
    "enabled": true,
    "rules": { "recommended": true, "a11y": { "recommended": true } }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "javascript": {
    "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" }
  }
}
```

Удалить файлы:
```bash
rm -f .eslintrc.* .prettierrc* .prettierignore
```

Прогнать форматтер один раз по проекту (это будет большой коммит):
```bash
pnpm format
git add -A
git commit -m "chore: migrate ESLint+Prettier to Biome"
```

⚠️ Прежде чем коммитить — убедись, что форматтер не сломал файлы (особенно MDX). Открой dev — рендерится?

### 2.4. Обновить `.claude/hooks/format.sh`

Заменить вызов prettier на Biome:
```bash
#!/usr/bin/env bash
file=$(jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.mdx|*.css)
    ;;
  *)
    exit 0
    ;;
esac

root="$(cd "$(dirname "$0")/../.." && pwd)"
[ ! -f "$root/package.json" ] && exit 0

cd "$root" || exit 0
if [ -x "node_modules/.bin/biome" ]; then
  node_modules/.bin/biome check --write --no-errors-on-unmatched "$file" 2>/dev/null || true
fi

exit 0
```

### 2.5. Расширить `.claude/hooks/guard-rm.sh`

Покрыть `rm -rf .`, `rm -rf ./`, `git push -f` (короткая форма):
```bash
#!/usr/bin/env bash
cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# Текущая папка, домашка, рут, glob
if echo "$cmd" | grep -Eq 'rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+)?(-[a-zA-Z]*[fF][a-zA-Z]*[[:space:]]+)?(/|~|\$HOME|\*|\.|\.\/)([[:space:]]|$|/)'; then
  echo "BLOCKED by guard-rm: refusing destructive rm on /, ~, \$HOME, ., ./, or glob." >&2
  exit 2
fi

# git push --force OR -f
if echo "$cmd" | grep -Eq '(^|[;&|][[:space:]]*)git[[:space:]]+push[[:space:]]+[^"'"'"']*(--force|[[:space:]]-f([[:space:]]|$))'; then
  echo "BLOCKED by guard-rm: refusing git push --force/-f (use regular push)." >&2
  exit 2
fi

exit 0
```

Закоммитить вместе: `chore: harden guard-rm hook`.

---

## Этап 3: Кодовая миграция (средний риск)

### 3.1. `output: 'standalone'` в `next.config.ts`

Открыть `next.config.ts` и добавить:
```typescript
const nextConfig = {
  output: 'standalone',     // ← НОВОЕ
  compress: false,
  reactStrictMode: true,
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
    minimumCacheTTL: 60 * 60 * 24 * 365,
  },
  experimental: {
    ppr: 'incremental',     // ← НОВОЕ (опционально)
  },
}
```

Проверить что билд проходит:
```bash
pnpm build
# в .next/standalone/ должна появиться папка с server.js
```

Закоммитить: `chore: enable standalone output`.

### 3.2. Server Action вместо `/api/lead`

Если в проекте есть `app/api/lead/route.ts` — мигрируем на Server Action.

Создать `app/actions/submit-lead.ts`:
```typescript
'use server'
import { z } from 'zod'
import { headers } from 'next/headers'
import { sendToCRM } from '@/lib/crm'
import { appendFallback } from '@/lib/fallback'
import { rateLimit } from '@/lib/rate-limit'

const schema = z.object({
  name: z.string().min(2),
  phone: z.string().min(10),
  email: z.string().email().optional(),
  message: z.string().optional(),
  source: z.string(),
  consent: z.literal('true'),       // FormData приносит строку, не bool
  turnstileToken: z.string().min(10),
})

export async function submitLead(_prev: unknown, formData: FormData) {
  const ip = (await headers()).get('x-forwarded-for') ?? 'unknown'
  if (!rateLimit(ip, 1, 10_000)) {
    return { error: 'Слишком много запросов. Подождите минуту.' }
  }

  const parsed = schema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { error: 'Проверьте поля формы' }

  // Turnstile
  const verify = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      secret: process.env.TURNSTILE_SECRET_KEY!,
      response: parsed.data.turnstileToken,
      remoteip: ip,
    }),
  })
  const result = await verify.json()
  if (!result.success) return { error: 'Защита от спама не пройдена' }

  try {
    await sendToCRM(parsed.data)
  } catch (err) {
    console.error('CRM error', err)
    await appendFallback(parsed.data)
  }
  return { success: true }
}
```

В клиентских формах (`ConsultationDialog.tsx`, `LeadForm.tsx`) — заменить `fetch('/api/lead', ...)` на:
```typescript
'use client'
import { useActionState } from 'react'
import { submitLead } from '@/app/actions/submit-lead'

const [state, formAction, isPending] = useActionState(submitLead, null)
// ...
<form action={formAction}>
  {/* ... поля ... */}
  <button type="submit" disabled={isPending}>
    {isPending ? 'Отправка...' : 'Отправить'}
  </button>
</form>

{state?.error && <p className="text-red-500">{state.error}</p>}
{state?.success && <p className="text-green-500">Заявка отправлена!</p>}
```

После успешной миграции — удалить `app/api/lead/route.ts`:
```bash
rm app/api/lead/route.ts
```

Проверить локально: открыть форму, отправить → лид должен дойти в CRM (или fallback в `data/leads.json`).

Закоммитить: `refactor: migrate /api/lead to Server Action with Turnstile`.

### 3.3. Cloudflare Turnstile

Если в проекте Turnstile ещё не подключён:

1. Получить site-key и secret-key (Cloudflare → Turnstile → Add Site)
2. Установить:
   ```bash
   pnpm add @marsidev/react-turnstile
   ```
3. В `.env.local` (не коммитить!):
   ```
   NEXT_PUBLIC_TURNSTILE_SITE_KEY=0x4...
   TURNSTILE_SECRET_KEY=0x4...
   ```
4. В формах добавить компонент:
   ```typescript
   import { Turnstile } from '@marsidev/react-turnstile'

   <Turnstile
     siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY!}
     options={{ theme: 'light', size: 'flexible' }}
     onSuccess={(token) => setTurnstileToken(token)}
   />
   <input type="hidden" name="turnstileToken" value={turnstileToken ?? ''} />
   ```

Закоммитить: `feat: add Cloudflare Turnstile to forms`.

### 3.4. Content Collections (только если есть блог)

Пропусти этот шаг, если `content/blog/` не существует.

```bash
pnpm add content-collections @content-collections/core @content-collections/mdx @content-collections/next
pnpm remove next-mdx-remote 2>/dev/null
```

Создать `content-collections.ts` в корне (см. шаблон в `~/ClaudeCode/web-dev-bootstrap/specs/07-blog-optional.md` после ТЗ-1, или собственный по доке https://www.content-collections.dev/).

Обновить `next.config.ts`:
```typescript
import { withContentCollections } from '@content-collections/next'

const nextConfig = { /* ... */ }
export default withContentCollections(nextConfig)
```

Заменить старый `lib/blog.ts` на импорт из `content-collections`:
```typescript
import { allPosts } from 'content-collections'
// allPosts уже типизирован, .sort, .filter работают
```

В `app/blog/page.tsx` и `app/blog/[slug]/page.tsx` — заменить ручной `gray-matter`+`fs` на `allPosts`.

Проверить локально: блог открывается, статья рендерится с MDX-компонентами.

Закоммитить: `refactor: migrate blog to Content Collections`.

---

## Этап 4: Deploy-миграция (высокий риск)

⚠️ **Это самая чувствительная часть.** После неё деплой работает по-новому. Рекомендую: **сначала закоммитить всё предыдущее в `dev` и протестировать через текущий (старый) deploy один раз** — убедиться, что обновления Этапа 2-3 не сломали проект. Только потом переходить к Этапу 4.

### 4.1. Подготовить новые секреты GitHub

В **GitHub → Settings → Secrets and variables → Actions**:

**Удалить старые** (если были):
- `DEPLOY_SSH_KEY` (старый из `~/.ssh/deploy_key` с VPS)

**Добавить новые:**
- `SSH_PRIVATE_KEY` — приватный ключ из Mac (`~/.ssh/{site}-deploy`, см. ниже как сгенерировать)
- `SSH_HOST` — IP VPS (если ещё не было)
- `SSH_USER` — `deploy`
- `SSH_PORT` — `2222` (или `22`)
- `PROD_ENV_FILE` — содержимое локального `.env.production` целиком (multiline)
- `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `NEXT_PUBLIC_YM_ID`, `NEXT_PUBLIC_GA_ID` — публичные ID для билда

**Variables:**
- `SITE_NAME` — kebab-case имя сайта (то же, что в `package.json#name` и в PM2)

Сгенерировать новый SSH-ключ (на Mac):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy -N "" -C "{site}-deploy"
# Публичную часть положить в authorized_keys deploy-юзера на VPS:
cat ~/.ssh/{site}-deploy.pub | ssh deploy@{vps-ip} "tee -a ~/.ssh/authorized_keys"
# Приватную часть загрузить в GitHub Secret:
gh secret set SSH_PRIVATE_KEY < ~/.ssh/{site}-deploy
# (опционально) удалить приватную часть с Mac:
# rm ~/.ssh/{site}-deploy   ← только если уверен, что ключ загружен в GitHub
```

### 4.2. Подготовить структуру `releases/` на VPS

Зайти на VPS и подготовить:
```bash
ssh deploy@{vps-ip}
cd ~/prod/{site}/

# Сделать backup текущей рабочей версии
mkdir -p releases
git rev-parse HEAD > /tmp/current-sha
cp -r . releases/$(cat /tmp/current-sha)/ 2>/dev/null || true

# Создать симлинк current на текущую версию
ln -sfn releases/$(cat /tmp/current-sha) current

# Перенаправить PM2 на current/
pm2 stop {site}-prod
pm2 delete {site}-prod
pm2 start current/server.js --name {site}-prod --update-env
pm2 save
```

⚠️ Если `server.js` не существует (потому что `output: 'standalone'` ещё не включен в проекте на VPS) — пропусти, после первого нового деплоя через push-based он появится автоматически.

### 4.3. Удалить старый `deploy_key` с VPS

```bash
ssh deploy@{vps-ip}
rm -f ~/.ssh/deploy_key ~/.ssh/deploy_key.pub
# Из ~/.ssh/authorized_keys удалить публичную часть deploy_key (если она там была)
nano ~/.ssh/authorized_keys
# Из GitHub → Settings → Deploy keys удалить старый (если был добавлен)
```

### 4.4. Заменить `.github/workflows/deploy-prod.yml`

Скопировать новый шаблон workflow из `~/ClaudeCode/web-dev-bootstrap/_BUILD/v3/01-bootstrap-refactor.md` (раздел Phase 5, Tasks 2) или из обновлённого bootstrap-репо (`specs/01b-server-handoff.md` после ТЗ-1).

Подставить специфику этого сайта:
- `vars.SITE_NAME` = имя проекта
- Прод-порт PM2 (`{site}-prod`) — без изменений

Аналогично для `deploy-dev.yml`, если был.

### 4.5. Переписать локальный `scripts/rollback.sh`

Заменить старую логику (git reset + npm ci + build) на симлинк-switch (см. шаблон в bootstrap `_BUILD/v3/01-bootstrap-refactor.md` Phase 5, Tasks 5).

### 4.6. Тестовый деплой

```bash
# 1. Закоммитить всё в dev
git add -A
git commit -m "chore: migrate deploy to push-based v3 schema"
git push origin dev

# 2. Открыть GitHub → Actions → следить за пробежкой workflow
# 3. После завершения — проверить: симлинк current переключился, PM2 рестартанул, сайт открывается
ssh deploy@{vps-ip} "ls -la /home/deploy/prod/{site}/current && pm2 ls"

# 4. Открыть https://{domain}/ — рендерится? формы работают?
```

Если всё ОК — мерджить в main (через PR), новый деплой пойдёт уже на прод.

Если упало — откат:
```bash
ssh deploy@{vps-ip}
cd ~/prod/{site}
ln -sfn releases/<previous-sha> current
pm2 reload {site}-prod --update-env
```
И сообщить ошибку — поправим в новой итерации.

---

## Этап 5: `.claude/` обновления и память

### 5.1. Создать slash-команды

Скопировать из bootstrap (после ТЗ-1):
```bash
mkdir -p .claude/commands
cp ~/ClaudeCode/web-dev-bootstrap/.claude/commands/handoff.md .claude/commands/
cp ~/ClaudeCode/web-dev-bootstrap/.claude/commands/resume.md .claude/commands/
cp ~/ClaudeCode/web-dev-bootstrap/.claude/commands/catchup.md .claude/commands/
```

### 5.2. Обновить `CLAUDE.md`

Сравнить текущий `CLAUDE.md` с актуальным `~/ClaudeCode/web-dev-bootstrap/_BUILD/claude-md-template.md`. Добавить отсутствующие секции:
- `## Multi-Claude protocol` (новая)
- Обновлённый `## Stack` (pnpm, mise, Biome, schema-dts)
- Обновлённый `## Commands` (`pnpm` вместо `npm`, без `compress`)
- Обновлённые KB pointers если что-то менялось

Не трогать project-specific секции (`# Project: [Name]`, описание проекта, project-specific правила).

### 5.3. Расширить `.claude/memory/project_state.md`

Привести к новой структуре с разделом «Session log» (см. шаблон в `~/ClaudeCode/web-dev-bootstrap/.claude/memory/project_state.md` после ТЗ-1).

Добавить запись о миграции:
```markdown
### Session [YYYY-MM-DD] — Migration to v3.0

**Done in this session:**
- Migrated from v2.x to v3.0 stack
- pnpm + mise + Biome + Content Collections + Server Actions + Turnstile + push-based deploy
- New SSH key {site}-deploy generated and uploaded to GitHub Secrets
- VPS: releases/ structure created, symlink current activated
- Removed: deploy_key from VPS, ESLint, Prettier, /api/lead Route Handler

**Open at handoff:**
- (если что-то не доделано — записать)

**Resume hint:** Проект на v3.0. Дальнейшие правки — через спеку 13-extend-site как обычно.
```

### 5.4. Обновить `.claude/memory/INDEX.md` (если есть)

Сверить с актуальным шаблоном из bootstrap. Обычно меняется мало, но проверить полезно.

---

## Этап 6: Caddy на VPS (опционально)

Если хочешь перевести VPS с nginx на Caddy:

⚠️ Это **общая инфраструктура** — затрагивает все сайты, живущие на этом VPS. Делать только когда все сайты на VPS уже мигрированы на v3 или готовы к миграции.

Шаги:
1. Установить Caddy на VPS (см. https://caddyserver.com/docs/install)
2. Сконвертировать nginx-конфиги в Caddyfile (по одному файлу на сайт в `/etc/caddy/Caddyfile.d/`). Шаблон — в `~/ClaudeCode/web-dev-bootstrap/docs/server-add-site.md` после ТЗ-1.
3. `caddy validate --config /etc/caddy/Caddyfile`
4. `systemctl stop nginx; systemctl disable nginx; systemctl start caddy`
5. Проверить, что все сайты на VPS открываются с HTTPS (Caddy сам получит сертификаты при первом запросе на каждый домен).

Если что-то пошло не так — `systemctl stop caddy; systemctl start nginx` обратно. Caddy и nginx на одних портах (80, 443), оба сразу не запустишь.

---

## Done when

- В `package.json` `pnpm` команды, нет упоминаний `npm run`
- `pnpm-lock.yaml` существует, `package-lock.json` удалён
- `biome.json` существует, `.eslintrc.*` и `.prettierrc*` удалены
- `next.config.ts` содержит `output: 'standalone'`
- `app/api/lead/route.ts` удалён, `app/actions/submit-lead.ts` существует
- Формы используют `useActionState` и Server Action
- Cloudflare Turnstile подключён (если ранее не было)
- Если был блог — он на Content Collections
- `.github/workflows/deploy-prod.yml` использует push-based схему (build на runner, rsync, симлинк)
- `scripts/rollback.sh` переписан под симлинк-switch
- На VPS: структура `releases/<sha>/` + симлинк `current`, PM2 запущен из `current/server.js`
- `.claude/commands/handoff.md`, `resume.md`, `catchup.md` существуют
- `.claude/hooks/format.sh` использует Biome
- `.claude/hooks/guard-rm.sh` расширен (rm -rf ., git push -f)
- `.claude/memory/project_state.md` имеет запись о миграции
- `CLAUDE.md` имеет секцию `Multi-Claude protocol`
- Тестовый деплой через push-based прошёл, сайт работает на проде
- `git tag v3-migrated-$(date +%Y%m%d)` создан и запушен
- В `.claude/memory/decisions.md` запись о миграции с **Why:** (для исторической памяти)

---

## Rollback всей миграции

Если миграция пошла катастрофически и нужно откатить весь проект:

```bash
# 1. На Mac:
git fetch origin
git checkout pre-v3-migration-YYYYMMDD     # тег из шага 1.3
git push -f origin main                    # ОСТОРОЖНО: только если уверен

# 2. На VPS — вернуть старую версию через симлинк (если успел переключить)
ssh deploy@{vps-ip}
cd ~/prod/{site}
ls -1tr releases/    # найти sha до миграции (если был сохранён в releases/)
ln -sfn releases/<old-sha> current
pm2 reload {site}-prod --update-env

# Если releases/ ещё не создан — вручную восстановить из бэкапа или git checkout старого коммита:
git fetch origin
git checkout pre-v3-migration-YYYYMMDD
npm install                                # ВНИМАНИЕ: npm, не pnpm — старая версия
npm run build
pm2 restart {site}-prod --update-env

# 3. На GitHub — вернуть старые секреты (DEPLOY_SSH_KEY и т.д.)
```

После отката — сообщи ошибку, разберёмся в чём конкретно было дело.

---

## Известные грабли

### «Build на runner падает с OOM»
- GitHub Actions runner имеет 7 GB RAM. Если Next.js билд сожрал больше — это очень тяжёлый проект. Решение: `NODE_OPTIONS=--max-old-space-size=6144` в env билда.

### «rsync переносит .env, но он попадает в Git»
- Никогда не коммитить `.env`. В Etap 4.1 секрет `PROD_ENV_FILE` приходит в момент деплоя через workflow и записывается на VPS в `releases/<sha>/.env`. На Mac в репо — только `.env.example`.

### «PM2 не находит server.js в current/»
- `output: 'standalone'` создаёт `.next/standalone/server.js`. После rsync на VPS должно быть `releases/<sha>/server.js`. Если нет — проверь, что в workflow шаг «Pack standalone» правильно копирует.

### «Симлинк current не переключается»
- Проверь права: `ls -la /home/deploy/prod/{site}/`. Симлинк должен быть owned `deploy:deploy`. Если nobody — `chown -h deploy:deploy current`.

### «PSI mobile упал после миграции на 5-10 баллов»
- Проверь, что `output: 'standalone'` не убрал какие-то custom-файлы из билда (например, public файлы, которые должны были скопироваться). Сравни `.next/static/` до и после.

### «Server Action возвращает HTML вместо JSON»
- В Next.js 16 Server Actions работают через `<form action={...}>`, не через fetch. Если в форме не используешь `action={formAction}` — получишь регрессию. Перепроверь.

### «Turnstile widget не показывается»
- Проверь, что `NEXT_PUBLIC_TURNSTILE_SITE_KEY` установлен (не только в `.env`, но и в GitHub Secrets для билда).

### «Старые ссылки на /api/lead 404»
- Если форма на сайте кешируется (через CDN/Cloudflare) — пользователь может попасть на старую версию JS, который ещё шлёт fetch на `/api/lead`. Решение: purge cache в Cloudflare после деплоя миграции.

---

## Финальный handoff после миграции

1. Запиши в `.claude/memory/decisions.md`:
   ```markdown
   ### [YYYY-MM-DD] Migration to bootstrap v3.0

   **Что:** Проект мигрирован с v2.x на v3.0 (Caddy если применимо, push-based deploy, Server Actions, Biome, pnpm, mise, Turnstile, Content Collections).

   **Why:** Унификация со стандартом bootstrap v3.0 для упрощения поддержки. Push-based deploy убирает риск OOM на VPS при билде, атомарный rollback через симлинк.
   ```

2. Сообщи пользователю:
   ```
   Миграция завершена. Проект на v3.0.
   Тестовый деплой: ✅ работает.
   Дальнейшие правки контента/добавления страниц — через спеку 13-extend-site.md как обычно.
   ```

3. Если есть ещё неперемигрированные проекты — повтори процесс в новой Claude-сессии в их папках.

---

## Когда НЕ мигрировать

Если проект:
- **уже не активный** (заказчик не платит за поддержку, сайт работает «как есть») — оставь на v2.x. Миграция ради миграции бессмысленна.
- **критически нагружен** прямо сейчас (Чёрная пятница, рекламная кампания) — отложи на спокойный период.
- **на cobranded-инфре** (нестандартный VPS, нестандартный CRM, кастомные nginx-вещи) — каждый шаг сверяй вдвойне или вообще откажись от Этапа 4 (deploy), оставив только tooling-миграцию.

Старые проекты на v2.x могут жить **параллельно** с v3-проектами неограниченно. Bootstrap v3 не требует, чтобы все проекты были v3.

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
Прочитай файл ТЗ миграции по URL:
https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/v3.0/_BUILD/v3/02-migrate-existing-project.md

Затем выполни его на этом проекте. Сначала покажи план миграции с учётом текущей
версии проекта, жди подтверждения перед любыми правками.
```

Альтернативный промт (если bootstrap уже клонирован локально):

```
Прочитай файл `~/ClaudeCode/web-dev-bootstrap/_BUILD/v3/02-migrate-existing-project.md`
и выполни его на этом проекте. Сначала покажи план миграции, жди подтверждения.
```

Оба варианта эквивалентны — bootstrap-репо public, raw URL и локальный путь дают тот же контент.

---

## Helper для копирования файлов из bootstrap'а

ТЗ-2 в нескольких местах копирует канонические файлы из bootstrap'а (`biome.json.example`, hooks, slash-команды, deploy-templates). Чтобы это работало **с любой машины** (с локальным bootstrap'ом и без), в начале миграции Claude должен определить helper-функцию `BOOTSTRAP_GET` и использовать её во всех `cp`-командах ниже.

**Положи этот блок в `~/.bootstrap-helper.sh` на время миграции:**

```bash
#!/usr/bin/env bash
# Универсальный getter файла из bootstrap-репо.
# Использует локальный clone если есть, иначе скачивает с GitHub raw.

BOOTSTRAP_LOCAL="${BOOTSTRAP_LOCAL:-$HOME/ClaudeCode/web-dev-bootstrap}"
BOOTSTRAP_TAG="${BOOTSTRAP_TAG:-v3.0}"
BOOTSTRAP_RAW="https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/${BOOTSTRAP_TAG}"

BOOTSTRAP_GET() {
  local src="$1"      # путь относительно корня bootstrap-репо
  local dst="$2"      # куда положить (относительно cwd текущего проекта)

  if [ -f "$BOOTSTRAP_LOCAL/$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$BOOTSTRAP_LOCAL/$src" "$dst"
    echo "✓ $dst (from local clone)"
  else
    mkdir -p "$(dirname "$dst")"
    if curl -fsSL "$BOOTSTRAP_RAW/$src" -o "$dst"; then
      echo "✓ $dst (fetched from $BOOTSTRAP_RAW/$src)"
    else
      echo "✗ FAILED: $dst (couldn't fetch from $BOOTSTRAP_RAW/$src or local $BOOTSTRAP_LOCAL/$src)" >&2
      return 1
    fi
  fi
}

export -f BOOTSTRAP_GET
export BOOTSTRAP_LOCAL BOOTSTRAP_TAG BOOTSTRAP_RAW
```

Затем в каждой Claude-сессии миграции (или прописано в session-init):

```bash
source ~/.bootstrap-helper.sh
```

**Примеры использования** (вместо прямого `cp ~/ClaudeCode/web-dev-bootstrap/...` ниже в ТЗ-2 используй `BOOTSTRAP_GET`):

```bash
BOOTSTRAP_GET biome.json.example biome.json
BOOTSTRAP_GET .claude/hooks/format.sh .claude/hooks/format.sh
BOOTSTRAP_GET .claude/hooks/guard-rm.sh .claude/hooks/guard-rm.sh
BOOTSTRAP_GET .claude/hooks/stop-reminder.sh .claude/hooks/stop-reminder.sh
BOOTSTRAP_GET .claude/commands/handoff.md .claude/commands/handoff.md
BOOTSTRAP_GET .claude/commands/resume.md .claude/commands/resume.md
BOOTSTRAP_GET .claude/commands/catchup.md .claude/commands/catchup.md
BOOTSTRAP_GET _BUILD/v3/templates/deploy-prod.yml.example .github/workflows/deploy-prod.yml
BOOTSTRAP_GET scripts/rollback.sh scripts/rollback.sh && chmod +x scripts/rollback.sh
```

`BOOTSTRAP_TAG=v3.0` означает: миграция всегда использует **зафиксированную версию** v3.0 bootstrap'а, даже если в `main` появятся правки. Это **намеренно** — чтобы поведение миграции было воспроизводимо. Если нужна более свежая версия (например, в bootstrap'е появился v3.1 с фиксами): `export BOOTSTRAP_TAG=v3.1` перед запуском миграции.

### Про текстовые ссылки на файлы bootstrap'а в этом ТЗ

Во многих местах ниже встречаются формулировки вроде «см. шаблон в `~/ClaudeCode/web-dev-bootstrap/<path>`» — это **референс на файл в bootstrap-репо**, не команда. Если у тебя bootstrap клонирован локально — открывай его по этому пути. Если нет — открывай тот же файл на GitHub: `https://github.com/tem11134v2-cmd/web-dev-bootstrap/blob/v3.0/<path>`. Содержимое идентично.

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

### 1.3. Backup tag + страховка несохранённого

**Обязательный шаг** перед любыми правками:

```bash
# Если есть uncommitted-изменения — сначала сохранить их в stash, чтобы не потерять при reset
if ! git diff --quiet || ! git diff --cached --quiet; then
  git stash push -u -m "pre-v3-migration-stash-$(date +%Y%m%d)"
  echo "⚠ Uncommitted changes сохранены в stash. После миграции — git stash list / git stash pop, если нужны."
fi

# Тег + push — точка отката к до-миграционному состоянию
git tag pre-v3-migration-$(date +%Y%m%d)
git push origin pre-v3-migration-$(date +%Y%m%d)
```

Это позволит вернуться к до-миграционному состоянию через safe revert (см. раздел «Rollback всей миграции» внизу), а stash восстанавливается через `git stash pop` если что-то из uncommitted понадобится.

### 1.4. (Опционально) Обновить `specs/` и `docs/` из bootstrap'а

Если проект склонирован из v2.0.x или v2.1.x — в его `specs/*.md` и `docs/*.md` могут быть те же P0 баги, что лечились в Phase 0 ТЗ-1 (`localhost:4000`, `migration-map`, `compress-images`, schema A/B и т.д.). На initial setup это уже не влияет (он давно прошёл), но если планируешь дальше использовать `specs/13-extend-site.md` для правок — стоит подтянуть актуальные версии.

```bash
# Если bootstrap локально (rsync напрямую):
if [ -d "$BOOTSTRAP_LOCAL" ]; then
  rsync -av --exclude='spec.md' --exclude='content.md' --exclude='pages.md' --exclude='integrations.md' \
    "$BOOTSTRAP_LOCAL/docs/" docs/
  rsync -av "$BOOTSTRAP_LOCAL/specs/" specs/
else
  # Bootstrap локально нет — скачать tarball и развернуть:
  TMP=$(mktemp -d)
  curl -fsSL "https://github.com/tem11134v2-cmd/web-dev-bootstrap/archive/refs/tags/${BOOTSTRAP_TAG}.tar.gz" \
    | tar xz -C "$TMP"
  EXTRACTED="$TMP/web-dev-bootstrap-${BOOTSTRAP_TAG}"
  rsync -av --exclude='spec.md' --exclude='content.md' --exclude='pages.md' --exclude='integrations.md' \
    "$EXTRACTED/docs/" docs/
  rsync -av "$EXTRACTED/specs/" specs/
  rm -rf "$TMP"
fi
# specs/ обычно не имеет project-specific файлов — там только setup-инструкции
```

**Альтернатива (более консервативная):** не трогать `specs/` и `docs/` вообще — они нужны только для initial setup, после миграции на v3 ты будешь работать через `specs/13-extend-site.md` (он сам по себе обновится после первого использования / при необходимости).

Решает разработчик. По умолчанию — **пропустить** (специфики используются редко).

### 1.5. Проверить размер миграции

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

# 2. Поставить pnpm если ещё нет (приоритет — corepack, как в bootstrap v3)
which pnpm || corepack enable && corepack prepare pnpm@latest --activate || npm install -g pnpm

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

# 3. Скопировать канонический biome.json из bootstrap (single source of truth)
BOOTSTRAP_GET biome.json.example biome.json

# 4. Удалить старые конфиги
rm -f .eslintrc.* .prettierrc* .prettierignore
```

> Канонический `biome.json.example` обновляется в каждом релизе bootstrap'а. Если хочется кастомизировать правила под проект — правь **проектный** `biome.json` после копирования, а не bootstrap-шаблон.

Прогнать форматтер один раз по проекту (это будет большой коммит):
```bash
pnpm format
git add -A
git commit -m "chore: migrate ESLint+Prettier to Biome"
```

⚠️ Прежде чем коммитить — убедись, что форматтер не сломал файлы (особенно MDX). Открой dev — рендерится?

### 2.4. Обновить `.claude/hooks/format.sh`

Канонический `format.sh` (Biome вместо Prettier) лежит в bootstrap'е. Скопировать поверх:

```bash
BOOTSTRAP_GET .claude/hooks/format.sh .claude/hooks/format.sh
chmod +x .claude/hooks/format.sh
```

Закоммитить отдельно: `chore: update format hook to use Biome`.

### 2.5. Расширить `.claude/hooks/guard-rm.sh`

В v3 `guard-rm.sh` покрывает дополнительные случаи: `rm -rf .`, `rm -rf ./`, `git push -f` (короткая форма), и др. Скопировать актуальный из bootstrap'а:

```bash
BOOTSTRAP_GET .claude/hooks/guard-rm.sh .claude/hooks/guard-rm.sh
chmod +x .claude/hooks/guard-rm.sh
```

Закоммитить отдельно: `chore: harden guard-rm hook from bootstrap v3`.

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

### 3.2. Server Action + Cloudflare Turnstile + multi-sink (один шаг)

> ⚠️ **Все три части делаются вместе в одном коммите.** Server Action в схеме требует обязательный `turnstileToken` (проверка ДО sinks, иначе сломанный sink = открытый канал для ботов), виджет Turnstile добавляет токен в форму, а multi-sink заменяет одиночный `sendToCRM` на `Promise.allSettled`. Если разделить шаги — между коммитами форма будет валиться Zod-валидацией на пустом токене или sinks-импорты будут broken.

Если `app/api/lead/route.ts` в проекте нет (например, проект уже частично на Server Action) — пропусти подшаг (в), сразу к (г).

#### а) Установить Turnstile + sinks-зависимости

1. Получить site-key и secret-key (Cloudflare → Turnstile → Add Site).
2. Установить пакеты:
   ```bash
   pnpm add @marsidev/react-turnstile googleapis node-telegram-bot-api
   pnpm add -D @types/node-telegram-bot-api
   ```
3. В `.env.local` (не коммитить — gitignored):
   ```
   # Turnstile (обязательно)
   NEXT_PUBLIC_TURNSTILE_SITE_KEY=0x4...
   TURNSTILE_SECRET_KEY=0x4...

   # Sinks (опционально — заполняй когда подключаешь канал)
   # GOOGLE_SHEETS_CLIENT_EMAIL=...
   # GOOGLE_SHEETS_PRIVATE_KEY=...
   # GOOGLE_SHEETS_SPREADSHEET_ID=...
   # TG_BOT_TOKEN=...
   # TG_CHAT_ID=...
   ```

   `googleapis` и `node-telegram-bot-api` устанавливаются заранее, даже если каналы пока не подключаешь — sink-функции импортируют их лениво и без env-переменных бросают `SinkSkipped`. Добавление каналов потом — просто env-переменные, без `pnpm add`.

#### б) Создать `lib/sinks/`

Создать четыре файла в `lib/sinks/`:

- `index.ts` — диспетчер с `LeadData`, `SinkSkipped`, `allSinks`, `classifySinkResults`
- `sheets.ts` — Google Sheets через googleapis (с guard'ом `SinkSkipped` если ключей нет)
- `telegram.ts` — Telegram Bot через node-telegram-bot-api (с guard'ом)
- `crm.ts` — stub до реального подключения CRM (всегда бросает `SinkSkipped("CRM_NOT_CONFIGURED")`)

Полные шаблоны кода — в `docs/forms-and-crm.md` § «Структура `lib/sinks/`» (читай оттуда, не дублируем 100 строк здесь). Если bootstrap клонирован локально — `cat ~/ClaudeCode/web-dev-bootstrap/docs/forms-and-crm.md`. Если нет — `https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/v3.2/docs/forms-and-crm.md`.

Если в проекте есть **старый** `lib/crm.ts` (одиночная CRM-функция) — её содержимое переезжает в `lib/sinks/crm.ts` (заменяя stub) с добавлением `SinkSkipped` guard'а в начале. Сам файл `lib/crm.ts` после миграции удалить.

#### в) Создать `app/actions/submit-lead.ts`

```typescript
'use server'
import { z } from 'zod'
import { headers } from 'next/headers'
import { rateLimit } from '@/lib/rate-limit'
import { appendFallback } from '@/lib/fallback'
import { allSinks, classifySinkResults, type LeadData } from '@/lib/sinks'

const schema = z.object({
  name: z.string().min(2),
  phone: z.string().min(10),
  email: z.string().email().optional(),
  message: z.string().optional(),
  source: z.string(),
  consent: z.literal(true),
  turnstileToken: z.string().min(1),
})

export type LeadState = { success: true } | { error: string } | null

export async function submitLead(_prev: LeadState, formData: FormData): Promise<LeadState> {
  const ip = (await headers()).get('x-forwarded-for') ?? 'unknown'
  if (!rateLimit(ip, 1, 10_000)) {
    return { error: 'Слишком много запросов. Подождите минуту.' }
  }

  const raw = Object.fromEntries(formData)
  const parsed = schema.safeParse({
    ...raw,
    consent: raw.consent === 'on' || raw.consent === 'true',
  })
  if (!parsed.success) return { error: 'Проверьте поля формы' }

  // Turnstile verify ДО sinks.
  const verify = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      secret: process.env.TURNSTILE_SECRET_KEY!,
      response: parsed.data.turnstileToken,
      remoteip: ip,
    }),
  })
  const result = (await verify.json()) as { success: boolean }
  if (!result.success) return { error: 'Защита от спама не пройдена' }

  // Multi-sink: параллельная доставка во все настроенные каналы.
  const leadData: LeadData = {
    name: parsed.data.name,
    phone: parsed.data.phone,
    email: parsed.data.email,
    message: parsed.data.message,
    source: parsed.data.source,
  }
  const results = await Promise.allSettled(allSinks.map((sink) => sink(leadData)))
  const { successes, skips, failures } = classifySinkResults(results)

  if (failures.length > 0) {
    console.error('Lead sink failures:', failures.map((f) => (f as PromiseRejectedResult).reason))
  }
  if (successes.length === 0) {
    await appendFallback(leadData)
    if (failures.length === 0 && skips.length === allSinks.length) {
      console.warn(
        'All lead sinks are not configured. Set GOOGLE_SHEETS_*, TG_BOT_TOKEN, or AMO_CRM_* in .env to start receiving leads.',
      )
    }
  }

  return { success: true }
}
```

Старый `app/api/lead/route.ts` (если был) удаляется в подшаге (д).

#### г) Найти все формы в проекте

Чтобы не пропустить ни одну:
```bash
# Все компоненты с формой:
grep -rln 'useForm\|<form\|action=' app/ components/ 2>/dev/null

# Все клиентские компоненты с submit-handler'ами:
grep -rln '"use client"' app/ components/ 2>/dev/null | xargs grep -l 'onSubmit\|formAction' 2>/dev/null
```
Типичные кандидаты: `ConsultationDialog.tsx`, `LeadForm.tsx`, `ContactForm.tsx`, footer-форма, форма квиза.

#### д) В каждой найденной форме: Turnstile widget + переключение на `useActionState`

Заменить `fetch('/api/lead', ...)` на форму с виджетом и Server Action:
```typescript
'use client'
import { useActionState, useState } from 'react'
import { Turnstile } from '@marsidev/react-turnstile'
import { submitLead } from '@/app/actions/submit-lead'

const [state, formAction, isPending] = useActionState(submitLead, null)
const [turnstileToken, setTurnstileToken] = useState<string | null>(null)

return (
  <>
    <form action={formAction}>
      {/* ... поля name/phone/email/message/source/consent ... */}

      <Turnstile
        siteKey={process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY!}
        options={{ theme: 'light', size: 'flexible' }}
        onSuccess={(token) => setTurnstileToken(token)}
      />
      <input type="hidden" name="turnstileToken" value={turnstileToken ?? ''} />

      <button type="submit" disabled={!turnstileToken || isPending}>
        {isPending ? 'Отправка...' : 'Отправить'}
      </button>
    </form>

    {state?.error && <p className="text-red-500">{state.error}</p>}
    {state?.success && <p className="text-green-500">Заявка отправлена!</p>}
  </>
)
```

#### е) Удалить старый Route Handler

```bash
rm app/api/lead/route.ts
```

#### ж) Проверить локально

Открой каждую форму, дождись прогрузки Turnstile-виджета (~1 сек), submit. На этом этапе ни один sink ещё не настроен (env пустой по подшагу а) — лид должен сохраниться в `data/leads.json` через fallback. В консоли увидишь warning `All lead sinks are not configured. Set GOOGLE_SHEETS_*, TG_BOT_TOKEN, ...`.

Это **ожидаемо** — каналы подключаешь следующим шагом миграции (или после, в `specs/13-extend-site.md`). Главное — форма работает, Turnstile проходит, JSON-фоллбек страхует.

Если виджет не показывается — проверь `NEXT_PUBLIC_TURNSTILE_SITE_KEY` в `.env.local` (`console.log(process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY)` в клиентском коде).

Закоммитить **одним коммитом** (Server Action + Turnstile + multi-sink вместе): `refactor: migrate /api/lead to Server Action with Turnstile + multi-sink leads`.

#### Подключение каналов после миграции

После того как Server Action + Turnstile + multi-sink работают, подключай sinks **по одному**, отдельными коммитами:

1. **Sheets** — добавить `GOOGLE_SHEETS_*` env, проверить что лид попадает в таблицу.
2. **Telegram** — добавить `TG_BOT_TOKEN` + `TG_CHAT_ID`, проверить что приходит сообщение в чат.
3. **CRM** — заменить stub в `lib/sinks/crm.ts` на реальный код (см. `docs/forms-and-crm.md` § «CRM-интеграции»), добавить env.

Каждое подключение — отдельный commit и отдельный test. Между коммитами форма продолжает работать (skipped sinks ничего не ломают). Подробности — в `specs/09-forms-crm.md` § «Sinks: подключение каналов».

### 3.3. Content Collections (только если есть блог)

Пропусти этот шаг, если `content/blog/` не существует.

```bash
pnpm add content-collections @content-collections/core @content-collections/mdx @content-collections/next
pnpm remove next-mdx-remote 2>/dev/null
```

Создать `content-collections.ts` в корне (см. готовый шаблон в `specs/07-blog-optional.md` bootstrap-репо, или собственный по доке https://www.content-collections.dev/).

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

Workflow в `_BUILD/v3/templates/deploy-prod.yml.example` использует `environment: production` — поэтому секреты должны лежать **в Environment, а не в repo-level Secrets**, иначе job упадёт на `Setup SSH` с пустым `SSH_PRIVATE_KEY`.

В **GitHub → Settings → Environments → создать `production`** (для dev-поддомена — отдельный environment `dev`):

**Удалить старые** (если были на repo-level):
- `DEPLOY_SSH_KEY` (старый из `~/.ssh/deploy_key` с VPS)
- `SERVER_IP` (если был)

**Добавить в Environment `production` (Secrets):**
- `SSH_PRIVATE_KEY` — приватный ключ из Mac (`~/.ssh/{site}-deploy`, см. ниже как сгенерировать)
- `SSH_HOST` — IP VPS (если ещё не было)
- `SSH_USER` — `deploy`
- `SSH_PORT` — `2222` (или `22`)
- `PROD_ENV_FILE` — содержимое локального `.env.production` целиком (multiline)

**Repository-level Secrets** (используются в build job, до того как environment подтягивается):
- `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `NEXT_PUBLIC_YM_ID`, `NEXT_PUBLIC_GA_ID` — публичные ID для билда

**Repository-level Variables:**
- `SITE_NAME` — kebab-case имя сайта (то же, что в `package.json#name` и в PM2)

Сгенерировать новый SSH-ключ (на Mac):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy -N "" -C "{site}-deploy"
# Публичную часть положить в authorized_keys deploy-юзера на VPS:
ssh-copy-id -i ~/.ssh/{site}-deploy.pub -p {ssh-port} deploy@{vps-ip}
# Приватную часть загрузить в GitHub Environment Secret (НЕ repo-level):
gh secret set SSH_PRIVATE_KEY --env production --repo {owner}/{site} \
  < ~/.ssh/{site}-deploy
# Загрузить .env как multiline secret:
gh secret set PROD_ENV_FILE --env production --repo {owner}/{site} \
  < ~/projects/{site}/.env.production
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

# Перенаправить PM2 на current/ — ОБЯЗАТЕЛЬНО абсолютный путь
# (PM2 запоминает target симлинка при start; без полного пути после ln -sfn будет запущен старый релиз)
pm2 stop {site}-prod 2>/dev/null
pm2 delete {site}-prod 2>/dev/null
pm2 start /home/deploy/prod/{site}/current/server.js --name {site}-prod --update-env
pm2 save
```

⚠️ Если `server.js` не существует (потому что `output: 'standalone'` ещё не включен в проекте на VPS) — пропусти, после первого нового деплоя через push-based он появится автоматически.

⚠️ **Важно про PM2 + симлинки:** на некоторых версиях PM2 `pm2 start <path>` запоминает абсолютный путь файла на момент запуска. Если запустить `pm2 start /path/to/current/server.js`, а потом перенаправить симлинк `current → новый_релиз`, PM2 может продолжить запускать **старый** target. Поэтому стандартный workflow при переключении релиза:

```bash
ln -sfn /home/deploy/prod/{site}/releases/<new-sha> /home/deploy/prod/{site}/current
pm2 reload {site}-prod --update-env
# Если reload не подхватил новую версию (тестируй по странице или sha в HTML):
pm2 delete {site}-prod
pm2 start /home/deploy/prod/{site}/current/server.js --name {site}-prod --update-env
pm2 save
```

В deploy-prod.yml workflow это уже учтено через `pm2 reload ... || pm2 start ...` fallback. Запиши в Известные грабли, что если симлинк переключился, а сайт всё ещё отдаёт старую версию — `pm2 delete && pm2 start` решает.

### 4.3. Удалить старый `deploy_key` с VPS (если был)

В bootstrap v2.x `deploy_key` — это **обычный SSH-ключ** (приватная часть на VPS, публичная в собственном `authorized_keys`), который Actions использовал для `git pull`. Не путать с GitHub Deploy Keys (отдельная фича — публичный ключ, привязанный per-repo через `Settings → Deploy keys`; в bootstrap v2.x не использовалась).

После Phase 5 push-deploy git pull на VPS не нужен → ключ становится лишним:

```bash
ssh deploy@{vps-ip}
ls -la ~/.ssh/deploy_key* 2>/dev/null && rm -f ~/.ssh/deploy_key ~/.ssh/deploy_key.pub
# Из ~/.ssh/authorized_keys удалить строку с deploy_key.pub (если он был добавлен в собственный authorized_keys)
nano ~/.ssh/authorized_keys
# В GitHub → Settings → Deploy keys: должно быть ПУСТО (bootstrap v2.x не использовал эту фичу). Если что-то есть — удали, оно тоже устарело.
```

### 4.4. Заменить `.github/workflows/deploy-prod.yml`

Канонический шаблон лежит в bootstrap'е по пути `_BUILD/v3/templates/deploy-prod.yml.example`. Скопировать через helper:

```bash
mkdir -p .github/workflows
BOOTSTRAP_GET _BUILD/v3/templates/deploy-prod.yml.example .github/workflows/deploy-prod.yml
```

Менять в нём ничего не нужно — все per-site значения вынесены в Variables/Secrets:
- `vars.SITE_NAME` уже задан как Repository Variable (см. § 4.1).
- Прод-порт PM2 (`{site}-prod`) задаётся в `pm2 start --name`, имя приходит из `vars.SITE_NAME`.
- SSH-параметры приходят из Environment `production` Secrets.

Аналогично для `deploy-dev.yml`, если был — копировать `_BUILD/v3/templates/deploy-dev.yml.example` и убедиться, что в репо есть Environment `dev` с собственным `SSH_PRIVATE_KEY` и `DEV_ENV_FILE`.

### 4.5. Переписать локальный `scripts/rollback.sh`

Готовая версия лежит в bootstrap-репо в `scripts/rollback.sh` (атомарный симлинк-switch вместо `git reset + rebuild`). Скопировать через helper:

```bash
mkdir -p scripts
BOOTSTRAP_GET scripts/rollback.sh scripts/rollback.sh
chmod +x scripts/rollback.sh
```

Сигнатура поменялась: было `scripts/rollback.sh <commit-hash> [site] [ssh_alias]`, стало `scripts/rollback.sh [site] [ssh_alias]` — скрипт сам находит предыдущий релиз в `~/prod/{site}/releases/`. Проверь, что в `~/.ssh/config` есть `Host {site}` (или передавай ssh_alias явно).

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

Скопировать из bootstrap через helper:
```bash
mkdir -p .claude/commands
BOOTSTRAP_GET .claude/commands/handoff.md .claude/commands/handoff.md
BOOTSTRAP_GET .claude/commands/resume.md .claude/commands/resume.md
BOOTSTRAP_GET .claude/commands/catchup.md .claude/commands/catchup.md
```

### 5.2. Скопировать stop-reminder hook + обновить settings.json

Stop-хук — мягкое напоминание про `/handoff`, если в текущей сессии были коммиты. Без него Claude после вашего ухода из чата ничего в память не запишет.

```bash
# Скопировать сам хук
BOOTSTRAP_GET .claude/hooks/stop-reminder.sh .claude/hooks/stop-reminder.sh
chmod +x .claude/hooks/stop-reminder.sh

# Проверить, что session-start.sh пишет HEAD-sha в /tmp (нужно для stop-reminder):
grep -q "session-start-sha" .claude/hooks/session-start.sh || \
  BOOTSTRAP_GET .claude/hooks/session-start.sh .claude/hooks/session-start.sh
chmod +x .claude/hooks/session-start.sh
```

Затем зарегистрировать `Stop` event в `.claude/settings.json`. Открыть проектный `settings.json`, сравнить с `~/ClaudeCode/web-dev-bootstrap/.claude/settings.json`, добавить отсутствующий блок `Stop` в секцию `hooks`:

```json
{
  "hooks": {
    "SessionStart": [...],
    "PreToolUse": [...],
    "PostToolUse": [...],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/stop-reminder.sh" }
        ]
      }
    ]
  }
}
```

⚠️ Не перезаписывай весь `settings.json` целиком — у проекта могут быть свои hooks или permissions. Делай **диф-мерж**:

```bash
# Скачай актуальный settings.json из bootstrap'а во временное место для сравнения:
BOOTSTRAP_GET .claude/settings.json /tmp/bootstrap-settings.json
diff .claude/settings.json /tmp/bootstrap-settings.json
# Перенеси только отсутствующие блоки (Stop hook, новые permissions) в проектный settings.json
rm /tmp/bootstrap-settings.json
```

Закоммитить: `chore: add stop-reminder hook + register Stop event`.

### 5.3. Обновить `CLAUDE.md`

Сравнить текущий `CLAUDE.md` с актуальным шаблоном из bootstrap'а через helper:

```bash
BOOTSTRAP_GET _BUILD/claude-md-template.md /tmp/bootstrap-claude-md-template.md
diff CLAUDE.md /tmp/bootstrap-claude-md-template.md
```

Добавить отсутствующие секции:
- `## Multi-Claude protocol` (новая)
- Обновлённый `## Stack` (pnpm, mise, Biome, schema-dts)
- Обновлённый `## Commands` (`pnpm` вместо `npm`, без `compress`)
- Обновлённые KB pointers если что-то менялось

Не трогать project-specific секции (`# Project: [Name]`, описание проекта, project-specific правила).

### 5.4. Расширить `.claude/memory/project_state.md`

Привести к новой структуре с разделом «Session log» (см. шаблон в `.claude/memory/project_state.md` bootstrap-репо).

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

### 5.5. Записи в `decisions.md` и `references.md`

**`decisions.md`** — почему вообще мигрировали (для будущей памяти, чтобы через год было понятно):

```markdown
### [YYYY-MM-DD] Migration to bootstrap v3.0

**What:** Проект мигрирован с bootstrap v2.x на v3.0.
- Tooling: pnpm + mise + Biome (заменили npm/nvm/ESLint+Prettier)
- Code: Server Action `submitLead` + Cloudflare Turnstile (вместо `/api/lead` Route Handler без капчи)
- Deploy: push-based через GitHub Actions runner + rsync standalone-артефакта + симлинк-релизы (вместо pull-based git+build на VPS)
- Опционально: Caddy на VPS (если переезжали)

**Why:** Унификация со стандартом v3.0. Push-based убирает риск OOM на VPS при билде, атомарный rollback через симлинк за миллисекунды без пересборки.

**Alternatives considered:** Остаться на v2.x (rejected — рассинхрон с актуальным bootstrap'ом, сложнее поддерживать долгосрочно).
```

**`references.md`** — обновить новыми артефактами миграции:

```markdown
## Deployment (после v3 migration)

- **GitHub Environments:** `production` (и `dev`, если используется) — Secrets живут там, не на repo-level.
- **SSH-ключ деплоя:** `~/.ssh/{site}-deploy` (приватный) → загружен в `gh secret set SSH_PRIVATE_KEY --env production`. Публичная часть — в `~/.ssh/authorized_keys` пользователя `deploy` на VPS.
- **Cloudflare Turnstile:** site-key + secret-key — в Cloudflare Dashboard → Turnstile → {site-name}. Site-key публичный (`NEXT_PUBLIC_TURNSTILE_SITE_KEY`), secret-key только в `PROD_ENV_FILE` Environment Secret.
- **Pre-migration backup:** тег `pre-v3-migration-YYYYMMDD` (на origin).
```

### 5.6. Обновить `.claude/memory/INDEX.md` (если есть)

Сверить с актуальным шаблоном из bootstrap. Обычно меняется мало, но проверить полезно.

---

## Этап 6: Caddy на VPS (опционально)

Если на VPS до сих пор стоит nginx + certbot (т.е. VPS поднимался по bootstrap-vps.sh **до** v2.3-caddy) — переводи на Caddy. Если VPS свежий v2.3+, или ты уже мигрировал ранее — пропусти.

⚠️ Это **общая инфраструктура** — затрагивает все сайты, живущие на этом VPS. Делать только когда все сайты на VPS уже мигрированы на v3 или готовы к миграции (потому что после переключения старые pull-based workflow продолжат работать, но если у них в `~/prod/{site}/.git` сидит старая версия конфига — могут быть нюансы).

Не делай механический конвертер `nginx → Caddyfile` — структура и подходы разные. Используй готовый Caddy-шаблон.

Шаги:

1. **Установить Caddy.** Лучше всего — прогнать обновлённый `bootstrap-vps.sh` (он проверит, что Caddy установлен из cloudsmith-репо и базовый `/etc/caddy/Caddyfile` собран). Запуск с локального bootstrap-репо:

   ```bash
   ssh root@{vps-ip} 'CADDY_ADMIN_EMAIL=admin@example.com bash -s' \
     < ~/ClaudeCode/web-dev-bootstrap/scripts/bootstrap-vps.sh
   ```

   Если bootstrap локально нет — стримить с GitHub raw:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/tem11134v2-cmd/web-dev-bootstrap/v3.0/scripts/bootstrap-vps.sh \
     | ssh root@{vps-ip} 'CADDY_ADMIN_EMAIL=admin@example.com bash -s'
   ```

   Скрипт идемпотентен: уже установленные node/pm2/ufw не тронет, но добавит `caddy` и базовый Caddyfile с `import /etc/caddy/Caddyfile.d/*.caddy`.

2. **Для каждого сайта на VPS** перепиши nginx-vhost в Caddy-блок по шаблону из `~/ClaudeCode/web-dev-bootstrap/docs/server-add-site.md` § 4 (`reverse_proxy localhost:{port}` + `encode gzip zstd` + `@static path` + `@html path`). Положи в `/etc/caddy/Caddyfile.d/{site}.caddy`. Бэкап старого vhost-конфига держи **вне** `Caddyfile.d/` — иначе `caddy validate` подхватит `*.bak` и упадёт.

3. **Проверить:** `sudo caddy validate --config /etc/caddy/Caddyfile` — должно быть `Valid configuration`.

4. **Переключить:** `sudo systemctl stop nginx && sudo systemctl disable nginx && sudo systemctl reload caddy`. Caddy и nginx слушают одни порты (80, 443) — параллельно не запустишь, надо остановить nginx до reload Caddy.

5. **Проверить HTTPS на каждом домене:** Caddy сам получит сертификат при первом HTTPS-запросе (HTTP-01 challenge через 80 порт). Логи: `sudo journalctl -u caddy --since "5 min ago" | grep -i obtained`.

6. **(Опционально) удалить certbot и его таймеры:** `sudo apt purge certbot python3-certbot-nginx; sudo systemctl disable --now certbot.timer 2>/dev/null || true`. Старые сертификаты в `/etc/letsencrypt/` можно оставить — Caddy их игнорирует, держит свои в `/var/lib/caddy/`.

**Откат** (если что-то пошло не так): `sudo systemctl stop caddy && sudo systemctl start nginx`. Старые vhost-конфиги в `/etc/nginx/sites-enabled/` остались на месте, certbot-сертификаты в `/etc/letsencrypt/` — тоже. Сайты вернутся под старую инфру за секунды.

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

### Грепы для самопроверки (запустить из корня проекта)

```bash
# Не должно быть упоминаний npm-команд (кроме package-lock и старых backup'ов):
grep -rn "npm run\|npm install\|npm ci" --include="*.md" --include="*.json" --include="*.yml" \
  | grep -v "package-lock\|node_modules\|/_BUILD/v3/\|releases/" \
  | head -10                              # должно быть пусто или только в changelog'ах

# Не должно быть Route Handler endpoint'а:
test -f app/api/lead/route.ts && echo "✗ /api/lead route still exists" || echo "✓ /api/lead route removed"

# Server Action на месте:
test -f app/actions/submit-lead.ts && echo "✓ submitLead action exists" || echo "✗ MISSING"

# Biome конфигурация на месте:
test -f biome.json && echo "✓ biome.json exists" || echo "✗ MISSING"

# pnpm lock на месте, npm lock удалён:
test -f pnpm-lock.yaml && test ! -f package-lock.json && echo "✓ pnpm migration done" || echo "✗ check lockfiles"

# mise:
test -f .tool-versions && echo "✓ .tool-versions exists" || echo "✗ MISSING"

# Slash-команды:
for cmd in handoff resume catchup; do
  test -f .claude/commands/$cmd.md && echo "✓ /$cmd" || echo "✗ MISSING /$cmd"
done

# Stop hook:
test -f .claude/hooks/stop-reminder.sh && \
  grep -q '"Stop"' .claude/settings.json && \
  echo "✓ Stop hook registered" || echo "✗ Stop hook missing or not registered"

# Multi-Claude protocol в CLAUDE.md:
grep -q "Multi-Claude protocol" CLAUDE.md && echo "✓ Multi-Claude protocol section" || echo "✗ MISSING"
```

Если хоть одно `✗` — миграция не закрыта, доделай соответствующий шаг.

---

## Rollback всей миграции

Если миграция пошла катастрофически и нужно откатить весь проект:

### Безопасный путь: revert вместо force-push

`git push -f origin main` — **не используй**. Force-push в `main` блокируется хуком `guard-rm.sh` (расширенным в § 2.5), теряет историю, ломает GitHub Actions runs других коллабораторов. Правильный rollback через revert-серию:

```bash
# 1. На Mac:
git fetch origin
git checkout main
git pull origin main

# Создать revert-серию: обнулить все коммиты после pre-v3-migration-tag
# Это создаст новые коммиты, не переписывая историю.
git revert --no-edit pre-v3-migration-YYYYMMDD..HEAD
# Если конфликты — разрешить руками, потом git revert --continue

# Запушить (обычным push, не force):
git push origin main
```

**Альтернатива через PR** (ещё безопаснее, требует merge через UI):
```bash
git checkout -b chore/rollback-v3-migration
git revert --no-edit pre-v3-migration-YYYYMMDD..HEAD
git push -u origin chore/rollback-v3-migration
gh pr create --title "Rollback v3 migration" --body "Revert v3 migration commits — see decisions.md"
# Merge через GitHub UI — Actions передеплоит pre-migration версию автоматически
```

### Прод на VPS

```bash
# Если на VPS уже успел переключить симлинк current на v3-релиз:
ssh deploy@{vps-ip}
cd ~/prod/{site}
ls -1tr releases/    # найти sha до миграции
ln -sfn /home/deploy/prod/{site}/releases/<old-sha> current
pm2 reload {site}-prod --update-env
# Если reload не подхватил — pm2 delete && pm2 start (см. грабли про PM2-симлинк)

# Если releases/ ещё не создан (миграция упала в Этапе 4.2 до создания) — VPS не тронут,
# просто переоткатил Actions через revert (выше) — следующий push передеплоит старую версию.
```

### GitHub Secrets

После revert'а workflow всё ещё ожидает новые Environment Secrets (`SSH_PRIVATE_KEY` в `production`). Выбор:
- **Оставить новые секреты** — workflow работает, deploy продолжает push-based
- **Полностью откатить** — вернуть старый repo-level `DEPLOY_SSH_KEY`, удалить Environment `production`, убрать в .github/workflows старый `deploy-prod.yml` (через тот же revert)

Чаще всего достаточно **оставить новые секреты** — они нейтральны, проект просто использует старый workflow.

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

### «Симлинк переключился, но сайт всё ещё на старой версии»
- PM2 запоминает абсолютный путь `server.js` при старте. После `ln -sfn` нужен `pm2 reload`. Если `reload` не помог:
  ```bash
  pm2 delete {site}-prod
  pm2 start /home/deploy/prod/{site}/current/server.js --name {site}-prod --update-env
  pm2 save
  ```

### «Action упал на Setup SSH с пустым ключом»
- Секрет лежит в repo-level Secrets, а не в Environment `production`. В workflow прописано `environment: production`, поэтому `${{ secrets.SSH_PRIVATE_KEY }}` ищется именно в этом environment.
- Фикс: `gh secret set SSH_PRIVATE_KEY --env production --repo {owner}/{site} < ~/.ssh/{site}-deploy`. Тот же fix для `SSH_HOST`, `SSH_USER`, `SSH_PORT`, `PROD_ENV_FILE`.

### «Caddy не получает сертификат после переключения с nginx»
- Возможные причины:
  1. A-запись домена кэширована/смотрит на старый IP. Проверка: `dig +short {domain}` с разных машин — должно везде вернуть IP VPS.
  2. 80-порт занят nginx-residual (nginx не до конца остановился). `sudo lsof -i :80` — должен показывать `caddy`, не `nginx`.
  3. Cloudflare proxy включён (оранжевое облачко) — выключи на время выпуска (серое облачко = DNS only), потом верни.
- Логи: `sudo journalctl -u caddy --since "10 min ago" | grep -iE "obtained|error|challenge"`.

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

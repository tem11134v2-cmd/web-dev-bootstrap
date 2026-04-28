# ТЗ-1: Рефакторинг bootstrap v2.2.x → v3.0

**Это большое ТЗ для последовательной работы в нескольких Claude-сессиях в bootstrap-репо.** Финальный артефакт — bootstrap v3.0 с современной инфраструктурой (Caddy, push-based deploy, Next.js 16 паттерны, Biome, pnpm, Content Collections, Cloudflare Turnstile, sequential multi-Claude handoff).

---

## Кому, где, как

- **Где запускать:** в репо `~/ClaudeCode/web-dev-bootstrap/` (сам bootstrap, не клиентский проект)
- **Кто запускает:** разработчик (Тимур) через Claude Code Desktop
- **Сколько сессий:** 7 (по одной на фазу 0–6). Между фазами — `/clear` и новая сессия. Каждая сессия начинает работу с чтения `.claude/memory/project_state.md`, чтобы понять где остановилась прошлая.
- **Сколько времени:** ~1–2 рабочих дня суммарно, если идти подряд. Можно растянуть.
- **Релизный итог:** теги `v2.2.2 → v2.3-caddy → v2.3-dx → v2.4 → v3.0-next16 → v3.0-deploy → v3.0`

---

## Стартовый промт первой сессии

Скопируй в первый промт новой Claude-сессии в папке bootstrap:

```
Прочитай CLAUDE.md, specs/INDEX.md, _BUILD/v3/01-bootstrap-refactor.md, _BUILD/changelog.md.
Затем прочитай .claude/memory/project_state.md (если он указывает на активную фазу — продолжаем оттуда; если пустой/новый — начинаем с Фазы 0).
Покажи план текущей фазы. Жди подтверждения перед любыми правками.
```

Каждая последующая сессия — тот же промт, Claude автоматически по `project_state.md` поймёт, какая фаза следующая.

---

## Принципы работы во всех фазах

1. **Plan mode перед каждой фазой** (Shift+Tab×2). Покажи план — жди ОК.
2. **Тег перед стартом фазы:** `git tag pre-phase-N` — точка отката.
3. **Каждая фаза = своя feature-ветка** (см. таблицу веток ниже) → коммиты внутри неё → PR в `main` → merge через GitHub UI или `gh pr merge`. **Никакой ветки `dev` в bootstrap-репо нет**, исторический flow — `feature/X → PR → main`.
4. **Один коммит на завершённую подзадачу** (атомарность для отката).
5. **`pnpm build`** (после Фазы 2) или **`npm run build`** (до Фазы 2) для проектов, где есть `package.json`. Сам bootstrap-репо не билдится (он шаблон), поэтому build-проверка не применима к нему — применима к **результату использования шаблона**. В рамках ТЗ-1 это означает: если правка ломает шаблонные spec-инструкции (например, в `package.json scripts` шаблоне), это видно только при создании тестового проекта из шаблона. Делать только если есть подозрение.
6. **После завершения фазы:**
   - Финальный коммит фазы
   - `git push -u origin <feature-branch>`
   - `gh pr create` с описанием фазы
   - Merge в `main` (через `gh pr merge --squash` или GitHub UI)
   - Тег релиза (`git tag v2.x.y`, `git push origin v2.x.y`)
   - Запись в `_BUILD/changelog.md`
   - Обновление `.claude/memory/project_state.md` с указанием следующей фазы
   - Предложение пользователю `/clear` и новую сессию

6. **Если что-то пошло не так в фазе:** есть раздел «Rollback» в каждой фазе. Не импровизируй — следуй ему.

7. **Не трогать в этом ТЗ** (вне scope):
   - `docs/content-layout.md` (44 секции)
   - `docs/conversion-patterns.md`
   - `specs/templates/*` (форма шаблонов хороша)
   - `specs/examples/*` (с предупреждением «специфика migrator.me»)
   - `docs/legal-templates.md`

---

## Обзор фаз

| Фаза | Тема | Feature-ветка | Файлов меняем | Тег после | Сложность |
|---|---|---|---|---|---|
| 0 | P0 hotfixes (12 точечных багов) | `fix/v2.2.2-p0-bundle` | ~12 | `v2.2.2` | Низкая |
| 1 | Caddy вместо nginx+certbot | `feat/v2.3-caddy` | ~5 | `v2.3-caddy` | Средняя |
| 2 | DX: Biome, pnpm, mise, schema-dts | `feat/v2.3-dx-biome-pnpm-mise` | ~10 | `v2.3-dx` | Низкая |
| 3 | Cloudflare Turnstile + Content Collections | `feat/v2.4-turnstile-content-collections` | ~8 | `v2.4` | Средняя |
| 4 | Next.js 16: Server Actions, use cache | `feat/v3.0-next16-patterns` | ~7 | `v3.0-next16` | Средняя |
| 5 | Push-based deploy + standalone + ключи | `feat/v3.0-push-deploy` | ~10 | `v3.0-deploy` | **Высокая** |
| 6 | Multi-Claude handoff + HOW-TO-START + claude-md-template | `feat/v3.0-handoff-protocol` | ~6 | `v3.0` | Низкая |

## Работа через git worktrees (Claude Desktop)

Claude Desktop часто открывает сессию **в worktree** вместо основного дерева — это видно по cwd `_BUILD/.claude/worktrees/<auto-name>/`. Worktree-ветка автоматически создаётся с генерёным именем (например, `claude/inspiring-merkle-9f01cc`).

**Что делать на старте каждой фазы (если ты в worktree):**

1. Проверь cwd: `pwd` — если содержит `worktrees/`, ты в worktree.
2. Проверь, что worktree-ветка синхронизирована с `origin/main`:
   ```bash
   git fetch origin
   git status   # должно показать "Your branch is up to date with 'origin/main'" или "ahead/behind"
   ```
3. Если ветка отстала — `git rebase origin/main` (или `git pull --rebase`).
4. **Переименуй автогенерёную ветку** в осмысленную из таблицы выше:
   ```bash
   git branch -m <new-feature-branch-from-table>
   # Пример для Фазы 0: git branch -m fix/v2.2.2-p0-bundle
   ```
5. Дальше — работай в этой ветке. Push: `git push -u origin <feature-branch>`.
6. **После merge PR в `main`** — worktree остаётся в старой ветке (не переключается автоматически). Для следующей фазы либо:
   - в этом же worktree: `git fetch && git rebase origin/main && git checkout -b <next-feature-branch>`
   - или Claude Desktop создаст новый worktree автоматически — тогда повтори с шага 1

**Не работай параллельно в двух worktrees на bootstrap-репо** — состояние `.claude/memory/project_state.md` будет писаться вразнобой. Один worktree = одна активная фаза.

**Если worktree больше не нужен** — `git worktree remove _BUILD/.claude/worktrees/<name>`. Сам Claude Desktop этим управляет, обычно вмешательство не нужно.

---

# Фаза 0 — P0 hotfixes (→ v2.2.2)

## Goal

Закрыть 12 точечных багов в текущей v2.2.x, **не трогая архитектуру**. После этой фазы bootstrap всё ещё на старом стеке, но без сломанных ссылок и противоречий.

## KB files to read first

- `_BUILD/changelog.md` — понять историю версий
- `README.md` — увидеть устаревшую версию
- `CLAUDE.md` — увидеть устаревшие упоминания
- `specs/02-project-init.md`, `specs/03-design-system.md`, `specs/06-subpages-rollout.md`, `specs/13-extend-site.md` — основные точки правок

## Tasks

### 1. P0-1: убрать `compress-images.mjs` из стека

**Решение:** скрипт никогда не существовал, удаляем все упоминания и `&& npm run compress` из build.

Правки:
- `docs/stack.md:66` — `"build": "next build && npm run compress"` → `"build": "next build"`
- `docs/stack.md:69` — удалить строку `"compress": "node scripts/compress-images.mjs"`
- `docs/stack.md:76` — удалить пункт `compress` из описания скриптов
- `docs/architecture.md:38` — в комментарии папок убрать `(compress-images.mjs)`
- `docs/performance.md:80` — переписать «`gzip_static on` + постбилд `.gz` (через `npm run compress` шаг)» — убрать упоминание npm run compress, оставить только про `gzip_static on`
- `docs/performance.md` § 10 (~строка 129–131) — переписать раздел «Сжатие изображений при сборке» под нативный `next/image` + sharp (Next.js сам ресайзит и оптимизирует, sharp ставится как `optionalDependency` Next.js 15+)
- `CLAUDE.md:121` — удалить строку `npm run compress — sharp image optimization`
- `_BUILD/claude-md-template.md:100` — удалить ту же строку
- В `specs/11-performance.md:67` (если использует `npx sharp-cli`) — переписать на «использовать `next/image` нативно, для статики в `public/` — опционально однократный `npx sharp-cli`, но не подключать к build»

### 2. P0-2: исправить `localhost:4000` → `localhost:3000`

Точно три места (legitimate `:4010` в `docs/deploy.md:23` **не трогать** — это dev-поддомен на VPS):

- `specs/02-project-init.md:75` — «открыть localhost:4000» → «открыть localhost:3000»
- `specs/03-design-system.md:101` — то же
- `docs/team-onboarding.md:41` — `# → http://localhost:4000` → `:3000`

### 3. P0-3: синхронизировать версию в README

- `README.md:1` — `# web-dev-bootstrap v2.2` → `# web-dev-bootstrap v2.2.2`
- `README.md:92` — блок «Версия» — обновить дату/номер на актуальную из changelog (после фиксов это будет `v2.2.2 (YYYY-MM-DD)`)
- `_BUILD/claude-md-template.md:16` — `<!-- Дефолт v2.1. Замени если другой стек. -->` → `<!-- Дефолт v2.2.2. Замени если другой стек. -->`
- `CLAUDE.md:10–11` — «история версий v2.0 → v2.1.x» → «v2.0 → v2.2.x»
- `CLAUDE.md:16` — пример «(v2.1.4, v2.2.0 и т.д.)» → «(v2.2.3, v2.3.0 и т.д.)»

### 4. P0-4: удалить ссылки на `_BUILD/migration-map.md`

Файла нет, создавать не будем (содержание уже есть в changelog). Удалить упоминания:
- `README.md:38` — в описании `_BUILD/` убрать `migration-map`
- `README.md:76` — markdown-ссылку «**[_BUILD/migration-map.md]** — детальная карта переезда» удалить целиком
- `specs/00-brief.md:6` — пункт `_BUILD/migration-map.md` из списка KB удалить
- `_BUILD/changelog.md:116` — «Детальная карта — в `_BUILD/migration-map.md`. Коротко:» → «Коротко:» (ссылку убрать)

### 5. P0-5: убрать остатки схемы A/B по деплою

- `specs/13-extend-site.md:70–72` — заменить блок `**Деплой по схеме:** / A: pm2 restart / B: git push origin dev` на: `**Деплой:** \`git push origin dev\` → ревью → merge в main → автодеплой через GitHub Actions`
- `specs/06-subpages-rollout.md:81` — `17. Деплой по схеме (A или B)` → `17. Деплой: \`git push origin dev\` → PR в main`

### 6. P0-6: исправить ConsultationDialog в спеке 02

- `specs/02-project-init.md:71` — `(ConsultationDialogProvider — будет добавлен в спеке 09)` → `(ConsultationDialogProvider — будет добавлен в спеке 04)`

### 7. P0-7: убрать ссылки `/privacy` `/terms` из футера в спеке 03

Подход: в спеке 03 не добавлять юр-ссылки в footer (страницы появятся в 09, тогда же добавить ссылки).

- `specs/03-design-system.md:67` — пункт «Ссылки на `/privacy/` и `/terms/` (страницы создаются в спеке 09)» — удалить
- `specs/09-forms-crm.md` — добавить новый шаг (между текущими шагами создания `/privacy` и `/terms`): «X. Обновить компонент `Footer.tsx` — добавить ссылки на `/privacy` и `/terms`»

### 8. P0-8: переименовать `.claude/hooks.json` → `.claude/settings.json`

- `docs/workflow.md:107` — «Готовый `.claude/hooks.json` ставится один раз» → «Готовый `.claude/settings.json` ставится один раз»

### 9. N1: дополнить `scripts/README.md`

В таблицу скриптов добавить:
- `rollback.sh` — Откат прода на VPS на указанный коммит. См. `docs/automation.md`.
- `sync-env.sh` — Синхронизация локального `.env.production` на VPS + `pm2 restart --update-env`. См. `docs/automation.md`.

### 10. N2: убрать совет `Zod → Valibot` из спеки 11

Решение проекта: Zod оставляем (выигрыш в бандле незаметен на лендинге, экосистема за Zod). Удалить:
- `specs/11-performance.md:40` — пункт «Если есть `zod` v4 — заменить на `valibot` (1-3 KB вместо ~100 KB)» удалить целиком
- `docs/performance.md:42–44` — таблицу «Красные флаги зависимостей» — оставить, но строку про Zod→Valibot удалить (заменить на любую другую известную монолитную либу — например, `react-icons` целиком vs нужный сабсет, или `@mui/material` целиком)
- `docs/stack.md:43` — note про Zod v4 tree-shaking — удалить или сильно сократить (теперь это решение проекта, не «руки не дошли»)

### 11. N3: убрать `IDEAS.md` из CLAUDE.md

Файла нет, специально создавать незачем — пользователь его не использует.

- `CLAUDE.md:13` (если упомянут) — упоминание `IDEAS.md` удалить из «start of session» инструкций

### 12. N4: косметика changelog

В `_BUILD/changelog.md` — добавить в самый верх запись `v2.2.2 — YYYY-MM-DD · P0 hotfix bundle` с кратким перечислением 12 правок (compress-images, localhost:4000, версии, migration-map, schema A/B, ConsultationDialog spec, /privacy в footer, hooks.json name, scripts README, Zod→Valibot совет, IDEAS.md, и т.д.).

## Done when

- Все 12 пунктов выше применены
- `npm run build` проходит на этом репо (фейк-проект — нет, сам bootstrap не билдится, но `package.json` нет)
- `grep -rn "localhost:4000" --include="*.md"` возвращает только `:4010` в `docs/deploy.md` (легитимный)
- `grep -rn "compress-images" --include="*.md"` ничего не возвращает
- `grep -rn "migration-map" --include="*.md"` ничего не возвращает (или только исторически в changelog старых записях, без активных ссылок)
- `_BUILD/changelog.md` содержит запись о `v2.2.2`
- Коммиты атомарные (по одной P0 на коммит, если возможно)
- Тег `v2.2.2` создан
- PR в main смёрджен

## Rollback Phase 0

Если фаза пошла криво:
```bash
git tag -d v2.2.2 2>/dev/null
git reset --hard pre-phase-0
# Если уже пушил feature-ветку:
git push --force-with-lease origin fix/v2.2.2-p0-bundle
# Если PR ещё не открыт — просто бросить ветку:
# git checkout main && git branch -D fix/v2.2.2-p0-bundle
```

## Memory updates после Phase 0

В `.claude/memory/project_state.md`:
```
## Текущая фаза bootstrap-refactor

- Фаза 0 (P0 hotfixes) — done [YYYY-MM-DD], тег v2.2.2
- Следующая: Фаза 1 (Caddy)
```

Затем `/clear` → новая сессия с тем же стартовым промтом.

---

# Фаза 1 — Caddy вместо nginx+certbot (→ v2.3-caddy)

## Goal

Заменить связку `nginx + certbot + Let's Encrypt` на **Caddy** (встроенный ACME, автоматический HTTPS, multi-site через виртуальные хосты по доменам в одном Caddyfile). PM2 остаётся.

## KB files to read first

- `scripts/bootstrap-vps.sh` — раздел про nginx и certbot (строки ~150–220)
- `docs/server-manual-setup.md` — описание шагов
- `docs/server-add-site.md` — текущий nginx-шаблон
- `docs/server-multisite.md` — как уживаются сайты
- `docs/deploy.md` — упоминания nginx
- `docs/troubleshooting.md` — раздел про SSL
- (внешний референс) https://caddyserver.com/docs/quick-starts/reverse-proxy

## Background

В nginx-схеме на каждый сайт мы пишем ~30 строк конфига и руками вызываем certbot. В Caddy на каждый сайт ~6 строк, SSL автоматический. Multi-site работает через отдельные блоки в `/etc/caddy/Caddyfile` или через подключение `import /etc/caddy/Caddyfile.d/*.caddy`.

## Tasks

### 1. Обновить `scripts/bootstrap-vps.sh`

- Заменить `apt install nginx certbot python3-certbot-nginx` на `apt install caddy` (через официальный Caddy apt-repo: добавить ключ + source list — см. https://caddyserver.com/docs/install#debian-ubuntu-raspbian)
- Удалить шаги, связанные с certbot (renewal cron не нужен — Caddy сам)
- Создать `/etc/caddy/Caddyfile.d/` (пустая папка для per-site конфигов)
- В основном `/etc/caddy/Caddyfile` оставить только:
  ```
  {
      email <admin-email-from-env>
  }
  import /etc/caddy/Caddyfile.d/*.caddy
  ```
- Параметр `CADDY_ADMIN_EMAIL` сделать env-переменной скрипта (для ACME)
- Тестировать `caddy validate --config /etc/caddy/Caddyfile` перед `systemctl reload caddy`

### 2. Обновить `docs/server-manual-setup.md`

- Раздел про nginx переписать на Caddy
- Убрать упоминания certbot и cron renewal
- Добавить ссылки на официальную доку Caddy

### 3. Полностью переписать `docs/server-add-site.md`

Текущий nginx-шаблон → Caddy-шаблон. Под каждый сайт — отдельный файл `/etc/caddy/Caddyfile.d/{site}.caddy`:

```caddyfile
{site}.com {
    reverse_proxy localhost:{prod-port}
    encode gzip zstd
    @static path *.css *.js *.woff2 *.png *.jpg *.webp *.avif *.svg *.ico
    header @static Cache-Control "public, max-age=31536000, immutable"
    @html path *.html /
    header @html Cache-Control "public, max-age=0, must-revalidate"
}

# Опционально dev-поддомен:
dev.{site}.com {
    reverse_proxy localhost:{dev-port}
    encode gzip zstd
    basicauth {
        dev <bcrypt-hash>
    }
}
```

- Шаги «добавить файл → проверить `caddy validate` → `systemctl reload caddy`» (вместо `nginx -t && systemctl reload nginx`)

### 4. Обновить `docs/server-multisite.md`

Раздел про nginx → Caddy (multi-site через `Caddyfile.d/*.caddy`). Реестр портов в `~/ports.md` — без изменений.

### 5. Обновить `docs/deploy.md`

Все упоминания nginx → Caddy. ASCII-схема в начале — не трогать (она про Mac → GitHub → VPS, без nginx-специфики).

### 6. Обновить `docs/troubleshooting.md`

- Раздел «SSL-сертификат истёк» — переписать (Caddy сам обновляет, но если что — `caddy reload`)
- Добавить раздел «Caddy не стартует»: `journalctl -u caddy -n 50` + `caddy validate`
- Раздел про DDoS-Guard — оставить как есть (не зависит от веб-сервера)

### 7. Обновить runbook в `specs/12-handoff.md`

- Замена certbot-команд на Caddy-команды (но сам runbook оставить — заказчик читает его на готовом проекте)

### 8. (Опционально) Обновить `docs/automation.md`

Если упоминается certbot — заменить на Caddy.

## Done when

- `bootstrap-vps.sh` ставит Caddy, не nginx+certbot
- `docs/server-add-site.md` содержит Caddy-шаблон с reverse_proxy + encode + cache headers
- `docs/server-multisite.md` описывает multi-site через `Caddyfile.d/`
- `docs/troubleshooting.md` имеет Caddy-раздел
- `_BUILD/changelog.md` содержит запись `v2.3-caddy`
- Тег `v2.3-caddy` создан
- PR в main смёрджен

## Rollback Phase 1

```bash
git tag -d v2.3-caddy 2>/dev/null
git reset --hard pre-phase-1
```

## Memory updates после Phase 1

```
- Фаза 1 (Caddy) — done [YYYY-MM-DD], тег v2.3-caddy
- Следующая: Фаза 2 (DX: Biome + pnpm + mise + schema-dts)
```

---

# Фаза 2 — DX win: Biome, pnpm, mise, schema-dts (→ v2.3-dx)

## Goal

Заменить ESLint+Prettier на Biome, npm на pnpm, nvm на mise, добавить schema-dts. Это **DX-улучшения без архитектурных изменений** — все правки локальны на Mac разработчика.

## KB files to read first

- `docs/stack.md` — текущий стек
- `specs/01a-local-setup.md` — текущая Mac-инициализация
- `specs/02-project-init.md` — `create-next-app` + установка пакетов
- `_BUILD/HOW-TO-START.md` — раздел 0.4 (brew install gh node)
- `.claude/hooks/format.sh` — текущий хук с Prettier
- `CLAUDE.md` — раздел Commands

## Tasks

### 1. Biome вместо ESLint+Prettier

- В `docs/stack.md` — раздел про линтер: ESLint+Prettier → Biome. Добавить ссылку на https://biomejs.dev
- `specs/02-project-init.md` — заменить установку:
  ```bash
  pnpm add -D --save-exact @biomejs/biome
  pnpm exec biome init
  ```
- Добавить файл `biome.json.example` в bootstrap (или прописать в спеке 02 содержимое):
  ```json
  {
    "$schema": "https://biomejs.dev/schemas/2.x.x/schema.json",
    "files": { "ignore": ["node_modules", ".next", "out", "dist", "public/**/*.js"] },
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
    "javascript": { "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" } }
  }
  ```
- `package.json scripts` (в спеке 02 и в шаблоне):
  ```json
  "lint": "biome check",
  "format": "biome check --write",
  "typecheck": "tsc --noEmit"
  ```
  (заметь: добавляется `typecheck` отдельной командой)
- Удалить из стандартной установки: `eslint`, `eslint-config-next`, `prettier`, `prettier-plugin-tailwindcss` (Biome имеет свою сортировку Tailwind через `useSortedClasses`)
- Обновить `.claude/hooks/format.sh` — заменить вызов prettier на Biome:
  ```bash
  if [ -x "node_modules/.bin/biome" ]; then
    node_modules/.bin/biome check --write --no-errors-on-unmatched "$file" 2>/dev/null || true
  fi
  ```

### 2. pnpm вместо npm

- В `docs/stack.md` — упомянуть pnpm как дефолт, добавить заметку про экономию диска при multi-site
- Все упоминания `npm install` → `pnpm install`, `npm ci` → `pnpm install --frozen-lockfile`, `npm run X` → `pnpm X`
  - Файлы: `specs/01a, 01b, 02, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, optional/*`
  - `docs/stack.md`, `docs/deploy.md`, `docs/server-add-site.md`, `docs/server-multisite.md`, `docs/automation.md`, `docs/troubleshooting.md`, `docs/team-onboarding.md`, `docs/workflow.md`
  - `scripts/rollback.sh` — `npm ci` → `pnpm install --frozen-lockfile`
  - `_BUILD/HOW-TO-START.md` — раздел 0.4 — добавить `corepack enable && corepack prepare pnpm@latest --activate` после установки Node, или `brew install pnpm`
  - `CLAUDE.md` — Commands раздел — `npm` → `pnpm`
- В `bootstrap-vps.sh` — на VPS тоже ставить pnpm (`npm install -g pnpm` или corepack)

### 3. mise вместо nvm

- `_BUILD/HOW-TO-START.md` раздел 0.3+0.4 — переписать:
  ```bash
  brew install gh mise
  mise use --global node@22
  mise use --global pnpm@latest
  ```
  (вместо `brew install gh node` и manual nvm)
- `specs/01a-local-setup.md` — раздел про `.nvmrc` → создание `.tool-versions`:
  ```
  node 22
  pnpm latest
  ```
- `docs/team-onboarding.md` — упоминания nvm → mise
- В bootstrap-репо в корне создать `.tool-versions` файл (как пример для нового проекта — Claude его клонирует или копирует на спеке 02)

### 4. schema-dts для типобезопасного JSON-LD

- В `docs/stack.md` — раздел вспомогательных пакетов: добавить `schema-dts` (типы Schema.org от Google)
- `specs/02-project-init.md` — добавить в `pnpm add -D`: `schema-dts`
- `specs/05-subpages-template.md` — пример `lib/schema.ts` обернуть в типы:
  ```typescript
  import type { WithContext, Service, BreadcrumbList, FAQPage } from 'schema-dts'

  export function generateServiceSchema(data: ServicePageData): WithContext<Service> {
    return {
      '@context': 'https://schema.org',
      '@type': 'Service',
      name: data.metaTitle,
      // ...
    }
  }
  ```
- `specs/08-seo-schema.md` — `lib/schema.ts` функции типизировать через `schema-dts`

### 5. Обновить `_BUILD/HOW-TO-START.md`

Раздел 0.3–0.4 переписан как:

```markdown
### 0.3. Homebrew

(оставить как есть)

### 0.4. mise + Node + pnpm

brew install gh mise
mise use --global node@22
mise use --global pnpm@latest

# Активация mise в shell:
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc

# Проверка:
node --version  # v22.x
pnpm --version  # 9.x или 10.x
```

### 6. Записать в changelog

`v2.3-dx` запись с перечислением: «Biome (lint+format), pnpm, mise, schema-dts». Кратко указать выгоду для каждого.

## Done when

- В bootstrap нет упоминаний `prettier`, `eslint-config-next` (кроме исторических в changelog)
- Все `npm` команды → `pnpm` (грепом проверить: `grep -rn "npm install\|npm ci\|npm run" --include="*.md" --include="*.sh"`)
- `.nvmrc` упоминания заменены на `.tool-versions`
- `.claude/hooks/format.sh` использует Biome
- В `docs/stack.md` упомянут `schema-dts`
- `_BUILD/HOW-TO-START.md` обновлён (mise + pnpm)
- `_BUILD/changelog.md` имеет запись `v2.3-dx`
- Тег `v2.3-dx` создан, PR в main смёрджен

## Rollback Phase 2

```bash
git tag -d v2.3-dx 2>/dev/null
git reset --hard pre-phase-2
```

## Memory updates после Phase 2

```
- Фаза 2 (DX win) — done [YYYY-MM-DD], тег v2.3-dx
- Следующая: Фаза 3 (Turnstile + Content Collections)
```

---

# Фаза 3 — Cloudflare Turnstile + Content Collections (→ v2.4)

## Goal

Закрыть две функциональные дыры: **антиспам в формах** (Cloudflare Turnstile) и **типобезопасный MDX-стек** для блога/контентных страниц (Content Collections вместо `next-mdx-remote`).

## KB files to read first

- `docs/forms-and-crm.md` — текущая архитектура форм
- `specs/09-forms-crm.md` — спека по формам
- `specs/07-blog-optional.md` — текущий блог на `next-mdx-remote`
- `docs/architecture.md` — раздел про MDX
- `docs/stack.md` — список зависимостей
- (внешние) https://www.content-collections.dev/, https://developers.cloudflare.com/turnstile/

## Tasks

### 1. Cloudflare Turnstile

- В `docs/forms-and-crm.md` добавить раздел «Антиспам — Cloudflare Turnstile»:
  - Как получить site-key и secret-key (Cloudflare → Turnstile → My Site → Add Site, выбрать **Managed** widget — invisible или checkbox по контексту)
  - В `.env`: `NEXT_PUBLIC_TURNSTILE_SITE_KEY=...`, `TURNSTILE_SECRET_KEY=...`
  - Клиентская часть — через официальный `@marsidev/react-turnstile` или собственный `<Script>`
  - Серверная проверка в `/api/lead`:
    ```typescript
    const verify = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        secret: process.env.TURNSTILE_SECRET_KEY!,
        response: token,
        remoteip: ip,
      }),
    })
    const result = await verify.json()
    if (!result.success) return NextResponse.json({ error: 'Captcha failed' }, { status: 400 })
    ```
- В `specs/09-forms-crm.md` добавить шаги:
  - X. Установить `@marsidev/react-turnstile`
  - X+1. Получить site-key и secret-key, положить в `.env`
  - X+2. Добавить `<Turnstile />` компонент в формы (ConsultationDialog, inline LeadForm)
  - X+3. В `/api/lead` добавить проверку токена ДО CRM-вызова
- В `docs/stack.md` добавить `@marsidev/react-turnstile` в вспомогательные пакеты
- Если у заказчика уже есть Cloudflare-аккаунт (см. `docs/domain-connect.md`) — Turnstile там же. Если нет — отдельная регистрация.

### 2. Content Collections

- В `docs/architecture.md` раздел «MDX для контента» — переписать под Content Collections
- В `docs/stack.md` заменить `next-mdx-remote` на `content-collections` + `@content-collections/mdx`
- **Полностью переписать `specs/07-blog-optional.md`** под Content Collections:
  - Установка:
    ```bash
    pnpm add content-collections @content-collections/core @content-collections/mdx @content-collections/next
    ```
  - `content-collections.ts` в корне:
    ```typescript
    import { defineCollection, defineConfig } from '@content-collections/core'
    import { compileMDX } from '@content-collections/mdx'
    import { z } from 'zod'

    const posts = defineCollection({
      name: 'posts',
      directory: 'content/blog',
      include: '**/*.mdx',
      schema: z.object({
        title: z.string(),
        description: z.string(),
        date: z.string(),
        author: z.string().optional(),
        cover: z.string().optional(),
        tags: z.array(z.string()).optional(),
      }),
      transform: async (doc, ctx) => {
        const mdx = await compileMDX(ctx, doc)
        return { ...doc, mdx, slug: doc._meta.path }
      },
    })

    export default defineConfig({ collections: [posts] })
    ```
  - В `next.config.ts` обернуть `withContentCollections(nextConfig)`
  - Использование в `app/blog/page.tsx`:
    ```typescript
    import { allPosts } from 'content-collections'
    // полностью типизированный массив
    ```
  - В `app/blog/[slug]/page.tsx`:
    ```typescript
    import { MDXContent } from '@content-collections/mdx/react'
    const post = allPosts.find(p => p.slug === slug)
    return <MDXContent code={post.mdx} components={{ Callout }} />
    ```
- Update `.claude/memory/pointers.md` шаблон — заменить «`lib/blog.ts`» на «`content-collections.ts` (config) + автогенерированный `allPosts`»

### 3. Записать в changelog

`v2.4` с двумя главными добавлениями.

## Done when

- `docs/forms-and-crm.md` имеет раздел Turnstile с конкретным кодом
- `specs/09-forms-crm.md` содержит шаги установки и проверки токена
- `specs/07-blog-optional.md` полностью на Content Collections (нет упоминаний `next-mdx-remote` в этой спеке)
- `docs/stack.md` обновлён
- `_BUILD/changelog.md` запись `v2.4`
- Тег `v2.4` создан, PR смёрджен

## Rollback Phase 3

```bash
git tag -d v2.4 2>/dev/null
git reset --hard pre-phase-3
```

## Memory updates после Phase 3

```
- Фаза 3 (Turnstile + Content Collections) — done [YYYY-MM-DD], тег v2.4
- Следующая: Фаза 4 (Next.js 16 паттерны)
```

---

# Фаза 4 — Next.js 16 паттерны (→ v3.0-next16)

## Goal

Перейти на современные паттерны Next.js 16: **Server Actions для форм** (вместо POST + Route Handler), **`use cache` директива**, **PPR где уместно**, **`useActionState` + `useOptimistic`** в формах.

## KB files to read first

- `docs/architecture.md` — Server/Client разделение
- `docs/forms-and-crm.md` — текущая архитектура форм
- `specs/04-homepage-and-approval.md` — где формы появляются
- `specs/05-subpages-template.md` — `ServicePageForms.tsx` client-компонент
- `specs/09-forms-crm.md` — `/api/lead` POST handler
- (внешние) https://nextjs.org/docs/app/api-reference/directives/use-cache, https://nextjs.org/docs/app/getting-started/fetching-data

## Tasks

### 1. Server Actions для лидов

- **Полностью заменить** `app/api/lead/route.ts` на Server Action в `app/actions/submit-lead.ts`:
  ```typescript
  'use server'
  import { z } from 'zod'
  import { sendToCRM } from '@/lib/crm'
  import { appendFallback } from '@/lib/fallback'
  import { rateLimit } from '@/lib/rate-limit'
  import { headers } from 'next/headers'

  const schema = z.object({
    name: z.string().min(2),
    phone: z.string().min(10),
    email: z.string().email().optional(),
    message: z.string().optional(),
    source: z.string(),
    consent: z.literal(true),
    turnstileToken: z.string(),
  })

  export async function submitLead(prevState: unknown, formData: FormData) {
    const ip = (await headers()).get('x-forwarded-for') ?? 'unknown'
    if (!rateLimit(ip, 1, 10_000)) {
      return { error: 'Слишком много запросов. Подождите минуту.' }
    }

    const parsed = schema.safeParse(Object.fromEntries(formData))
    if (!parsed.success) return { error: 'Проверьте поля формы' }

    // Turnstile verify
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
- В клиентской форме использовать `useActionState`:
  ```typescript
  'use client'
  import { useActionState } from 'react'
  import { submitLead } from '@/app/actions/submit-lead'

  const [state, formAction, isPending] = useActionState(submitLead, null)
  // <form action={formAction}>...</form>
  ```
- Удалить `app/api/lead/route.ts` (не нужен)
- Обновить `docs/forms-and-crm.md` — раздел архитектуры:
  - Убрать `[/api/lead/route.ts]` из ASCII-схемы, заменить на `[Server Action: submitLead]`
  - Указать, что endpoint `/api/lead` больше не существует — формы обращаются напрямую к Server Action
- Обновить `specs/09-forms-crm.md` — переписать первые шаги под Server Action

### 2. `use cache` директива

- В `docs/performance.md` добавить раздел «§ N: Кэширование с `use cache`»:
  - Что это, когда применять (статичные секции, MDX-контент, расчёты на основе константных данных)
  - Пример: `use cache` на функцию `getAllPosts()`, чтобы не перепарсить MDX на каждом запросе
- В `specs/07-blog-optional.md` — обновлено в Фазе 3 (Content Collections), но добавить пометку, что `getAllPosts()` может быть обёрнут `use cache` для дополнительного кеширования (хотя Content Collections и так build-time)
- В `specs/05-subpages-template.md` — упомянуть `use cache` для тяжёлых server-компонентов

### 3. PPR (опционально, экспериментальная фича)

- В `docs/architecture.md` упомянуть Partial Prerendering как опциональную фичу
- В `next.config.ts` шаблоне добавить:
  ```typescript
  experimental: {
    ppr: 'incremental', // включается на конкретных роутах через export const experimental_ppr = true
  }
  ```
- Объяснить trade-off: PPR полезен для страниц со статичной шапкой + динамическим блоком («осталось N мест»). Не для всех страниц.

### 4. `useOptimistic` для UI без задержки

- В `docs/forms-and-crm.md` упомянуть паттерн: пока Server Action летит — оптимистично показать «Заявка принята», откатить если ошибка.
- Не делать обязательным — это nice-to-have для UX.

### 5. Tailwind v4 OKLCH колоры

- В `docs/design-system.md` — раздел Цветовая палитра — упомянуть, что в Tailwind v4 удобно использовать OKLCH:
  ```css
  @theme {
    --color-primary: oklch(0.45 0.15 250);
    --color-accent: oklch(0.65 0.20 30);
  }
  ```
- Объяснить, почему OKLCH лучше HSL/RGB (плавные градиенты, предсказуемые тени).
- В `specs/03-design-system.md` дать пример с OKLCH.

### 6. Записать в changelog

`v3.0-next16` с описанием Server Actions + use cache + PPR + OKLCH.

## Done when

- `app/api/lead/route.ts` упоминаний нет (Server Action в `app/actions/`)
- `docs/forms-and-crm.md` обновлена ASCII-схема
- `docs/performance.md` имеет раздел `use cache`
- `docs/design-system.md` упоминает OKLCH
- `_BUILD/changelog.md` запись `v3.0-next16`
- Тег `v3.0-next16`, PR в main

## Rollback Phase 4

```bash
git tag -d v3.0-next16 2>/dev/null
git reset --hard pre-phase-4
```

## Memory updates после Phase 4

```
- Фаза 4 (Next.js 16 паттерны) — done [YYYY-MM-DD], тег v3.0-next16
- Следующая: Фаза 5 (push-based deploy + standalone + ключи) — крупная, готовься к нескольким сессиям внутри
```

---

# Фаза 5 — Push-based deploy + standalone + раздельные ключи (→ v3.0-deploy)

## Goal

Перейти с **pull-based** (Actions → SSH → git pull → build на VPS → pm2 restart) на **push-based** (build на runner → rsync артефакта → атомарный switch симлинком). Привести в порядок SSH-ключи (приватный только в GitHub Secrets, на VPS — публичный в `authorized_keys`). Это **самая рискованная фаза** — внимательнее.

⚠️ **Без обкатки на тестовом VPS** — пользователь готов править ошибки на лету. Поэтому ТЗ содержит особенно подробный rollback-план и явные точки коммита.

## KB files to read first

- `docs/deploy.md` — текущая ASCII-схема и описание workflow
- `scripts/bootstrap-vps.sh` — раздел про deploy_key
- `scripts/rollback.sh` — текущая логика отката
- `scripts/sync-env.sh` — текущая sync секретов
- `specs/01b-server-handoff.md` — генерация workflow YAML
- `specs/12-handoff.md` — runbook для заказчика
- `specs/14-migrate.md` — там тоже pull-based, тоже править
- `docs/automation.md` — описание скриптов
- (внешние) https://nextjs.org/docs/app/getting-started/deploying, https://nextjs.org/docs/messages/install-sharp

## Sub-phases (рекомендуется делить внутри одной фазы)

Фаза 5 большая. Разбейте на коммиты:
- 5.1 — `output: 'standalone'` в `next.config.ts` шаблоне + обновить `package.json`
- 5.2 — Новый `.github/workflows/deploy-prod.yml.example` (build на runner + rsync + симлинк)
- 5.3 — Раздельные SSH-ключи (один Actions→VPS, второй опционально для git fetch на VPS — или вообще убрать git с VPS)
- 5.4 — Структура `releases/<sha>/` + симлинк `current` на VPS, обновить `bootstrap-vps.sh` и `server-add-site.md`
- 5.5 — Переписать `scripts/rollback.sh` под симлинк-switch
- 5.6 — `.env` через GitHub Environment Secrets вместо `sync-env.sh` (сам `sync-env.sh` оставить как fallback инструмент или удалить)
- 5.7 — Переписать `specs/01b-server-handoff.md`, `specs/12-handoff.md` runbook, `specs/14-migrate.md`
- 5.8 — Обновить `docs/deploy.md`, `docs/troubleshooting.md` (новые сценарии)

Каждая sub-phase — отдельный коммит. Не сливать всё в один.

## Tasks

### 1. (5.1) `output: 'standalone'`

- В `docs/stack.md` удалить блок «Почему без `output: "standalone"`»
- В `next.config.ts` шаблоне (в спеке 02 или в стартовом проекте) добавить:
  ```typescript
  const nextConfig = {
    output: 'standalone',
    compress: false,                   // gzip отдаёт Caddy
    reactStrictMode: true,
    images: { /* ... */ },
    experimental: { ppr: 'incremental' },
  }
  ```
- В `specs/02-project-init.md` явно прописать включение standalone

### 2. (5.2) Новый GitHub Actions workflow

- Создать в `_BUILD/v3/templates/deploy-prod.yml.example` (или сразу в `specs/01b-server-handoff.md` как шаблон):
  ```yaml
  name: Deploy production
  on:
    push:
      branches: [main]

  concurrency:
    group: deploy-prod-${{ vars.SITE_NAME }}
    cancel-in-progress: false

  jobs:
    build:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: pnpm/action-setup@v4
          with: { version: latest }
        - uses: actions/setup-node@v4
          with: { node-version: 22, cache: 'pnpm' }
        - run: pnpm install --frozen-lockfile
        - run: pnpm build
          env:
            NEXT_TELEMETRY_DISABLED: 1
            NEXT_PUBLIC_TURNSTILE_SITE_KEY: ${{ secrets.NEXT_PUBLIC_TURNSTILE_SITE_KEY }}
            NEXT_PUBLIC_YM_ID: ${{ secrets.NEXT_PUBLIC_YM_ID }}
            NEXT_PUBLIC_GA_ID: ${{ secrets.NEXT_PUBLIC_GA_ID }}
        - name: Pack standalone
          run: |
            mkdir -p deploy
            cp -r .next/standalone/. deploy/
            cp -r .next/static deploy/.next/static
            cp -r public deploy/public
        - uses: actions/upload-artifact@v4
          with: { name: app, path: deploy, retention-days: 5 }

    deploy:
      needs: build
      runs-on: ubuntu-latest
      environment: production
      steps:
        - uses: actions/download-artifact@v4
          with: { name: app, path: deploy }
        - name: Setup SSH
          run: |
            mkdir -p ~/.ssh
            echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_ed25519
            chmod 600 ~/.ssh/id_ed25519
            ssh-keyscan -H ${{ secrets.SSH_HOST }} >> ~/.ssh/known_hosts
        - name: Rsync to release dir
          run: |
            RELEASE_DIR="/home/deploy/prod/${{ vars.SITE_NAME }}/releases/${{ github.sha }}"
            ssh -i ~/.ssh/id_ed25519 -p ${{ secrets.SSH_PORT || 22 }} \
                ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
                "mkdir -p $RELEASE_DIR"
            rsync -az --delete \
                -e "ssh -i ~/.ssh/id_ed25519 -p ${{ secrets.SSH_PORT || 22 }}" \
                deploy/ \
                ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:$RELEASE_DIR/
        - name: Push .env from secrets
          run: |
            ENV_DIR="/home/deploy/prod/${{ vars.SITE_NAME }}/releases/${{ github.sha }}"
            ssh -i ~/.ssh/id_ed25519 -p ${{ secrets.SSH_PORT || 22 }} \
                ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
                "cat > $ENV_DIR/.env" <<EOF
            ${{ secrets.PROD_ENV_FILE }}
            EOF
            ssh -i ~/.ssh/id_ed25519 -p ${{ secrets.SSH_PORT || 22 }} \
                ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
                "chmod 600 $ENV_DIR/.env"
        - name: Activate release
          run: |
            ssh -i ~/.ssh/id_ed25519 -p ${{ secrets.SSH_PORT || 22 }} \
                ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
                "ln -sfn /home/deploy/prod/${{ vars.SITE_NAME }}/releases/${{ github.sha }} \
                         /home/deploy/prod/${{ vars.SITE_NAME }}/current && \
                 pm2 reload ${{ vars.SITE_NAME }}-prod --update-env || \
                 pm2 start /home/deploy/prod/${{ vars.SITE_NAME }}/current/server.js \
                          --name ${{ vars.SITE_NAME }}-prod --update-env"
        - name: Cleanup old releases (keep last 5)
          run: |
            ssh -i ~/.ssh/id_ed25519 -p ${{ secrets.SSH_PORT || 22 }} \
                ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} \
                "cd /home/deploy/prod/${{ vars.SITE_NAME }}/releases && \
                 ls -1tr | head -n -5 | xargs -r rm -rf"
  ```
- Аналогичный `deploy-dev.yml.example` для ветки `dev`.
- Секреты репо (`gh secret set`):
  - `SSH_PRIVATE_KEY` — приватный (только здесь!)
  - `SSH_HOST` — IP VPS
  - `SSH_USER` — `deploy`
  - `SSH_PORT` — `2222` (или 22)
  - `PROD_ENV_FILE` — содержимое `.env.production` целиком (multiline secret)
  - `NEXT_PUBLIC_*` — для билд-тайма
- Variables: `SITE_NAME` — имя сайта.

### 3. (5.3) Раздельные SSH-ключи

Подход: **на VPS не должно быть приватного ключа**, который имеет доступ к GitHub. Для этого:

- На Mac разработчика сгенерировать **новый** ключ для деплоя:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/{site}-deploy -N "" -C "{site}-deploy"
  ```
- Публичную часть положить в `~/.ssh/authorized_keys` пользователя `deploy` на VPS (вручную или скриптом)
- Приватную часть положить в GitHub Secrets `SSH_PRIVATE_KEY` через `gh secret set SSH_PRIVATE_KEY < ~/.ssh/{site}-deploy`
- Удалить приватный ключ с Mac после загрузки в Secrets (опционально, но безопаснее)
- На VPS у `deploy`-юзера **больше нет** `~/.ssh/deploy_key` (его старая роль — git pull — больше не нужна, билд на runner)
- Обновить `bootstrap-vps.sh` — удалить шаги генерации `deploy_key` и добавления в собственный authorized_keys. Оставить только: установить публичный ключ разработчика в `authorized_keys`.
- Обновить `docs/server-manual-setup.md` — раздел про `deploy_key` переписать
- Обновить `docs/server-add-site.md` — упоминания deploy_key и git clone переписать (теперь VPS НЕ клонирует репо, только принимает rsync)

### 4. (5.4) Структура `releases/<sha>/` на VPS

- В `docs/server-add-site.md` (или в шаблоне add-site) — структура папок сайта на VPS:
  ```
  /home/deploy/prod/{site}/
    releases/
      <sha-1>/      ← старый
      <sha-2>/
      <sha-3>/      ← новый, переключается симлинком
    current -> releases/<sha-3>
  ```
- Симлинк `current` указывает на активный релиз. PM2 запускает `current/server.js`. Switch версии = `ln -sfn`.
- Изначально (первый деплой) папка `current` ещё не существует — workflow её создаёт через `ln -sfn`.

### 5. (5.5) Переписать `scripts/rollback.sh`

Старая логика (`git reset --hard + npm ci + build + restart`) больше не нужна. Новая:
```bash
#!/usr/bin/env bash
# Откат на предыдущий релиз через симлинк.
# Usage: scripts/rollback.sh [site] [ssh_alias]
set -euo pipefail

site="${1:-}"
ssh_alias="${2:-}"

if [ -z "$site" ]; then
  site=$(node -p "require('./package.json').name")
fi
if [ -z "$ssh_alias" ]; then
  ssh_alias="$site"
fi

ssh "$ssh_alias" bash <<EOF
set -euo pipefail
cd "/home/deploy/prod/${site}"
current_sha=\$(readlink current | xargs basename)
prev_sha=\$(ls -1tr releases | grep -v "\$current_sha" | tail -1)
if [ -z "\$prev_sha" ]; then
  echo "ERROR: no previous release to roll back to" >&2
  exit 1
fi
echo "Rolling back: \$current_sha -> \$prev_sha"
ln -sfn "/home/deploy/prod/${site}/releases/\$prev_sha" current
pm2 reload "${site}-prod" --update-env
echo "Done. current -> \$prev_sha"
EOF
```

Обновить `docs/automation.md` — описание `rollback.sh`. Указать, что rollback атомарный за миллисекунды и **не пересобирает** проект.

### 6. (5.6) `.env` через GitHub Environment Secrets

- Старый `scripts/sync-env.sh` — **оставить** как fallback (если нужно подкинуть env между деплоями руками), но в дефолтном flow он не нужен.
- Документировать в `_BUILD/HOW-TO-START.md`: «секреты живут в GitHub Environment `production`, добавляются через `gh secret set --env production`».
- В workflow используется `${{ secrets.PROD_ENV_FILE }}` (multiline) — пользователь хранит весь .env как один secret. Альтернатива — каждое значение отдельным secret и собирать в workflow.

### 7. (5.7) Переписать спеки 01b, 12, 14

- `specs/01b-server-handoff.md` — Tasks 1–4 (генерация YAML и nginx-шаблона) полностью переписать под новый workflow + Caddy
- `specs/12-handoff.md` — runbook section («Откат на последнюю рабочую версию», «Обновления из GitHub не приехали») — обновить команды под новую схему
- `specs/14-migrate.md` — Tasks 4 (GitHub Secrets) и 5 (DNS switchover) — обновить новыми именами секретов и без deploy_key

### 8. (5.8) Обновить docs

- `docs/deploy.md` — ASCII-схема и описание workflow
- `docs/troubleshooting.md` — новые сценарии:
  - «Симлинк current не переключился» (проверить permissions, права на ln)
  - «rsync завершился с ошибкой» (проверить SSH-доступ, размер артефакта, диск на VPS)
  - «PM2 не находит server.js в current/» (первый деплой, current ещё не создан — workflow должен это покрыть, но если упало — `ln -sfn releases/<sha> current` руками)

### 9. Записать в changelog

`v3.0-deploy` с описанием push-based + standalone + симлинк-релизы + раздельные ключи.

## Done when

- В bootstrap нигде не упоминается `git pull && npm ci && npm run build` как часть deploy (грепом проверить)
- В `specs/01b-server-handoff.md` workflow.yml содержит build на runner + rsync + симлинк
- `scripts/rollback.sh` переписан под симлинк-switch
- `bootstrap-vps.sh` не генерирует `deploy_key` (только устанавливает публичный ключ разработчика)
- `docs/troubleshooting.md` имеет новые сценарии
- `_BUILD/changelog.md` запись `v3.0-deploy`
- Тег `v3.0-deploy`, PR в main

## Rollback Phase 5

```bash
git tag -d v3.0-deploy 2>/dev/null
git reset --hard pre-phase-5
```

⚠️ Если ошибка обнаружится **после** того, как ты запустишь миграцию реального сайта (Артефакт 2) — откат сложнее. Тогда: на конкретном сайте через `git checkout v2.4` (старая версия workflow.yml), на bootstrap — `git reset --hard pre-phase-5`. Действовать через изоляцию по одному сайту.

## Memory updates после Phase 5

```
- Фаза 5 (push-based deploy) — done [YYYY-MM-DD], тег v3.0-deploy
- Следующая: Фаза 6 (multi-Claude handoff + HOW-TO-START + claude-md-template)
```

---

# Фаза 6 — Multi-Claude handoff + новый HOW-TO-START + claude-md-template (→ v3.0)

## Goal

Финальная фаза. Оформить **протокол sequential multi-Claude** (несколько сессий на один проект, передача через память + slash-команды). Полностью переписать `_BUILD/HOW-TO-START.md` и `_BUILD/claude-md-template.md` под v3.0. Поставить тег `v3.0`.

## KB files to read first

- `docs/workflow.md` — текущая дисциплина сессий
- `_BUILD/HOW-TO-START.md` — текущий onboarding (271 строка)
- `_BUILD/claude-md-template.md` — текущий шаблон CLAUDE.md
- `CLAUDE.md` — корневой
- `.claude/memory/INDEX.md`, `.claude/memory/project_state.md` — память
- `.claude/hooks/session-start.sh` — что хук делает при старте

## Tasks

### 1. Sequential multi-Claude протокол

Идея: **одна Claude-сессия за раз** на проекте, но разные сессии в разное время продолжают работу через память. Нужно явно описать handoff и resume.

#### 1a. Расширить `.claude/memory/project_state.md` шаблон

Текущий шаблон минимальный. Расширить до структурированного «session log»:

```markdown
---
name: project_state
description: Активная фаза, текущая спека, открытые задачи, журнал сессий
type: project
---

# Project state

## Active phase
[Например: «спека 06-subpages-rollout, в работе 5 из 12 страниц»]

## Active spec
- File: `specs/[XX]-[name].md`
- Status: in progress / on review / blocked
- Started: [YYYY-MM-DD]

## Blockers
- [блокер] — ждём от [кого] до [когда]

## Next 1-3 steps
1. [...]
2. [...]

## Session log

### Session [YYYY-MM-DD HH:MM] — [короткая суть]

**Done in this session:**
- [что сделано]
- [файлы тронуты — точные пути]

**Open at handoff:**
- [что осталось — конкретно]

**Uncommitted changes:** [нет / есть, перечислить]

**Resume hint:** [короткая подсказка следующей сессии]

---

(новые сессии добавляются сверху)

## Completed specs history
- [YYYY-MM-DD] `00-brief.md` — done
- [YYYY-MM-DD] `01a-local-setup.md` — done
- [...]
```

#### 1b. Slash-команды через `.claude/commands/`

Создать в `.claude/commands/`:

**`.claude/commands/handoff.md`:**
```markdown
---
description: Завершить сессию красиво — обновить project_state.md и подготовить hand-off для следующей сессии
---

Сделай следующее:

1. Прочитай `.claude/memory/project_state.md`.
2. Запиши в раздел «Session log» новую запись с текущей датой:
   - **Done in this session** — что было реально сделано (по коммитам и правкам)
   - **Open at handoff** — что не доделано, на чём остановились
   - **Uncommitted changes** — `git status --porcelain` итог
   - **Resume hint** — короткая подсказка для следующей сессии (1–2 предложения)
3. Если есть uncommitted changes — спроси пользователя: коммитить или сохранить как есть.
4. Обнови «Active phase», «Active spec», «Next steps».
5. Сообщи пользователю: «Handoff записан. Можешь делать /clear, следующая сессия продолжит с проекта state.»
```

**`.claude/commands/resume.md`:**
```markdown
---
description: Продолжить работу в новой сессии — прочитать память, проверить git-state, восстановить контекст
---

Сделай следующее:

1. Прочитай `.claude/memory/INDEX.md`, затем `.claude/memory/project_state.md`.
2. Прочитай последнюю запись в «Session log».
3. Сравни с реальностью:
   - `git status --porcelain` — совпадает ли с «Uncommitted changes» из лога?
   - `git log --oneline -10` — соответствует ли последним «Done» из лога?
4. Если есть расхождение — стоп, опиши пользователю что не сходится, спроси как продолжить.
5. Если всё ОК — кратко (3–5 строк) обобщи пользователю:
   - Где мы остановились
   - Что планируется дальше (Next steps)
   - Какая активная спека
6. Жди подтверждения от пользователя на старт работы.
```

**`.claude/commands/catchup.md`** (упомянут в workflow.md, но нет файла) — реализовать:
```markdown
---
description: Восстановить контекст проекта по последним изменениям (диф ветки от main)
---

1. `git log main..HEAD --oneline` — что в текущей ветке нового
2. `git diff main..HEAD --stat` — какие файлы изменены
3. Прочитай `.claude/memory/project_state.md` и сравни с git-историей
4. Кратко (5–10 строк) опиши пользователю: где мы по фазе, что в работе, что недавно коммитили
5. Не лезь в код глубже без запроса
```

Зарегистрировать команды (если не автоматически — в `.claude/settings.json`).

#### 1c. Stop-хук для напоминания о handoff

В `.claude/hooks/` создать `stop-reminder.sh` (или дополнить существующий механизм):
```bash
#!/usr/bin/env bash
# Напоминает в конце сессии обновить project_state.md, если были коммиты
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root" || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
session_start_sha=$(cat /tmp/.claude-session-start-sha 2>/dev/null || echo "")
current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")

if [ -n "$session_start_sha" ] && [ "$session_start_sha" != "$current_sha" ]; then
  echo "[stop-reminder] В этой сессии были коммиты. Если уходите надолго — выполните /handoff." >&2
fi
exit 0
```

Зарегистрировать в `.claude/settings.json` под `Stop` событие. И в `session-start.sh` добавить запись текущего sha в `/tmp/.claude-session-start-sha`.

### 2. Полностью переписать `_BUILD/HOW-TO-START.md`

Структура нового HOW-TO-START:

```markdown
# Как работать с bootstrap v3

## 0. Первичная настройка Mac (один раз в жизни)
- 0.1 GitHub аккаунт
- 0.2 Claude Code Desktop
- 0.3 Terminal + Xcode CLT
- 0.4 Homebrew + gh + mise + pnpm
   brew install gh mise
   mise use --global node@22
   mise use --global pnpm@latest
   echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
- 0.5 Git identity
- 0.6 SSH-ключ
- 0.7 gh auth login

## 1. Создать новый проект из v3-шаблона
   cd ~/projects
   gh repo create <твой-логин>/{site} --template tem11134v2-cmd/web-dev-bootstrap --private --clone
   cd {site}

## 2. Открыть в Claude Desktop, стартовый промт
   Прочитай CLAUDE.md и specs/INDEX.md. Затем открой specs/00-brief.md и проведи меня по нему.

## 3. Работа в одной сессии = одна спека
   Закончил спеку → /handoff → /clear → новая сессия.

## 4. Стартовый промт для **продолжения** работы в существующем v3-проекте
   /resume

   Если /resume не сработает (кеш слетел) — длинный вариант:
   Прочитай CLAUDE.md, .claude/memory/INDEX.md, .claude/memory/project_state.md.
   Покажи краткое резюме где мы остановились и что планируется.

## 5. Развернуть на сервере (один раз на проект)
   После спеки 01b в репо появятся .github/workflows/deploy-prod.yml и deploy/README.md.
   Иди по deploy/README.md (поднять VPS через bootstrap-vps.sh, добавить сайт через add-site, прописать секреты в GitHub).

## 6. Откатить прод
   На Mac: scripts/rollback.sh
   (откатывает на предыдущий релиз через симлинк, миллисекунды, не пересобирает)

## 7. Несколько проектов
   Один проект = одна папка в ~/projects. Один Claude-чат = один проект. Параллельные чаты на разные проекты — ОК. Параллельные чаты на ОДИН проект — НЕ ОК (две сессии правят одно и то же).

## 8. Мигрировать старый проект (v2.x) на v3
   В папке старого проекта — новый Claude-чат.
   Стартовый промт:
   Прочитай файл `~/ClaudeCode/web-dev-bootstrap/_BUILD/v3/02-migrate-existing-project.md`
   и выполни его на этом проекте. Сначала покажи план миграции, жди подтверждения.

## 9. Обновить сам bootstrap (для меня, разработчика)
   В папке ~/ClaudeCode/web-dev-bootstrap — новый чат.
   Если запускаешь _BUILD/v3/01-bootstrap-refactor.md (этот документ) — стартовый промт описан в его начале.
   Если просто продолжаешь правки — /resume.

## 10. Что делать если сломалось
   - "Claude залип / повторяет круги" → /clear → /resume
   - "После /resume Claude думает что мы в другой фазе" → проверить .claude/memory/project_state.md, исправить вручную
   - "Push в GitHub блокируется хуком" → gh auth switch -h github.com -u <owner>
   - "Прод не отвечает" → scripts/rollback.sh

## Частые косяки
   (раздел сохранить, актуализировать под v3)

## Где что лежит на Mac
   (актуализировать раздел)

## Что делать дальше после первого сайта
   (актуализировать)
```

Проверь, что полный документ ≤ 250 строк (текущий 271). Если получается длиннее — разбить на «0. Setup Mac» (один раз) и «1+. Работа с проектами» (повторяющееся), но в одном файле, секциями.

### 3. Переписать `_BUILD/claude-md-template.md`

Текущий шаблон рассинхронизирован с CLAUDE.md (нет секции «Automation rules», устарели Commands, нет правил мульти-Claude). Сделать **точную копию текущего CLAUDE.md** + плейсхолдеры для проекта. То есть после `cp _BUILD/claude-md-template.md CLAUDE.md` пользователь получает полностью валидный шаблон под v3.

Проверка: `diff CLAUDE.md _BUILD/claude-md-template.md` должен показать только различия в плейсхолдерах (`# Project: [Name]` и т.п.).

### 4. Обновить корневой `CLAUDE.md`

Добавить секцию `## Multi-Claude protocol`:
```markdown
## Multi-Claude protocol

Одна Claude-сессия = одна задача (одна спека). Параллельные сессии на ОДНУ папку проекта запрещены. Последовательные — норма:

- **Закончил работу:** `/handoff` — Claude обновит `.claude/memory/project_state.md` с состоянием.
- **Начал новую сессию:** `/resume` — Claude прочитает память, сверится с git, восстановит контекст.
- **Сломалось:** `/clear` → `/resume` (или ручная правка `project_state.md`, если совсем плохо).

Никогда не работай с двумя открытыми Claude-чатами на одну папку проекта — они не видят друг друга, поломают `project_state.md`.
```

### 5. Финальная проверка bootstrap'а

Прогнать через бутстрап «как будто впервые открываю»:
- `README.md` читается без устаревших ссылок
- `CLAUDE.md` без устаревших версий и упоминаний
- `_BUILD/HOW-TO-START.md` пошагово ведёт от пустого Mac до первого Claude-чата
- `_BUILD/claude-md-template.md` соответствует CLAUDE.md
- `specs/INDEX.md` граф зависимостей актуален (без A/B схем, ConsultationDialog в спеке 04, и т.д.)
- `docs/INDEX.md` — таблица «когда читать» актуальна
- В корне `.tool-versions` существует с `node 22` и `pnpm latest`

### 6. Записать в changelog

```markdown
## v3.0 — YYYY-MM-DD · Major architecture refactor

### Что нового vs v2.2
- **Caddy** заменил nginx + certbot + Let's Encrypt (auto-HTTPS из коробки, multi-site через Caddyfile.d/)
- **Push-based deploy** через GitHub Actions: build на runner → rsync `.next/standalone/` → атомарный switch симлинком
- **Раздельные SSH-ключи**: приватный только в GitHub Secrets, на VPS — только публичный
- **`.env`** через GitHub Environment Secrets (приходит в момент деплоя, не лежит на VPS постоянно)
- **Атомарный rollback** через `ln -sfn` на предыдущий релиз (миллисекунды, без пересборки)
- **Next.js 16 паттерны**: Server Actions для форм, `use cache`, опциональный PPR, OKLCH в Tailwind v4
- **Cloudflare Turnstile** в формах (антиспам)
- **Content Collections** вместо `next-mdx-remote` (типобезопасный MDX через Zod-схемы)
- **Biome** заменил ESLint + Prettier (один конфиг, в 15× быстрее)
- **pnpm** дефолтный package manager (3.7× быстрее, экономит диск на multi-site)
- **mise** заменил nvm (быстрее, единый менеджер для Node + pnpm)
- **schema-dts** для типобезопасных JSON-LD
- **Sequential multi-Claude protocol** через `/handoff` и `/resume` slash-команды

### Breaking changes
- `npm` → `pnpm` (старые проекты на v2.x должны мигрировать или остаться на v2.x)
- `nginx` → `Caddy` на VPS (миграция через ТЗ-2)
- Pull-based deploy → push-based (миграция через ТЗ-2)
- `/api/lead` Route Handler → Server Action (миграция через ТЗ-2)

### Migration
Старые проекты v2.x → v3.0: см. `_BUILD/v3/02-migrate-existing-project.md`. Не обязательная — старые проекты могут оставаться на v2.x неограниченно.
```

### 7. Тег `v3.0`

```bash
git tag v3.0
git push origin v3.0
```

И финальное обновление `.claude/memory/project_state.md`:
```
## Текущая фаза bootstrap-refactor
- Все 7 фаз done
- Тег v3.0 ✅
- Готов к запуску ТЗ-2 (миграция старых проектов)
```

## Done when

- `_BUILD/HOW-TO-START.md` переписан под v3, упоминает /handoff и /resume
- `_BUILD/claude-md-template.md` синхронизирован с актуальным CLAUDE.md
- `.claude/commands/handoff.md`, `resume.md`, `catchup.md` существуют и работают
- В `CLAUDE.md` корневом есть секция `Multi-Claude protocol`
- `_BUILD/changelog.md` имеет запись `v3.0` с полным списком изменений
- Тег `v3.0` создан и запушен
- PR в main смёрджен

## Rollback Phase 6

```bash
git tag -d v3.0 2>/dev/null
git reset --hard pre-phase-6
```

## Memory updates после Phase 6

```
## Bootstrap v3.0 — done [YYYY-MM-DD]
Все фазы 0-6 завершены. Тег v3.0 запушен. README актуализирован.
Следующее: миграция живых проектов через ТЗ _BUILD/v3/02-migrate-existing-project.md.
```

---

# Финальные критерии всего ТЗ-1

После всех 7 фаз:

- ✅ В `_BUILD/changelog.md` 7 новых записей: `v2.2.2`, `v2.3-caddy`, `v2.3-dx`, `v2.4`, `v3.0-next16`, `v3.0-deploy`, `v3.0`
- ✅ Тег `v3.0` существует на `origin/main`
- ✅ `git log v2.2.1..v3.0 --oneline` показывает чистую историю фазовых коммитов
- ✅ Документация согласована (нет упоминаний nginx, npm, ESLint, next-mdx-remote, /api/lead, Route Handler как дефолт)
- ✅ Шаблон `claude-md-template.md` валиден (`cp` в новый проект → проект работает)
- ✅ `_BUILD/HOW-TO-START.md` содержит все стартовые промты
- ✅ Slash-команды `/handoff`, `/resume`, `/catchup` зарегистрированы

## Outstanding после v3.0 (не блокируют тег)

- ⏳ **(post-v3.0) Регенерировать `_BUILD/HOW-TO-START.docx`** через `pandoc _BUILD/HOW-TO-START.md -o _BUILD/HOW-TO-START.docx` или вручную в Word. Текущий `.docx` синхронизирован с v2.2.1, не v3.0; pandoc-конвертация обычно требует ручной пройдки по стилям заголовков, разрывам страниц и оглавлению — не идеально автоматизируется. Не блокирует merge финального PR Phase 6 и не блокирует тег `v3.0`. Отдельный таск.
- ⏳ **(post-v3.0) Реальный push-based деплой на live-VPS** — Phase 5 не обкатывалась на тестовом VPS, покрыта только письменной верификацией + rollback-планом. Первый реальный run на production-сайте — happen-after-merge, ошибки правим на лету.

# Если что-то упало посреди ТЗ

1. Не паникуй. Каждая фаза имеет свой `pre-phase-N` тег и Rollback-блок.
2. Откати только проблемную фазу: `git reset --hard pre-phase-N`. Предыдущие фазы остаются.
3. Опиши пользователю, что случилось — он, скорее всего, скинет конкретику (логи, скриншоты).
4. После фикса — обнови `project_state.md` (что починили, на чём остановились) и продолжай.

# Что НЕ делать в этом ТЗ

- ❌ Не переходить на TanStack Form / Conform (RHF остаётся)
- ❌ Не менять Zod на Valibot (Zod остаётся, экосистема за него)
- ❌ Не добавлять Vitest / тесты (вне scope; если когда-то добавится — отдельной спекой)
- ❌ Не переходить на Coolify / Dokploy (Caddy + PM2 — целевой стек)
- ❌ Не трогать `docs/content-layout.md`, `docs/conversion-patterns.md`, `docs/legal-templates.md`
- ❌ Не пытаться обкатывать на тестовом VPS (пользователь будет править ошибки на лету по обратной связи)

# Финальный handoff

После завершения ТЗ-1 (тег `v3.0` на `origin/main`):

1. Скажи пользователю: «Bootstrap обновлён до v3.0. Следующий шаг — миграция живых проектов. Открой папку конкретного старого проекта в новом Claude-чате и используй промт из `_BUILD/v3/02-migrate-existing-project.md`.»
2. `.claude/memory/project_state.md` сбросить или пометить «refactor done», чтобы новые проекты на v3 стартовали с чистого state.

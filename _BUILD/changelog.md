# Changelog

## v2.4 — 2026-04-28 · Cloudflare Turnstile + Content Collections

Фаза 3 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Закрыты две функциональные дыры в шаблоне: **антиспам форм** через Cloudflare Turnstile и **типобезопасный MDX-стек** через Content Collections (вместо `next-mdx-remote` + ручного `gray-matter`). Обе правки — в спеках и доке, существующие проекты на старом стеке продолжают работать; миграция точечная (`_BUILD/v3/02-migrate-existing-project.md`).

- **Cloudflare Turnstile в формах.** Бесплатный CAPTCHA-аналог от Cloudflare с invisible-режимом по умолчанию (без VPN-блокировок reCAPTCHA, без вендор-лока на Google). Клиент через официальную обёртку `@marsidev/react-turnstile` (ленивая загрузка скрипта, ref для `reset()` после submit — токен одноразовый, иначе `timeout-or-duplicate` от CF). Сервер проверяет токен на `challenges.cloudflare.com/turnstile/v0/siteverify` (`application/x-www-form-urlencoded`, не JSON) **до** обращения к CRM — иначе при падающей CRM бот успеет насыпать в `data/leads.json`. Site-key (`NEXT_PUBLIC_TURNSTILE_SITE_KEY`) — единственное `NEXT_PUBLIC_` в формах (публичный по дизайну Cloudflare); secret-key (`TURNSTILE_SECRET_KEY`) — только серверный. Если у заказчика уже есть Cloudflare-аккаунт под DNS — Turnstile заводится там же, иначе отдельная регистрация (бесплатно). В `docs/forms-and-crm.md` — новый раздел «Антиспам — Cloudflare Turnstile» с готовым кодом для клиента и сервера, пояснением одноразовости токена и тестовыми ключами для localhost. В `specs/09-forms-crm.md` — отдельная секция «1. Cloudflare Turnstile», шаги установки/env/виджета и Turnstile-edge-кейсы в тестировании. В `docs/stack.md` — `@marsidev/react-turnstile` в вспомогательных пакетах + в init-команду как универсальная form-зависимость. В `specs/02-project-init.md` — `@marsidev/react-turnstile` в дефолтный install шаг 4.
- **Content Collections вместо `next-mdx-remote` + `gray-matter`.** Типобезопасный MDX-стек: Zod-схема в `content-collections.ts` — единая точка истины для frontmatter всех `.mdx` в `content/`. На билде Content Collections парсит, валидирует, компилирует и кладёт в `.content-collections/generated`. В коде — `import { allPosts } from 'content-collections'` (типизированный массив, IDE-автокомплит). Опечатка в `@type` или невалидный `date` — TypeScript-ошибка / понятный лог на билде, не runtime-500. Спека `specs/07-blog-optional.md` полностью переписана: установка (`content-collections @content-collections/core @content-collections/mdx @content-collections/next` + `@tailwindcss/typography`), `withContentCollections(nextConfig)`, `tsconfig.json paths` алиас, Zod-схема с draft-полями и `readingTime` в transform, `generateStaticParams` через `allPosts.filter(p => !p.draft)`, рендер через `<MDXContent code={post.mdx} />`. Добавлена сравнительная таблица «next-mdx-remote vs Content Collections». В `docs/architecture.md` — раздел «MDX через Content Collections» переписан, в схему папок добавлены `content-collections.ts` (root) и `.content-collections/` (gitignored). В `docs/stack.md` — MDX-row обновлён, в вспомогательных пакетах строка про CC + плагины. CC ставится **опционально** в spec/07 (только если в `docs/pages.md` запланирован блог) — поэтому из дефолтного init в `docs/stack.md` и `specs/02-project-init.md` пакеты CC убраны вместе со старыми `next-mdx-remote gray-matter`. В `.claude/memory/pointers.md` — новый раздел «Контент (MDX через Content Collections)».

3 атомарных коммита в ветке `feat/v2.4-turnstile-content-collections`: `feat(turnstile)`, `feat(content-collections)`, `chore(memory)`. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Для существующих проектов на `next-mdx-remote` шаги миграции — в `_BUILD/v3/02-migrate-existing-project.md` (раздел «next-mdx-remote → Content Collections»).

## v2.3-dx — 2026-04-28 · DX win: Biome, pnpm, mise, schema-dts

Фаза 2 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Четыре локальных DX-замены тулинга на Mac разработчика, без архитектурных изменений в рантайме сайтов. Каждый пункт по отдельности — мелкая правка; вместе они дают ощутимый ежедневный win: один линтер вместо двух, единый менеджер версий, экономия диска при multi-site, типобезопасный JSON-LD.

- **Biome вместо ESLint+Prettier.** Один бинарник, один конфиг, ~10× быстрее на типичном Next-проекте. Tailwind-классы сортируются встроенным правилом `useSortedClasses` (с распознаванием `clsx`/`cva`/`cn`/`tw`) — `prettier-plugin-tailwindcss` убран. `package.json scripts` теперь: `lint: biome check`, `format: biome check --write`, `typecheck: tsc --noEmit` (отдельно, потому что Biome не делает type-checking). В корне bootstrap'а появился `biome.json.example` (linter+a11y recommended, lineWidth 100, single quotes, no semicolons). Хук `.claude/hooks/format.sh` переключён с Prettier на Biome. Установка в `specs/02`: `pnpm add -D --save-exact @biomejs/biome && pnpm exec biome init`. Флаг `--no-eslint` добавлен в `create-next-app` — иначе он по умолчанию ставит ESLint, который мы тут же удаляем.
- **pnpm вместо npm.** Hardlinks вместо копирования при multi-site дают экономию диска на VPS (5–10 сайтов на одном VPS — типичный сценарий, см. `docs/server-multisite.md`). Полный sweep по spec'ам, доке и хелперам: `npm install` → `pnpm add`, `npm install -D` → `pnpm add -D`, `npm ci` → `pnpm install --frozen-lockfile`, `npm run X` → `pnpm X`, `package-lock.json` → `pnpm-lock.yaml`. На VPS pnpm активируется через `corepack` (идёт в комплекте с Node 16.13+) — отдельный apt-пакет не нужен. PM2 на VPS теперь ставится через `pnpm add -g` для консистентности. На Mac в `_BUILD/HOW-TO-START.md` тоже `corepack enable && corepack prepare pnpm@latest --activate` — а после Phase 2 это делает уже mise (см. ниже). `scripts/rollback.sh` обновлён.
- **mise вместо nvm.** Единый version manager для всего тулинга проекта (Node, pnpm, при необходимости Python/Go и т.д.). Читает `.tool-versions` автоматически на `cd` в папку — никакого ручного `nvm use`. В корне bootstrap'а появился пример `.tool-versions` (`node 22` + `pnpm latest`). `_BUILD/HOW-TO-START.md` § 0.4 переписан: `brew install gh mise` + `eval "$(mise activate zsh)"` в zshrc + `mise use --global node@22 pnpm@latest`. `specs/01a-local-setup.md` переключён с `.nvmrc` на `.tool-versions`; toolchain-проверка теперь `pnpm -v ≥ 9` вместо `npm -v`. `docs/team-onboarding.md` инструкция установки — `mise install && pnpm install`.
- **schema-dts для типобезопасного JSON-LD.** Типы Schema.org от Google. В `lib/schema.ts` функции теперь возвращают `WithContext<Service>`, `WithContext<BreadcrumbList>`, `WithContext<FAQPage>`, `WithContext<Organization>`, `WithContext<Article>` и т.д. Опечатка в `@type` или поле — TypeScript-ошибка на билде (`tsc --noEmit`), а не «странный warning в Yandex Validator уже на проде». Добавлен в `docs/stack.md` (helpers), в `specs/02` install (`pnpm add -D schema-dts`), в примеры `lib/schema.ts` в `specs/05` (Service/BreadcrumbList/FAQPage) и `specs/08` (Organization/LocalBusiness/Article).
- **Severity-A sweep по стек-строкам.** `CLAUDE.md` Stack-секция, `_BUILD/claude-md-template.md` (тот, что копируется в новые проекты), `README.md` H1 + Версия + Требования — все обновлены под v2.3-dx. `pnpm dev`/`pnpm build` теперь видны в Commands при старте каждой Claude-сессии, иначе модель работала бы по устаревшему `npm run`-стеку. README поднят с v2.2.2 до v2.3-dx (Phase 1 Caddy не обновил его — закрыли вместе).

8 атомарных коммитов в ветке `feat/v2.3-dx-biome-pnpm-mise`. Сам bootstrap-репо ничего не билдит — изменения проявятся только в **новых** проектах, раскатанных из шаблона после merge'а. Существующие проекты, уже сидящие на ESLint+Prettier+npm+nvm, продолжают работать; миграция точечная (см. `_BUILD/v3/02-migrate-existing-project.md`, который покрывает в том числе nvm → mise).

## v2.3-caddy — 2026-04-28 · Caddy вместо nginx+certbot

Фаза 1 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. Заменили связку `nginx + certbot + cron renewal` на **Caddy** — встроенный ACME (Let's Encrypt + ZeroSSL fallback), автоматический HTTPS, multi-site через `import /etc/caddy/Caddyfile.d/*.caddy`. ~30 строк nginx-конфига на сайт превратились в ~6 строк Caddyfile, ручной certbot и его системный таймер больше не нужны.

- **`scripts/bootstrap-vps.sh`** — apt-репо Caddy (cloudsmith) с GPG-ключом, `apt install caddy` вместо `nginx + certbot + python3-certbot-nginx`. Базовый `/etc/caddy/Caddyfile` с глобальным `email` + `import Caddyfile.d/*.caddy`. Папка `/etc/caddy/Caddyfile.d/` создаётся пустой с `00-placeholder.caddy` на `:8080`, чтобы `caddy validate` не падал на пустом glob'е до первого сайта. `caddy validate` перед `systemctl reload caddy`. Параметр `CADDY_ADMIN_EMAIL` — обязательный (без email ACME у Caddy не работает).
- **`docs/server-manual-setup.md`** — шаги 5 и 8 переписаны под Caddy. Команды запуска передают `CADDY_ADMIN_EMAIL` через env. Верификация: `caddy validate` + `systemctl is-active caddy`. Раздел «Обслуживание» — `journalctl -u caddy` для аудита SSL-ошибок вместо `certbot certificates`. Добавлены частые проблемы: placeholder `:8080`, ACME не выпускается (DNS / ufw).
- **`docs/server-add-site.md`** — полностью переписан § «положить конфиг» под Caddy: один файл на сайт в `/etc/caddy/Caddyfile.d/{site}.caddy`, шаблон с `reverse_proxy` + `encode gzip zstd` + `Cache-Control` (immutable 1y для статики, must-revalidate для HTML), опциональный dev-поддомен с `basicauth`. Удаление `00-placeholder.caddy` при первом сайте. § SSL: ничего делать не нужно — Caddy сам пройдёт HTTP-01 challenge при первом запросе. § Автопродление: Caddy за 30 дней до истечения, без cron.
- **`docs/server-multisite.md`** — multi-site через `Caddyfile.d/*.caddy` вместо `sites-available/sites-enabled`-symlink'ов. SSL-лимит Let's Encrypt — упомянут ZeroSSL fallback и DNS-01 wildcard через Caddy plugin.
- **`docs/deploy.md`** — ASCII-схема: «nginx + SSL» → «Caddy + ACME». Cloudflare-секция: добавлен подводный камень с HTTP-01 через CF proxy и обходные пути (DNS-01 через `caddy-dns/cloudflare` plugin), `trusted_proxies cloudflare` для логов реального IP.
- **`docs/troubleshooting.md`** — добавлены два раздела. «Caddy не стартует / падает после правки» — диагностика `systemctl status` + `journalctl` + `caddy validate`, типичные причины (typo, port conflict со старым nginx, права на `/var/lib/caddy`). «SSL не выписывается (Caddy)» — четыре причины по частоте (DNS, ufw 80, CF proxy, Let's Encrypt rate limit). Анти-совет: не делать `systemctl restart caddy` при ACME-проблемах, чтобы не сбить экспоненциальный бэкофф.
- **`specs/12-handoff.md`** — в runbook'е «SSL-сертификат истёк» команды `certbot renew` + `systemctl reload nginx` заменены на диагностику Caddy. В «Раз в месяц» — `systemctl status caddy` вместо `certbot certificates`.
- **Severity-A: stack strings.** `CLAUDE.md`, `_BUILD/claude-md-template.md`, `.claude/memory/references.md` — stack-строка проекта (`PM2 + Nginx + Let's Encrypt` → `PM2 + Caddy (встроенный ACME)`), путь к конфигу (`/etc/nginx/sites-available/[project]` → `/etc/caddy/Caddyfile.d/[project].caddy`), описание SSL (`auto-renew через certbot` → `автообновляется Caddy`). Эти строки попадают в context новой Claude-сессии при старте — несоответствие создавало бы ложную картину инфры.
- **Severity-B: descriptions sweep.** Точечные упоминания в `README.md` (01b генерит «Caddy-шаблон»), `docs/INDEX.md` (таблица KB-файлов и поинтер «Caddy-шаблон → server-add-site.md»), `scripts/README.md` (стек bootstrap-vps.sh + verify inline пример), `docs/domain-connect.md` (Cloudflare proxy + ACME, Caddy-симптомы вместо certbot), `docs/seo.md` (X-Robots-Tag через `curl -I`, склейки через Caddy `redir`), `specs/02-project-init.md` (комментарий `compress: false`), `specs/08-seo-schema.md` (§ редиректы переведён на Caddyfile.d/), `specs/optional/opt-i18n.md` (поддомен через блок в Caddyfile.d), `specs/optional/opt-migrate-from-existing.md` (`nginx upstream` → `reverse_proxy` upstream).

11 атомарных коммитов в ветке `feat/v2.3-caddy`. Сам bootstrap-репо ничего не билдит — изменения проявятся только при следующем запуске `bootstrap-vps.sh` на свежем VPS или при миграции существующего (см. `_BUILD/v3/02-migrate-existing-project.md` § «nginx → Caddy»). Существующие prod-VPS на nginx+certbot продолжают работать как раньше — миграция точечная.

**Отложено на отдельные задачи (C-level, ~4 файла, требуют структурной переработки):**
- `specs/01b-server-handoff.md` — спека генерирует артефакт `deploy/nginx.conf.example`. Под Caddy это становится `deploy/{site}.caddy.example` с другим шаблоном; меняется и сам код-генератор внутри спеки, и acceptance criteria.
- `specs/14-migrate.md` — миграционный runbook (M1–M4), несколько мест с `certbot --nginx -d` и `nginx -t` в командах для VPS-cutover.
- `docs/performance.md` (§ 7–8 «Серверная оптимизация (nginx)») и `specs/11-performance.md` (§ 9 «Nginx-уровень») — целые секции про gzip/brotli/Cache-Control в nginx. Caddy делает большую часть этого через `encode gzip zstd` + `header @static Cache-Control` (уже в шаблоне `server-add-site.md` после Фазы 1) — секции нужно сильно сократить или превратить в «как проверить, что Caddy всё это уже делает». Это де-факто ревизия performance-методики, попадает в Фазу 4 / отдельный pass.

## v2.2.2 — 2026-04-28 · P0 hotfix bundle

Фаза 0 рефакторинга `_BUILD/v3/01-bootstrap-refactor.md`. 12 точечных правок поверх v2.2.1, без архитектурных изменений — закрываем накопившиеся противоречия и битые ссылки перед переходом на v3.0.

- **P0-1 (compress-images.mjs).** Скрипт никогда не существовал. Убрано из `package.json scripts`, описаний папок, `npm run build`, упоминаний в перформанс-доках. `next/image` сам ресайзит и оптимизирует на лету (sharp подключается как `optionalDependency` Next.js 15+).
- **P0-2 (localhost:4000 → :3000).** Три места в `specs/02`, `specs/03`, `docs/team-onboarding.md` отстали от единого порта 3000. Легитимный `:4010` в `docs/deploy.md` (dev-поддомен на VPS) не трогали.
- **P0-3 (синхронизация версий).** `README.md` H1 = `v2.2.2`, блок «Версия» переписан под актуальную дату. `_BUILD/claude-md-template.md` — дефолт стека `v2.2.2`. В meta-шапке `CLAUDE.md` — история версий «v2.0 → v2.2.x», пример тегов «v2.2.3 / v2.3.0».
- **P0-4 (`_BUILD/migration-map.md` ссылки).** Файла нет и не будет (содержание в changelog). Убраны упоминания из `README.md` ×2, `specs/00-brief.md`, `_BUILD/changelog.md`.
- **P0-5 (схемы A/B деплоя).** Остатки в `specs/13-extend-site.md` и `specs/06-subpages-rollout.md` приведены к единому push-flow `git push origin dev → PR в main → автодеплой через Actions` (схему B убрали в v2.1, но местами осталась).
- **P0-6 (ConsultationDialog spec).** В `specs/02-project-init.md:71` указано, что Provider добавляется в спеке 09 — на самом деле в 04 (вместе с первой формой на главной).
- **P0-7 (footer ссылки на /privacy /terms).** В спеке 03 убрали эти ссылки из Footer (страниц ещё нет — будут битые). Добавили шаг 12 в `specs/09-forms-crm.md` — обновить Footer.tsx после создания юр-страниц.
- **P0-8 (`hooks.json` → `settings.json`).** В `docs/workflow.md` исправлено название файла с хуками — реально это `.claude/settings.json`.
- **N1 (`scripts/README.md`).** Добавлены строки про `rollback.sh` и `sync-env.sh` в таблицу скриптов (появились в v2.2, но в README не попали).
- **N2 (Zod → Valibot совет).** Решение проекта: Zod остаётся (на лендинге ~100 KB незаметны, экосистема RHF + Zod зрелая). Совет «замени на valibot» убран из `specs/11`, `docs/performance.md`, `docs/stack.md`. В таблицу красных флагов вместо Zod — `react-icons` целиком (где tree-shake реально критичен).
- **N3 (`IDEAS.md`).** Файла нет, упоминание из meta-шапки `CLAUDE.md` убрано.
- **N4.** Эта запись.

12 атомарных коммитов в ветке `fix/v2.2.2-p0-bundle`. Архитектура без изменений — большой рефакторинг (Caddy / pnpm / Biome / push-deploy / Next 16 паттерны / multi-Claude handoff) идёт отдельным треком, см. `_BUILD/v3/01-bootstrap-refactor.md`.

## v2.2.1 — 2026-04-27 · HOW-TO-START clarity pass

Доводка инструкции после первой эксплуатации — стало понятнее для тех, кто видит её впервые (а не только для меня).

- **Новый §0.0 «Аккаунт на GitHub».** Что делать если аккаунта ещё нет, как узнать свой логин, чёткий словарик плейсхолдеров (`<твой-логин>`, `<твой-email>`, `{site}`) и правило «угловые/фигурные скобки заменяешь целиком, двойные кавычки — оставляешь».
- **§0.4** — пример успешного вывода `node --version` с пометкой «нужно v22 или новее, иначе `brew upgrade node`».
- **§0.5 (Git identity)** и **§0.6 (SSH-ключ)** перестроены на пару «шаблон + пример». Email теперь личный (раньше был placeholder `твой-email@example.com`, легко принять за инструкцию).
- **§0.7** — пример успешного `gh auth status`, чтобы не путать с ошибкой.
- **§1 (gh repo create)** — явное пояснение про два разных GitHub-имени в команде («первое имя — куда положить, второе — откуда взять, не перепутай»). Конкретный пример с `tem11134v2/migrator`. Блок «что произойдёт» после команды.
- **§2** — заметка про разовый macOS-промпт «Claude wants access to folder».
- **§9** — пояснение что такое `<hash>` (короткий идентификатор коммита, видно в `git log` или в URL).

`.docx` перегенерирован, ZIP-целостность валидна. Контент: 1×H1, 13×H2, 10×H3.

## v2.2 — 2026-04-26 · Automation layer

Сняли с человека всё, что Claude может делать сам: проверки перед сессией, переключение gh-аккаунтов, синхронизацию `.env` на VPS, откат прода, чистку старого swap до bootstrap. Теперь `HOW-TO-START` гораздо короче — длинных ручных ритуалов в нём почти не осталось.

- **Хуки `.claude/hooks/`:**
  - `session-start.sh` — `git fetch` + проверки в начале каждой сессии (отставание ветки, uncommitted, gh ↔ remote owner mismatch). Информирует, не блокирует.
  - `before-push.sh` — блокирует Claude-side `git push` / `gh pr` / `gh repo` при несовпадении активного gh-аккаунта с владельцем remote-а (exit 2). Caveat: не ловит терминальный push пользователя — это страховка от ошибок Claude, не immutable защита.
  - `format.sh` (prettier autoformat на изменённые файлы) и `guard-rm.sh` (блок `rm -rf /|~|*` и `git push --force`) — добавлены в шаблон (раньше были только проектным артефактом).
- **Скрипты `scripts/`:**
  - `sync-env.sh` — копирует `~/projects/{site}/.env.production` (gitignored) на VPS в `/home/deploy/prod/{site}/.env`, `chmod 600`, `pm2 restart --update-env`. Один канонический путь, без вопросов.
  - `rollback.sh` — `ssh + git reset --hard <hash> + npm ci + build + pm2 restart` на проде. Подсказывает корректный `git revert` (включая `-m 1` для merge-коммитов — частая ловушка после PR-merge).
  - `bootstrap-vps.sh` — pre-clean: пересоздаёт `/swapfile`, если его размер не совпадает с `SWAP_SIZE` (фикс для Timeweb default 512M).
- **Документация:**
  - `docs/automation.md` — описание четырёх хуков и двух скриптов: что делают, как локально отключить, как добавить новый.
  - `docs/troubleshooting.md` — gh auth mismatch, DDoS-Guard 301 до cutover, deploy_key denied, branch protection 403 на private+free, swap не пересоздаётся, prod 404 после билда.
  - `docs/team-onboarding.md` — для нового collaborator-а: clone, `npm install`, Claude Code, `feature → dev → main`. Чётко перечислено, что **не** дают (SSH, deploy_key, secrets).
- **`CLAUDE.md` — секция «Automation rules»:** session-start, before-push, secrets, rollback. Шаблонные формулировки без проектных аліасов.
- **`_BUILD/HOW-TO-START.md` + `.docx`:** переписаны. Сокращены §3 (доверяем session-start hook), `gh auth status` сжат в «Частые косяки». Добавлены §7 (collaborator), §8 (секреты), §9 (откат) — каждая по 1–2 строки промпта Claude'у. Entry-point для миграции живого сайта.
- **Branch protection:** включена на `main` шаблона (он public — бесплатно). Require PR, no force push, no deletions.
- **Тег `v2.2` после merge.**

## v2.1.3 — 2026-04-24 · Handoff and migration playbooks

Закрыли белое пятно: что делать когда сайт передаётся заказчику или переезжает на другой VPS. Спеки `12-handoff` и новая `14-migrate` покрывают все сценарии, которые Timur использует на практике.

- **`specs/12-handoff.md` переписан под три модели handoff'а:** H1 (full transfer — дефолт), H2 (client-owned, dev operates), H3 (read-only). HANDOFF.md-шаблон теперь содержит runbook + monthly maintenance + инструкцию по самостоятельному отзыву прав разработчика.
- **Новая `specs/14-migrate.md`** с четырьмя сценариями: M1 (scaling), M2 (handoff), M3 (emergency), M4 (clone to new domain). Scp runtime-данных, DNS switch, **7-day soak** перед decommission.
- **Зафиксированы дефолтные правила:**
  - `data/leads.json` — fallback, не источник истины (источник — CRM).
  - 7 дней между DNS switch и выключением старого VPS.
  - Single-Claude модель — мульти-разработчик не поддерживается; при handoff'е Claude заказчика заменяет Claude разработчика, а не идёт параллельно.
- `specs/INDEX.md` — спека `14-migrate` добавлена в основной поток (опциональная, после 12 или между 10/11 при масштабировании).

## v2.1.2 — 2026-04-24 · Security hardening pass

Добавили разумные дефолты поверх базового bootstrap. Применены и проверены на том же Timeweb VPS.

- **Non-standard SSH port (default 2222).** Параметризуемо через `SSH_PORT`. Критичный нюанс Ubuntu 22.04+: надо `systemctl disable ssh.socket && systemctl enable ssh.service` — иначе socket activation игнорирует `Port` из `sshd_config`.
- **fail2ban строже:** 3 попытки / 10 минут / бан 24 часа. `backend=systemd` (на Ubuntu 24.04 auth-логи идут в journald, не в `/var/log/auth.log`).
- **unattended-upgrades.** Security patches применяются автоматически ежедневно, без auto-reboot. Ставит `apt-listchanges` для журнала изменений.
- **Mac-side `~/.ssh/config`** с алиасом `vps1` — `ssh deploy@IP` работает без `-p 2222`. Инструкция в `docs/server-manual-setup.md`.

## v2.1.1 — 2026-04-24 · Claude-driven server bootstrap

Второй proход после живого тестирования на Ubuntu 24.04 Timeweb VPS. Обнаружили delta между чек-листом и реальностью, переписали под скрипт.

- **Добавлен `scripts/bootstrap-vps.sh`** — идемпотентный скрипт, делает всё что раньше было чек-листом. Проверен на Timeweb VPS.
- **Роль серверных доков инвертирована:** `server-manual-setup.md` теперь **для Claude**, не для человека. Разработчик один раз делает `ssh-copy-id root@{ip}`, дальше Claude рулит по SSH.
- **CLAUDE.md:** снято правило «Never SSH into the VPS from Claude Code», заменено на «run batched idempotent scripts, not ad-hoc interactive edits».
- **Deltas между v2.1 чек-листом и реальностью:**
  - `adduser` интерактивный → `adduser --gecos "" --disabled-password`.
  - `ufw enable` интерактивный → `ufw --force enable`.
  - `apt` висит на конфиг-prompt'ах → `DEBIAN_FRONTEND=noninteractive`.
  - На cloud-образах Ubuntu (Timeweb, Hetzner) `/etc/ssh/sshd_config.d/50-cloud-init.conf` перекрывает drop-in'ы — нужно затереть. Ещё и в главном `sshd_config` бывает `PermitRootLogin yes` на 42-й строке.
  - `pm2 startup` + пустой dump → systemd валится с `failed (Result: protocol)`. Сервис включается только после первого `pm2 save` с реальным процессом (делается в `server-add-site.md`).
- `scripts/README.md` — принципы написания серверных скриптов (idempotency, non-interactive, verify inline, secrets out of band).

## v2.1.0 — 2026-04-24 · Desktop-first workflow

**Что это.** Переход с серверной разработки (Claude Code внутри VPS через SSH) на **локальную десктопную**: Claude Desktop на Mac → `git push` в GitHub → GitHub Actions катит на VPS. Сервер разработчик настраивает руками по чек-листам — Claude в эти операции не лезет.

**Почему.** Десктопная модель убирает риски автономного изменения сервера, сокращает цикл правки (локальный hot-reload быстрее SSH+билд), и лучше подходит к кейсу «один разработчик ведёт несколько проектов».

### Ключевые изменения v2.0 → v2.1

- **Убрали схемы деплоя A/B.** Осталась одна единая модель: Mac → GitHub → VPS.
- **`docs/deploy-server-setup.md` удалён.** Разделён на четыре специализированных файла:
  - `docs/server-manual-setup.md` — разовая настройка свежего VPS (**для человека**).
  - `docs/server-add-site.md` — подключение нового сайта на готовый VPS (**для человека**).
  - `docs/server-multisite.md` — как уживаются несколько сайтов.
  - `docs/domain-connect.md` — A-записи и проверка `dig` (**для человека**).
- **Файлы «для человека» (`server-*`, `domain-connect`) помечены в `docs/INDEX.md`.** Claude на них ссылается, но не исполняет.
- **`specs/01-infrastructure.md` разделён на два:**
  - `specs/01a-local-setup.md` — проверка тулчейна на Mac, git, SSH, память.
  - `specs/01b-server-handoff.md` — Claude генерит в репо `.github/workflows/deploy-*.yml`, `deploy/nginx.conf.example`, `deploy/README.md`. Пользователь применяет на VPS сам.
- **Добавлен `specs/00.5-new-project-init.md`** — ритуал разработчика при старте каждого нового сайта (создание папки, репо, открытие Claude Desktop).
- **Убран `output: "standalone"` из стека.** Был лишним при PM2 + `next start`; подробности — в `docs/stack.md`.
- **Скрипты `package.json`:** `dev` теперь на 3000 (совпадает с дефолтным prod-портом на VPS). На VPS порт задаётся через `PORT=...` при `pm2 start` по реестру `~/ports.md`.
- **`CLAUDE.md`:** добавлено правило «Never push to main directly. Never SSH into the VPS from Claude Code».
- **Обновлены:** `README.md`, `docs/INDEX.md`, `specs/INDEX.md`, `specs/02/04/09/11/12/13`, `specs/templates/spec-template.md`, `docs/workflow.md`, `docs/architecture.md`, `.claude/memory/pointers.md`, `.claude/memory/references.md`, `.claude/memory/project_state.md`.

### Breaking changes v2.0 → v2.1

1. **Нельзя работать в `main` напрямую.** Всегда через ветку `dev` + PR. Старые проекты с разработкой на `main` нужно перевести — настроить protected branch и переключить workflow.
2. **Dev-сервер на Mac, не на VPS.** Если раньше запускали `npm run dev` по SSH — теперь локально. VPS только для prod (+ опционального dev-preview).
3. **Нет больше схемы A.** Проекты «dev=prod на одном VPS, без GitHub» больше не поддерживаются как отдельная ветвь. Для одиночных проектов всё равно ставим GitHub — это цена консистентности и безопасности.
4. **`next.config.ts` без standalone.** Если где-то в проекте закодирован `output: 'standalone'` — убрать. PM2 запускает `next start`, standalone лишний.
5. **Спека 01 переименована.** Промпты «run spec 01-infrastructure» нужно заменить на «run spec 01a-local-setup» (или `01b-server-handoff`).

---

## v2.0.0 — 2026-04-13 · Major restructure

**Что это.** Полная переработка bootstrap-промпта. Раньше был один файл `web-dev-bootstrap.md` на 2128 строк — теперь папка с `docs/` (KB) + `specs/` (последовательность задач) + `CLAUDE.md` (вход) + `.claude/memory/` (проектная память).

**Почему разбили.** Один большой `.md` съедал контекст Claude при любой задаче. В v2.0 Claude читает только то, что нужно для текущей спеки — через `docs/INDEX.md`. Поддержка проще: правка одного модуля не требует перетряхивать весь файл.

### Что переехало v1.7 → v2.0

Коротко:

| Модуль v1.7 | Стало в v2.0 |
|---|---|
| WORKFLOW | `docs/workflow.md` |
| STACK | `docs/stack.md` |
| ARCHITECTURE | `docs/architecture.md` |
| DESIGN-SYSTEM | `docs/design-system.md` |
| CONTENT-LAYOUT (44 секции) | `docs/content-layout.md` |
| FORMS-AND-CRM | `docs/forms-and-crm.md` |
| DEPLOY | `docs/deploy.md` + `docs/deploy-server-setup.md` |
| SEO | `docs/seo.md` |
| PERFORMANCE | `docs/performance.md` |
| CONVERSION-PATTERNS | `docs/conversion-patterns.md` |
| ШАБЛОНЫ ПРОЕКТНЫХ ФАЙЛОВ | `specs/00-brief.md` (как входной формат) |
| ШАБЛОН CLAUDE.md | `CLAUDE.md` (live) + `_BUILD/claude-md-template.md` (пустой) |

### Новое в v2.0

- **`docs/INDEX.md`** — карта KB с колонкой «когда читать», чтобы Claude не грузил всё подряд
- **`docs/legal-templates.md`** — 152-ФЗ cookie-баннер, согласие на ПДн, заглушки политики/оферты, чек-лист РКН
- **`docs/deploy-server-setup.md`** — отделён от `deploy.md`: VPS-bootstrap, nginx-шаблон, SSL, Cloudflare, GitHub Actions, troubleshooting
- **`specs/INDEX.md`** — 14 основных спек 00→13 с графом зависимостей
- **`specs/00-brief.md`** — приём материалов заказчика (тексты, бренд, страницы) в `docs/spec.md` + `content.md` + `pages.md` + `integrations.md`
- **`specs/01-13`** — каждая как одна сессия = один коммит-набор, с явным списком «KB files to read first»
- **`specs/optional/`** — 4 опциональные спеки: quiz, ecommerce, i18n, migrate-from-existing
- **`specs/templates/`** — `spec-template.md` + `page-spec-template.md`
- **`specs/examples/`** — 2 живых примера зрелых спек из реального проекта (референс формата, не задачи)
- **`.claude/memory/`** — 6 шаблонов проектной памяти (project_state, decisions, feedback, references, lessons, pointers) + INDEX с триггерами обновления
- **Деплой — две схемы:** A (dev=prod на одном VPS, без remote) и B (GitHub Actions + dev/prod папки). Раньше описывалась только B.

### Выброшенные дубли

Зафиксированы единые источники истины (см. `docs/INDEX.md` раздел «Источник истины»):

- `console.log` удалить — только в `performance.md § 4`
- WCAG AA контраст — только в `performance.md § 11`
- Lighthouse 90+ / PSI методика — только в `performance.md § 13`
- «Вирусный client» антипаттерн — короткая заметка в `architecture.md`, развёрнуто в `performance.md § 13.4`
- nginx-шаблон — только в `deploy-server-setup.md`
- Cookie-баннер / согласие на ПДн — только в `legal-templates.md`

### Breaking changes для тех, кто работал по v1.7

1. **Вместо одного `.md` — папка.** Старая схема «скопировал файл в проект → работаем» больше не работает. Нужна вся структура `docs/` + `specs/` + `CLAUDE.md` + `.claude/memory/`.
2. **Новый вход.** Раньше Claude читал `web-dev-bootstrap.md` целиком. Теперь вход — `CLAUDE.md` в корне, дальше `docs/INDEX.md` и спеки по требованию. Старые промпты типа «прочитай bootstrap» нужно заменить на «прочитай `CLAUDE.md` и `specs/INDEX.md`, начни со спеки `00-brief`».
3. **Деплой.** Если работали по v1.7 и использовали «папки dev + prod + GitHub Actions» — это теперь схема B (`docs/deploy.md` + `docs/deploy-server-setup.md`). Всё ещё поддерживается. Если деплой другой (solo dev=prod) — появилась схема A, переключаться не обязательно.
4. **Cookie-banner / 152-ФЗ стали обязательны** в `specs/09-forms-crm.md`. Если сайт работал без них по v1.7 — при следующем расширении (спека 13) добавь по `docs/legal-templates.md`.
5. **Workflow-дисциплина усилилась.** `CLAUDE.md` теперь явно требует plan mode перед кодом и обновление `.claude/memory/` по триггерам. В v1.7 это было «рекомендацией».

### v1.7 и ниже

Полной истории не ведём — предыдущая версия жила в одном файле. Архив старого `web-dev-bootstrap.md` остался локально у автора. В v2.0 миграция «один файл → структура» считается нулевой точкой.

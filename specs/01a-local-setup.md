# Spec 01a: Локальное окружение (Mac)

## KB files to read first

- docs/stack.md
- docs/workflow.md
- docs/spec.md (если уже заполнен в 00)
- `.claude/memory/references.md`

## Goal

Убедиться, что на Mac установлены все нужные инструменты для работы над проектом. Зафиксировать в памяти базовые факты о рабочей среде. На выходе — всё готово к `02-project-init`.

Предполагается, что пользователь уже прошёл `specs/00.5-new-project-init.md` (создал папку, репо, открыл Claude Desktop в папке). Эта спека проверяет инструменты и пишет в память.

## Tasks

### 1. Проверить тулчейн

Claude проверяет через Bash:

```bash
node -v              # ≥ 22
npm -v               # ≥ 10
git --version        # ≥ 2.40
gh --version         # ≥ 2.0, и `gh auth status` подтверждает login
```

Если чего-то нет — **не ставь сам**, попроси пользователя установить и подтвердить. Claude не управляет глобальным тулчейном Mac.

### 2. Проверить git-идентичность

```bash
git config --get user.name
git config --get user.email
```

Если пусто — попроси пользователя задать глобально:

```bash
git config --global user.name "Timur"
git config --global user.email "{email}"
```

### 3. Проверить SSH-ключ к GitHub

```bash
ssh -T git@github.com
```

Должно приветствовать по нику. Если нет — инструкция в `.claude/memory/references.md` (или у пользователя уже настроено через `gh auth login`, тогда всё ок).

### 4. Зафиксировать в памяти

Обнови `.claude/memory/references.md`:
- Локальный путь проекта: `~/projects/{site}` (абсолютный).
- GitHub URL репо.
- Ветки: `main` (prod, protected), `dev` (integration).
- Версии `node`, `npm`, ссылка на `.nvmrc` если есть.
- Email в git.

### 5. `.nvmrc` и lock-файл

Создай в корне проекта:

```
# .nvmrc
22
```

Это чтобы на VPS (у которого `nvm` может быть) и у других разработчиков совпадала версия Node.

Lock-файл (`package-lock.json`) появится в спеке `02-project-init` после `create-next-app`. Обязательно коммить его — GitHub Actions использует `npm ci`.

## Boundaries

- **Never:** ставить/удалять глобальные пакеты на Mac без подтверждения. `brew install`, `npm -g install` — только через пользователя.
- **Never:** трогать `~/.ssh/` ключи автоматически. Это чувствительная папка.
- **Ask first:** если не уверен, какую версию Node/pnpm/npm выбрать — уточни у пользователя.

## Done when

- Все команды из п. 1 проходят.
- `git config` заполнен, `ssh -T git@github.com` приветствует.
- `.claude/memory/references.md` обновлён.
- `.nvmrc` создан, закоммичен.

## Memory updates

- `references.md` — локальный путь, GitHub URL, ветки, версии тулчейна.
- `project_state.md` — отметить `01a` done, следующая `01b-server-handoff`.

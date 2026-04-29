#!/usr/bin/env bash
# Собирает _BUILD/HANDBOOK.md — единый markdown-документ для владельца
# из source-of-truth .md файлов.
#
# Запускать из корня репо: bash scripts/build-handbook.sh
#
# Идея: один документ для владельца со всем, что ему реально нужно — без
# Claude-only KB-файлов, без spec-инструкций. Регенерируется одной командой
# после правок любого исходника.

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Список источников: "путь|заголовок Части в HANDBOOK"
# Порядок имеет значение — это порядок чтения линейно.
# ──────────────────────────────────────────────────────────────────────────────
declare -a SOURCES=(
  "_BUILD/HOW-TO-START.md|I. Старт и работа с проектом"
  "docs/team-onboarding.md|II. Подключение второго разработчика"
  "docs/domain-connect.md|III. Подключение домена"
  "docs/legal-templates.md|IV. Юридические тексты для RU-сайтов (152-ФЗ)"
  "docs/troubleshooting.md|V. Если что-то сломалось"
  "_BUILD/changelog.md|Приложение A. История версий"
)

OUT_MD="_BUILD/HANDBOOK.md"

# ──────────────────────────────────────────────────────────────────────────────
# Pre-flight
# ──────────────────────────────────────────────────────────────────────────────

if [ ! -f CLAUDE.md ] || [ ! -d _BUILD ]; then
  echo "ERROR: запускай из корня bootstrap-репо (где лежит CLAUDE.md)" >&2
  exit 1
fi

for entry in "${SOURCES[@]}"; do
  file="${entry%%|*}"
  if [ ! -f "$file" ]; then
    echo "ERROR: источник не найден: $file" >&2
    exit 1
  fi
done

VERSION=$(grep -m1 -E "^## v[0-9]" _BUILD/changelog.md | sed -E 's/^## (v[^ ]+).*/\1/' || echo "v?")
DATE=$(date +%Y-%m-%d)

# ──────────────────────────────────────────────────────────────────────────────
# Сборка HANDBOOK.md
# ──────────────────────────────────────────────────────────────────────────────

echo "→ Сборка $OUT_MD ..."

{
  cat <<EOF
# web-dev-bootstrap — Руководство владельца

**Версия:** $VERSION
**Собрано:** $DATE

> Это **сборный** документ из 6 источников в репо. Не правь HANDBOOK напрямую — правь исходные \`.md\` и пересобирай через \`bash scripts/build-handbook.sh\`.

## Что внутри

| Часть | Содержание | Источник |
|---|---|---|
| I | Старт и работа с проектом (главный workflow) | \`_BUILD/HOW-TO-START.md\` |
| II | Подключение второго разработчика (для коллаборатора) | \`docs/team-onboarding.md\` |
| III | Подключение домена (DNS у регистратора) | \`docs/domain-connect.md\` |
| IV | Юридические тексты для RU-сайтов (152-ФЗ) | \`docs/legal-templates.md\` |
| V | Если что-то сломалось (троублшутинг) | \`docs/troubleshooting.md\` |
| Прил. A | История версий | \`_BUILD/changelog.md\` |

> **Что НЕ вошло** (по дизайну): инструкции для Claude (\`docs/architecture.md\`, \`design-system.md\`, \`content-layout.md\`, \`performance.md\`, \`seo.md\`, \`forms-and-crm.md\`, \`automation.md\`, \`server-*.md\`, \`workflow.md\`, \`stack.md\`, \`conversion-patterns.md\`), spec-файлы для Claude (\`specs/\*\`), миграционный промт (\`_BUILD/v3/02-migrate-existing-project.md\`). Все они доступны в репо как самостоятельные файлы и читаются Claude'ом по запросу.

---

EOF

  for entry in "${SOURCES[@]}"; do
    file="${entry%%|*}"
    title="${entry##*|}"

    echo "## Часть $title"
    echo ""
    echo "_Источник: [\`$file\`](../$file)_"
    echo ""

    # Сдвинуть все заголовки в файле на +1 уровень: # → ##, ## → ###, и т.д.
    # Чтобы в HANDBOOK была иерархия:
    #   # Главный титул (один)
    #   ## Часть I (наш заголовок выше)
    #   ### Подраздел из исходного файла (был ##)
    #   #### Под-подраздел (был ###)
    sed -E 's/^(#+) /\1# /' "$file"

    echo ""
    echo "---"
    echo ""
  done
} > "$OUT_MD"

LINES_MD=$(wc -l < "$OUT_MD" | tr -d ' ')
SIZE_MD=$(wc -c < "$OUT_MD" | awk '{ printf "%.0fK", $1/1024 }')

echo "  ✓ $OUT_MD ($LINES_MD строк, $SIZE_MD)"
echo ""
echo "Открыть:"
echo "   code $OUT_MD          # VS Code"
echo "   cursor $OUT_MD        # Cursor"
echo "   open $OUT_MD          # дефолтный markdown-просмотрщик"

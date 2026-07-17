#!/usr/bin/env bash
# rollback.sh — switch the production symlink on the VPS back to the previous
# release. Push-based deploy keeps last 5 releases in
# /home/deploy/prod/{site}/releases/<sha>/, so rollback is just `ln -sfn` plus
# a clean PM2 restart — no git fetch, no pnpm install, no build. Seconds.
#
# После смены симлинка PM2 перезапускается ТОЛЬКО через `delete` + `start`:
# `pm2 restart`/`reload` кэширует resolved-путь симлинка и продолжает крутить
# старый релиз (боевой урок). `PORT` и `HOSTNAME=127.0.0.1` передаются как env
# ОС на `pm2 start` — standalone server.js читает их из окружения процесса,
# не из `.env`.
#
# Usage:
#   scripts/rollback.sh [site] [ssh_alias] [port]
#   PROD_PORT=3010 scripts/rollback.sh [site] [ssh_alias]
#
# Defaults:
#   site      — package.json#name in cwd
#   ssh_alias — same as site (so configure ~/.ssh/config Host {site} → VPS)
#   port      — third arg or $PROD_PORT; ОБЯЗАТЕЛЕН (см. usage-подсказку ниже)
#
# After rollback: revert the bad commit on Mac and push so the next workflow
# rebuilds from green main. Otherwise the next push will redeploy the broken
# release on top of the rolled-back symlink.

set -euo pipefail

site="${1:-}"
ssh_alias="${2:-}"
port="${3:-${PROD_PORT:-}}"

if [ -z "$site" ]; then
  if [ -f package.json ]; then
    site=$(node -p "require('./package.json').name" 2>/dev/null || true)
  fi
fi
if [ -z "$site" ]; then
  echo "ERROR: cannot determine site name. Pass as first arg." >&2
  echo "Usage: scripts/rollback.sh [site] [ssh_alias] [port]" >&2
  exit 1
fi

if [ -z "$port" ]; then
  cat >&2 <<'USAGE'
ERROR: prod port is not set.

После смены симлинка PM2 перезапускается через `delete` + `start`, и на
`start` обязательно передаётся PORT (standalone server.js читает его из env
процесса, не из .env). Скрипту нужен порт ЭТОГО сайта:

  scripts/rollback.sh <site> <ssh_alias> <port>
  PROD_PORT=3010 scripts/rollback.sh <site> <ssh_alias>

Где взять порт: ~/ports.md на VPS, repository variable PROD_PORT в GitHub-репо,
или .claude/memory/references.md проекта.
USAGE
  exit 1
fi
case "$port" in
  *[!0-9]*) echo "ERROR: port must be a number, got: $port" >&2; exit 1 ;;
esac

ssh_alias="${ssh_alias:-$site}"
remote_dir="/home/deploy/prod/${site}"
pm2_name="${site}-prod"

echo "About to roll back the production symlink on the VPS:"
echo "  remote host:    $ssh_alias"
echo "  remote dir:     $remote_dir"
echo "  pm2 process:    $pm2_name (PORT=$port, HOSTNAME=127.0.0.1)"
echo
echo "This will:"
echo "  1. Find the previous release in $remote_dir/releases/ (and check its server.js exists)"
echo "  2. Switch $remote_dir/current symlink to it (atomic ln -sfn)"
echo "  3. pm2 delete $pm2_name, then PORT=$port HOSTNAME=127.0.0.1 pm2 start current/server.js"
echo "     (restart/reload после смены симлинка не годятся — кэшируют resolved-путь)"
echo "  4. pm2 save + healthcheck"
echo
read -r -p "Proceed? [y/N] " confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted." >&2; exit 1 ;;
esac

# shellcheck disable=SC2087
ssh "$ssh_alias" bash <<EOF
set -euo pipefail
cd "${remote_dir}"

if [ ! -L current ]; then
  echo "ERROR: ${remote_dir}/current is not a symlink — nothing to roll back." >&2
  exit 1
fi

current_sha=\$(readlink current | xargs basename)
prev_sha=\$(ls -1tr releases | grep -vx "\$current_sha" | tail -1 || true)

if [ -z "\$prev_sha" ]; then
  echo "ERROR: only one release in releases/, no previous to roll back to." >&2
  echo "       (current = \$current_sha)" >&2
  exit 1
fi

if [ ! -f "releases/\$prev_sha/server.js" ]; then
  echo "ERROR: releases/\$prev_sha/server.js not found — refuse to switch symlink to a broken release." >&2
  exit 1
fi

echo "Rolling back: \$current_sha → \$prev_sha"
ln -sfn "${remote_dir}/releases/\$prev_sha" current
pm2 delete "${pm2_name}" >/dev/null 2>&1 || true
PORT=${port} HOSTNAME=127.0.0.1 pm2 start current/server.js --name "${pm2_name}" >/dev/null
pm2 save >/dev/null
sleep 2
if curl -sf -o /dev/null -I "http://127.0.0.1:${port}"; then
  echo "Healthcheck OK: http://127.0.0.1:${port} отвечает."
else
  echo "WARNING: healthcheck failed — смотри pm2 logs ${pm2_name}." >&2
fi
echo "Done. current → \$(readlink current | xargs basename)"
EOF

echo
echo "OK. Production symlink now points to the previous release."
echo
echo "NEXT STEP on Mac (so the rollback survives the next push to main):"
echo "  git fetch origin && git checkout main && git pull"
echo
echo "  # If <bad-commit> is a merge commit (e.g. 'Merge pull request #N'):"
echo "  git revert -m 1 <bad-merge-commit-hash>"
echo "  # Otherwise (regular commit):"
echo "  git revert <bad-commit-hash>"
echo
echo "  git push origin main"
echo "  # GitHub Actions will rebuild and ship a new release. The bad commit"
echo "  # stays in history but is reverted; the rolled-back release stays in"
echo "  # releases/ until the cleanup step prunes it (last-5 retention)."
echo
echo "Hint: to check if a commit is a merge, run:"
echo "  [ \$(git rev-list --parents -n 1 <hash> | wc -w) -gt 2 ] && echo 'merge — use -m 1' || echo 'regular'"

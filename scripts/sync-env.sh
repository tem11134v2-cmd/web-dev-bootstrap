#!/usr/bin/env bash
# sync-env.sh — copy local .env.production to the VPS production folder
# and restart pm2 so the new vars are picked up.
#
# Usage:
#   scripts/sync-env.sh                            # site=package.json#name, ssh_alias=${site}-new
#   scripts/sync-env.sh <site> <ssh_alias>        # explicit
#
# Local file: ~/projects/<site>/.env.production (gitignored). Remote file: /home/deploy/prod/<site>/.env (chmod 600).
#
# Why this exists: secrets must never be committed. Manual scp + ssh + pm2 restart
# is error-prone (path typos, forgetting --update-env). This script is the one
# blessed path.

set -euo pipefail

site="${1:-}"
ssh_alias="${2:-}"

if [ -z "$site" ]; then
  if [ -f package.json ]; then
    site=$(node -p "require('./package.json').name" 2>/dev/null || true)
  fi
fi

if [ -z "$site" ]; then
  echo "ERROR: cannot determine site name. Pass as first arg or run inside a project folder with package.json." >&2
  exit 1
fi

# Convention: secrets live next to the project, gitignored, single canonical path.
LOCAL_ENV="${HOME}/projects/${site}/.env.production"
ssh_alias="${ssh_alias:-${site}-new}"

if [ ! -f "$LOCAL_ENV" ]; then
  echo "ERROR: $LOCAL_ENV not found." >&2
  echo "Create it (gitignored via .env* pattern) with TG_BOT_TOKEN, TG_CHAT_ID, SMTP_PASS, etc." >&2
  echo "See .env.example in the project for the expected keys." >&2
  exit 1
fi

remote_path="/home/deploy/prod/${site}/.env"
pm2_name="${site}-prod"

echo "About to sync secrets:"
echo "  local file:  $LOCAL_ENV ($(wc -l <"$LOCAL_ENV" | tr -d ' ') lines, $(wc -c <"$LOCAL_ENV" | tr -d ' ') bytes)"
echo "  remote host: $ssh_alias"
echo "  remote path: $remote_path"
echo "  pm2 process: $pm2_name (will be restarted with --update-env)"
echo
read -r -p "Proceed? [y/N] " confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted." >&2; exit 1 ;;
esac

scp -q "$LOCAL_ENV" "${ssh_alias}:${remote_path}"
ssh "$ssh_alias" "chmod 600 ${remote_path} && pm2 restart ${pm2_name} --update-env >/dev/null && pm2 save >/dev/null"

echo "OK. Verifying first non-empty var on the server:"
first_var=$(grep -E '^[A-Z_][A-Z0-9_]*=' "$LOCAL_ENV" | head -1 | cut -d= -f1)
if [ -n "$first_var" ]; then
  ssh "$ssh_alias" "pm2 env 0 2>/dev/null | grep -E '^${first_var}=' | head -1 | sed 's/=.*/=<set>/'" || true
fi

echo "Done."

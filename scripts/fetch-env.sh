#!/usr/bin/env bash
# fetch-env.sh — pull the active .env from VPS into local .env.production.
#
# Mirror of sync-env.sh: that one pushes Mac → VPS as a fallback for
# Actions-based delivery. This one pulls VPS → Mac when you set up a fresh
# device (new Mac, lost laptop, second machine) and need a working
# .env.production for local prod-like work.
#
# Why VPS is the source of truth here:
#   - Actions writes the active .env from PROD_ENV_FILE secret on every push;
#     the file in releases/<sha>/.env is therefore the freshest plain-text
#     copy that exists anywhere (GitHub stores secrets encrypted — they can
#     be set, not read back).
#   - .env.production is gitignored on purpose (server-side secrets like
#     TURNSTILE_SECRET_KEY, Sheets service account, Telegram bot token, CRM
#     credentials never go into git history).
#
# Usage:
#   scripts/fetch-env.sh                          # site=package.json#name, ssh_alias=site
#   scripts/fetch-env.sh <site> <ssh_alias>       # explicit
#
# Pre-req: SSH access to the VPS as `deploy` user. If you don't have it yet
# on this device — first `ssh-copy-id deploy@<vps-ip>` from another machine
# that does, or via the hosting panel.
#
# Local file:  ~/projects/<site>/.env.production (will be (over)written; existing
#              file is backed up as .env.production.bak.<timestamp>)
# Remote file: /home/deploy/prod/<site>/current/.env (resolves into the active
#              releases/<sha>/.env via the symlink)

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

LOCAL_ENV="${HOME}/projects/${site}/.env.production"
ssh_alias="${ssh_alias:-${site}}"
remote_path="/home/deploy/prod/${site}/current/.env"

echo "About to fetch secrets from VPS into local .env.production:"
echo "  remote host: $ssh_alias"
echo "  remote path: $remote_path  (resolves into the active releases/<sha>/.env via the 'current' symlink)"
echo "  local file:  $LOCAL_ENV"

if [ -f "$LOCAL_ENV" ]; then
  echo "  ⚠ existing local file will be backed up as .env.production.bak.<timestamp>"
fi
echo

read -r -p "Proceed? [y/N] " confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted." >&2; exit 1 ;;
esac

# Verify ssh access before touching anything locally.
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_alias" "test -f ${remote_path}" 2>/dev/null; then
  echo >&2
  echo "ERROR: cannot reach $remote_path on $ssh_alias." >&2
  echo "Possible causes:" >&2
  echo "  - SSH access not set up on this device. From another machine that has access:" >&2
  echo "      ssh-copy-id deploy@<vps-ip>" >&2
  echo "    or add this device's ~/.ssh/id_ed25519.pub to deploy@vps:~/.ssh/authorized_keys via the hosting panel." >&2
  echo "  - ~/.ssh/config is missing a Host entry for '$ssh_alias' — add one or pass an explicit alias as the 2nd arg." >&2
  echo "  - The site has not been deployed yet — releases/<sha>/.env doesn't exist." >&2
  exit 1
fi

# Backup the existing local file so we never destroy work silently.
mkdir -p "$(dirname "$LOCAL_ENV")"
if [ -f "$LOCAL_ENV" ]; then
  ts=$(date +%Y%m%d-%H%M%S)
  cp "$LOCAL_ENV" "${LOCAL_ENV}.bak.${ts}"
  echo "Backed up existing $LOCAL_ENV → ${LOCAL_ENV}.bak.${ts}"
fi

# Pull. scp resolves the symlink server-side and copies the actual file content.
scp -q "${ssh_alias}:${remote_path}" "$LOCAL_ENV"
chmod 600 "$LOCAL_ENV"

lines=$(wc -l <"$LOCAL_ENV" | tr -d ' ')
bytes=$(wc -c <"$LOCAL_ENV" | tr -d ' ')
echo "OK. Fetched $LOCAL_ENV ($lines lines, $bytes bytes, mode 600)."
echo

# Show variable names (not values) so user knows what arrived without leaking secrets.
echo "Variables in fetched file:"
grep -E '^[A-Z_][A-Z0-9_]*=' "$LOCAL_ENV" | cut -d= -f1 | sed 's/^/  /' || true

echo
echo "Done. Next steps:"
echo "  - pnpm dev    # local prod-like run with these secrets"
echo "  - if you edited locally and want to push back: scripts/sync-env.sh + gh secret set PROD_ENV_FILE"

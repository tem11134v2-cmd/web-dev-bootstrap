#!/usr/bin/env bash
# rollback.sh — roll back the production deploy on the VPS to a specific commit.
# Use this when a bad deploy is on prod and you need to restore service NOW;
# afterwards revert the bad commit on Mac and push so Actions redeploys cleanly.
#
# Usage:
#   scripts/rollback.sh <commit-hash> [site] [ssh_alias]
#
# Defaults: site=package.json#name, ssh_alias=${site}-new (e.g. mysite-new)

set -euo pipefail

hash="${1:-}"
site="${2:-}"
ssh_alias="${3:-}"

if [ -z "$hash" ]; then
  echo "ERROR: commit hash required as first arg." >&2
  echo "Usage: scripts/rollback.sh <commit-hash> [site] [ssh_alias]" >&2
  exit 1
fi

if [ -z "$site" ]; then
  if [ -f package.json ]; then
    site=$(node -p "require('./package.json').name" 2>/dev/null || true)
  fi
fi
if [ -z "$site" ]; then
  echo "ERROR: cannot determine site name. Pass as second arg." >&2
  exit 1
fi

ssh_alias="${ssh_alias:-${site}-new}"

remote_dir="/home/deploy/prod/${site}"
pm2_name="${site}-prod"

echo "About to rollback production:"
echo "  remote host:    $ssh_alias"
echo "  remote dir:     $remote_dir"
echo "  reset to:       $hash"
echo "  pm2 process:    $pm2_name"
echo
echo "WARNING: this resets the prod working tree to the given commit (git reset --hard)."
echo "         Any commits ahead of <hash> on the server become unreachable."
read -r -p "Proceed? [y/N] " confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted." >&2; exit 1 ;;
esac

# shellcheck disable=SC2087
ssh "$ssh_alias" bash <<EOF
set -euo pipefail
cd "${remote_dir}"
git fetch --quiet
git reset --hard "${hash}"
npm ci --no-audit --no-fund
npm run build
pm2 restart "${pm2_name}" --update-env >/dev/null
pm2 save >/dev/null
echo "Rolled back to: \$(git rev-parse --short HEAD) - \$(git log -1 --format=%s)"
EOF

echo
echo "OK. Production now serves commit ${hash}."
echo
echo "NEXT STEP on Mac (so the rollback survives the next deploy):"
echo "  git fetch origin"
echo "  git checkout main"
echo "  git pull"

# Detect: is the BAD commit (the one we are reverting from) a merge commit?
# Heuristic: if the previous HEAD on prod (pre-rollback) is a GitHub PR-merge,
# 'git revert <bad>' will fail with "commit ... has more than one parent".
# We don't know the bad hash here, but we DO know HEAD on local main moves
# forward via PR merges typically — so warn proactively.
echo
echo "  # If <bad-commit> is a merge commit (e.g. 'Merge pull request #N'):"
echo "  git revert -m 1 <bad-merge-commit-hash>"
echo "  # Otherwise (regular commit):"
echo "  git revert <bad-commit-hash>"
echo
echo "  git push origin main"
echo "  # GitHub Actions will redeploy. The bad commit stays in history but is reverted."
echo
echo "Hint: to check if a commit is a merge, run:"
echo "  [ \$(git rev-list --parents -n 1 <hash> | wc -w) -gt 2 ] && echo 'merge — use -m 1' || echo 'regular'"

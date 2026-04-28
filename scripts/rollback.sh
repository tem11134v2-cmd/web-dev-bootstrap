#!/usr/bin/env bash
# rollback.sh — switch the production symlink on the VPS back to the previous
# release. Push-based deploy keeps last 5 releases in
# /home/deploy/prod/{site}/releases/<sha>/, so rollback is just `ln -sfn` and
# `pm2 reload` — no git fetch, no pnpm install, no build. Milliseconds.
#
# Usage:
#   scripts/rollback.sh [site] [ssh_alias]
#
# Defaults:
#   site      — package.json#name in cwd
#   ssh_alias — same as site (so configure ~/.ssh/config Host {site} → VPS).
#
# After rollback: revert the bad commit on Mac and push so the next workflow
# rebuilds from green main. Otherwise the next push will redeploy the broken
# release on top of the rolled-back symlink.

set -euo pipefail

site="${1:-}"
ssh_alias="${2:-}"

if [ -z "$site" ]; then
  if [ -f package.json ]; then
    site=$(node -p "require('./package.json').name" 2>/dev/null || true)
  fi
fi
if [ -z "$site" ]; then
  echo "ERROR: cannot determine site name. Pass as first arg." >&2
  echo "Usage: scripts/rollback.sh [site] [ssh_alias]" >&2
  exit 1
fi

ssh_alias="${ssh_alias:-$site}"
remote_dir="/home/deploy/prod/${site}"
pm2_name="${site}-prod"

echo "About to roll back the production symlink on the VPS:"
echo "  remote host:    $ssh_alias"
echo "  remote dir:     $remote_dir"
echo "  pm2 process:    $pm2_name"
echo
echo "This will:"
echo "  1. Find the previous release in $remote_dir/releases/"
echo "  2. Switch $remote_dir/current symlink to it"
echo "  3. Run 'pm2 reload $pm2_name --update-env'"
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

echo "Rolling back: \$current_sha → \$prev_sha"
ln -sfn "${remote_dir}/releases/\$prev_sha" current
pm2 reload "${pm2_name}" --update-env >/dev/null
pm2 save >/dev/null
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
echo "  # GitHub Actions will rebuild and rsync a new release. The bad commit"
echo "  # stays in history but is reverted; the rolled-back release stays in"
echo "  # releases/ until the cleanup step prunes it (last-5 retention)."
echo
echo "Hint: to check if a commit is a merge, run:"
echo "  [ \$(git rev-list --parents -n 1 <hash> | wc -w) -gt 2 ] && echo 'merge — use -m 1' || echo 'regular'"

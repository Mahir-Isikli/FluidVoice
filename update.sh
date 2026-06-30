#!/bin/bash
# Pull the latest upstream FluidVoice, re-apply our local feature patch on top,
# and rebuild. This is how you stay current with upstream while keeping the
# custom mouse-bindable Paste-Last / Press-Enter changes.
#
# Requires a remote named "upstream" -> altic-dev/FluidVoice.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if ! git remote | grep -qx upstream; then
  echo "No 'upstream' remote. Add it once with:"
  echo "  git remote add upstream https://github.com/altic-dev/FluidVoice.git"
  exit 1
fi

echo "==> Fetching upstream…"
git fetch upstream

NEW="$(git log --oneline HEAD..upstream/main 2>/dev/null | wc -l | tr -d ' ')"
echo "==> $NEW new upstream commit(s) on main since your branch base."
if [ "$NEW" != "0" ]; then
  git log --oneline HEAD..upstream/main | head -40
fi

if [ "$NEW" = "0" ]; then
  echo "==> Already up to date. Nothing to do."
  exit 0
fi

echo "==> Rebasing $BRANCH onto upstream/main…"
if git rebase upstream/main; then
  echo "==> Rebase clean. Rebuilding + relaunching…"
  ./rebuild.sh --open
  echo "==> Done. You're on the latest upstream with your patch applied."
else
  echo "!! Rebase hit conflicts (most likely the upstream paste-last feature landed and overlaps ours)."
  echo "!! Aborting to leave your tree exactly as it was. Ask Claude to reconcile the conflict."
  git rebase --abort
  exit 1
fi

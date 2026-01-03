#!/usr/bin/env bash
set -e

cd "$HOME/apprendys"

notify-send "Apprendys" "Recherche de mises à jour…"

git add -A >/dev/null 2>&1 || true
git stash push -m "apprendys-auto-stash" >/dev/null 2>&1 || true

git pull --rebase

bash "$HOME/apprendys/apply.sh" 2>/dev/null || true

notify-send "Apprendys" "Apprendys est à jour."

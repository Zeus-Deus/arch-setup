#!/usr/bin/env bash
# zellij — terminal multiplexer. Persistent sessions, splits, and tabs that
# survive a dropped connection. On every machine so an attached session is
# reachable wherever you land.
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

if ! command -v zellij >/dev/null 2>&1; then
  step "installing zellij"
  sudo pacman -S --needed --noconfirm zellij
fi
step "zellij ready"

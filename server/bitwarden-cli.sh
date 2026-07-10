#!/usr/bin/env bash
# bitwarden-cli — the `bw` CLI for headless credential retrieval (Vexis pulls
# secrets through it). Server-only. Login/unlock is interactive and one-time:
#   bw login    # once, ties this machine to the account
#   bw unlock   # per session -> export BW_SESSION=...
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

if ! command -v bw >/dev/null 2>&1; then
  step "installing bitwarden-cli"
  sudo pacman -S --needed --noconfirm bitwarden-cli
fi
step "bitwarden-cli ready (run 'bw login' then 'bw unlock')"

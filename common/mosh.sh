#!/usr/bin/env bash
# mosh — roaming-resilient remote shell. Authenticates over SSH, then runs on
# UDP 60000-61000, so it survives sleep, IP changes, and laggy links. Over
# tailscale it works as-is; on a firewalled box, open that UDP range.
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

if ! command -v mosh >/dev/null 2>&1; then
  step "installing mosh"
  sudo pacman -S --needed --noconfirm mosh
fi
step "mosh ready"

#!/usr/bin/env bash
# bitwarden — the desktop password-manager GUI (Electron app). On every machine
# so credentials are one keystroke away. The `bw` CLI is separate (server role).
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

if ! command -v bitwarden >/dev/null 2>&1; then
  step "installing bitwarden (desktop app)"
  sudo pacman -S --needed --noconfirm bitwarden
fi
step "bitwarden ready"

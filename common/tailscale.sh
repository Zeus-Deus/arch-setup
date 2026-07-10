#!/usr/bin/env bash
# tailscale — install, enable, and bring up the tailnet.
# The login is the one interactive step: `tailscale up` prints a URL you open
# once to authenticate THIS machine. Nothing here stores a secret.
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

if ! command -v tailscale >/dev/null 2>&1; then
  step "installing tailscale"
  sudo pacman -S --needed --noconfirm tailscale
fi

sudo systemctl enable --now tailscaled

if ! tailscale status >/dev/null 2>&1 || [ -z "$(tailscale ip -4 2>/dev/null || true)" ]; then
  step "bringing tailscale up — this opens a one-time login URL; approve it"
  sudo tailscale up
fi

step "tailscale IP: $(tailscale ip -4 2>/dev/null | head -1 || echo 'pending')"

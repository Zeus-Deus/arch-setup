#!/usr/bin/env bash
# arch-setup — personal Arch/Omarchy machine provisioning.
#
# One command to make a fresh Arch/Omarchy box "yours": dev/system tooling
# installed, configured, and enabled, safe-by-default.
#
# Usage:
#   ./install.sh              # common layer only (default)
#   ./install.sh common       # same as above
#   ./install.sh desktop      # common + desktop-only bits
#   ./install.sh server       # common + server-only bits
#
# Modules are small, idempotent, and additive. Re-running is safe.
set -euo pipefail

ROLE="${1:-common}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ARCH_SETUP_ROLE="$ROLE"
export ARCH_SETUP_DIR="$HERE"

blue() { printf '\n\033[1;34m::\033[0m %s\n' "$*"; }

case "$ROLE" in
  common|desktop|server) ;;
  *) echo "unknown role: '$ROLE' (use: common | desktop | server)" >&2; exit 1 ;;
esac

blue "arch-setup — role=$ROLE"

# --- common layer: runs for every role -------------------------------------
# Order matters: tailscale + keys go in BEFORE ssh is hardened, so you can
# never lock yourself out.
bash "$HERE/common/tailscale.sh"
bash "$HERE/common/ssh.sh"
bash "$HERE/common/earlyoom.sh"
bash "$HERE/common/btrfsmaintenance.sh"
bash "$HERE/common/zellij.sh"
bash "$HERE/common/mosh.sh"
bash "$HERE/common/bitwarden.sh"

# --- role-specific layers (add scripts here as the repo grows) --------------
if [ "$ROLE" = desktop ] && [ -d "$HERE/desktop" ]; then
  for m in "$HERE"/desktop/*.sh; do [ -e "$m" ] && bash "$m"; done
fi
if [ "$ROLE" = server ] && [ -d "$HERE/server" ]; then
  for m in "$HERE"/server/*.sh; do [ -e "$m" ] && bash "$m"; done
fi

blue "done — role=$ROLE. Open a NEW ssh session to confirm access before closing this one."

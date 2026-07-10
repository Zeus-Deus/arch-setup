#!/usr/bin/env bash
# earlyoom — kill the largest hog before the box thrashes itself unreachable,
# and NEVER the daemons needed to reach/recover it (sshd, tailscaled, ...).
#
# Trigger: available RAM < 10% AND free swap < 50%.
# Desktop role adds `-n` for on-screen (D-Bus) notifications; headless omits it.
# Logs land in the journal: `journalctl -u earlyoom`.
set -euo pipefail
ROLE="${ARCH_SETUP_ROLE:-common}"
step() { printf '  -> %s\n' "$*"; }

if ! command -v earlyoom >/dev/null 2>&1; then
  step "installing earlyoom"
  sudo pacman -S --needed --noconfirm earlyoom
fi

NOTIFY=""
[ "$ROLE" = desktop ] && NOTIFY=" -n"

sudo tee /etc/default/earlyoom >/dev/null <<EOF
# managed by arch-setup
# Kill the largest process when available RAM <10% AND free swap <50%,
# instead of letting the box thrash itself unreachable.
# Never pick the daemons we need to reach/recover the box remotely.
EARLYOOM_ARGS="-r 3600 -m 10 -s 50${NOTIFY} --avoid '(^|/)(init|systemd|sshd|tailscaled|dockerd|containerd|systemd-journal)\$'"
EOF

sudo systemctl enable --now earlyoom
sudo systemctl restart earlyoom
step "earlyoom enabled (role=$ROLE, on-screen notify=${NOTIFY:+on}${NOTIFY:-off})"

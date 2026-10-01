#!/usr/bin/env bash
# headless — a laptop that runs with the lid closed and never sleeps.
# Lid switch ignored (on battery, on power, docked); all sleep targets masked,
# so neither logind nor an idle daemon can suspend it.
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

sudo install -d -m 755 /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/90-arch-setup-headless.conf >/dev/null <<'EOF'
# managed by arch-setup — run with the lid closed
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

sudo systemctl mask --quiet sleep.target suspend.target hibernate.target \
  hybrid-sleep.target suspend-then-hibernate.target

# logind re-reads its config on SIGHUP; restarting it would kill the session.
sudo systemctl kill -s HUP systemd-logind || true
step "lid close ignored, sleep/suspend/hibernate masked"

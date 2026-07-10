#!/usr/bin/env bash
# btrfsmaintenance — keep btrfs healthy: monthly scrub (verifies checksums,
# catches bit-rot) and monthly balance (reclaims half-empty chunks). Trim is
# left to the system's fstrim.timer; defrag stays off (bad for SSD/COW).
# No-op on any machine without a btrfs filesystem.
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

if ! findmnt -rn -t btrfs >/dev/null 2>&1; then
  step "no btrfs filesystem — skipping"
  exit 0
fi

if ! pacman -Q btrfsmaintenance >/dev/null 2>&1; then
  step "installing btrfsmaintenance"
  sudo pacman -S --needed --noconfirm btrfsmaintenance
fi

# Set the run periods in the package config, preserving every other key.
CONF=/etc/default/btrfsmaintenance
sudo sed -i \
  -e 's/^BTRFS_SCRUB_PERIOD=.*/BTRFS_SCRUB_PERIOD="monthly"/' \
  -e 's/^BTRFS_BALANCE_PERIOD=.*/BTRFS_BALANCE_PERIOD="monthly"/' \
  "$CONF"

# refresh reads the config and (re)enables the matching timers; the .path unit
# re-applies it automatically whenever that config changes.
sudo systemctl enable --now btrfsmaintenance-refresh.path
sudo systemctl start btrfsmaintenance-refresh.service
step "btrfs scrub+balance scheduled monthly (check: systemctl list-timers 'btrfs-*')"

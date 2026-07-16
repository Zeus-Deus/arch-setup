#!/usr/bin/env bash
# ssd-trim — make sure TRIM/discard actually reaches the SSD.
#
# Two conservative defaults stack on Arch and quietly kill SSDs over time:
#   1. fstrim.timer ships disabled, so freed blocks are never reported.
#   2. LUKS mappings block discards by default, so even a manual fstrim
#      can't get through the crypt layer.
# On a QLC drive that fills up, the controller ends up garbage-collecting
# on every write and the whole machine stalls on IO (seen 2026-07-16:
# writes collapsed to ~7 MB/s, desktop unusable with an idle CPU).
#
# Discard-on-LUKS caveat: it reveals which blocks are unused to someone with
# physical disk access. Accepted trade — Fedora/Ubuntu installers do the same.
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

# Pass discards through every LUKS mapping (persistent = stored in the LUKS2
# header, survives reboots; refresh prompts for the passphrase once).
for name in $(lsblk -ln -o NAME,TYPE | awk '$2=="crypt"{print $1}'); do
  if sudo cryptsetup status "$name" | grep -qw discards; then
    step "$name: discard passthrough already enabled"
  else
    step "$name: enabling discard passthrough (asks for the LUKS passphrase)"
    sudo cryptsetup refresh --allow-discards --persistent "$name"
  fi
done

sudo systemctl enable --now fstrim.timer
step "weekly fstrim.timer enabled"

# First trim now — a drive that's never been trimmed shouldn't wait a week.
sudo fstrim -av || true
step "initial fstrim done"

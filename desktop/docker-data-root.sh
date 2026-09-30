#!/usr/bin/env bash
# docker-data-root — keep Docker's images, build cache, containers and named
# volumes on the encrypted data SSD, without touching Docker or Omarchy config.
#
#   /data/docker  --bind-->  /var/lib/docker   (the path Docker already uses)
#
# Opt-in by layout: does nothing unless /data is a mounted filesystem.
# Never moves data. If /var/lib/docker already holds data, it stops and asks
# you to migrate first:
#   sudo systemctl stop docker.socket docker.service
#   sudo rsync -aHAX --numeric-ids /var/lib/docker/ /data/docker/
#   (verify, move the old dir aside, re-run this module, delete it later)
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

SRC=/data/docker
DST=/var/lib/docker
FSTAB_LINE="$SRC $DST none bind,nofail,x-systemd.requires=/data 0 0"
DROPIN=/etc/systemd/system/docker.service.d/data-ssd.conf

if ! command -v dockerd >/dev/null 2>&1; then
  step "docker not installed — skipping docker-data-root"; exit 0
fi
ls /data >/dev/null 2>&1 || true   # trigger /data automount
if ! findmnt -M /data -n -o FSTYPE | grep -qv autofs; then
  step "/data not mounted — skipping docker-data-root"; exit 0
fi

if findmnt -M "$DST" >/dev/null; then
  step "$DST already mounted"
elif sudo test -n "$(sudo ls -A "$DST" 2>/dev/null)"; then
  step "$DST holds data on the OS drive — migrate it to $SRC first (see header); not switching"
  exit 1
fi

# Own subvolume, so future /data snapshots can skip Docker's churn.
if ! sudo test -e "$SRC"; then
  if [ "$(findmnt -M /data -n -o FSTYPE | grep -v autofs)" = btrfs ]; then
    sudo btrfs subvolume create "$SRC" >/dev/null
  else
    sudo mkdir -p "$SRC"
  fi
  sudo chmod 710 "$SRC"
  step "created $SRC"
fi

# Empty, closed mountpoint underneath the bind.
if ! findmnt -M "$DST" >/dev/null; then
  sudo mkdir -p "$DST"
  sudo chmod 000 "$DST"
fi

if ! grep -qE "^[^#]*[[:space:]]$DST[[:space:]]" /etc/fstab; then
  sudo cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d_%H%M%S)"
  printf '\n# Docker data on the data SSD (arch-setup desktop/docker-data-root.sh)\n%s\n' "$FSTAB_LINE" \
    | sudo tee -a /etc/fstab >/dev/null
  step "fstab: $SRC -> $DST"
fi

# Fail closed: docker never starts without the bind (else it would write to the OS drive).
sudo mkdir -p "$(dirname "$DROPIN")"
printf '[Unit]\nRequiresMountsFor=%s\n' "$DST" | sudo tee "$DROPIN" >/dev/null
sudo systemctl daemon-reload
sudo systemctl start var-lib-docker.mount
findmnt -M "$DST" >/dev/null || { step "bind mount failed"; exit 1; }
step "$DST is bound to $SRC; docker.service requires it"

if systemctl is-active --quiet docker; then
  sudo systemctl restart docker
  step "docker restarted"
fi

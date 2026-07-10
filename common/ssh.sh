#!/usr/bin/env bash
# ssh — install openssh and harden it, in a lock-out-proof order.
#
# Safety design:
#   1. authorized_keys is installed BEFORE passwords are disabled.
#   2. Hardening = pubkey only, no root, no passwords (matches the live config).
#   3. Config is validated with `sshd -t` BEFORE the service is reloaded.
#   4. reload (not restart) keeps existing sessions alive while you test a new one.
#
# Optional network hiding: bind sshd to the tailscale IP only, so it isn't
# reachable on LAN/public at all. OFF by default — set ARCH_SETUP_SSH_TAILNET_ONLY=1
# to enable. Caveat: on a headless box, a reboot before tailscale is up can leave
# sshd unable to bind. Pubkey-only already blocks every attack; this is extra.
set -euo pipefail
ROLE="${ARCH_SETUP_ROLE:-common}"
DIR="${ARCH_SETUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
step() { printf '  -> %s\n' "$*"; }

# 1. openssh present
if ! command -v sshd >/dev/null 2>&1; then
  step "installing openssh"
  sudo pacman -S --needed --noconfirm openssh
fi

# 2. install authorized keys FIRST — never lock yourself out
install -d -m 700 "$HOME/.ssh"
AK="$HOME/.ssh/authorized_keys"
touch "$AK"; chmod 600 "$AK"
if [ -f "$DIR/keys/authorized_keys" ]; then
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    case "$key" in \#*) continue ;; esac
    grep -qxF "$key" "$AK" || { echo "$key" >> "$AK"; step "added key: ${key##* }"; }
  done < "$DIR/keys/authorized_keys"
fi

# 3. hardening drop-in (identical on every machine)
sudo install -d -m 755 /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/99-arch-setup-hardening.conf >/dev/null <<'EOF'
# managed by arch-setup — pubkey only, no passwords, no root login
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
step "hardening drop-in written"

# 4. optional tailnet-only bind (off by default)
BINDFILE=/etc/ssh/sshd_config.d/98-arch-setup-tailnet-bind.conf
if [ "${ARCH_SETUP_SSH_TAILNET_ONLY:-0}" = 1 ]; then
  TSIP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
  if [ -n "$TSIP" ]; then
    sudo tee "$BINDFILE" >/dev/null <<EOF
# managed by arch-setup — listen only on the tailscale IP (+ loopback)
ListenAddress $TSIP
ListenAddress 127.0.0.1
EOF
    step "sshd bound to tailscale IP $TSIP (+loopback) only"
  else
    step "WARNING: tailnet-only requested but no tailscale IP yet — skipping bind"
  fi
else
  [ -f "$BINDFILE" ] && { sudo rm -f "$BINDFILE"; step "removed stale tailnet-bind"; }
fi

# 5. VALIDATE before touching the running service
if ! sudo sshd -t; then
  echo "ERROR: sshd config invalid — NOT reloading. Fix the above before continuing." >&2
  exit 1
fi

sudo systemctl enable --now sshd
sudo systemctl reload sshd
step "sshd hardened & reloaded — test a NEW ssh connection before closing your current one"

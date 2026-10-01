#!/usr/bin/env bash
# firewall — this box can be reached, but can't reach your other machines.
#
# Inbound:  nothing, except ssh + mosh on the tailscale interface.
#           (Firewall instead of sshd ListenAddress: no boot-order race.)
#           Omarchy's LocalSend ports are closed.
# Outbound: internet yes. Local network no (RFC1918, link-local, ULA), except
#           DNS + DHCP so the box still gets online. New connections into the
#           tailnet are rejected too — defense in depth behind the tailnet
#           policy; replies to your inbound ssh still flow (conntrack).
#
# Lock-out guard: ssh is only narrowed to tailscale once this box HAS a
# tailscale IP. Existing sessions survive (established traffic is allowed).
#
# Not covered: other LAN hosts' public IPv6 addresses, and Docker container
# traffic (FORWARD chain). Use an isolated Wi-Fi (guest network) as the outer
# layer, and keep the agent out of the docker group.
set -euo pipefail
TS_IF=tailscale0
step() { printf '  -> %s\n' "$*"; }
ufw() { sudo ufw "$@" >/dev/null; }

# A kernel update without a reboot leaves no modules for the running kernel,
# so iptables/ufw can't load. Fail with a clear message instead of a ufw trace.
if [ ! -d "/usr/lib/modules/$(uname -r)" ]; then
  echo "ERROR: kernel was updated but not rebooted — reboot, then re-run ./install.sh isolated" >&2
  exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
  step "installing ufw"
  sudo pacman -S --needed --noconfirm ufw
fi

ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Closed on an untrusted box: Omarchy's LocalSend + any generic ssh allows.
for r in 53317/tcp 53317/udp; do sudo ufw delete allow "$r" >/dev/null 2>&1 || true; done

# --- inbound ----------------------------------------------------------------
if [ -n "$(tailscale ip -4 2>/dev/null | head -1 || true)" ]; then
  ufw allow in on "$TS_IF" to any port 22 proto tcp comment 'ssh: tailnet only'
  ufw allow in on "$TS_IF" to any port 60000:61000 proto udp comment 'mosh: tailnet only'
  for r in 22/tcp 22 ssh OpenSSH; do sudo ufw delete allow "$r" >/dev/null 2>&1 || true; done
  step "ssh/mosh reachable over tailscale only"
else
  ufw allow 22/tcp comment 'ssh: fallback until tailscale is up'
  step "WARNING: no tailscale IP yet — ssh left open on all interfaces; re-run after tailscale is up"
fi

# --- outbound ---------------------------------------------------------------
# Allows first (ufw matches in order), then the rejects.
LAN4="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16"
LAN6="fc00::/7 fe80::/10"
for net in $LAN4; do
  ufw allow out to "$net" port 53 comment 'dns to local router'
  ufw allow out to "$net" port 67 proto udp comment 'dhcp to local router'
done
ufw allow out on "$TS_IF" to 100.100.100.100 port 53 comment 'tailscale MagicDNS'
for net in $LAN4 $LAN6; do
  ufw reject out to "$net" comment 'isolated: no local network'
done
ufw reject out on "$TS_IF" comment 'isolated: no new tailnet connections'

sudo ufw --force enable >/dev/null
sudo systemctl enable ufw >/dev/null 2>&1
step "firewall active: inbound tailnet-only ssh, outbound internet-only"

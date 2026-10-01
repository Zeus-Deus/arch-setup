#!/usr/bin/env bash
# agent-user — an unprivileged account for untrusted agent workloads
# (e.g. a Hermes PR reviewer). If an agent is prompt-injected, this is all it gets:
#   * no sudo, no docker group (docker group = root), password locked
#   * can't SSH in (DenyUsers); the admin enters with `sudo -iu agent`
#   * can't read the admin's home (0700)
#   * lingering on, so its user services (e.g. a gateway) run without a login
set -euo pipefail
AGENT="${ARCH_SETUP_AGENT_USER:-agent}"
step() { printf '  -> %s\n' "$*"; }

if ! id "$AGENT" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash -c "untrusted agent workloads" "$AGENT"
  step "created user $AGENT"
fi

# Strip anything privileged, even if it was added by hand later.
for g in wheel sudo docker adm sys; do
  if id -nG "$AGENT" | tr ' ' '\n' | grep -qx "$g"; then
    sudo gpasswd -d "$AGENT" "$g" >/dev/null
    step "removed $AGENT from $g"
  fi
done

sudo passwd -l "$AGENT" >/dev/null
sudo chmod 700 "/home/$AGENT"
chmod 700 "$HOME"                       # admin home invisible to the agent
sudo loginctl enable-linger "$AGENT"

# Keep the agent off SSH entirely.
DROPIN=/etc/ssh/sshd_config.d/97-arch-setup-deny-agent.conf
printf '# managed by arch-setup — agent account never logs in over ssh\nDenyUsers %s\n' "$AGENT" \
  | sudo tee "$DROPIN" >/dev/null
if sudo sshd -t; then
  sudo systemctl reload sshd
else
  sudo rm -f "$DROPIN"
  echo "ERROR: sshd config invalid after DenyUsers — drop-in removed, not reloading." >&2
  exit 1
fi

step "$AGENT: no sudo, no docker, no ssh, linger on (enter with: sudo -iu $AGENT)"

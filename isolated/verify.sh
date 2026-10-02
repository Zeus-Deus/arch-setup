#!/usr/bin/env bash
# verify — prove the isolation actually holds. Runs last; re-run any time:
#   bash isolated/verify.sh
# Network checks run AS the agent user, since that's who we're containing.
# Exit code = number of failures.
set -uo pipefail
AGENT="${ARCH_SETUP_AGENT_USER:-agent}"
TAG="${ARCH_SETUP_TS_TAG:-tag:isolated}"
fails=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fails=$((fails+1)); }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi; }
# Can the agent open a TCP connection? (exit 0 = connected)
agent_can() { sudo -u "$AGENT" timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }
blocked() { local d="$1" h="$2" p="$3"; if agent_can "$h" "$p"; then fail "$d ($h:$p reachable)"; else pass "$d ($h:$p)"; fi; }

echo ":: ssh"
T="$(sudo sshd -T 2>/dev/null)"
check "root login disabled"     grep -qix 'permitrootlogin no' <<<"$T"
check "password auth disabled"  grep -qix 'passwordauthentication no' <<<"$T"
check "keyboard-interactive off" grep -qix 'kbdinteractiveauthentication no' <<<"$T"
check "$AGENT denied over ssh"  grep -qix "denyusers $AGENT" <<<"$T"

echo ":: tailscale"
check "tailscale up"            test -n "$(tailscale ip -4 2>/dev/null)"
check "tagged $TAG"             bash -c "tailscale status --json | jq -e '(.Self.Tags // []) | index(\"$TAG\")'"

echo ":: firewall"
S="$(sudo ufw status verbose 2>/dev/null)"
check "ufw active"              grep -q '^Status: active' <<<"$S"
check "default deny incoming"   grep -q 'deny (incoming)' <<<"$S"
check "ssh allowed on tailscale only" bash -c "grep -E '^22/tcp on tailscale0 +ALLOW IN' <<<\"\$0\" && ! grep -E '^22(/tcp)? +ALLOW IN' <<<\"\$0\"" "$S"
check "LocalSend closed"        bash -c "! grep -q 53317 <<<\"\$0\"" "$S"

echo ":: agent account ($AGENT)"
check "exists"                  id "$AGENT"
# Real grants only. Deny-only rules like Omarchy's "(ALL) !/usr/bin/asdcontrol"
# (from a %ALL-style sudoers line) list the user but grant nothing.
check "no sudo rights"          bash -c "! sudo -l -U $AGENT | sed -n '/may run the following/,\$p' | tail -n +2 | grep -vE '^\s*\([^)]*\)\s*!' | grep -q ."
check "sudo actually refused"   bash -c "! sudo -u $AGENT sudo -n true"
check "not in wheel/docker"     bash -c "! id -nG $AGENT | tr ' ' '\n' | grep -qxE 'wheel|sudo|docker'"
check "password locked"         bash -c "sudo passwd -S $AGENT | awk '{print \$2}' | grep -qx L"
check "can't read admin home"   bash -c "! sudo -u $AGENT ls $HOME"
check "lingering (services run without login)" test -e "/var/lib/systemd/linger/$AGENT"

echo ":: network (as $AGENT)"
check "internet reachable"      sudo -u "$AGENT" curl -fsS -m 10 -o /dev/null https://archlinux.org
check "DNS resolves"            sudo -u "$AGENT" getent hosts github.com
GW="$(ip -4 route show default | awk '{print $3; exit}')"
[ -n "$GW" ] && blocked "router admin blocked"      "$GW" 80
[ -n "$GW" ] && blocked "router admin (https) blocked" "$GW" 443
for t in ${ARCH_SETUP_VERIFY_LAN:-}; do blocked "LAN target blocked" "${t%:*}" "${t##*:}"; done
mapfile -t PEERS < <(tailscale status --json 2>/dev/null \
  | jq -r '.Peer[]? | select(.Online) | "\(.HostName) \(.TailscaleIPs[0])"')
for p in "${PEERS[@]}"; do
  blocked "tailnet peer ${p% *} blocked" "${p##* }" 22
done
[ "${#PEERS[@]}" -eq 0 ] && echo "  (no online tailnet peers visible to test)"

echo ":: headless"
check "lid close ignored"       bash -c "systemd-analyze cat-config systemd/logind.conf | grep -qx 'HandleLidSwitch=ignore'"
check "suspend masked"          bash -c "systemctl is-enabled suspend.target 2>&1 | grep -qx masked"

echo
if [ "$fails" -eq 0 ]; then printf '\033[32mall checks passed\033[0m\n'
else printf '\033[31m%d check(s) failed\033[0m\n' "$fails"; fi
exit "$fails"

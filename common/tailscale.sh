#!/usr/bin/env bash
# tailscale — install, enable, and bring up the tailnet.
#
# Two ways in:
#   * default: `tailscale up` prints a one-time login URL. The machine joins as
#     YOU (a full member, same access as your other devices).
#   * TS_AUTHKEY=tskey-... : joins with a pre-made auth key, no account login on
#     this box. The key is passed via a temp file, never on the command line.
#
# The isolated role REQUIRES a key tagged $ARCH_SETUP_TS_TAG (default
# tag:isolated). An interactive login would make the box a full member and
# defeat the isolation, so that path is refused. What a tag may reach is
# decided by the tailnet policy file, not here.
set -euo pipefail
ROLE="${ARCH_SETUP_ROLE:-common}"
TAG="${ARCH_SETUP_TS_TAG:-tag:isolated}"
step() { printf '  -> %s\n' "$*"; }
die()  { printf '  !! %s\n' "$*" >&2; exit 1; }

if ! command -v tailscale >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  step "installing tailscale (+ jq)"
  sudo pacman -S --needed --noconfirm tailscale jq
fi

sudo systemctl enable --now tailscaled

ts_ip()     { tailscale ip -4 2>/dev/null | head -1 || true; }
self_tags() { tailscale status --json 2>/dev/null | jq -r '(.Self.Tags // []) | join(",")'; }

if [ -z "$(ts_ip)" ]; then
  args=()
  [ -n "${ARCH_SETUP_TS_HOSTNAME:-}" ] && args+=("--hostname=$ARCH_SETUP_TS_HOSTNAME")

  if [ -n "${TS_AUTHKEY:-}" ]; then
    [ "$ROLE" = isolated ] && args+=("--advertise-tags=$TAG")
    keyfile="$(mktemp)"                       # 0600, removed on exit
    trap 'rm -f "$keyfile"' EXIT
    printf '%s' "$TS_AUTHKEY" > "$keyfile"
    step "joining the tailnet with the provided auth key"
    sudo tailscale up --auth-key="file:$keyfile" "${args[@]}"
  elif [ "$ROLE" = isolated ]; then
    die "isolated role needs TS_AUTHKEY (an auth key tagged $TAG). Refusing an interactive login: it would join this box as a full member."
  else
    step "bringing tailscale up — this opens a one-time login URL; approve it"
    sudo tailscale up "${args[@]}"
  fi
fi

if [ "$ROLE" = isolated ]; then
  case ",$(self_tags)," in
    *",$TAG,"*) step "tagged $TAG (owned by the tag, not by you)" ;;
    *) die "this box is on the tailnet WITHOUT $TAG — it has full member access. Remove it in the admin console and re-run with a tagged key." ;;
  esac
fi

step "tailscale IP: $(ts_ip || echo pending)"

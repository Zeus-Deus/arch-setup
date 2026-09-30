# arch-setup — instructions for the next agent

This is the owner's personal **Arch/Omarchy machine-provisioning** repo. It is
NOT a dotfiles repo — the owner keeps Omarchy's default UI (waybar, Hyprland,
etc.). This repo only installs and configures **dev/system tooling** so a fresh
Arch/Omarchy box becomes usable in one command.

## Prime directive

Keep it **simple, clean, minimal, and safe-by-default**. This repo grows one
small module at a time. Do not add frameworks, do not add a package manager
abstraction, do not pull in dotfiles. If a change makes the repo harder to read
in 30 seconds, it's wrong.

## Layout

```
install.sh          # entrypoint: ./install.sh [common|desktop|server]
common/             # modules that run on EVERY machine
  tailscale.sh
  ssh.sh
  earlyoom.sh
  ssd-trim.sh
  btrfsmaintenance.sh
  zellij.sh
  mosh.sh
  bitwarden.sh
desktop/            # (optional) laptop/desktop-only modules
server/             # (optional) headless-server-only modules
keys/authorized_keys  # PUBLIC keys allowed to log in — safe to commit
```

Role is passed as `$ARCH_SETUP_ROLE` and the repo root as `$ARCH_SETUP_DIR`.

## Rules for adding a module

- One tool per script, under `common/` (everywhere) or `desktop/` / `server/`
  (role-specific). `install.sh` auto-runs role dirs.
- **Idempotent.** Guard installs with `command -v <tool>` and use
  `pacman -S --needed --noconfirm`. Re-running must be safe.
- **Never commit secrets.** Public keys only. Private keys, tailscale auth
  keys, API tokens → never in git (see `.gitignore`). Auth (tailscale login,
  agent keys) happens interactively on first run, not baked into the repo.
- **Never lock the owner out.** For anything touching ssh/network/access:
  install keys and bring up connectivity BEFORE hardening, and validate
  config (e.g. `sshd -t`) BEFORE reloading the service. `reload`, don't
  `restart`, services that carry the live session.
- `sudo` is expected on the target machine (the owner runs `./install.sh`
  there). Don't try to avoid sudo; just use it for privileged steps.

## What each current module does

- **tailscale.sh** — installs tailscale, enables `tailscaled`, runs
  `tailscale up` (one-time login URL). No secret stored.
- **ssh.sh** — installs openssh, merges `keys/authorized_keys`, writes a
  pubkey-only hardening drop-in, validates, reloads. Optional tailnet-only
  bind via `ARCH_SETUP_SSH_TAILNET_ONLY=1` (off by default; boot-race caveat
  on headless boxes).
- **earlyoom.sh** — installs earlyoom, writes `/etc/default/earlyoom` with an
  `--avoid` list that protects sshd/tailscaled/etc., enables the service.
  Desktop role adds `-n` for on-screen notifications.
- **ssd-trim.sh** — enables discard passthrough on every LUKS mapping
  (`cryptsetup refresh --allow-discards --persistent`, asks the passphrase
  once) + weekly `fstrim.timer` + one immediate `fstrim -av`. Without this,
  Arch never TRIMs an encrypted SSD and the drive eventually degrades.
- **btrfsmaintenance.sh** — monthly btrfs scrub + balance; no-op off btrfs.
- **zellij.sh** — terminal multiplexer.
- **mosh.sh** — roaming-resilient remote shell (SSH auth + UDP 60000-61000).
- **bitwarden.sh** — Bitwarden desktop GUI app.
- **desktop/nvidia-container-toolkit.sh** — NVIDIA container toolkit; wires Docker's GPU runtime.
- **desktop/docker-data-root.sh** — Docker storage on the `/data` SSD via an fstab bind
  `/data/docker -> /var/lib/docker` + `RequiresMountsFor` drop-in (fail closed).
  Leaves Omarchy's packaged `/etc/docker/daemon.json` untouched. Skips if `/data`
  isn't mounted; refuses if `/var/lib/docker` already holds data (migrate first).
- **server/bitwarden-cli.sh** — `bw` CLI for headless credential retrieval.

## Not doing (yet)

A custom bootable ISO (archiso) that auto-runs this repo is a future layer that
would *wrap* this repo, not replace it. If asked, build the repo modules first;
the ISO just clones and runs `install.sh`. Never bake private keys/tokens into
an image.

# arch-setup

Personal Arch/Omarchy machine provisioning. One command turns a fresh box into
a usable one — dev/system tooling installed, configured, and enabled,
safe-by-default. Not dotfiles: Omarchy's default UI is kept as-is.

## Use

```bash
git clone git@github.com:Zeus-Deus/arch-setup.git
cd arch-setup
./install.sh            # common layer (works on any machine)
./install.sh desktop    # + desktop/laptop-only bits
./install.sh server     # + headless-server-only bits
TS_AUTHKEY=tskey-... ./install.sh isolated   # untrusted box, see below
```

Re-running is safe (every module is idempotent). Modules use `sudo` for
privileged steps, so run as your normal user.

## What's in it

| Module | Does |
|---|---|
| `common/tailscale.sh` | Installs tailscale, enables `tailscaled`, runs `tailscale up` (one-time login URL). |
| `common/ssh.sh` | Installs openssh, adds your public keys, hardens to **pubkey-only / no root / no passwords**, validates before reload. |
| `common/earlyoom.sh` | Installs earlyoom to kill runaway processes before the box freezes — never sshd/tailscaled. Desktop adds on-screen alerts. |
| `common/btrfsmaintenance.sh` | Monthly btrfs scrub + balance (verify checksums, reclaim chunks). No-op off btrfs. |
| `common/zellij.sh` | Installs the zellij terminal multiplexer. |
| `common/mosh.sh` | Installs mosh — roaming-resilient remote shell (SSH auth + UDP). |
| `common/bitwarden.sh` | Installs the Bitwarden desktop app (GUI). |
| `desktop/nvidia-container-toolkit.sh` | Installs the NVIDIA container toolkit; wires Docker's GPU runtime. |
| `desktop/docker-data-root.sh` | If an encrypted data SSD is mounted at `/data`, bind-mounts `/data/docker` onto `/var/lib/docker` (fstab) and makes Docker require it. Never moves data; skips when `/data` is absent. |
| `server/bitwarden-cli.sh` | Installs the `bw` CLI for headless credential retrieval. |
| `isolated/headless.sh` | Lid close ignored, sleep/suspend/hibernate masked. |
| `isolated/agent-user.sh` | `agent` user for untrusted workloads: no sudo, no docker, no ssh, can't read your home, lingering. |
| `isolated/firewall.sh` | ufw: ssh/mosh in over tailscale only; out to the internet only (no LAN, no new tailnet connections). |
| `isolated/verify.sh` | Pass/fail report of all of the above, network checks run as `agent`. Re-run any time. |

## Access safety

`ssh.sh` is ordered so you can't lock yourself out: your keys go in **before**
password auth is disabled, and the config is validated with `sshd -t` **before**
the service reloads. Existing sessions survive a reload — always test a fresh
connection before closing your current one.

Want ssh reachable *only* over tailscale (invisible on LAN/public)? Run with:

```bash
ARCH_SETUP_SSH_TAILNET_ONLY=1 ./install.sh server
```

Off by default — pubkey-only already blocks every attack, and binding to the
tailscale IP has a boot-order caveat on headless machines.

## Isolated role

For machines that run untrusted work (AI agents, PR reviewers) and must not be
able to reach your other machines. No personal accounts go on the box: no
Bitwarden, no tailscale login.

1. Tailnet policy (once): `tag:isolated` in `tagOwners`, and grants only from
   `autogroup:member`, so tagged devices can be reached but can't connect out.
2. Admin console → Settings → Keys: auth key with tag `tag:isolated`.
3. On the box, connected to an isolated Wi-Fi (guest network):

```bash
TS_AUTHKEY=tskey-... ARCH_SETUP_TS_HOSTNAME=reviewer ./install.sh isolated
```

It refuses to run without a tagged key, and fails if `isolated/verify.sh` does.
After this, ssh in over tailscale only. Run agent workloads as `sudo -iu agent`.
Updated the kernel? Reboot before (re-)running, or the firewall can't load.

## Secrets

Public keys live in `keys/authorized_keys` (safe to commit). Private keys,
tailscale auth keys, and API tokens are **never** committed — logins happen
interactively on first run. See `.gitignore`.

## Adding to it

One small script per tool under `common/` (everywhere) or `desktop/` / `server/`
(role-specific). Keep it minimal. See `CLAUDE.md` for the conventions.

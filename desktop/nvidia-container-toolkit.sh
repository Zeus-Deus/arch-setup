#!/usr/bin/env bash
# nvidia-container-toolkit — let Docker containers use the NVIDIA GPU. Installs
# the toolkit and wires it into Docker's runtime. Assumes the NVIDIA driver is
# already present; this only bridges Docker <-> GPU. Desktop-only (the GPU boxes).
set -euo pipefail
step() { printf '  -> %s\n' "$*"; }

# Only act on machines that actually have an NVIDIA GPU. Skip cleanly on
# AMD/Intel/headless boxes so `install.sh desktop` stays portable across the fleet.
has_nvidia_gpu() {
  if command -v lspci >/dev/null 2>&1; then
    lspci 2>/dev/null | grep -iq 'nvidia'
    return
  fi
  # pciutils absent: fall back to the loaded driver / sysfs.
  [ -d /proc/driver/nvidia ] && return 0
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1
}

if ! has_nvidia_gpu; then
  step "no NVIDIA GPU detected — skipping nvidia-container-toolkit"
  exit 0
fi

if ! pacman -Q nvidia-container-toolkit >/dev/null 2>&1; then
  step "installing nvidia-container-toolkit"
  sudo pacman -S --needed --noconfirm nvidia-container-toolkit
fi

if command -v docker >/dev/null 2>&1; then
  step "wiring docker runtime for nvidia"
  sudo nvidia-ctk runtime configure --runtime=docker
  if systemctl is-active --quiet docker; then
    sudo systemctl restart docker
    step "docker restarted"
  fi
else
  step "docker not installed — toolkit ready; re-run this after docker to wire the runtime"
fi

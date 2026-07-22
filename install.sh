#!/usr/bin/env bash
# Installer for quickshell_dwm on a fresh Arch Linux system.
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPECTED="$HOME/projects/quickshell_dwm"

if [ "$REPO_DIR" != "$EXPECTED" ]; then
    echo "WARNING: this repo is at $REPO_DIR"
    echo "dwm's Super+Space binding and the xinitrc expect $EXPECTED."
    echo "Move the repo there, or edit dwm/config.h (launchercmd) and dotfiles/xinitrc."
    read -rp "Continue anyway? [y/N] " a
    [ "$a" = "y" ] || exit 1
fi

echo "==> Installing packages (sudo)..."
sudo pacman -S --needed \
    base-devel libx11 libxft libxinerama xorg-server xorg-xinit xorg-xprop \
    quickshell picom snixembed \
    xdotool dmenu \
    ghostty \
    ttf-jetbrains-mono-nerd \
    networkmanager bluez bluez-utils

echo "==> Enabling network + bluetooth services..."
sudo systemctl enable --now NetworkManager bluetooth

echo "==> Building and installing dwm..."
make -C "$REPO_DIR/dwm" clean all
sudo make -C "$REPO_DIR/dwm" install

echo "==> Installing dotfiles (existing files backed up as *.bak)..."
mkdir -p "$HOME/.config"
for pair in "dotfiles/xinitrc:$HOME/.xinitrc" "dotfiles/picom.conf:$HOME/.config/picom.conf"; do
    src="$REPO_DIR/${pair%%:*}"
    dst="${pair##*:}"
    [ -f "$dst" ] && cp "$dst" "$dst.bak"
    cp "$src" "$dst"
done

echo
echo "Done. Before starting:"
echo "  1. EDIT ~/.xinitrc — the xrandr monitor layout and the NVIDIA/browser"
echo "     env vars are machine-specific. Adjust or delete them for your box."
echo "  2. Log in on a TTY and run: startx"

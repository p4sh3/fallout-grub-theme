#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'


GRUB_DIR='grub'
BOOT_MODE='legacy'
GRUB_THEME='fallout-grub-theme'
REPO_URL="https://github.com/p4sh3/${GRUB_THEME}/archive/master.tar.gz"
DEST_DIR="/boot/${GRUB_DIR}/themes/${GRUB_THEME}"

# Pretty print helpers (colors + icons)
RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'

info()    { printf "%b\n" "${CYAN}ℹ️  ${BOLD}$*${RESET}"; }
action()  { printf "%b\n" "${MAGENTA}✨ ${BOLD}$*${RESET}"; }
success() { printf "%b\n" "${GREEN}✅ ${BOLD}$*${RESET}"; }
warn()    { printf "%b\n" "${YELLOW}⚠️  ${BOLD}$*${RESET}"; }
error()   { printf "%b\n" "${RED}❌ ${BOLD}$*${RESET}" >&2; }

# Check dependencies
DEPENDENCIES=(mktemp sed sort sudo tar tee tr wget)

for cmd in "${DEPENDENCIES[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "'$cmd' command is required but was not found. Aborting."
    exit 1
  fi
done


# Change to temporary directory
cd $(mktemp -d)

# Pre-authorise sudo
action "Requesting elevated privileges (sudo) — you may be prompted for your password..."
sudo echo >/dev/null 2>&1 || {
  error "Unable to obtain sudo credentials. Aborting."
  exit 1
}

action "Fetching and unpacking theme from repository"
wget -O - "$REPO_URL" | tar -xzf - --strip-components=1

if [[ -d /sys/firmware/efi && -d /boot/efi ]]; then
  BOOT_MODE='UEFI'
else
  BOOT_MODE='legacy'
fi
info "Detected boot mode: ${BOOT_MODE}"

action "Creating GRUB themes directory (${DEST_DIR})"
sudo mkdir -p "$DEST_DIR"

action "Copying theme files to the GRUB themes directory"
sudo cp -r * "$DEST_DIR"

action "Cleaning existing GRUB theme settings from /etc/default/grub"
sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub

action "Ensuring GRUB uses graphical output (commenting GRUB_TERMINAL if present)"
sudo sed -i 's/^\(GRUB_TERMINAL\w*=.*\)/#\1/' /etc/default/grub

action "Removing trailing empty lines from GRUB config"
sudo sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /etc/default/grub

action "Appending a newline to GRUB config to ensure clean ending"
echo | sudo tee -a /etc/default/grub

action "Registering the new theme in GRUB configuration"
echo "GRUB_THEME=${DEST_DIR}/theme.txt" | sudo tee -a /etc/default/grub
success "Theme path added to /etc/default/grub"

action "Removing temporary installation files"
rm -rf "$PWD"
cd

action "Updating GRUB configuration (this may take a moment)"
eval sudo update-grub && success "GRUB configuration updated successfully." || {
  error "Failed to update GRUB. Please run 'sudo update-grub' manually and check for errors."
  exit 1
}

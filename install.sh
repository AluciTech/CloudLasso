#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INSTALL_DIR="/opt/cloudlasso"
BIN_DIR="/usr/local/bin"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
DIM='\033[2m'
NC='\033[0m'

# Display
print_banner() {
    echo -e "${CYAN}"
    cat << 'BANNER'
   _____ _                 _ _
  / ____| |               | | |
 | |    | | ___  _   _  __| | |     __ _ ___ ___  ___
 | |    | |/ _ \| | | |/ _` | |    / _` / __/ __|/ _ \
 | |____| | (_) | |_| | (_| | |___| (_| \__ \__ \ (_) |
  \_____|_|\___/ \__,_|\__,_|______\__,_|___/___/\___/
BANNER
    echo -e "${NC}"
    echo -e "  ${DIM}Installer | Lasso your cloud files down to local disk${NC}"
    echo ""
}

# Helpers
step() {
    echo ""
    echo -e "  ${CYAN}-->  $1${NC}"
    echo ""
}

success() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}[!!]${NC} $1"
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
}

# System dependencies
install_dependencies() {
    step "Installing required system dependencies"

    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y wget fuse3 libnotify-bin
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y wget fuse libnotify
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm wget fuse3 libnotify
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y wget fuse3 libnotify-tools
    else
        warn "Unsupported package manager. Install 'wget', 'fuse', and 'libnotify' manually."
    fi
}

# rclone
install_rclone() {
    step "Checking for rclone"

    if command -v rclone &>/dev/null; then
        success "rclone is already installed."
        return
    fi

    echo "  rclone not found. Fetching and installing..."
    sudo -v ; curl https://rclone.org/install.sh | sudo bash

    if ! command -v rclone &>/dev/null; then
        fail "Failed to install rclone automatically."
        echo "  Check your network or install manually from https://rclone.org/downloads/"
        exit 1
    fi
    success "rclone installed."
}

# Install
install_cloudlasso() {
    step "Installing CloudLasso..."

    sudo mkdir -p "$INSTALL_DIR"

    sudo cp "$SCRIPT_DIR/cloudlasso.sh" "$INSTALL_DIR/"
    if [ -d "$SCRIPT_DIR/icons" ]; then
        sudo cp -r "$SCRIPT_DIR/icons" "$INSTALL_DIR/"
    else
        warn "No 'icons' directory found. Notifications will not have custom icons."
    fi

    sudo chmod +x "$INSTALL_DIR/cloudlasso.sh"
    sudo ln -sf "$INSTALL_DIR/cloudlasso.sh" "$BIN_DIR/cloudlasso"

    success "CloudLasso installed. Run 'cloudlasso' from any terminal."
}

# Entry point
print_banner
install_dependencies
install_rclone
install_cloudlasso

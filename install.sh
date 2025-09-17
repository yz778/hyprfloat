#!/bin/sh

set -e

# ANSI color codes (set blank if not in a TTY)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    RESET='\033[0m'
else
    GREEN=''
    RED=''
    RESET=''
fi

json=$(curl -s https://api.github.com/repos/yz778/hyprfloat/releases/latest)
VERSION=$(echo "$json" | grep -oP '"name":\s*"\K[^"]+')
TARBALL_URL=$(echo "$json" | grep -oP '"tarball_url":\s*"\K[^"]+')
INSTALL_HOME="${INSTALL_HOME:-$HOME/.local/share}"
CONFIG_HOME="${CONFIG_HOME:-$HOME/.config/hypr}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

check_prerequisites() {
    printf " - Checking dependencies"

    for cmd in curl tar lua; do
        if ! command -v "$cmd" >/dev/null; then
            printf ": ${RED}$cmd is not installed${RESET}\n"
            exit 1
        fi
    done

    for lib in posix cjson; do
        if ! lua -l $lib -e "" 2>/dev/null; then
            printf ": ${RED}lua-$lib is not installed${RESET}\n"
            exit 1
        fi
    done

    printf " ... ${GREEN}OK${RESET}\n"
}

download() {
    printf " - Downloading hyprfloat ($VERSION)"

    TMP_DIR=$(mktemp -d)
    if ! curl -sL "$TARBALL_URL" | tar -xz -C "$TMP_DIR" --strip-components=1 2>/dev/null; then
        printf ": ${RED}download failed${RESET}\n"
        exit 1
    fi

    printf " ... ${GREEN}OK${RESET}\n"
}

install_files() {
    local INSTALL_DIR="$INSTALL_HOME/hyprfloat"
    printf " - Installing $INSTALL_DIR "
    printf "${RED}"
    mkdir -p "$INSTALL_DIR"
    cp -r "$TMP_DIR/src/." "$INSTALL_HOME/hyprfloat/"
    printf "${RESET}"
    printf "... ${GREEN}OK${RESET}\n"

    printf " - Installing $BIN_DIR/hyprfloat "
    printf "${RED}"
    ln -sf "$INSTALL_DIR/hyprfloat" "$BIN_DIR/hyprfloat"
    printf "${RESET}"
    printf "... ${GREEN}OK${RESET}\n"
}

check_version() {
    printf " - Verifying"
    if output=$(hyprfloat version); then
        printf ": $output ... ${GREEN}OK${RESET}\n"
    else
        printf " ${RED}failed${RESET}\n"
        exit 1
    fi
}

cleanup() {
    rm -rf "$TMP_DIR"
}

#### MAIN

trap cleanup EXIT INT TERM

echo "Installing hyprfloat"
check_prerequisites
download
install_files
check_version
echo "Done"

echo "
To get started, you can install the default configuration by running:
    hyprfloat install-config
"

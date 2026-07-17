#!/bin/bash
# Quick Continue - macOS uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/uninstall.sh | bash

set -e

PLIST_NAME="com.quickcontinue.daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
APP_DIR="$HOME/Applications/QuickContinue"
APP_BUNDLE="$APP_DIR/QuickContinue.app"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

echo ""
echo "=========================================="
echo "  Quick Continue - Uninstaller"
echo "=========================================="
echo ""

# 1) Stop LaunchAgent if running
if launchctl list 2>/dev/null | grep -q "$PLIST_NAME"; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    info "LaunchAgent stopped."
else
    warn "LaunchAgent not running."
fi

# 2) Remove LaunchAgent plist
if [ -f "$PLIST_PATH" ]; then
    rm -f "$PLIST_PATH"
    info "LaunchAgent plist removed."
fi

# 3) Quit and remove .app bundle (button mode)
if [ -d "$APP_BUNDLE" ]; then
    osascript -e 'tell application "QuickContinue" to quit' 2>/dev/null || true
    sleep 1
fi

# 4) Remove Login Items entry
osascript -e 'tell application "System Events" to delete every login item whose name is "QuickContinue"' 2>/dev/null || true
info "Login Items entry removed."

# 5) Remove app directory
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
    info "Application removed: $APP_DIR"
fi

echo ""
echo -e "  ${GREEN}Uninstalled successfully.${NC}"
echo ""

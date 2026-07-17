#!/bin/bash
# Quick Continue - macOS one-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.sh | bash
#        curl -fsSL .../install.sh | bash -s -- --button   # With floating button

set -e

# Parse arguments
EXTRA_ARGS=""
for arg in "$@"; do
    case $arg in
        --button)
            EXTRA_ARGS="--button"
            ;;
    esac
done

REPO="hope0719/workbuddy-quick-continue"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

APP_DIR="$HOME/Applications/QuickContinue"
BINARY="$APP_DIR/quick_continue"
PLIST_NAME="com.quickcontinue.daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
APP_BUNDLE="$APP_DIR/QuickContinue.app"
SOURCE_URL="${BASE_URL}/src/mac/quick_continue.swift"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=========================================="
echo "  Quick Continue - macOS Installer"
echo "=========================================="
echo ""

# 1) Check platform
if [[ "$(uname)" != "Darwin" ]]; then
    error "This installer is for macOS only."
fi

# 2) Check for Swift
if ! command -v swiftc &>/dev/null; then
    warn "Swift compiler not found."
    echo "  Install Xcode Command Line Tools first:"
    echo "    xcode-select --install"
    echo ""
    read -p "  Run xcode-select --install now? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xcode-select --install
        echo "  Please re-run this installer after Xcode CLT is installed."
        exit 0
    else
        error "Swift compiler is required."
    fi
fi
info "Swift compiler found: $(swiftc --version | head -1)"

# 3) Stop and remove existing services (both LaunchAgent and Login Items)
if launchctl list 2>/dev/null | grep -q "$PLIST_NAME"; then
    warn "Stopping existing LaunchAgent..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi
if [ -f "$PLIST_PATH" ]; then
    rm -f "$PLIST_PATH"
fi
# Remove old Login Items entry (best-effort via osascript)
osascript -e 'tell application "System Events" to delete every login item whose name is "QuickContinue"' 2>/dev/null || true
info "Cleaned up previous installation."

# 4) Create install directory
mkdir -p "$APP_DIR"
info "Install directory: $APP_DIR"

# 5) Download source
echo "  Downloading source..."
TMP_SOURCE=$(mktemp /tmp/quick_continue_XXXXXX.swift)
if curl -fsSL "$SOURCE_URL" -o "$TMP_SOURCE"; then
    info "Source downloaded."
else
    rm -f "$TMP_SOURCE"
    error "Failed to download source from $SOURCE_URL"
fi

# 6) Compile
echo "  Compiling (this may take a moment)..."
if swiftc -O \
    -framework CoreGraphics \
    -framework AppKit \
    -o "$BINARY" \
    "$TMP_SOURCE" 2>&1; then
    info "Compiled successfully."
else
    rm -f "$TMP_SOURCE"
    error "Compilation failed."
fi
rm -f "$TMP_SOURCE"
chmod +x "$BINARY"

# 7) Configure startup method based on mode
if [ -n "$EXTRA_ARGS" ]; then
    # ── Button mode: create .app bundle + Login Item ──
    # LaunchAgent cannot show GUI (no GUI context in background mode).
    # Instead, create a .app bundle and add it to Login Items.

    # Build .app bundle structure
    mkdir -p "$APP_BUNDLE/Contents/MacOS"

    # Create Info.plist
    cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launch.sh</string>
    <key>CFBundleIdentifier</key>
    <string>com.quickcontinue.app</string>
    <key>CFBundleName</key>
    <string>QuickContinue</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

    # Create launcher script inside .app
    cat > "$APP_BUNDLE/Contents/MacOS/launch.sh" <<LAUNCHER
#!/bin/bash
exec "$BINARY" --button
LAUNCHER
    chmod +x "$APP_BUNDLE/Contents/MacOS/launch.sh"

    info "Created app bundle: $APP_BUNDLE"

    # Add to Login Items (starts at login with full GUI context)
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_BUNDLE\", hidden:false}"
    info "Added to Login Items (auto-start at login)."

    # Start now
    open "$APP_BUNDLE"
    info "Service started."
else
    # ── Hotkey-only mode: use LaunchAgent (no GUI needed) ──
    mkdir -p "$HOME/Library/LaunchAgents"

    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BINARY}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${APP_DIR}/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${APP_DIR}/stderr.log</string>
</dict>
</plist>
PLIST
    info "LaunchAgent configured."

    launchctl load "$PLIST_PATH"
    info "Service started."
fi

# 8) Done
echo ""
echo "=========================================="
echo -e "  ${GREEN}Installation complete!${NC}"
echo "=========================================="
echo ""
echo "  Hotkey:  Cmd+Shift+J"
if [ -n "$EXTRA_ARGS" ]; then
    echo "  Button:  Floating button (bottom-right)"
fi
echo "  Action:  Type '继续' + Enter"
echo ""
if [ -n "$EXTRA_ARGS" ]; then
    echo "  Auto-start: Login Items (System Settings → General → Login Items)"
else
    echo "  Auto-start: Login (LaunchAgent)"
fi
echo ""
echo "  Commands:"
if [ -n "$EXTRA_ARGS" ]; then
    echo "    Stop:    osascript -e 'tell application \"QuickContinue\" to quit'"
    echo "    Start:   open $APP_BUNDLE"
else
    echo "    Stop:    launchctl unload ~/Library/LaunchAgents/${PLIST_NAME}.plist"
    echo "    Start:   launchctl load ~/Library/LaunchAgents/${PLIST_NAME}.plist"
    echo "    Logs:    cat ${APP_DIR}/stdout.log"
fi
echo "    Uninstall: curl -fsSL ${BASE_URL}/uninstall.sh | bash"
echo ""
warn "First time? Grant Accessibility permission:"
echo "  System Settings → Privacy & Security → Accessibility"
echo ""

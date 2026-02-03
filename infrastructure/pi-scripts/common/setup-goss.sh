#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/common/setup-goss.sh
# Install goss binary on a Pi for infrastructure verification.
# Overridable commands/paths for testing.

CURL="${CURL:-curl}"
CHMOD="${CHMOD:-chmod}"
GOSS_VERSION="${GOSS_VERSION:-v0.4.9}"
GOSS_BIN="${GOSS_BIN:-/usr/local/bin/goss}"
GOSS_ARCH="${GOSS_ARCH:-arm64}"

# Download and install the goss binary.
# Idempotent: skips if already installed and correct version.
install_goss() {
    # Check if goss is already installed with the correct version
    if [ -x "$GOSS_BIN" ]; then
        local installed_version
        installed_version="$("$GOSS_BIN" --version 2>/dev/null || true)"
        if [[ "$installed_version" == *"$GOSS_VERSION"* ]]; then
            echo "Goss $GOSS_VERSION already installed at $GOSS_BIN, skipping."
            return 0
        fi
    fi

    local url="https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-${GOSS_ARCH}"
    echo "Downloading goss $GOSS_VERSION..."
    $CURL -fsSL -o "$GOSS_BIN" "$url"
    $CHMOD +x "$GOSS_BIN"
    echo "Goss $GOSS_VERSION installed at $GOSS_BIN."
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Installing Goss ==="
    install_goss
    echo "Done."
fi

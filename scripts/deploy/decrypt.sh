#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/decrypt.sh
# Phase 1 of the deploy pipeline: decrypt secrets to a temp directory.
# Sourced by tests (for function access) or run directly.

# Decrypt a SOPS-encrypted file into a directory with strict permissions.
# Usage: decrypt_secrets <encrypted_file> <output_dir>
decrypt_secrets() {
    local encrypted_file="$1"
    local output_dir="$2"

    if [ ! -f "$encrypted_file" ]; then
        echo "ERROR: Encrypted file not found: $encrypted_file" >&2
        return 1
    fi

    if [ -z "${SOPS_AGE_KEY_FILE:-}" ]; then
        echo "ERROR: SOPS_AGE_KEY_FILE is not set. Point it to your age private key." >&2
        return 1
    fi

    if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
        echo "ERROR: SOPS_AGE_KEY_FILE does not exist: $SOPS_AGE_KEY_FILE" >&2
        return 1
    fi

    mkdir -p "$output_dir"
    chmod 700 "$output_dir"

    local decrypted_file="$output_dir/secrets.dec.yaml"
    sops --decrypt "$encrypted_file" > "$decrypted_file"
    chmod 600 "$decrypted_file"
}

# Remove decrypted secrets directory securely.
# Usage: shred_secrets <output_dir>
shred_secrets() {
    local output_dir="$1"

    if [ -d "$output_dir" ]; then
        # Overwrite files before removing (best-effort shred)
        find "$output_dir" -type f -exec sh -c 'dd if=/dev/urandom of="$1" bs=$(wc -c < "$1") count=1 2>/dev/null; rm -f "$1"' _ {} \;
        rm -rf "$output_dir"
    fi
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    ENCRYPTED="$PROJECT_ROOT/infrastructure/pi-scripts/secrets.enc.yaml"
    DECRYPT_DIR="$(mktemp -d)"

    echo "=== Decrypt Secrets (Phase 1) ==="
    echo "Decrypting to: $DECRYPT_DIR"

    decrypt_secrets "$ENCRYPTED" "$DECRYPT_DIR"

    echo "Decrypted secrets available at: $DECRYPT_DIR/secrets.dec.yaml"
    echo "Export DECRYPT_DIR=$DECRYPT_DIR for subsequent pipeline phases."
    echo ""
    echo "IMPORTANT: Run 'shred_secrets $DECRYPT_DIR' when deployment is complete."
fi

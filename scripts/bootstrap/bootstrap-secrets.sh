#!/usr/bin/env bash
set -euo pipefail

# scripts/bootstrap/bootstrap-secrets.sh
# Generate an age keypair and create .sops.yaml configuration.
# Sourced by tests (for function access) or run directly via make bootstrap-secrets.

# Generate an age keypair in the specified directory.
# Prints the public key to stdout.
# Returns non-zero if the key file already exists.
generate_keypair() {
    local target_dir="$1"
    local keyfile="$target_dir/age.key"

    if [ -f "$keyfile" ]; then
        echo "ERROR: $keyfile already exists. Remove it first to regenerate." >&2
        return 1
    fi

    mkdir -p "$target_dir"
    age-keygen -o "$keyfile" 2>&1
}

# Create a .sops.yaml file in the specified directory with the given public key.
create_sops_yaml() {
    local target_dir="$1"
    local pubkey="$2"

    cat > "$target_dir/.sops.yaml" <<EOF
# .sops.yaml -- SOPS configuration for age encryption
# Public key only -- private key must be in 1Password, NEVER in git.
creation_rules:
  - path_regex: secrets\.enc\.yaml$
    age: >-
      $pubkey
EOF
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    echo "=== Secrets Bootstrap ==="
    echo ""

    # Step 1: Generate keypair
    echo "Generating age keypair..."
    output=$(generate_keypair "$PROJECT_ROOT")
    pubkey=$(echo "$output" | grep '^Public key:' | awk '{print $3}')

    if [ -z "$pubkey" ]; then
        echo "ERROR: Failed to extract public key from age-keygen output." >&2
        exit 1
    fi

    echo "Public key: $pubkey"
    echo ""

    # Step 2: Create .sops.yaml
    echo "Creating .sops.yaml..."
    create_sops_yaml "$PROJECT_ROOT" "$pubkey"
    echo "Created $PROJECT_ROOT/.sops.yaml"
    echo ""

    # Step 3: Remind operator to back up private key
    echo "============================================"
    echo "  IMPORTANT: Back up your private key NOW"
    echo "============================================"
    echo ""
    echo "  1. Copy the private key from: $PROJECT_ROOT/age.key"
    echo "  2. Store it in 1Password (or your password manager)"
    echo "  3. Delete the local copy: rm $PROJECT_ROOT/age.key"
    echo ""
    echo "  The .gitignore already blocks age.key from git,"
    echo "  but do NOT leave it on disk long-term."
    echo "============================================"
fi

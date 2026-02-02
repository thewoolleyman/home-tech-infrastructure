#!/usr/bin/env bash
set -euo pipefail

# scripts/bootstrap/create-secrets.sh
# Create a secrets template and encrypt it with SOPS + age.
# Sourced by tests (for function access) or run directly.

# Generate a plaintext secrets template YAML at the given path.
generate_secrets_template() {
    local output_file="$1"

    cat > "$output_file" <<'EOF'
# Secrets for home-tech-infrastructure Pi deployments.
# Edit the REPLACE_ME values with real credentials, then encrypt with sops.
deploy_ssh_private_key: "REPLACE_ME"
namecheap_ddns_password: "REPLACE_ME"
pi_host_keys:
  bastion: "REPLACE_ME"
  dns: "REPLACE_ME"
  bastion-backup: "REPLACE_ME"
  dns-backup: "REPLACE_ME"
EOF
}

# Encrypt a plaintext YAML file into a SOPS-encrypted file.
# Extracts the age public key from the given .sops.yaml config.
encrypt_secrets() {
    local plaintext_file="$1"
    local encrypted_file="$2"
    local sops_config="$3"

    if [ -f "$encrypted_file" ]; then
        echo "ERROR: $encrypted_file already exists. Remove it first to re-encrypt." >&2
        return 1
    fi

    local pubkey
    pubkey=$(grep -oE 'age1[a-z0-9]+' "$sops_config" | head -1)
    if [ -z "$pubkey" ]; then
        echo "ERROR: No age public key found in $sops_config" >&2
        return 1
    fi

    sops --encrypt --age "$pubkey" --input-type yaml --output-type yaml \
         --output "$encrypted_file" "$plaintext_file"
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    SECRETS_DIR="$PROJECT_ROOT/infrastructure/pi-scripts"
    PLAINTEXT="$SECRETS_DIR/secrets.yaml"
    ENCRYPTED="$SECRETS_DIR/secrets.enc.yaml"
    SOPS_CONFIG="$PROJECT_ROOT/.sops.yaml"

    if [ ! -f "$SOPS_CONFIG" ]; then
        echo "ERROR: .sops.yaml not found. Run 'make bootstrap-secrets' first." >&2
        exit 1
    fi

    echo "=== Create Encrypted Secrets ==="
    echo ""

    # Step 1: Generate template
    echo "Generating secrets template..."
    generate_secrets_template "$PLAINTEXT"
    echo "Created $PLAINTEXT"
    echo ""
    echo "Edit $PLAINTEXT with real values, then re-run this script."
    echo "Or press Enter to encrypt the template as-is (with REPLACE_ME placeholders)."
    read -r

    # Step 2: Encrypt
    echo "Encrypting..."
    encrypt_secrets "$PLAINTEXT" "$ENCRYPTED" "$SOPS_CONFIG"
    echo "Created $ENCRYPTED"

    # Step 3: Shred plaintext
    echo "Removing plaintext..."
    rm -f "$PLAINTEXT"
    echo "Removed $PLAINTEXT"
    echo ""
    echo "Done. Commit $ENCRYPTED to git."
fi

#!/bin/bash
# Post-create setup script for Claude Code devcontainer
set -e

echo "=== Post-Create Setup Starting ==="

# Fix permissions for command history volume
# Docker volumes are created with root ownership, but we run as 'node' user
sudo chown -R node:node /commandhistory
touch /commandhistory/.zsh_history
touch /commandhistory/.bash_history

# Configure Terraform credentials for HCP Terraform
echo "Configuring Terraform credentials..."
mkdir -p ~/.terraform.d
cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF
echo "Terraform credentials configured"

# Setup internal CA certificates if configured
CERT_NAME="${INTERNAL_CA_CERT_NAME:-internal-ca-chain}"
CERT_PATH="/usr/local/share/ca-certificates/${CERT_NAME}.crt"

echo ""
SCRIPT_DIR="$(dirname "$0")"
"${SCRIPT_DIR}/../../scripts/setup-internal-certs.sh"

# If the cert was installed, set NODE_EXTRA_CA_CERTS so Node.js (and Claude) trust it
if [ -f "$CERT_PATH" ]; then
    echo "Setting NODE_EXTRA_CA_CERTS and OTEL_EXPORTER_OTLP_CERTIFICATE in shell profile"
    {
        echo ""
        echo "# Internal CA certs (added by post-create.sh)"
        echo "export NODE_EXTRA_CA_CERTS=\"$CERT_PATH\""
        echo "export OTEL_EXPORTER_OTLP_CERTIFICATE=\"$CERT_PATH\""
    } >> /home/node/.zshrc
fi

echo "=== Post-Create Setup Complete ==="

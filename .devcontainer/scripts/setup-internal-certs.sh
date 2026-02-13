#!/bin/bash
# Internal CA certificate setup for DevContainers
# Installs certificates from internal services into the system CA store
#
# This script is optional and skips gracefully when:
#   - INTERNAL_CA_HOST is not set (most users)
#   - The internal CA host is not reachable from the current network
#
# It is primarily needed when your OTEL collector or other internal services
# use TLS certificates signed by a private/corporate CA. Without these certs
# in the system trust store, OTEL exporters and tools like curl/Node.js will
# reject the TLS connection. If you're not sending telemetry to an internal
# endpoint, you can safely ignore the skip message.
set -e

# ============================================================================
# CONFIGURATION - UPDATE THESE VALUES FOR YOUR ENVIRONMENT
# ============================================================================
INTERNAL_HOST="${INTERNAL_CA_HOST:-}"
INTERNAL_IP="${INTERNAL_CA_IP:-}"
CERT_NAME="${INTERNAL_CA_CERT_NAME:-internal-ca-chain}"
# Additional hosts to add to /etc/hosts (colon-separated, like PATH)
# These will all resolve to INTERNAL_CA_IP
ADDITIONAL_HOSTS="${INTERNAL_CA_ADDITIONAL_HOSTS:-}"
# ============================================================================

if [ -z "$INTERNAL_HOST" ]; then
    echo "Skipping internal CA setup (INTERNAL_CA_HOST not set)"
    echo "  This is normal — internal CA certs are only needed when sending"
    echo "  telemetry (OTEL) to an endpoint that uses a private/corporate CA."
    exit 0
fi

CERT_DIR="/usr/local/share/ca-certificates"
CERT_PATH="${CERT_DIR}/${CERT_NAME}.crt"

echo "=== Internal CA Certificate Setup ==="
echo "Host: $INTERNAL_HOST"
[ -n "$INTERNAL_IP" ] && echo "IP:   $INTERNAL_IP"
echo ""

# Step 1: Add hostnames to /etc/hosts (if IP provided)
echo "[1/4] Configuring DNS resolution..."
if [ -z "$INTERNAL_IP" ]; then
    echo "  - Skipped (no IP provided, using DNS)"
else
    # Build list of all hosts to add (colon-separated)
    ALL_HOSTS="$INTERNAL_HOST"
    if [ -n "$ADDITIONAL_HOSTS" ]; then
        ALL_HOSTS="$ALL_HOSTS:$ADDITIONAL_HOSTS"
    fi

    # Split on colons
    IFS=':' read -ra HOST_ARRAY <<< "$ALL_HOSTS"
    for HOST in "${HOST_ARRAY[@]}"; do
        if grep -q "$HOST" /etc/hosts 2>/dev/null; then
            echo "  ✓ $HOST already in /etc/hosts"
        else
            echo "$INTERNAL_IP $HOST" | sudo tee -a /etc/hosts > /dev/null
            echo "  ✓ Added $HOST -> $INTERNAL_IP to /etc/hosts"
        fi
    done
fi

# Step 2: Extract and install certificate chain
echo "[2/4] Installing certificate chain..."

# Check if we already have certificates installed
EXISTING_CERTS=$(find "$CERT_DIR" -name "${CERT_NAME}*.crt" 2>/dev/null | wc -l)
if [ "$EXISTING_CERTS" -gt 0 ]; then
    echo "  ✓ Certificates already exist ($EXISTING_CERTS file(s))"
else
    # Try to extract from server
    echo "  Extracting certificate chain from $INTERNAL_HOST:443..."

    # Create temp file for the full chain
    TEMP_CHAIN=$(mktemp)
    trap "rm -f $TEMP_CHAIN" EXIT

    if ! openssl s_client -connect "${INTERNAL_HOST}:443" -showcerts </dev/null 2>/dev/null \
        | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ print }' > "$TEMP_CHAIN"; then
        echo "  ⚠ Could not connect to $INTERNAL_HOST:443 — skipping cert setup"
        echo "    This is safe to ignore if you are not on the internal network."
        echo "    OTEL and other TLS connections to this host will not work until certs are installed."
        exit 0
    fi

    CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" "$TEMP_CHAIN" 2>/dev/null || echo "0")
    if [ "$CERT_COUNT" -eq 0 ]; then
        echo "  ⚠ No certificates returned from $INTERNAL_HOST:443 — skipping cert setup"
        echo "    This is safe to ignore if you are not on the internal network."
        echo "    OTEL and other TLS connections to this host will not work until certs are installed."
        exit 0
    fi

    echo "  ✓ Extracted $CERT_COUNT certificate(s)"

    # Split certificates into individual files for update-ca-certificates
    # This ensures each CA cert in the chain is properly added to the trust store
    echo "  Splitting chain into individual certificates..."

    CERT_NUM=0
    CURRENT_CERT=""
    while IFS= read -r line; do
        CURRENT_CERT="${CURRENT_CERT}${line}"$'\n'
        if [[ "$line" == *"END CERTIFICATE"* ]]; then
            CERT_NUM=$((CERT_NUM + 1))
            if [ "$CERT_NUM" -eq 1 ]; then
                # First cert is usually the server cert, skip it - we only need CA certs
                # But save the full chain for NODE_EXTRA_CA_CERTS
                sudo cp "$TEMP_CHAIN" "$CERT_PATH"
                sudo chmod 644 "$CERT_PATH"
            else
                # Install intermediate and root CA certs separately
                INDIVIDUAL_CERT_PATH="${CERT_DIR}/${CERT_NAME}-ca${CERT_NUM}.crt"
                echo "$CURRENT_CERT" | sudo tee "$INDIVIDUAL_CERT_PATH" > /dev/null
                sudo chmod 644 "$INDIVIDUAL_CERT_PATH"
                echo "    ✓ Saved CA certificate #$CERT_NUM"
            fi
            CURRENT_CERT=""
        fi
    done < "$TEMP_CHAIN"

    echo "  ✓ Certificate chain installed"
fi

# Step 3: Update system CA certificates
echo "[3/4] Updating system CA store..."
RESULT=$(sudo update-ca-certificates --fresh 2>&1)
ADDED=$(echo "$RESULT" | grep -oP '\d+(?= added)' || echo "0")
echo "  ✓ CA store updated ($ADDED certificates added)"

# Step 4: Verify certificate trust
echo "[4/4] Verifying certificate trust..."

VERIFY_SUCCESS=true

# Use first additional host for verification if available (subdomains usually have valid certs)
# Fall back to INTERNAL_HOST if no additional hosts configured
VERIFY_HOST="${ADDITIONAL_HOSTS%%:*}"  # Get first colon-separated value
VERIFY_HOST="${VERIFY_HOST:-$INTERNAL_HOST}"
echo "  Testing against: $VERIFY_HOST"

# Test TLS handshake with curl (system CA)
echo -n "  curl (system CA): "
CURL_OUTPUT=$(curl -sv --connect-timeout 5 "https://${VERIFY_HOST}" -o /dev/null 2>&1) || true
if echo "$CURL_OUTPUT" | grep -q "SSL certificate verify ok"; then
    echo "✓ TLS handshake successful"
else
    VERIFY_SUCCESS=false
    echo "✗ TLS handshake failed"
    # Extract the specific error
    ERROR_MSG=$(echo "$CURL_OUTPUT" | grep -E "(SSL certificate problem|unable to get|certificate verify failed)" | head -1)
    if [ -n "$ERROR_MSG" ]; then
        echo "    Error: $ERROR_MSG"
    fi
    echo "    Debug: curl -v https://${VERIFY_HOST}"
fi

# Test with Node.js (custom CA)
echo -n "  node (NODE_EXTRA_CA_CERTS): "
NODE_EXIT_CODE=0
NODE_OUTPUT=$(NODE_EXTRA_CA_CERTS="$CERT_PATH" node -e "
    fetch('https://${VERIFY_HOST}')
        .then(() => { console.log('OK'); process.exit(0); })
        .catch((e) => { console.error(e.cause?.code || e.message); process.exit(1); })
" 2>&1) || NODE_EXIT_CODE=$?
if [ $NODE_EXIT_CODE -eq 0 ]; then
    echo "✓ TLS handshake successful"
else
    VERIFY_SUCCESS=false
    echo "✗ TLS handshake failed"
    echo "    Error: $NODE_OUTPUT"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Certificate chain installed at: $CERT_PATH"

# List all installed cert files
echo "Individual CA certificates:"
find "$CERT_DIR" -name "${CERT_NAME}*.crt" -exec basename {} \; | sed 's/^/  /'

echo ""
if [ "$VERIFY_SUCCESS" = true ]; then
    echo "✓ All verification checks passed"
else
    echo "⚠ Some verification checks failed - this may be expected if:"
    echo "  - The server requires authentication"
    echo "  - The endpoint returns non-200 status codes"
    echo "  - Network policies block direct access"
    echo ""
    echo "To manually verify TLS trust:"
    echo "  openssl s_client -connect ${VERIFY_HOST}:443 -CApath /etc/ssl/certs"
fi

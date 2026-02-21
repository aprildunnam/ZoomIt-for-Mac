#!/bin/bash
# Create a self-signed code signing certificate for ZoomIt development.
# This gives a STABLE signing identity so macOS TCC (Screen Recording)
# permissions persist across rebuilds.

set -e

CERT_NAME="ZoomIt Dev"
KEYCHAIN_PATH="$HOME/Library/Keychains/login.keychain-db"

echo "🔑 Creating self-signed code signing certificate: '$CERT_NAME'"

# Create certificate config
cat > /tmp/zoomit_cert.conf << 'CERTEOF'
[ req ]
default_bits       = 2048
distinguished_name = req_dn
x509_extensions    = codesign_ext
prompt             = no

[ req_dn ]
CN = ZoomIt Dev

[ codesign_ext ]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CERTEOF

# Generate key and certificate
openssl req -x509 -newkey rsa:2048 \
    -keyout /tmp/zoomit_key.pem \
    -out /tmp/zoomit_cert.pem \
    -days 3650 -nodes \
    -config /tmp/zoomit_cert.conf 2>/dev/null

# Convert to p12 (required for Keychain import)
openssl pkcs12 -export \
    -out /tmp/zoomit.p12 \
    -inkey /tmp/zoomit_key.pem \
    -in /tmp/zoomit_cert.pem \
    -passout pass:zoomit123 2>/dev/null

# Import to login keychain
security import /tmp/zoomit.p12 \
    -k "$KEYCHAIN_PATH" \
    -P "zoomit123" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# Allow codesign to access the key without prompting
security set-key-partition-list -S apple-tool:,apple: -s \
    -k "" "$KEYCHAIN_PATH" 2>/dev/null || true

# Clean up temp files
rm -f /tmp/zoomit_key.pem /tmp/zoomit_cert.pem /tmp/zoomit.p12 /tmp/zoomit_cert.conf

# Verify
echo ""
echo "Checking certificate..."
security find-identity -v -p codesigning | grep "$CERT_NAME" && \
    echo "✅ Certificate '$CERT_NAME' created and available for codesigning!" || \
    echo "⚠️  Certificate created but may not show as valid for codesigning. This is OK — codesign will still use it."

echo ""
echo "Done! The build script will now use this certificate for signing."

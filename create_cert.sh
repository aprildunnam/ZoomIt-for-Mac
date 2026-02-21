#!/bin/bash
# Create a self-signed code signing certificate for ZoomIt development.
# This gives a STABLE signing identity so macOS TCC (Screen Recording)
# permissions persist across rebuilds.

set -e

CERT_NAME="ZoomIt Dev"
KEYCHAIN_PATH="$HOME/Library/Keychains/login.keychain-db"
TMPDIR_CERT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_CERT"' EXIT

echo "🔑 Creating self-signed code signing certificate: '$CERT_NAME'"

# Create certificate config
cat > "$TMPDIR_CERT/cert.conf" << 'CERTEOF'
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

# Generate a random password for the p12 export
P12_PASS=$(openssl rand -base64 16)

# Generate key and certificate
openssl req -x509 -newkey rsa:2048 \
    -keyout "$TMPDIR_CERT/key.pem" \
    -out "$TMPDIR_CERT/cert.pem" \
    -days 3650 -nodes \
    -config "$TMPDIR_CERT/cert.conf" 2>/dev/null

# Convert to p12 (required for Keychain import)
openssl pkcs12 -export \
    -out "$TMPDIR_CERT/cert.p12" \
    -inkey "$TMPDIR_CERT/key.pem" \
    -in "$TMPDIR_CERT/cert.pem" \
    -passout "pass:$P12_PASS" 2>/dev/null

# Import to login keychain
security import "$TMPDIR_CERT/cert.p12" \
    -k "$KEYCHAIN_PATH" \
    -P "$P12_PASS" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# Allow codesign to access the key without prompting
security set-key-partition-list -S apple-tool:,apple: -s \
    -k "" "$KEYCHAIN_PATH" 2>/dev/null || true

# Temp files cleaned up automatically by trap

# Verify
echo ""
echo "Checking certificate..."
security find-identity -v -p codesigning | grep "$CERT_NAME" && \
    echo "✅ Certificate '$CERT_NAME' created and available for codesigning!" || \
    echo "⚠️  Certificate created but may not show as valid for codesigning. This is OK — codesign will still use it."

echo ""
echo "Done! The build script will now use this certificate for signing."

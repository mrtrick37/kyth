#!/bin/bash
set -euo pipefail

# Apply mt-OS branding to the base image
cat > /etc/os-release <<'EOF' || true
NAME="mt-OS"
PRETTY_NAME="mt-OS"
ID=mt-os
VERSION_ID="43"
HOME_URL="https://example.org/mt-os"
EOF

# Remove Waydroid artifacts if present
rm -f /usr/share/applications/*waydroid*.desktop || true
rm -f /usr/local/share/applications/*waydroid*.desktop || true
rm -f /usr/share/kservices5/*waydroid* || true
rm -rf /usr/share/waydroid /var/lib/waydroid || true

echo "mt-OS base customization applied"

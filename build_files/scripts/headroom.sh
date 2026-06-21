#!/bin/bash
# Install Headroom as a maintained KythOS image tool.

set -euo pipefail

HEADROOM_VERSION="${HEADROOM_VERSION:?HEADROOM_VERSION must be set}"
HEADROOM_EXTRAS="${HEADROOM_EXTRAS:-proxy,code,relevance}"
HEADROOM_PREFIX="${HEADROOM_PREFIX:-/usr/lib/headroom}"
HEADROOM_PYTHON="${HEADROOM_PYTHON:-python3.13}"

echo "━━━ Installing Headroom ${HEADROOM_VERSION} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Extras: ${HEADROOM_EXTRAS}"

dnf5 install -y --skip-unavailable \
	python3.13

rm -rf "${HEADROOM_PREFIX}"
install -d -m 0755 "$(dirname "${HEADROOM_PREFIX}")"
"${HEADROOM_PYTHON}" -m venv "${HEADROOM_PREFIX}"

"${HEADROOM_PREFIX}/bin/python" -m pip install --upgrade pip setuptools wheel
"${HEADROOM_PREFIX}/bin/python" -m pip install --prefer-binary \
	"headroom-ai[${HEADROOM_EXTRAS}]==${HEADROOM_VERSION}"

ln -sfn "${HEADROOM_PREFIX}/bin/headroom" /usr/bin/headroom

headroom --version
headroom --help >/dev/null

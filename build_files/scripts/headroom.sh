#!/bin/bash
# Install Headroom as a maintained KythOS image tool.

set -euo pipefail

HEADROOM_VERSION="${HEADROOM_VERSION:?HEADROOM_VERSION must be set}"
HEADROOM_EXTRAS="${HEADROOM_EXTRAS:-proxy,code,relevance}"
HEADROOM_PREFIX="${HEADROOM_PREFIX:-/opt/headroom}"

echo "━━━ Installing Headroom ${HEADROOM_VERSION} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Extras: ${HEADROOM_EXTRAS}"

dnf5 install -y --skip-unavailable \
	python3-pip \
	python3-virtualenv

rm -rf "${HEADROOM_PREFIX}"
mkdir -p "$(dirname "${HEADROOM_PREFIX}")"
python3 -m venv "${HEADROOM_PREFIX}"

"${HEADROOM_PREFIX}/bin/python" -m pip install --upgrade pip setuptools wheel
"${HEADROOM_PREFIX}/bin/python" -m pip install --prefer-binary \
	"headroom-ai[${HEADROOM_EXTRAS}]==${HEADROOM_VERSION}"

ln -sfn "${HEADROOM_PREFIX}/bin/headroom" /usr/bin/headroom

headroom --version
headroom --help >/dev/null

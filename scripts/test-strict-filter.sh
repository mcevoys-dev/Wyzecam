#!/usr/bin/env bash
# Apply the strict-filter patch to docker-wyze-bridge v4.5.0 and run the
# camera filter tests. No Wyze credentials and no container.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="${ROOT}/wyze_bridge_db3/patches/strict-filter.patch"
TARBALL_SHA256="318b8f1e41c2ffe994b326fbfac0ccbb84718ee24ee0ea76f3fe5943d693d2db"
TARBALL_URL="https://github.com/IDisposable/docker-wyze-bridge/archive/da56b956b9bfb8f426f8c2efda71f8f2851e76b8.tar.gz"
WORK="${ROOT}/dist/bridge-src"

if [[ -x "${HOME}/sdk/go1.26.4/bin/go" ]]; then
  export PATH="${HOME}/sdk/go1.26.4/bin:${PATH}"
fi
if ! go version | grep -q 'go1\.26\.4'; then
  echo "Go 1.26.4 is required so this matches golang:1.26.4-alpine. Found: $(go version)" >&2
  exit 1
fi
export GOTOOLCHAIN=local

rm -rf "${WORK}"
mkdir -p "${WORK}" "${ROOT}/dist"
curl -fsSL -o "${ROOT}/dist/docker-wyze-bridge-v4.5.0.tar.gz" "${TARBALL_URL}"
echo "${TARBALL_SHA256}  ${ROOT}/dist/docker-wyze-bridge-v4.5.0.tar.gz" | sha256sum -c
tar -xzf "${ROOT}/dist/docker-wyze-bridge-v4.5.0.tar.gz" -C "${WORK}" --strip-components=1
patch -p1 -d "${WORK}" --forward --input="${PATCH}"
(
  cd "${WORK}"
  go test ./internal/camera/ -count=1 -run 'TestFilter_' -v
)
rm -rf "${WORK}" "${ROOT}/dist/docker-wyze-bridge-v4.5.0.tar.gz"
echo "strict filter tests passed"

#!/usr/bin/env bash
# Rebuild the linux/amd64 go2rtc binary the app Dockerfile builds.
# Network is required for the upstream tarball and, on a cold module cache,
# for Go modules. No Wyze credentials are read.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="${ROOT}/wyze_bridge_db3/patches/wyzedb3-a42e34e-pkg-tutk.patch"
TARBALL_SHA256="78aa79bcedec8f155e4060a379613979b0b3ee48ff62ee5164bafc0ac6532386"
TARBALL_URL="https://github.com/AlexxIT/go2rtc/archive/b5948cfb25404cc5cb37b166ecaa2dca20b11d4b.tar.gz"
WORK="${ROOT}/dist/src"
OUT="${ROOT}/dist/go2rtc-linux-amd64"

if [[ -x "${HOME}/sdk/go/bin/go" ]]; then
  export PATH="${HOME}/sdk/go/bin:${PATH}"
fi
if ! go version | grep -q 'go1\.24\.'; then
  echo "Go 1.24.x is required so this matches golang:1.24.11-alpine. Found: $(go version)" >&2
  exit 1
fi
export GOTOOLCHAIN=local

rm -rf "${WORK}"
mkdir -p "${WORK}" "${ROOT}/dist"
curl -fsSL -o "${ROOT}/dist/go2rtc-v1.9.14.tar.gz" "${TARBALL_URL}"
echo "${TARBALL_SHA256}  ${ROOT}/dist/go2rtc-v1.9.14.tar.gz" | sha256sum -c
tar -xzf "${ROOT}/dist/go2rtc-v1.9.14.tar.gz" -C "${WORK}" --strip-components=1
patch -p1 -d "${WORK}" --forward --input="${PATCH}"
(
  cd "${WORK}"
  go test ./pkg/tutk/ ./pkg/tutk/dtls/ -count=1
)
sed -i 's/app.Version = "1.9.14"/app.Version = "1.9.14+wyzedb3.a42e34e"/' "${WORK}/main.go"
(
  cd "${WORK}"
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -buildvcs=false -ldflags '-s -w' -o "${OUT}" .
)
sha256sum "${OUT}" | tee "${ROOT}/dist/SHA256SUMS"
file "${OUT}"
echo "built ${OUT}"

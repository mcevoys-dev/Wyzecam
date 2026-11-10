# Home Assistant app image. linux/amd64 only.
# go2rtc: v1.9.14 plus the unreleased WYZEDB3 patch.
# Bridge: docker-wyze-bridge v4.5.0 source plus patches/strict-filter.patch.
# The published v4.5.0 image is not the bridge binary: that binary fail-opens
# an unmatched nickname to every camera.
# Upstream image digest, not pulled by this Dockerfile:
# idisposablegithub365/wyze-bridge linux/amd64
# sha256:02f21ef39c1c3bd70e7123b2503e3543bb8d2d703ecfd4de83288e29b7f45483

ARG BUILD_ARCH=amd64

FROM golang:1.24.11-alpine@sha256:1a97fbadb2eb46ba8e4bce6b08f45bc24ef0180d1f3b3192886a080c8268ba71 AS go2rtc-build
ENV GOTOOLCHAIN=local
RUN apk add --no-cache ca-certificates curl patch
WORKDIR /src
COPY patches/wyzedb3-a42e34e-pkg-tutk.patch /tmp/wyzedb3-a42e34e-pkg-tutk.patch
RUN curl -fsSL -o /tmp/go2rtc.tar.gz \
      "https://github.com/AlexxIT/go2rtc/archive/b5948cfb25404cc5cb37b166ecaa2dca20b11d4b.tar.gz" \
    && echo "78aa79bcedec8f155e4060a379613979b0b3ee48ff62ee5164bafc0ac6532386  /tmp/go2rtc.tar.gz" | sha256sum -c \
    && tar -xzf /tmp/go2rtc.tar.gz --strip-components=1 -C /src \
    && patch -p1 --forward --input=/tmp/wyzedb3-a42e34e-pkg-tutk.patch \
    && sed -i 's/app.Version = "1.9.14"/app.Version = "1.9.14+wyzedb3.a42e34e"/' main.go \
    && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
       go build -trimpath -buildvcs=false -ldflags '-s -w' -o /out/go2rtc .

FROM golang:1.26.4-alpine@sha256:0648ddfa35769070197ba1cdf22a16dc452caf9315e66b91791308a543baf229 AS bridge-build
ENV GOTOOLCHAIN=local
RUN apk add --no-cache ca-certificates curl patch
WORKDIR /src
COPY patches/strict-filter.patch /tmp/strict-filter.patch
COPY patches/host-listeners.patch /tmp/host-listeners.patch
COPY patches/kvs-ice-urls.patch /tmp/kvs-ice-urls.patch
RUN curl -fsSL -o /tmp/bridge.tar.gz \
      "https://github.com/IDisposable/docker-wyze-bridge/archive/da56b956b9bfb8f426f8c2efda71f8f2851e76b8.tar.gz" \
    && echo "318b8f1e41c2ffe994b326fbfac0ccbb84718ee24ee0ea76f3fe5943d693d2db  /tmp/bridge.tar.gz" | sha256sum -c \
    && tar -xzf /tmp/bridge.tar.gz --strip-components=1 -C /src \
    && patch -p1 --forward --input=/tmp/strict-filter.patch \
    && patch -p1 --forward --input=/tmp/host-listeners.patch \
    && patch -p1 --forward --input=/tmp/kvs-ice-urls.patch \
    && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
       go build -trimpath -buildvcs=false -ldflags '-s -w -X main.Version=4.5.0+strict-filter+hostnet+kvs' \
       -o /out/wyze-bridge ./cmd/wyze-bridge

FROM ghcr.io/home-assistant/base@sha256:ed340acf0a3a77a761b4d3ee2977ab5ddc44038304597e66b0ccfd859b8d8a1f
ARG BUILD_ARCH=amd64
ARG BUILD_VERSION=4.5.0-wyzedb3.6
LABEL io.hass.arch="${BUILD_ARCH}" \
      io.hass.type="app" \
      io.hass.version="${BUILD_VERSION}" \
      org.opencontainers.image.title="Wyze Bridge DB3" \
      org.opencontainers.image.description="docker-wyze-bridge v4.5.0 with a strict camera filter, plus unreleased go2rtc WYZEDB3 patch a42e34e" \
      org.opencontainers.image.licenses="AGPL-3.0-only AND MIT" \
      org.opencontainers.image.source="https://github.com/IDisposable/docker-wyze-bridge" \
      org.opencontainers.image.revision="da56b956b9bfb8f426f8c2efda71f8f2851e76b8" \
      org.opencontainers.image.version="4.5.0-wyzedb3.6" \
      com.wyzebridge.go2rtc.base="b5948cfb25404cc5cb37b166ecaa2dca20b11d4b" \
      com.wyzebridge.go2rtc.patch="a42e34e431e17e37e82e3bd988db43056e8b8d57" \
      com.wyzebridge.go2rtc.patch.status="unreleased" \
      com.wyzebridge.filter.patch="strict-filter" \
      com.wyzebridge.listeners.patch="host-listeners"
COPY --from=bridge-build /out/wyze-bridge /usr/local/bin/wyze-bridge
COPY --from=go2rtc-build /out/go2rtc /usr/local/bin/go2rtc
COPY LICENSES/ /usr/local/share/licenses/
COPY PROVENANCE.md /usr/local/share/wyze-bridge-db3/PROVENANCE.md
COPY run.sh /run.sh
RUN apk add --no-cache iproute2 \
    && chmod 0755 /run.sh /usr/local/bin/wyze-bridge /usr/local/bin/go2rtc
CMD ["/run.sh"]
